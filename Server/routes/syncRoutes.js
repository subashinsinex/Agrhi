const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const jwtChecker = require("../middleware/jwtChecker");
const syncServices = require("../services/syncServices");

// Ensure uploads directory exists
const uploadsDir = "uploads/images";
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
  console.log(`✅ Created uploads directory: ${uploadsDir}`);
}

// Configure multer for image uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    // Use image_id from request as filename base (if available)
    const imageId = req.body.image_id;
    const ext = path.extname(file.originalname);
    const filename = imageId
      ? `${imageId}${ext}`
      : `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;
    cb(null, filename);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    console.log("📎 Checking file:", {
      fieldname: file.fieldname,
      originalname: file.originalname,
      mimetype: file.mimetype,
    });

    const allowedMimetypes = [
      "image/jpeg",
      "image/jpg",
      "image/png",
      "application/octet-stream",
    ];

    const allowedExtensions = /\.(jpg|jpeg|png)$/i;

    const hasValidMimetype = allowedMimetypes.includes(
      file.mimetype.toLowerCase(),
    );
    const hasValidExtension = allowedExtensions.test(
      file.originalname.toLowerCase(),
    );

    if (hasValidMimetype || hasValidExtension) {
      console.log("✅ File accepted");
      return cb(null, true);
    } else {
      console.log("❌ File rejected - mimetype:", file.mimetype);
      return cb(null, false);
    }
  },
});

// ================= DISEASE ANALYSIS TWO-WAY SYNC ROUTES =================

/**
 * POST /api/sync/batch-upload
 * Batch upload analyses (metadata only, no images)
 */
router.post("/batch-upload", jwtChecker, async (req, res) => {
  try {
    console.log("📥 Batch upload request received");

    if (!req.user_id) {
      console.log("❌ req.user_id is undefined");
      return res.status(401).json({
        error: "Authentication failed",
        success: false,
      });
    }

    const { analyses } = req.body;
    const userId = req.user_id;

    console.log("User ID:", userId);
    console.log("Analyses count:", analyses?.length);

    if (!Array.isArray(analyses) || analyses.length === 0) {
      console.log("❌ No analyses provided");
      return res.status(400).json({
        error: "No analyses provided",
        success: false,
      });
    }

    console.log(`📤 Receiving ${analyses.length} analyses from user ${userId}`);

    // Validate that all analyses belong to the authenticated user
    const invalidAnalyses = analyses.filter((a) => a.user_id !== userId);
    if (invalidAnalyses.length > 0) {
      console.log(`❌ User ID mismatch`);
      return res.status(403).json({
        error: "User ID mismatch in analyses",
        success: false,
      });
    }

    const result = await syncServices.batchUploadAnalyses(userId, analyses);
    res.status(200).json(result);
  } catch (error) {
    console.error("❌ Batch upload error:", error);
    res.status(500).json({
      error: "Internal server error",
      success: false,
      message: error.message,
    });
  }
});

/**
 * GET /api/sync/changes
 * Download analyses changes (incremental sync)
 */
router.get("/changes", jwtChecker, async (req, res) => {
  try {
    if (!req.user_id) {
      console.log("❌ req.user_id is undefined");
      return res.status(401).json({
        error: "Authentication failed",
        success: false,
      });
    }

    const { since } = req.query;
    const userId = req.user_id;

    const result = await syncServices.getAnalysisChanges(userId, since);
    res.status(200).json(result);
  } catch (error) {
    console.error("❌ Download error:", error);
    res.status(500).json({
      error: "Internal server error",
      message: error.message,
    });
  }
});

/**
 * POST /api/images/upload
 * Upload image file with image_id
 * Client sends: image_id (form field) + image file
 * Server returns: server_image_url (location on server)
 */
router.post(
  "/images/upload",
  jwtChecker,
  upload.single("image"),
  async (req, res) => {
    try {
      console.log("📥 Image upload request received");

      if (!req.user_id) {
        console.log("❌ req.user_id is undefined");
        return res.status(401).json({
          error: "Authentication failed",
          success: false,
        });
      }

      const { image_id } = req.body;
      const file = req.file;

      console.log("📷 Image ID:", image_id);
      console.log("📁 File:", file ? file.filename : "No file");

      if (!image_id) {
        console.log("❌ Missing image_id");
        return res.status(400).json({
          error: "image_id is required",
          success: false,
        });
      }

      if (!file) {
        console.log("❌ No file uploaded");
        return res.status(400).json({
          error: "No image file provided",
          success: false,
        });
      }

      // Server URL where the image is stored
      const serverImageUrl = `/uploads/images/${file.filename}`;

      // Save image metadata to database
      await syncServices.saveImageMetadata(image_id, serverImageUrl);

      console.log(`✅ Image uploaded successfully: ${image_id}`);

      res.status(200).json({
        success: true,
        server_image_url: serverImageUrl,
        image_id: image_id,
        filename: file.filename,
        size: file.size,
      });
    } catch (error) {
      console.error("❌ Image upload error:", error);
      res.status(500).json({
        error: "Internal server error",
        success: false,
        message: error.message,
      });
    }
  },
);

/**
 * GET /api/sync/status
 * Get sync status for debugging
 */
router.get("/sync/status", jwtChecker, async (req, res) => {
  try {
    console.log("📥 Status request received");

    if (!req.user_id) {
      console.log("❌ req.user_id is undefined");
      return res.status(401).json({
        error: "Authentication failed",
        success: false,
      });
    }

    const userId = req.user_id;
    const db = require("../db/database");

    const analysisCount = await db.pool.query(
      "SELECT COUNT(*) as count FROM disease_analysis_results WHERE user_id = $1",
      [userId],
    );

    const imageCount = await db.pool.query(
      "SELECT COUNT(*) as count FROM images WHERE image_id IN (SELECT image_id FROM disease_analysis_results WHERE user_id = $1)",
      [userId],
    );

    res.status(200).json({
      success: true,
      user_id: userId,
      total_analyses: parseInt(analysisCount.rows[0].count),
      total_images: parseInt(imageCount.rows[0].count),
      server_time: new Date().toISOString(),
    });
  } catch (error) {
    console.error("❌ Status error:", error);
    res.status(500).json({
      error: "Internal server error",
      message: error.message,
    });
  }
});

module.exports = router;
