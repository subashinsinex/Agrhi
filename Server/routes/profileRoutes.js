const express = require("express");
const router = express.Router();
const profileServices = require("../services/profileServices");
const jwtChecker = require("../middleware/jwtChecker");
const multer = require("multer");
const path = require("path");
const fs = require("fs");

// Ensure uploads/profile_images exists
const profileImagesDir = path.join(
  __dirname,
  "..",
  "uploads",
  "profile_images"
);
if (!fs.existsSync(profileImagesDir)) {
  fs.mkdirSync(profileImagesDir, { recursive: true });
  console.log("Created uploads directory:", profileImagesDir);
}

// Multer storage for profile images
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
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    const allowed = ["image/jpeg", "image/jpg", "image/png"];
    const ok =
      allowed.includes(file.mimetype.toLowerCase()) ||
      /\.(jpg|jpeg|png)i?$/i.test(file.originalname.toLowerCase());
    if (ok) return cb(null, true);
    console.log("Invalid profile image:", file.mimetype, file.originalname);
    return cb(null, false);
  },
});

// POST /api/profile/upload-photo - form-data: image file (auth required)
router.post(
  "/upload-photo",
  jwtChecker,
  profileUpload.single("image"),
  async (req, res) => {
    try {
      const imageId = req.body.image_id;
      const file = req.file;
      if (!imageId) {
        return res
          .status(400)
          .json({ success: false, message: "image_id is required" });
      }
      if (!file) {
        return res
          .status(400)
          .json({ success: false, message: "No image file provided" });
      }
      const imageUrl = `/uploads/profileimages/${file.filename}`;
      const result = await profileServices.updateProfileImageUrl(
        imageId,
        imageUrl
      );
      res.json({
        success: true,
        image_id: result.imageid,
        image_url: result.imageurl,
      });
    } catch (error) {
      console.error("Upload photo error:", error);
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

router.get("/getUserDetails/:user_id", jwtChecker, async (req, res) => {
  try {
    const { user_id } = req.params; // ✅ Get user_id from URL
    const user = await profileServices.getUserById(user_id);

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(user);
  } catch (error) {
    console.error("Error fetching user details:", error);
    res.status(500).json({ message: "Error fetching user details" });
  }
});

router.post("/createUser", async (req, res) => {
  try {
    const newUser = req.body; // ✅ user registration data
    const result = await profileServices.createUser(newUser); // ✅ call createUser

    res.status(201).json({
      message: "User registered successfully",
      user: result,
    });
  } catch (error) {
    console.error("Route createUser error:", error);
    // Check error message for known validation failure
    if (
      error.message === "Phone number already exist" ||
      error.message === "Email already exist" ||
      error.message === "Phone number and email already exist"
    ) {
      res.status(400).json({ message: error.message });
    } else {
      res.status(500).json({ message: "Error creating user" });
    }
  }
});

router.put("/updateUser/:userid", jwtChecker, async (req, res) => {
  try {
    const user_id = req.params.userid;
    const updatedUser = req.body;
    const result = await profileServices.updateUser(user_id, updatedUser);
    res.json(result);
  } catch (error) {
    console.error("Route putUser error:", error);
    res.status(500).json({ message: "Error updating user" });
  }
});

router.get("/get-image-url/:imageId", jwtChecker, async (req, res) => {
  try {
    const { imageId } = req.params;
    const imageUrl = await profileServices.getImageURL(imageId);
    res.json({ success: true, image_url: imageUrl });
  } catch (error) {
    console.error("Error fetching image id:", error);
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
