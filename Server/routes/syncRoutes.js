const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const jwtChecker = require("../middleware/jwtChecker");
const syncServices = require("../services/syncServices");
const db = require("../db/database");
const logger = require("../utils/logger");

// Setup uploads directory
const uploadsDir = "uploads/images";
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
  logger.server(`Created uploads directory: ${uploadsDir}`);
}

// Multer disk storage config
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const filename = req.body.image_id
      ? `${req.body.image_id}${ext}`
      : `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;
    cb(null, filename);
  },
});

// Accept JPEG, PNG, and octet-stream files up to 10MB
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = [
      "image/jpeg",
      "image/jpg",
      "image/png",
      "application/octet-stream",
    ];
    const ok =
      allowed.includes(file.mimetype.toLowerCase()) ||
      /\.(jpg|jpeg|png)$/i.test(file.originalname.toLowerCase());
    cb(null, ok);
  },
});

// Batch upload analyses metadata
router.post("/batch-upload", jwtChecker, async (req, res) => {
  
  try {
    if (!req.user_id) {
      return res
        .status(401)
        .json({ error: "Authentication failed", success: false });
    }

    const { analyses } = req.body;

    if (!Array.isArray(analyses) || analyses.length === 0) {
      return res
        .status(400)
        .json({ error: "No analyses provided", success: false });
    }

    if (analyses.some((a) => a.user_id !== req.user_id)) {
      return res
        .status(403)
        .json({ error: "User ID mismatch in analyses", success: false });
    }

    const result = await syncServices.batchUploadAnalyses(
      req.user_id,
      analyses,
    );
    res.status(200).json(result);
  } catch (error) {
    logger.error("POST /batch-upload - Error:", error);
    res
      .status(500)
      .json({
        error: "Internal server error",
        success: false,
        message: error.message,
      });
  }
});

// Download analysis changes (incremental sync)
router.get("/changes", jwtChecker, async (req, res) => {
  
  try {
    if (!req.user_id) {
      return res
        .status(401)
        .json({ error: "Authentication failed", success: false });
    }

    const result = await syncServices.getAnalysisChanges(
      req.user_id,
      req.query.since,
    );
    res.status(200).json(result);
  } catch (error) {
    logger.error("GET /changes - Error:", error);
    res
      .status(500)
      .json({ error: "Internal server error", message: error.message });
  }
});

// Upload single image with metadata
router.post(
  "/images/upload",
  jwtChecker,
  upload.single("image"),
  async (req, res) => {
    
    try {
      if (!req.user_id) {
        return res
          .status(401)
          .json({ error: "Authentication failed", success: false });
      }

      const { image_id } = req.body;

      if (!image_id) {
        return res
          .status(400)
          .json({ error: "image_id is required", success: false });
      }

      if (!req.file) {
        return res
          .status(400)
          .json({ error: "No image file provided", success: false });
      }

      const serverImageUrl = `/uploads/images/${req.file.filename}`;
      await syncServices.saveImageMetadata(image_id, serverImageUrl);

      res.status(200).json({
        success: true,
        server_image_url: serverImageUrl,
        image_id,
        filename: req.file.filename,
        size: req.file.size,
      });
    } catch (error) {
      logger.error("POST /images/upload - Error:", error);
      res
        .status(500)
        .json({
          error: "Internal server error",
          success: false,
          message: error.message,
        });
    }
  },
);

// Get sync status and analysis/image counts
router.get("/sync/status", jwtChecker, async (req, res) => {
  
  try {
    if (!req.user_id) {
      return res
        .status(401)
        .json({ error: "Authentication failed", success: false });
    }

    const userId = req.user_id;

    const [analysisCount, imageCount] = await Promise.all([
      db.pool.query(
        "SELECT COUNT(*) as count FROM disease_analysis_results WHERE user_id = $1",
        [userId],
      ),
      db.pool.query(
        "SELECT COUNT(*) as count FROM images WHERE image_id IN (SELECT image_id FROM disease_analysis_results WHERE user_id = $1)",
        [userId],
      ),
    ]);

    res.status(200).json({
      success: true,
      user_id: userId,
      total_analyses: parseInt(analysisCount.rows[0].count),
      total_images: parseInt(imageCount.rows[0].count),
      server_time: new Date().toISOString(),
    });
  } catch (error) {
    logger.error("GET /sync/status - Error:", error);
    res
      .status(500)
      .json({ error: "Internal server error", message: error.message });
  }
});

module.exports = router;
