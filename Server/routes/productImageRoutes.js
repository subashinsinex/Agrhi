const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const jwtChecker = require("../middleware/jwtChecker");
const productImageService = require("../services/productImageServices");
const logger = require("../utils/logger");

// Setup product images upload directory
const uploadsDir = path.join(__dirname, "..", "uploads", "product_image");
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
  logger.server(`Created product images directory: ${uploadsDir}`);
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

const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

// Shared validator for product_id and file presence
function validateUpload(product_id, file, res) {
  if (!product_id || product_id === "" || product_id === "undefined") {
    res
      .status(400)
      .json({ success: false, error: "Valid product_id (UUID) is required" });
    return false;
  }
  if (!uuidRegex.test(product_id)) {
    res
      .status(400)
      .json({
        success: false,
        error: "Invalid product_id format (must be UUID)",
      });
    return false;
  }
  if (!file) {
    res.status(400).json({ success: false, error: "No image file provided" });
    return false;
  }
  return true;
}

router.use(jwtChecker);

// Upload image for retail product
router.post("/upload", upload.single("image"), async (req, res) => {
  
  try {
    if (!req.user_id) {
      return res
        .status(401)
        .json({ success: false, error: "Authentication failed" });
    }

    const { product_id } = req.body;
    if (!validateUpload(product_id, req.file, res)) return;

    const result = await productImageService.saveProductImage(
      req.file,
      product_id,
    );

    return res.status(200).json({
      success: true,
      image_id: result.image_id,
      image_url: result.image_url,
      product: result.product,
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

// Upload image for farm product
router.post("/upload-farm", upload.single("image"), async (req, res) => {
  
  try {
    if (!req.user_id) {
      return res
        .status(401)
        .json({ success: false, error: "Authentication failed" });
    }

    const { product_id } = req.body;
    if (!validateUpload(product_id, req.file, res)) return;

    const result = await productImageService.saveFarmProductImage(
      req.file,
      product_id,
    );

    return res.status(200).json({
      success: true,
      image_id: result.image_id,
      image_url: result.image_url,
      product: result.product,
    });
  } catch (error) {
    logger.error("POST /upload-farm - Error:", error);
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
