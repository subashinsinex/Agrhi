// Email OTP verification service
const crypto = require("crypto");
const pool = require("../db/database");
const emailService = require("../utils/emailSender");
const logger = require("../utils/logger");

class EmailVerificationService {
  // Send OTP to user's registered email
  async sendVerificationOTP({ userId, ipAddress }) {
    logger.info("sendVerificationOTP - Request", { userId });

    try {
      // Fetch user email and verification status
      const userResult = await pool.query(
        `SELECT ua.email, ua.email_verified, ud.name
        FROM users_auth ua
        LEFT JOIN user_details ud ON ua.user_id = ud.user_id
        WHERE ua.user_id = $1`,
        [userId],
      );

      if (userResult.rows.length === 0) {
        logger.error("sendVerificationOTP - User not found", { userId });
        return { success: false, message: "User not found" };
      }

      const user = userResult.rows[0];
      const username = user.name || "User";

      if (user.email_verified) {
        logger.info("sendVerificationOTP - Already verified", { userId });
        return { success: false, message: "Email is already verified" };
      }

      if (!user.email) {
        logger.error("sendVerificationOTP - No email on file", { userId });
        return {
          success: false,
          message: "No email address found for this account",
        };
      }

      // Check rate limit (max 5 OTPs per hour)
      const rateLimitExceeded = await this._checkOTPRateLimit(userId);
      if (rateLimitExceeded) {
        logger.error("sendVerificationOTP - Rate limit exceeded", { userId });
        return {
          success: false,
          message: "Too many OTP requests. Please try again in 1 hour.",
        };
      }

      // Check 60s cooldown between resends
      const cooldownActive = await this._checkCooldown(userId);
      if (cooldownActive.active) {
        logger.info("sendVerificationOTP - Cooldown active", {
          userId,
          secondsRemaining: cooldownActive.secondsRemaining,
        });
        return {
          success: false,
          message: `Please wait ${cooldownActive.secondsRemaining} seconds before requesting a new OTP`,
          secondsRemaining: cooldownActive.secondsRemaining,
        };
      }

      // Generate and hash 6-digit OTP
      const otp = this._generateOTP();
      const otpHash = crypto.createHash("sha256").update(otp).digest("hex");
      const expiresAt = new Date(Date.now() + 600000);

      // Store OTP record
      await pool.query(
        `INSERT INTO email_otp_verifications (user_id, otp_hash, expires_at)
        VALUES ($1, $2, $3)`,
        [userId, otpHash, expiresAt],
      );

      // Send OTP email
      const emailSent = await emailService.sendEmailVerificationOTP({
        to: user.email,
        username,
        otp,
        ipAddress,
      });

      if (!emailSent) {
        logger.error("sendVerificationOTP - Email send failed", { userId });
        return {
          success: false,
          message: "Failed to send OTP email. Please try again.",
        };
      }

      const maskedEmail = this._maskEmail(user.email);
      logger.info("sendVerificationOTP - OTP sent", { userId, maskedEmail });

      return {
        success: true,
        message: "OTP sent successfully",
        emailHint: maskedEmail,
        expiresIn: 600,
      };
    } catch (error) {
      logger.error("sendVerificationOTP - Error:", error);
      throw error;
    }
  }

  // Verify submitted OTP and mark email as verified
  async verifyOTP({ userId, otp, ipAddress }) {
    logger.info("verifyOTP - Request", { userId });

    try {
      const otpHash = crypto.createHash("sha256").update(otp).digest("hex");

      await pool.query("BEGIN");

      // Fetch and lock OTP record
      const otpResult = await pool.query(
        `SELECT id, verified, expires_at, attempts
        FROM email_otp_verifications
        WHERE user_id = $1 AND otp_hash = $2
        FOR UPDATE`,
        [userId, otpHash],
      );

      if (otpResult.rows.length === 0) {
        await pool.query("ROLLBACK");
        await this._incrementFailedAttempts(userId);
        logger.error("verifyOTP - Invalid OTP", { userId });
        return { success: false, message: "Invalid OTP" };
      }

      const otpData = otpResult.rows[0];

      if (new Date(otpData.expires_at) < new Date()) {
        await pool.query("ROLLBACK");
        logger.error("verifyOTP - OTP expired", { userId });
        return {
          success: false,
          message: "OTP has expired. Please request a new one.",
        };
      }

      if (otpData.verified) {
        await pool.query("ROLLBACK");
        logger.error("verifyOTP - OTP already used", { userId });
        return { success: false, message: "This OTP has already been used" };
      }

      if (otpData.attempts >= 5) {
        await pool.query("ROLLBACK");
        logger.error("verifyOTP - Max attempts exceeded", { userId });
        return {
          success: false,
          message:
            "Maximum verification attempts exceeded. Please request a new OTP.",
        };
      }

      // Mark OTP as verified
      await pool.query(
        `UPDATE email_otp_verifications SET verified = TRUE, verified_at = NOW() WHERE id = $1`,
        [otpData.id],
      );

      // Mark email as verified in users_auth
      await pool.query(
        "UPDATE users_auth SET email_verified = TRUE WHERE user_id = $1",
        [userId],
      );

      await pool.query("COMMIT");
      logger.info("verifyOTP - Email verified successfully", { userId });

      // Send confirmation email async (non-blocking)
      this._sendVerificationConfirmationEmail(userId, ipAddress);

      return { success: true, message: "Email verified successfully" };
    } catch (error) {
      await pool.query("ROLLBACK");
      logger.error("verifyOTP - Error:", error);
      throw error;
    }
  }

