const express = require("express");
const router = express.Router();
const profileServices = require("../services/profileServices");
const jwtChecker = require("../middleware/jwtChecker");
const multer = require("multer");
const path = require("path");
const fs = require("fs");

const profileImagesDir = path.join(
  __dirname,
  "..",
  "uploads",
  "profile_images"
);
if (!fs.existsSync(profileImagesDir)) {
  fs.mkdirSync(profileImagesDir, { recursive: true });
  console.log("✅ Created uploads directory:", profileImagesDir);
}

const profileStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, profileImagesDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const filename = `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;
    cb(null, filename);
  },
});

const profileUpload = multer({
  storage: profileStorage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = ["image/jpeg", "image/jpg", "image/png", "image/webp"];
    const ok =
      allowed.includes(file.mimetype.toLowerCase()) ||
      /\.(jpg|jpeg|png|webp)i?$/i.test(file.originalname.toLowerCase());

    if (ok) {
      console.log("✅ File accepted:", file.mimetype, file.originalname);
      return cb(null, true);
    }

    console.log("❌ File rejected:", file.mimetype, file.originalname);
    return cb(null, false);
  },
});

router.post(
  "/upload-photo",
  jwtChecker,
  profileUpload.single("image"),
  async (req, res) => {
    try {
      console.log("📥 Upload request received:");
      console.log("  - req.user_id:", req.user_id);
      console.log("  - File:", req.file?.filename);
      console.log("  - File size:", req.file?.size, "bytes");

      const file = req.file;

      if (!file) {
        return res.status(400).json({
          success: false,
          message:
            "No image file provided or file type not allowed. Supported: JPG, PNG, WEBP",
        });
      }

      if (!req.user_id) {
        console.error("❌ req.user_id is not set by jwtChecker middleware");
        return res.status(401).json({
          success: false,
          message: "User not authenticated - JWT middleware failed",
        });
      }

      const userId = req.user_id;
      console.log("✅ Authenticated user_id:", userId);

      const oldPicUrl = await profileServices.getProfilePictureUrl(userId);
      console.log("🔍 Old pic_url:", oldPicUrl);

      if (
        oldPicUrl &&
        oldPicUrl !== "no-image" &&
        !oldPicUrl.includes("default")
      ) {
        try {
          const oldFilename = path.basename(oldPicUrl);
          const oldFilePath = path.join(
            __dirname,
            "../uploads/profile_images",
            oldFilename
          );

          if (fs.existsSync(oldFilePath)) {
            fs.unlinkSync(oldFilePath);
            console.log("🗑️ Deleted old profile picture:", oldFilePath);
          } else {
            console.log("ℹ️ Old file not found:", oldFilePath);
          }
        } catch (deleteError) {
          console.error("⚠️ Error deleting old profile picture:", deleteError);
        }
      }

      const picUrl = `/uploads/profile_images/${file.filename}`;

      const result = await profileServices.updateProfilePictureUrl(
        userId,
        picUrl
      );

      console.log("✅ Profile picture uploaded successfully");
      console.log("   - User ID:", userId);
      console.log("   - Old Pic URL:", oldPicUrl || "None");
      console.log("   - New Pic URL:", picUrl);

      res.json({
        success: true,
        pic_url: picUrl,
      });
    } catch (error) {
      console.error("❌ Upload photo error:", error);

      if (req.file) {
        try {
          fs.unlinkSync(req.file.path);
          console.log("🗑️ Deleted failed upload file:", req.file.path);
        } catch (cleanupError) {
          console.error("⚠️ Error cleaning up failed upload:", cleanupError);
        }
      }

      res.status(500).json({ success: false, message: error.message });
    }
  }
);

router.get("/getUserDetails/:user_id", jwtChecker, async (req, res) => {
  try {
    const { user_id } = req.params;
    const user = await profileServices.getUserById(user_id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.json(user);
  } catch (error) {
    console.error("Error fetching user details:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching user details",
    });
  }
});

router.post("/createUser", async (req, res) => {
  try {
    const newUser = req.body;
    const result = await profileServices.createUser(newUser);

    res.status(201).json({
      success: true,
      message: "User registered successfully",
      user: result,
    });
  } catch (error) {
    console.error("Route createUser error:", error);
    if (
      error.message === "Phone number already exist" ||
      error.message === "Email already exist" ||
      error.message === "Phone number and email already exist"
    ) {
      res.status(400).json({
        success: false,
        message: error.message,
      });
    } else {
      res.status(500).json({
        success: false,
        message: "Error creating user",
      });
    }
  }
});

router.put("/updateUser/:userid", jwtChecker, async (req, res) => {
  try {
    const user_id = req.params.userid;
    const updatedUser = req.body;

    if (req.user_id !== user_id) {
      return res.status(403).json({
        success: false,
        message: "You can only update your own profile",
      });
    }

    const result = await profileServices.updateUser(user_id, updatedUser);
    res.json({
      success: true,
      ...result,
    });
  } catch (error) {
    console.error("Route updateUser error:", error);
    res.status(500).json({
      success: false,
      message: "Error updating user",
    });
  }
});

router.delete(
  "/remove-profile-picture/:user_id",
  jwtChecker,
  async (req, res) => {
    try {
      const userId = req.params.user_id;

      if (req.user_id !== userId) {
        return res.status(403).json({
          success: false,
          message: "You can only remove your own profile picture",
        });
      }

      const user = await profileServices.getUserById(userId);

      if (!user) {
        return res.status(404).json({
          success: false,
          message: "User not found",
        });
      }

      const currentPicUrl = user.pic_url;

      if (currentPicUrl && currentPicUrl !== "no-image") {
        const filePath = path.join(__dirname, "..", currentPicUrl);

        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
          console.log("🗑️ Deleted file:", filePath);
        }
      }

      await profileServices.updateProfilePictureUrl(userId, "no-image");

      console.log("✅ Profile picture removed for user:", userId);

      res.json({
        success: true,
        message: "Profile picture removed",
      });
    } catch (error) {
      console.error("❌ Error removing profile picture:", error);
      res.status(500).json({
        success: false,
        message: error.message,
      });
    }
  }
);

module.exports = router;
