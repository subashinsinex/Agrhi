// routes/forgotPasswordRoutes.js
const express = require("express");
const router = express.Router();
const forgotPasswordService = require("../services/forgotPasswordService");

/**
 * @route   POST /api/forgot-password/request
 * @desc    Request password reset via mobile number
 * @access  Public
 */
router.post("/request", async (req, res) => {
  try {
    const { mobile } = req.body;

    // Validate input
    if (!mobile) {
      return res.status(400).json({
        success: false,
        message: "Mobile number is required",
      });
    }

    // Validate mobile format (10 digits)
    if (!/^\d{10}$/.test(mobile)) {
      return res.status(400).json({
        success: false,
        message: "Invalid mobile number format",
      });
    }

    // Get IP address for security logging
    const ipAddress = req.ip || req.connection.remoteAddress;
    const userAgent = req.headers["user-agent"];

    const result = await forgotPasswordService.requestPasswordReset({
      mobile,
      ipAddress,
      userAgent,
    });

    res.json(result);
  } catch (error) {
    console.error("Forgot password request error:", error);
    res.status(500).json({
      success: false,
      message: "An error occurred. Please try again later.",
    });
  }
});

/**
 * @route   POST /api/forgot-password/verify-token
 * @desc    Verify reset token validity
 * @access  Public
 */
router.post("/verify-token", async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({
        success: false,
        message: "Token is required",
      });
    }

    const result = await forgotPasswordService.verifyResetToken(token);

    if (!result.success) {
      return res.status(400).json(result);
    }

    res.json(result);
  } catch (error) {
    console.error("Verify token error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

/**
 * @route   POST /api/forgot-password/reset
 * @desc    Reset password with valid token
 * @access  Public
 */
router.post("/reset", async (req, res) => {
  try {
    const { token, newPassword } = req.body;

    // Validate inputs
    if (!token || !newPassword) {
      return res.status(400).json({
        success: false,
        message: "Token and new password are required",
      });
    }

    // Validate password strength
    if (newPassword.length < 8) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 8 characters long",
      });
    }

    // Optional: Additional password strength validation
    if (!/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/.test(newPassword)) {
      return res.status(400).json({
        success: false,
        message:
          "Password must contain at least one uppercase letter, one lowercase letter, and one number",
      });
    }

    const ipAddress = req.ip || req.connection.remoteAddress;

    const result = await forgotPasswordService.resetPassword({
      token,
      newPassword,
      ipAddress,
    });

    if (!result.success) {
      return res.status(400).json(result);
    }

    res.json(result);
  } catch (error) {
    console.error("Reset password error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

/**
 * @route   GET /api/forgot-password/status/:mobile
 * @desc    Check if user can request password reset (rate limit check)
 * @access  Public
 */
router.get("/status/:mobile", async (req, res) => {
  try {
    const { mobile } = req.params;

    if (!mobile || !/^\d{10}$/.test(mobile)) {
      return res.status(400).json({
        success: false,
        message: "Invalid mobile number",
      });
    }

    const result = await forgotPasswordService.checkResetStatus(mobile);

    res.json(result);
  } catch (error) {
    console.error("Check status error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

module.exports = router;