  // Resend OTP after cooldown check
  async resendOTP({ userId, ipAddress }) {
    logger.info("resendOTP - Request", { userId });

    try {
      const cooldownActive = await this._checkCooldown(userId);
      if (cooldownActive.active) {
        logger.info("resendOTP - Cooldown active", {
          userId,
          secondsRemaining: cooldownActive.secondsRemaining,
        });
        return {
          success: false,
          message: `Please wait ${cooldownActive.secondsRemaining} seconds before requesting a new OTP`,
          secondsRemaining: cooldownActive.secondsRemaining,
        };
      }

      return await this.sendVerificationOTP({ userId, ipAddress });
    } catch (error) {
      logger.error("resendOTP - Error:", error);
      throw error;
    }
  }

  // Get full email verification status for a user
  async getVerificationStatus(userId) {
    logger.info("getVerificationStatus - Request", { userId });

    try {
      const userResult = await pool.query(
        "SELECT email, email_verified FROM users_auth WHERE user_id = $1",
        [userId],
      );

      if (userResult.rows.length === 0) {
        logger.error("getVerificationStatus - User not found", { userId });
        return { success: false, message: "User not found" };
      }

      const user = userResult.rows[0];

      // Fetch most recent pending OTP
      const pendingOTPResult = await pool.query(
        `SELECT expires_at, attempts
        FROM email_otp_verifications
        WHERE user_id = $1 AND verified = FALSE AND expires_at > NOW()
        ORDER BY created_at DESC LIMIT 1`,
        [userId],
      );

      const hasPendingOTP = pendingOTPResult.rows.length > 0;
      const pendingOTP = hasPendingOTP ? pendingOTPResult.rows[0] : null;
      const cooldown = await this._checkCooldown(userId);

      logger.info("getVerificationStatus - Success", {
        userId,
        emailVerified: user.email_verified,
        hasPendingOTP,
      });

      return {
        success: true,
        emailVerified: user.email_verified,
        hasEmail: !!user.email,
        emailHint: user.email ? this._maskEmail(user.email) : null,
        hasPendingOTP,
        otpExpiresAt: pendingOTP ? pendingOTP.expires_at : null,
        attemptsRemaining: pendingOTP
          ? Math.max(0, 5 - pendingOTP.attempts)
          : 5,
        canResend: !cooldown.active,
        cooldownSeconds: cooldown.active ? cooldown.secondsRemaining : 0,
      };
    } catch (error) {
      logger.error("getVerificationStatus - Error:", error);
      throw error;
    }
  }

  // Generate random 6-digit OTP
  _generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  // Check if user exceeded 5 OTP requests per hour
  async _checkOTPRateLimit(userId) {
    try {
      const result = await pool.query(
        `SELECT COUNT(*) as count FROM email_otp_verifications
        WHERE user_id = $1 AND created_at > NOW() - INTERVAL '1 hour'`,
        [userId],
      );
      const count = parseInt(result.rows[0].count);
      logger.info("_checkOTPRateLimit", { userId, count });
      return count >= 5;
    } catch (error) {
      logger.error("_checkOTPRateLimit - Error:", error);
      return false;
    }
  }

  // Check 60s cooldown between OTP requests
  async _checkCooldown(userId) {
    try {
      const result = await pool.query(
        `SELECT created_at FROM email_otp_verifications
        WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1`,
        [userId],
      );

      if (result.rows.length === 0) {
        return { active: false, secondsRemaining: 0 };
      }

      const lastOTPTime = new Date(result.rows[0].created_at);
      const elapsedSeconds = Math.floor((new Date() - lastOTPTime) / 1000);
      const cooldownSeconds = 60;

      if (elapsedSeconds < cooldownSeconds) {
        return {
          active: true,
          secondsRemaining: cooldownSeconds - elapsedSeconds,
        };
      }

      return { active: false, secondsRemaining: 0 };
    } catch (error) {
      logger.error("_checkCooldown - Error:", error);
      return { active: false, secondsRemaining: 0 };
    }
  }

  // Increment failed OTP attempt count
  async _incrementFailedAttempts(userId) {
    try {
      await pool.query(
        `UPDATE email_otp_verifications
        SET attempts = attempts + 1
        WHERE user_id = $1 AND verified = FALSE AND expires_at > NOW()`,
        [userId],
      );
      logger.info("_incrementFailedAttempts - Incremented", { userId });
    } catch (error) {
      logger.error("_incrementFailedAttempts - Error:", error);
    }
  }

  // Send email confirmation after successful verification
  async _sendVerificationConfirmationEmail(userId, ipAddress) {
    try {
      const userResult = await pool.query(
        `SELECT ua.email, ud.name
        FROM users_auth ua
        LEFT JOIN user_details ud ON ua.user_id = ud.user_id
        WHERE ua.user_id = $1`,
        [userId],
      );

      if (userResult.rows.length > 0 && userResult.rows[0].email) {
        const user = userResult.rows[0];
        await emailService.sendEmailVerifiedConfirmation({
          to: user.email,
          username: user.name || "User",
          ipAddress,
          timestamp: new Date().toLocaleString("en-IN", {
            timeZone: "Asia/Kolkata",
            dateStyle: "medium",
            timeStyle: "short",
          }),
        });
        logger.info("_sendVerificationConfirmationEmail - Sent", { userId });
      }
    } catch (error) {
      logger.error(
        "_sendVerificationConfirmationEmail - Error (non-critical):",
        error,
      );
    }
  }

  // Mask email for safe display
  _maskEmail(email) {
    if (!email) return null;
    return email.replace(
      /(.{2})(.*)(@.*)/,
      (match, p1, p2, p3) => p1 + "*".repeat(Math.min(p2.length, 5)) + p3,
    );
  }
}

module.exports = new EmailVerificationService();
