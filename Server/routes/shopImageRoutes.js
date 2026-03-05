const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const jwtChecker = require("../middleware/jwtChecker");
const shopImageService = require("../services/shopImageServices");
const logger = require("../utils/logger");

// Setup shop images upload directory
const uploadsDir = path.join(__dirname, "..", "uploads", "shop_images");
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
  logger.server(`Created shop images directory: ${uploadsDir}`);
}

// Multer disk storage config
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  },
});

// Accept only JPEG and PNG files up to 10MB
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = ["image/jpeg", "image/jpg", "image/png"];
    const ok =
      allowed.includes(file.mimetype.toLowerCase()) ||
      /\.(jpg|jpeg|png)$/i.test(file.originalname.toLowerCase());
    cb(null, ok);
  },
});

// Upload shop image for retailer
router.post("/upload", jwtChecker, upload.single("image"), async (req, res) => {
  
  try {
    if (!req.user_id) {
      return res
        .status(401)
        .json({ success: false, error: "Authentication failed" });
    }

    const { retailer_id } = req.body;

    if (!retailer_id) {
      return res
        .status(400)
        .json({ success: false, error: "retailer_id is required" });
    }

    if (!req.file) {
      return res
        .status(400)
        .json({ success: false, error: "No image file provided" });
    }

    const result = await shopImageService.saveShopImageForRetailer(
      req.file,
      retailer_id,
    );

    return res.status(200).json({
      success: true,
      image_id: result.image_id,
      image_url: result.image_url,
      retailer: result.retailer,
    });
  } catch (error) {
    logger.error("POST /upload - Error:", error);
    res
      .status(500)
      .json({
        success: false,
        error: "Internal server error",
        message: error.message,
      });
  }
});

module.exports = router;
