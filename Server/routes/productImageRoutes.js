const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const jwtChecker = require("../middleware/jwtChecker");
const productImageService = require("../services/productImageServices");

// Ensure uploads/product_image exists
const uploadsDir = path.join(__dirname, "..", "uploads", "product_image");
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
  console.log("Created uploads directory:", uploadsDir);
}

// Multer storage for product images
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const filename = `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;
    cb(null, filename);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = ["image/jpeg", "image/jpg", "image/png"];
    const ok =
      allowed.includes(file.mimetype.toLowerCase()) ||
      /\.(jpg|jpeg|png)$/i.test(file.originalname.toLowerCase());

    if (ok) return cb(null, true);

    console.log("Invalid product image:", file.mimetype, file.originalname);
    return cb(null, false);
  },
});

// ✅ Apply jwtChecker to all routes in this router
router.use(jwtChecker);

// POST /api/product-images/upload
// For retail products
// form-data:
//   - product_id: text
//   - image: file
router.post("/upload", upload.single("image"), async (req, res) => {
  try {
    if (!req.user_id) {
      return res
        .status(401)
        .json({ success: false, error: "Authentication failed" });
    }

    const { product_id } = req.body;
    const file = req.file;

    if (!product_id || product_id === "" || product_id === "undefined") {
      return res.status(400).json({
        success: false,
        error: "Valid product_id (UUID) is required",
      });
    }

    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(product_id)) {
      return res.status(400).json({
        success: false,
        error: "Invalid product_id format (must be UUID)",
      });
    }

    if (!file) {
      return res
        .status(400)
        .json({ success: false, error: "No image file provided" });
    }

    const result = await productImageService.saveProductImage(file, product_id);

    return res.status(200).json({
      success: true,
      image_id: result.image_id,
      image_url: result.image_url,
      product: result.product,
    });
  } catch (error) {
    console.error("product-image upload error:", error);
    res.status(500).json({
      success: false,
      error: "Internal server error",
      message: error.message,
    });
  }
});

// POST /api/product-images/upload-farm
// For farm products
// form-data:
//   - product_id: text
//   - image: file
router.post("/upload-farm", upload.single("image"), async (req, res) => {
  try {
    if (!req.user_id) {
      return res
        .status(401)
        .json({ success: false, error: "Authentication failed" });
    }

    const { product_id } = req.body;
    const file = req.file;

    if (!product_id || product_id === "" || product_id === "undefined") {
      return res.status(400).json({
        success: false,
        error: "Valid product_id (UUID) is required",
      });
    }

    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(product_id)) {
      return res.status(400).json({
        success: false,
        error: "Invalid product_id format (must be UUID)",
      });
    }

    if (!file) {
      return res
        .status(400)
        .json({ success: false, error: "No image file provided" });
    }

    const result = await productImageService.saveFarmProductImage(
      file,
      product_id,
    );

    return res.status(200).json({
      success: true,
      image_id: result.image_id,
      image_url: result.image_url,
      product: result.product,
    });
  } catch (error) {
    console.error("farm-product-image upload error:", error);
    res.status(500).json({
      success: false,
      error: "Internal server error",
      message: error.message,
    });
  }
});

module.exports = router;
