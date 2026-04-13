const path = require("path");
const fs = require("fs");
const ffmpeg = require("fluent-ffmpeg");
const ffmpegPath = require("ffmpeg-static");
const ffprobePath = require("ffprobe-static").path;
const { query } = require("../db/database");

ffmpeg.setFfmpegPath(ffmpegPath);
ffmpeg.setFfprobePath(ffprobePath);

// ─── Ensure Upload Folders ────────────────────────────────────────

const DIRS = [
  "uploads/community/images",
  "uploads/community/videos/raw",
  "uploads/community/videos/compressed",
  "uploads/community/thumbnails",
];
DIRS.forEach((dir) => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

// ─── Row Normalizer ───────────────────────────────────────────────
// Ensures booleans and integers are always the correct JS type
// regardless of how the pg driver serializes them.

const normalizePost = (row) => ({
  ...row,
  likes_count: parseInt(row.likes_count) || 0,
  comments_count: parseInt(row.comments_count) || 0,
  video_duration:
    row.video_duration != null ? parseInt(row.video_duration) : null,
  is_liked_by_me: row.is_liked_by_me === true || row.is_liked_by_me === "true",
  is_my_post: row.is_my_post === true || row.is_my_post === "true",
  is_processing: row.is_processing === true || row.is_processing === "true",
});

// ─── Video Helpers ────────────────────────────────────────────────

const moveToCompressed = (inputPath, outputFilename) => {
  return new Promise((resolve, reject) => {
    const outputPath = `uploads/community/videos/compressed/${outputFilename}`;
    try {
      fs.renameSync(inputPath, outputPath);
      resolve(outputPath);
    } catch (err) {
      try {
        fs.copyFileSync(inputPath, outputPath);
        fs.unlinkSync(inputPath);
        resolve(outputPath);
      } catch (copyErr) {
        reject(copyErr);
      }
    }
  });
};

const generateThumbnail = (videoPath, thumbFilename) => {
  return new Promise((resolve, reject) => {
    ffmpeg(videoPath)
      .screenshots({
        timestamps: ["00:00:01"],
        filename: thumbFilename,
        folder: "uploads/community/thumbnails",
        size: "480x?",
      })
      .on("end", () => resolve(`uploads/community/thumbnails/${thumbFilename}`))
      .on("error", reject);
  });
};

const getVideoDuration = (videoPath) => {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(videoPath, (err, metadata) => {
      if (err) reject(err);
      else resolve(Math.round(metadata.format.duration));
    });
  });
};

// ─── Background Video Processor ──────────────────────────────────

const _processVideoInBackground = async (postId, file) => {
  try {
    const baseName = path.basename(file.path, path.extname(file.path));
    const compressedFilename = `compressed_${baseName}.mp4`;
    const thumbFilename = `thumb_${Date.now()}.jpg`;

    const compressedPath = await moveToCompressed(
      file.path,
      compressedFilename,
    );

    const [, duration] = await Promise.all([
      generateThumbnail(compressedPath, thumbFilename),
      getVideoDuration(compressedPath),
    ]);

    if (duration > 35) {
      fs.unlinkSync(compressedPath);
      throw new Error("Video exceeds 30 second limit");
    }

    await query(
      `UPDATE community_posts
       SET media_url       = $1,
           video_thumbnail = $2,
           video_duration  = $3,
           is_processing   = false
       WHERE id = $4`,
      [
        `/${compressedPath}`,
        `/uploads/community/thumbnails/${thumbFilename}`,
        duration,
        postId,
      ],
    );

    console.log(`✅ Video processed for post ${postId} (${duration}s)`);
  } catch (err) {
    console.error(`❌ Video processing failed for post ${postId}:`, err);
    await query(
      `UPDATE community_posts
       SET is_processing = false, media_url = NULL, media_type = 'none'
       WHERE id = $1`,
      [postId],
    ).catch(() => {});
  }
};

// ─── Post Services ────────────────────────────────────────────────

