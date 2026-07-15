const express = require("express");
const router = express.Router();
const emailVerificationService = require("../services/emailVerificationService");
const jwt = require("../middleware/jwtChecker");
const logger = require("../utils/logger");

// Send OTP to user's registered email
router.post("/send-otp", jwt, async (req, res) => {
  
  try {
    const result = await emailVerificationService.sendVerificationOTP({
      userId: req.user_id,
      ipAddress: req.clientIp || req.ip,
    });

    if (!result.success) {
      return res.status(400).json(result);
    }
    res.json(result);
  } catch (error) {
    logger.error("POST /send-otp - Error:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

// Verify OTP and mark email as verified
router.post("/verify-otp", jwt, async (req, res) => {
  
  try {
    const { otp } = req.body;

    if (!otp) {
      return res
        .status(400)
        .json({ success: false, message: "OTP is required" });
    }

    // Validate 6-digit OTP format
    if (!/^\d{6}$/.test(otp)) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid OTP format" });
    }

    const result = await emailVerificationService.verifyOTP({
      userId: req.user_id,
      otp,
      ipAddress: req.clientIp || req.ip,
    });

    if (!result.success) {
      return res.status(400).json(result);
    }
    res.json(result);
  } catch (error) {
    logger.error("POST /verify-otp - Error:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

// Resend OTP with cooldown enforcement
router.post("/resend-otp", jwt, async (req, res) => {
  
  try {
    const result = await emailVerificationService.resendOTP({
      userId: req.user_id,
      ipAddress: req.clientIp || req.ip,
    });

    if (!result.success) {
      return res.status(400).json(result);
    }
    res.json(result);
  } catch (error) {
    logger.error("POST /resend-otp - Error:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

// Get email verification status
router.get("/status", jwt, async (req, res) => {
  
  try {
    const result = await emailVerificationService.getVerificationStatus(
      req.user_id,
    );
    res.json(result);
  } catch (error) {
    logger.error("GET /status - Error:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

module.exports = router;
