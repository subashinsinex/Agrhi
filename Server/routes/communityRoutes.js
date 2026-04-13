const express = require("express");
const router = express.Router();
const path = require("path");
const fs = require("fs");
const multer = require("multer");
const jwtChecker = require("../middleware/jwtChecker");
const { asyncLocalStorage } = require("../db/database");
const communityServices = require("../services/communityServices");

// ─── Multer Setup ─────────────────────────────────────────────────

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dest = file.mimetype.startsWith("video/")
      ? "uploads/community/videos/raw/"
      : "uploads/community/images/";
    cb(null, dest);
  },
  filename: (req, file, cb) => {
    const unique = `${Date.now()}_${Math.round(Math.random() * 1e6)}${path.extname(file.originalname)}`;
    cb(null, unique);
  },
});

const fileFilter = (req, file, cb) => {
  const allowed = /jpeg|jpg|png|webp|mp4|mov|avi|mkv|webm/;
  const ext = path.extname(file.originalname).toLowerCase().replace(".", "");
  allowed.test(ext)
    ? cb(null, true)
    : cb(new Error("Only images and videos allowed"), false);
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
});

// ─── Feed ─────────────────────────────────────────────────────────

router.get("/getPosts", jwtChecker, async (req, res) => {
  try {
    const { page, limit, category } = req.query;
    const posts = await communityServices.getPosts(
      req.user_id,
      page,
      limit,
      category,
    );
    res.json(posts);
  } catch (error) {
    console.error("Route getPosts error:", error);
    res.status(500).json({ message: "Error fetching posts" });
  }
});

// ─── Create Post ──────────────────────────────────────────────────

router.post(
  "/createPost",
  jwtChecker,
  upload.single("media"),
  async (req, res) => {
    await asyncLocalStorage.run({ userId: req.user_id }, async () => {
      try {
        const { content, category } = req.body;
        if (!content || content.trim() === "") {
          return res.status(400).json({ message: "Content cannot be empty" });
        }
        const post = await communityServices.createPost(
          req.user_id,
          content.trim(),
          category,
          req.file,
        );
        res.status(201).json(post);
      } catch (error) {
        console.error("Route createPost error:", error);
        res.status(500).json({ message: "Error creating post" });
      }
    });
  },
);

// ─── Delete Post ──────────────────────────────────────────────────

router.delete("/deletePost/:postId", jwtChecker, async (req, res) => {
  try {
    const result = await communityServices.deletePost(
      req.user_id,
      req.params.postId,
    );
    res.json(result);
  } catch (error) {
    console.error("Route deletePost error:", error);
    if (error.message === "Not authorized or post not found") {
      return res.status(403).json({ message: error.message });
    }
    res.status(500).json({ message: "Error deleting post" });
  }
});

// ─── Toggle Like ──────────────────────────────────────────────────

router.post("/toggleLike/:postId", jwtChecker, async (req, res) => {
  try {
    const result = await communityServices.toggleLike(
      req.user_id,
      req.params.postId,
    );
    res.json(result);
  } catch (error) {
    console.error("Route toggleLike error:", error);
    res.status(500).json({ message: "Error toggling like" });
  }
});

// ─── Get Comments ─────────────────────────────────────────────────

router.get("/getComments/:postId", jwtChecker, async (req, res) => {
  try {
    const comments = await communityServices.getComments(
      req.user_id,
      req.params.postId,
    );
    res.json(comments);
  } catch (error) {
    console.error("Route getComments error:", error);
    res.status(500).json({ message: "Error fetching comments" });
  }
});

// ─── Add Comment ──────────────────────────────────────────────────

router.post("/addComment/:postId", jwtChecker, async (req, res) => {
  try {
    const { content } = req.body;
    if (!content || content.trim() === "") {
      return res.status(400).json({ message: "Comment cannot be empty" });
    }
    const comment = await communityServices.addComment(
      req.user_id,
      req.params.postId,
      content.trim(),
    );
    res.status(201).json(comment);
  } catch (error) {
    console.error("Route addComment error:", error);
    res.status(500).json({ message: "Error adding comment" });
  }
});

// ─── Delete Comment ───────────────────────────────────────────────

router.delete(
  "/deleteComment/:postId/:commentId",
  jwtChecker,
  async (req, res) => {
    try {
      const result = await communityServices.deleteComment(
        req.user_id,
        req.params.postId,
        req.params.commentId,
      );
      res.json(result);
    } catch (error) {
      console.error("Route deleteComment error:", error);
      if (error.message === "Not authorized or comment not found") {
        return res.status(403).json({ message: error.message });
      }
      res.status(500).json({ message: "Error deleting comment" });
    }
  },
);

// ─── Stream Video ─────────────────────────────────────────────────

router.get("/stream/:filename", (req, res) => {
  const { filename } = req.params;

  if (!/^[\w\-]+\.mp4$/.test(filename)) {
    return res.status(400).json({ message: "Invalid filename" });
  }

  const videoPath = path.join(
    __dirname,
    "../uploads/community/videos/compressed",
    filename,
  );

  if (!fs.existsSync(videoPath)) {
    return res.status(202).json({ message: "Video is still processing" });
  }

  const fileSize = fs.statSync(videoPath).size;
  const range = req.headers.range;

  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Accept-Ranges", "bytes");
  res.setHeader("Content-Type", "video/mp4");

  if (!range) {
    res.writeHead(200, { "Content-Length": fileSize });
    fs.createReadStream(videoPath).pipe(res);
    return;
  }

  const [startStr, endStr] = range.replace(/bytes=/, "").split("-");
  const start = parseInt(startStr, 10);
  const end = endStr ? parseInt(endStr, 10) : fileSize - 1;

  res.writeHead(206, {
    "Content-Range": `bytes ${start}-${end}/${fileSize}`,
    "Content-Length": end - start + 1,
  });

  fs.createReadStream(videoPath, { start, end }).pipe(res);
});

// ─── My Posts ─────────────────────────────────────────────────────

router.get("/getMyPosts", jwtChecker, async (req, res) => {
  try {
    const { page, limit } = req.query;
    const posts = await communityServices.getMyPosts(req.user_id, page, limit);
    res.json(posts);
  } catch (error) {
    console.error("Route getMyPosts error:", error);
    res.status(500).json({ message: "Error fetching my posts" });
  }
});

// ─── Update Post ──────────────────────────────────────────────────

router.put("/updatePost/:postId", jwtChecker, async (req, res) => {
  try {
    const { content } = req.body;
    if (!content || content.trim() === "") {
      return res.status(400).json({ message: "Content cannot be empty" });
    }
    const post = await communityServices.updatePost(
      req.user_id,
      req.params.postId,
      content.trim(),
    );
    res.json(post);
  } catch (error) {
    console.error("Route updatePost error:", error);
    if (error.message === "Not authorized or post not found") {
      return res.status(403).json({ message: error.message });
    }
    res.status(500).json({ message: "Error updating post" });
  }
});

module.exports = router;
