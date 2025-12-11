// routes/emailVerificationRoutes.js
const express = require("express");
const router = express.Router();
const emailVerificationService = require("../services/emailVerificationService");
const jwt = require("../middleware/jwtChecker");

/**
 * @route   POST /api/email-verification/send-otp
 * @desc    Send OTP to user's email for verification
 * @access  Private (requires authentication)
 */
router.post("/send-otp", jwt, async (req, res) => {
  try {
    const userId = req.user_id; // From JWT token

    // Get real client IP (works behind WiFi/proxy/NAT)
    const ipAddress = req.clientIp || req.ip;

    const result = await emailVerificationService.sendVerificationOTP({
      userId,
      ipAddress,
    });

    if (!result.success) {
      return res.status(400).json(result);
    }

    res.json(result);
  } catch (error) {
    console.error("Send OTP error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

/**
 * @route   POST /api/email-verification/verify-otp
 * @desc    Verify OTP and mark email as verified
 * @access  Private (requires authentication)
 */
router.post("/verify-otp", jwt, async (req, res) => {
  try {
    const userId = req.user_id;
    const { otp } = req.body;

    if (!otp) {
      return res.status(400).json({
        success: false,
        message: "OTP is required",
      });
    }

    // Validate OTP format (6 digits)
    if (!/^\d{6}$/.test(otp)) {
      return res.status(400).json({
        success: false,
        message: "Invalid OTP format",
      });
    }

    // Get real client IP
    const ipAddress = req.clientIp || req.ip;

    const result = await emailVerificationService.verifyOTP({
      userId,
      otp,
      ipAddress,
    });

    if (!result.success) {
      return res.status(400).json(result);
    }

    res.json(result);
  } catch (error) {
    console.error("Verify OTP error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

/**
 * @route   POST /api/email-verification/resend-otp
 * @desc    Resend OTP (with cooldown)
 * @access  Private (requires authentication)
 */
router.post("/resend-otp", jwt, async (req, res) => {
  try {
    const userId = req.user_id;

    // Get real client IP
    const ipAddress = req.clientIp || req.ip;

    const result = await emailVerificationService.resendOTP({
      userId,
      ipAddress,
    });

    if (!result.success) {
      return res.status(400).json(result);
    }

    res.json(result);
  } catch (error) {
    console.error("Resend OTP error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

/**
 * @route   GET /api/email-verification/status
 * @desc    Check email verification status
 * @access  Private (requires authentication)
 */
router.get("/status", jwt, async (req, res) => {
  try {
    const userId = req.user_id;

    const result = await emailVerificationService.getVerificationStatus(userId);

    res.json(result);
  } catch (error) {
    console.error("Get verification status error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

module.exports = router;
