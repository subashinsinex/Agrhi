const express = require("express");
const router = express.Router();
const forgotPasswordService = require("../services/forgotPasswordService");
const logger = require("../utils/logger");

// Request password reset via mobile number
router.post("/request", async (req, res) => {
  
  try {
    const { mobile } = req.body;

    if (!mobile) {
      return res
        .status(400)
        .json({ success: false, message: "Mobile number is required" });
    }

    if (!/^\d{10}$/.test(mobile)) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid mobile number format" });
    }

    const result = await forgotPasswordService.requestPasswordReset({
      mobile,
      ipAddress: req.clientIp || req.ip,
      userAgent: req.headers["user-agent"],
    });

    res.json(result);
  } catch (error) {
    logger.error("POST /request - Error:", error);
    res
      .status(500)
      .json({
        success: false,
        message: "An error occurred. Please try again later.",
      });
  }
});

// Verify reset token validity
router.post("/verify-token", async (req, res) => {
  
  try {
    const { token } = req.body;

    if (!token) {
      return res
        .status(400)
        .json({ success: false, message: "Token is required" });
    }

    const result = await forgotPasswordService.verifyResetToken(token);

    if (!result.success) {
      return res.status(400).json(result);
    }

    res.json(result);
  } catch (error) {
    logger.error("POST /verify-token - Error:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

// Reset password using valid token
router.post("/reset", async (req, res) => {
  
  try {
    const { token, newPassword } = req.body;

    if (!token || !newPassword) {
      return res
        .status(400)
        .json({
          success: false,
          message: "Token and new password are required",
        });
    }

    if (newPassword.length < 8) {
      return res
        .status(400)
        .json({
          success: false,
          message: "Password must be at least 8 characters long",
        });
    }

    if (!/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/.test(newPassword)) {
      return res.status(400).json({
        success: false,
        message:
          "Password must contain at least one uppercase letter, one lowercase letter, and one number",
      });
    }

    const result = await forgotPasswordService.resetPassword({
      token,
      newPassword,
      ipAddress: req.clientIp || req.ip,
    });

    if (!result.success) {
      return res.status(400).json(result);
    }

    res.json(result);
  } catch (error) {
    logger.error("POST /reset - Error:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

// Check rate limit status for mobile number
router.get("/status/:mobile", async (req, res) => {
  
  try {
    const { mobile } = req.params;

    if (!mobile || !/^\d{10}$/.test(mobile)) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid mobile number" });
    }

    const result = await forgotPasswordService.checkResetStatus(mobile);
    res.json(result);
  } catch (error) {
    logger.error("GET /status/:mobile - Error:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

module.exports = router;
