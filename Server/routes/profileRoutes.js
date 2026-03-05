const express = require("express");
const router = express.Router();
const profileServices = require("../services/profileServices");
const jwtChecker = require("../middleware/jwtChecker");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const { compressImageInPlace } = require("../utils/imageCompressor");
const logger = require("../utils/logger");

// Setup profile images upload directory
const profileImagesDir = path.join(
  __dirname,
  "..",
  "uploads",
  "profile_images",
);
if (!fs.existsSync(profileImagesDir)) {
  fs.mkdirSync(profileImagesDir, { recursive: true });
  logger.server(`Created profile images directory: ${profileImagesDir}`);
}

// Multer disk storage config
const profileStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, profileImagesDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  },
});

// Accept JPEG, PNG, WEBP files up to 20MB
const profileUpload = multer({
  storage: profileStorage,
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = ["image/jpeg", "image/jpg", "image/png", "image/webp"];
    const ok =
      allowed.includes(file.mimetype.toLowerCase()) ||
      /\.(jpg|jpeg|png|webp)$/i.test(file.originalname.toLowerCase());
    cb(null, ok);
  },
});

// Upload or replace profile photo
router.post(
  "/upload-photo",
  jwtChecker,
  profileUpload.single("image"),
  async (req, res) => {
    
    try {
      if (!req.file) {
        return res.status(400).json({
          success: false,
          message:
            "No image file provided or file type not allowed. Supported: JPG, PNG, WEBP",
        });
      }

      if (!req.user_id) {
        return res
          .status(401)
          .json({ success: false, message: "User not authenticated" });
      }

      const userId = req.user_id;
      const file = req.file;

      // Delete old profile picture from disk if it exists
      const oldPicUrl = await profileServices.getProfilePictureUrl(userId);
      if (
        oldPicUrl &&
        oldPicUrl !== "no-image" &&
        !oldPicUrl.includes("default")
      ) {
        try {
          const oldFilePath = path.join(
            __dirname,
            "../uploads/profile_images",
            path.basename(oldPicUrl),
          );
          if (fs.existsSync(oldFilePath)) fs.unlinkSync(oldFilePath);
        } catch (deleteError) {
          logger.error(
            "POST /upload-photo - Failed to delete old picture:",
            deleteError,
          );
        }
      }

      // Compress and save new image
      const picUrl = `/uploads/profile_images/${file.filename}`;
      await compressImageInPlace(path.join(__dirname, "..", picUrl), {
        width: 512,
        quality: 70,
      });
      await profileServices.updateProfilePictureUrl(userId, picUrl);

      res.json({ success: true, pic_url: picUrl });
    } catch (error) {
      logger.error("POST /upload-photo - Error:", error);

      // Cleanup failed upload file
      if (req.file) {
        try {
          fs.unlinkSync(req.file.path);
        } catch (cleanupError) {
          logger.error("POST /upload-photo - Cleanup failed:", cleanupError);
        }
      }

      res.status(500).json({ success: false, message: error.message });
    }
  },
);

// Get user details by user_id
router.get("/getUserDetails/:user_id", jwtChecker, async (req, res) => {
  
  try {
    const user = await profileServices.getUserById(req.params.user_id);
    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "User not found" });
    }
    res.json(user);
  } catch (error) {
    logger.error("GET /getUserDetails - Error:", {
      user_id: req.params.user_id,
      error,
    });
    res
      .status(500)
      .json({ success: false, message: "Error fetching user details" });
  }
});

// Register new user
router.post("/createUser", async (req, res) => {
  
  try {
    const result = await profileServices.createUser(req.body);
    res
      .status(201)
      .json({
        success: true,
        message: "User registered successfully",
        user: result,
      });
  } catch (error) {
    logger.error("POST /createUser - Error:", error);
    const duplicateErrors = [
      "Phone number already exist",
      "Email already exist",
      "Phone number and email already exist",
    ];
    if (duplicateErrors.includes(error.message)) {
      return res.status(400).json({ success: false, message: error.message });
    }
    res.status(500).json({ success: false, message: "Error creating user" });
  }
});

// Update user profile (own profile only)
router.put("/updateUser/:userid", jwtChecker, async (req, res) => {
  
  try {
    const user_id = req.params.userid;
    if (req.user_id !== user_id) {
      return res
        .status(403)
        .json({
          success: false,
          message: "You can only update your own profile",
        });
    }
    const result = await profileServices.updateUser(user_id, req.body);
    res.json({ success: true, ...result });
  } catch (error) {
    logger.error("PUT /updateUser - Error:", {
      user_id: req.params.userid,
      error,
    });
    res.status(500).json({ success: false, message: "Error updating user" });
  }
});

// Remove profile picture (own profile only)
router.delete(
  "/remove-profile-picture/:user_id",
  jwtChecker,
  async (req, res) => {
    
    try {
      const userId = req.params.user_id;
      if (req.user_id !== userId) {
        return res
          .status(403)
          .json({
            success: false,
            message: "You can only remove your own profile picture",
          });
      }

      const user = await profileServices.getUserById(userId);
      if (!user) {
        return res
          .status(404)
          .json({ success: false, message: "User not found" });
      }

      // Delete file from disk if it exists
      if (user.pic_url && user.pic_url !== "no-image") {
        const filePath = path.join(__dirname, "..", user.pic_url);
        if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
      }

      await profileServices.updateProfilePictureUrl(userId, "no-image");
      res.json({ success: true, message: "Profile picture removed" });
    } catch (error) {
      logger.error("DELETE /remove-profile-picture - Error:", {
        userId: req.params.user_id,
        error,
      });
      res.status(500).json({ success: false, message: error.message });
    }
  },
);

module.exports = router;