const getPosts = async (userId, page = 1, limit = 10, category) => {
  const pageNum = parseInt(page) || 1;
  const limitNum = parseInt(limit) || 10;
  const offset = (pageNum - 1) * limitNum;
  const params = [userId];

  let baseQuery = `
    SELECT
      cp.id, cp.content, cp.category,
      cp.media_url, cp.media_type,
      cp.video_thumbnail, cp.video_duration, cp.is_processing,
      cp.likes_count, cp.comments_count, cp.created_at,
      ud.name     AS author_name,
      ud.pic_url  AS author_pic,
      EXISTS (
        SELECT 1 FROM post_likes pl
        WHERE pl.post_id = cp.id AND pl.user_id = $1::uuid
      ) AS is_liked_by_me,
      (cp.user_id = $1::uuid) AS is_my_post
    FROM community_posts cp
    JOIN user_details ud ON ud.user_id = cp.user_id
  `;

  if (category && category !== "all") {
    params.push(category);
    baseQuery += ` WHERE cp.category = $${params.length}`;
  }

  baseQuery += ` ORDER BY cp.created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
  params.push(limitNum, offset);

  const result = await query(baseQuery, params);
  // ✅ normalize every row so Flutter always gets correct bool/int types
  return result.rows.map(normalizePost);
};

const createPost = async (userId, content, category, file) => {
  const isVideo = file?.mimetype.startsWith("video/");

  const mediaType = file ? (isVideo ? "video" : "image") : "none";
  const mediaUrl = file
    ? isVideo
      ? `/uploads/community/videos/raw/${file.filename}`
      : `/uploads/community/images/${file.filename}`
    : null;

  const result = await query(
    `INSERT INTO community_posts
      (user_id, content, category, media_url, media_type,
       video_thumbnail, video_duration, is_processing)
     VALUES ($1::uuid, $2, $3, $4, $5, NULL, NULL, $6)
     RETURNING *`,
    [userId, content, category || "general", mediaUrl, mediaType, !!isVideo],
  );

  const post = result.rows[0];

  if (isVideo) {
    _processVideoInBackground(post.id, file).catch((err) =>
      console.error("Unhandled bg video error:", err),
    );
  }

  return normalizePost(post);
};

const deletePost = async (userId, postId) => {
  const result = await query(
    `DELETE FROM community_posts
     WHERE id = $1 AND user_id = $2::uuid
     RETURNING id, media_url, video_thumbnail`,
    [postId, userId],
  );

  if (result.rows.length === 0)
    throw new Error("Not authorized or post not found");

  const { media_url, video_thumbnail } = result.rows[0];
  [media_url, video_thumbnail].forEach((filePath) => {
    if (!filePath) return;
    const abs = path.join(__dirname, "..", filePath);
    try {
      if (fs.existsSync(abs)) fs.unlinkSync(abs);
    } catch (_) {}
  });

  return result.rows[0];
};

// ─── Like Services ────────────────────────────────────────────────

const toggleLike = async (userId, postId) => {
  const existing = await query(
    `SELECT id FROM post_likes WHERE post_id = $1 AND user_id = $2::uuid`,
    [postId, userId],
  );

  if (existing.rows.length > 0) {
    await query(
      `DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2::uuid`,
      [postId, userId],
    );
    await query(
      `UPDATE community_posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = $1`,
      [postId],
    );
    return { liked: false };
  }

  await query(
    `INSERT INTO post_likes (post_id, user_id) VALUES ($1, $2::uuid)`,
    [postId, userId],
  );
  await query(
    `UPDATE community_posts SET likes_count = likes_count + 1 WHERE id = $1`,
    [postId],
  );
  return { liked: true };
};

// ─── Comment Services ─────────────────────────────────────────────

const getComments = async (userId, postId) => {
  const result = await query(
    `SELECT
      pc.id, pc.content, pc.created_at,
      ud.name    AS author_name,
      ud.pic_url AS author_pic,
      (pc.user_id = $2::uuid) AS is_my_comment
     FROM post_comments pc
     JOIN user_details ud ON ud.user_id = pc.user_id
     WHERE pc.post_id = $1
     ORDER BY pc.created_at ASC`,
    [postId, userId],
  );
  return result.rows.map((row) => ({
    ...row,
    // ✅ normalize bool here too
    is_my_comment: row.is_my_comment === true || row.is_my_comment === "true",
  }));
};

const addComment = async (userId, postId, content) => {
  const result = await query(
    `INSERT INTO post_comments (post_id, user_id, content)
     VALUES ($1, $2::uuid, $3)
     RETURNING id, content, created_at`,
    [postId, userId, content],
  );
  await query(
    `UPDATE community_posts SET comments_count = comments_count + 1 WHERE id = $1`,
    [postId],
  );
  return result.rows[0];
};

const deleteComment = async (userId, postId, commentId) => {
  const result = await query(
    `DELETE FROM post_comments WHERE id = $1 AND user_id = $2::uuid RETURNING id`,
    [commentId, userId],
  );
  if (result.rows.length === 0)
    throw new Error("Not authorized or comment not found");
  await query(
    `UPDATE community_posts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = $1`,
    [postId],
  );
  return result.rows[0];
};

// ─── My Posts ─────────────────────────────────────────────────────

const getMyPosts = async (userId, page = 1, limit = 20) => {
  const pageNum = parseInt(page) || 1;
  const limitNum = parseInt(limit) || 20;
  const offset = (pageNum - 1) * limitNum;

  const result = await query(
    `SELECT
      cp.id, cp.content, cp.category,
      cp.media_url, cp.media_type,
      cp.video_thumbnail, cp.video_duration, cp.is_processing,
      cp.likes_count, cp.comments_count,
      cp.created_at, cp.updated_at,
      ud.name     AS author_name,
      ud.pic_url  AS author_pic,
      true        AS is_my_post,
      EXISTS (
        SELECT 1 FROM post_likes pl
        WHERE pl.post_id = cp.id AND pl.user_id = $1::uuid
      ) AS is_liked_by_me
    FROM community_posts cp
    JOIN user_details ud ON ud.user_id = cp.user_id
    WHERE cp.user_id = $1::uuid
    ORDER BY cp.created_at DESC
    LIMIT $2 OFFSET $3`,
    [userId, limitNum, offset],
  );
  // ✅ normalize every row
  return result.rows.map(normalizePost);
};

// ─── Update Post ──────────────────────────────────────────────────

const updatePost = async (userId, postId, content) => {
  const result = await query(
    `UPDATE community_posts
     SET content = $1, updated_at = NOW()
     WHERE id = $2 AND user_id = $3::uuid
     RETURNING id, content, category, media_url, media_type,
               video_thumbnail, video_duration, is_processing,
               likes_count, comments_count, created_at, updated_at`,
    [content.trim(), postId, userId],
  );
  if (result.rows.length === 0)
    throw new Error("Not authorized or post not found");
  return normalizePost(result.rows[0]);
};

module.exports = {
  getPosts,
  getMyPosts,
  createPost,
  updatePost,
  deletePost,
  toggleLike,
  getComments,
  addComment,
  deleteComment,
};
