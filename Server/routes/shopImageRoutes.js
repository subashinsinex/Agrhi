// routes/shopImageRoutes.js
const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const fs = require("fs");

const jwtChecker = require("../middleware/jwtChecker");
const shopImageService = require("../services/shopImageServices");

// Ensure uploads/shop_images exists
const uploadsDir = path.join(__dirname, "..", "uploads", "shop_images");
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
  console.log(`✅ Created uploads directory: ${uploadsDir}`);
}

// Multer storage for shop images
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
    console.log("❌ Invalid shop image:", file.mimetype, file.originalname);
    return cb(null, false);
  },
});

/**
 * POST /api/shop-images/upload
 * form-data:
 *   - retailer_id (text)
 *   - image (file)
 *
 * 1) Save file to uploads/shop_images
 * 2) Insert into images
 * 3) Update retailers.image_id
 */
router.post(
  "/upload",
  jwtChecker,
  upload.single("image"), // field name in form-data
  async (req, res) => {
    try {
      if (!req.user_id) {
        return res
          .status(401)
          .json({ success: false, error: "Authentication failed" });
      }

      const { retailer_id } = req.body;
      const file = req.file;

      if (!retailer_id) {
        return res
          .status(400)
          .json({ success: false, error: "retailer_id is required" });
      }
      if (!file) {
        return res
          .status(400)
          .json({ success: false, error: "No image file provided" });
      }

      const result = await shopImageService.saveShopImageForRetailer(
        file,
        retailer_id
      );

      return res.status(200).json({
        success: true,
        image_id: result.image_id,
        image_url: result.image_url,
        retailer: result.retailer,
      });
    } catch (error) {
      console.error("shop-image upload error:", error);
      res.status(500).json({
        success: false,
        error: "Internal server error",
        message: error.message,
      });
    }
  }
);

module.exports = router;
