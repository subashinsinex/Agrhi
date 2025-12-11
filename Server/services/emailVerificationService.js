// services/emailVerificationService.js
const crypto = require("crypto");
const pool = require("../db/database");
const emailService = require("../utils/emailSender");

class EmailVerificationService {
  /**
   * Send OTP to user's email
   */
  async sendVerificationOTP({ userId, ipAddress }) {
    try {
      // Get user details from users_auth and user_details
      const userResult = await pool.query(
        `SELECT ua.email, ua.email_verified, ud.name
        FROM users_auth ua
        LEFT JOIN user_details ud ON ua.user_id = ud.user_id
        WHERE ua.user_id = $1`,
        [userId]
      );

      if (userResult.rows.length === 0) {
        return {
          success: false,
          message: "User not found",
        };
      }

      const user = userResult.rows[0];
      const username = user.name || "User";

      // Check if already verified
      if (user.email_verified) {
        return {
          success: false,
          message: "Email is already verified",
        };
      }

      // Check if email exists
      if (!user.email) {
        return {
          success: false,
          message: "No email address found for this account",
        };
      }

      // Check rate limiting (max 5 OTPs per hour)
      const rateLimitExceeded = await this._checkOTPRateLimit(userId);
      if (rateLimitExceeded) {
        return {
          success: false,
          message: "Too many OTP requests. Please try again in 1 hour.",
        };
      }

      // Check cooldown (60 seconds between resends)
      const cooldownActive = await this._checkCooldown(userId);
      if (cooldownActive.active) {
        return {
          success: false,
          message: `Please wait ${cooldownActive.secondsRemaining} seconds before requesting a new OTP`,
          secondsRemaining: cooldownActive.secondsRemaining,
        };
      }

      // Generate 6-digit OTP
      const otp = this._generateOTP();
      const otpHash = crypto.createHash("sha256").update(otp).digest("hex");

      // OTP expires in 10 minutes
      const expiresAt = new Date(Date.now() + 600000);

      // Store OTP in database
      await pool.query(
        `INSERT INTO email_otp_verifications (
          user_id, 
          otp_hash, 
          expires_at
        ) VALUES ($1, $2, $3)`,
        [userId, otpHash, expiresAt]
      );

      // Send OTP email with IP address
      const emailSent = await emailService.sendEmailVerificationOTP({
        to: user.email,
        username: username,
        otp: otp,
        ipAddress: ipAddress, // This now includes location tracking
      });

      if (!emailSent) {
        return {
          success: false,
          message: "Failed to send OTP email. Please try again.",
        };
      }

      // Mask email
      const maskedEmail = this._maskEmail(user.email);

      return {
        success: true,
        message: "OTP sent successfully",
        emailHint: maskedEmail,
        expiresIn: 600, // seconds
      };
    } catch (error) {
      console.error("Send verification OTP error:", error);
      throw error;
    }
  }

  /**
   * Verify OTP
   */
  async verifyOTP({ userId, otp, ipAddress }) {
    const client = await pool.connect();

    try {
      const otpHash = crypto.createHash("sha256").update(otp).digest("hex");

      await client.query("BEGIN");

      // Find and lock the OTP record
      const otpResult = await client.query(
        `SELECT id, verified, expires_at, attempts
        FROM email_otp_verifications
        WHERE user_id = $1
        AND otp_hash = $2
        FOR UPDATE`,
        [userId, otpHash]
      );

      if (otpResult.rows.length === 0) {
        await client.query("ROLLBACK");

        // Increment failed attempts
        await this._incrementFailedAttempts(userId);

        return {
          success: false,
          message: "Invalid OTP",
        };
      }

      const otpData = otpResult.rows[0];

      // Check if expired
      if (new Date(otpData.expires_at) < new Date()) {
        await client.query("ROLLBACK");
        return {
          success: false,
          message: "OTP has expired. Please request a new one.",
        };
      }

      // Check if already verified
      if (otpData.verified) {
        await client.query("ROLLBACK");
        return {
          success: false,
          message: "This OTP has already been used",
        };
      }

      // Check attempts (max 5 attempts)
      if (otpData.attempts >= 5) {
        await client.query("ROLLBACK");
        return {
          success: false,
          message:
            "Maximum verification attempts exceeded. Please request a new OTP.",
        };
      }

      // Mark OTP as verified
      await client.query(
        `UPDATE email_otp_verifications 
        SET verified = TRUE, verified_at = NOW() 
        WHERE id = $1`,
        [otpData.id]
      );

      // Mark email as verified in users_auth table
      await client.query(
        "UPDATE users_auth SET email_verified = TRUE WHERE user_id = $1",
        [userId]
      );

      await client.query("COMMIT");

      // Send confirmation email with IP and location (async)
      this._sendVerificationConfirmationEmail(userId, ipAddress);

      return {
        success: true,
        message: "Email verified successfully",
      };
    } catch (error) {
      await client.query("ROLLBACK");
      console.error("Verify OTP error:", error);
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Resend OTP
   */
  async resendOTP({ userId, ipAddress }) {
    try {
      // Check cooldown
      const cooldownActive = await this._checkCooldown(userId);
      if (cooldownActive.active) {
        return {
          success: false,
          message: `Please wait ${cooldownActive.secondsRemaining} seconds before requesting a new OTP`,
          secondsRemaining: cooldownActive.secondsRemaining,
        };
      }

      // Use the same sendVerificationOTP method
      return await this.sendVerificationOTP({ userId, ipAddress });
    } catch (error) {
      console.error("Resend OTP error:", error);
      throw error;
    }
  }

  /**
   * Get verification status
   */
  async getVerificationStatus(userId) {
    try {
      const userResult = await pool.query(
        "SELECT email, email_verified FROM users_auth WHERE user_id = $1",
        [userId]
      );

      if (userResult.rows.length === 0) {
        return {
          success: false,
          message: "User not found",
        };
      }

      const user = userResult.rows[0];

      // Check if there's a pending OTP
      const pendingOTPResult = await pool.query(
        `SELECT expires_at, attempts
        FROM email_otp_verifications
        WHERE user_id = $1
        AND verified = FALSE
        AND expires_at > NOW()
        ORDER BY created_at DESC
        LIMIT 1`,
        [userId]
      );

      const hasPendingOTP = pendingOTPResult.rows.length > 0;
      const pendingOTP = hasPendingOTP ? pendingOTPResult.rows[0] : null;

      // Check cooldown
      const cooldown = await this._checkCooldown(userId);

      return {
        success: true,
        emailVerified: user.email_verified,
        hasEmail: !!user.email,
        emailHint: user.email ? this._maskEmail(user.email) : null,
        hasPendingOTP: hasPendingOTP,
        otpExpiresAt: pendingOTP ? pendingOTP.expires_at : null,
        attemptsRemaining: pendingOTP
          ? Math.max(0, 5 - pendingOTP.attempts)
          : 5,
        canResend: !cooldown.active,
        cooldownSeconds: cooldown.active ? cooldown.secondsRemaining : 0,
      };
    } catch (error) {
      console.error("Get verification status error:", error);
      throw error;
    }
  }

  /**
   * Generate 6-digit OTP
   */
  _generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  /**
   * Check OTP rate limiting (5 per hour)
   */
  async _checkOTPRateLimit(userId) {
    try {
      const result = await pool.query(
        `SELECT COUNT(*) as count
        FROM email_otp_verifications
        WHERE user_id = $1
        AND created_at > NOW() - INTERVAL '1 hour'`,
        [userId]
      );

      const count = parseInt(result.rows[0].count);
      return count >= 5;
    } catch (error) {
      console.error("OTP rate limit check error:", error);
      return false;
    }
  }

  /**
   * Check cooldown (60 seconds between OTPs)
   */
  async _checkCooldown(userId) {
    try {
      const result = await pool.query(
        `SELECT created_at
        FROM email_otp_verifications
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT 1`,
        [userId]
      );

      if (result.rows.length === 0) {
        return { active: false, secondsRemaining: 0 };
      }

      const lastOTPTime = new Date(result.rows[0].created_at);
      const now = new Date();
      const elapsedSeconds = Math.floor((now - lastOTPTime) / 1000);
      const cooldownSeconds = 60;

      if (elapsedSeconds < cooldownSeconds) {
        return {
          active: true,
          secondsRemaining: cooldownSeconds - elapsedSeconds,
        };
      }

      return { active: false, secondsRemaining: 0 };
    } catch (error) {
      console.error("Cooldown check error:", error);
      return { active: false, secondsRemaining: 0 };
    }
  }

  /**
   * Increment failed attempts
   */
  async _incrementFailedAttempts(userId) {
    try {
      await pool.query(
        `UPDATE email_otp_verifications
        SET attempts = attempts + 1
        WHERE user_id = $1
        AND verified = FALSE
        AND expires_at > NOW()`,
        [userId]
      );
    } catch (error) {
      console.error("Increment failed attempts error:", error);
    }
  }

  /**
   * Send verification confirmation email
   */
  async _sendVerificationConfirmationEmail(userId, ipAddress) {
    try {
      const userResult = await pool.query(
        `SELECT ua.email, ud.name
        FROM users_auth ua
        LEFT JOIN user_details ud ON ua.user_id = ud.user_id
        WHERE ua.user_id = $1`,
        [userId]
      );

      if (userResult.rows.length > 0 && userResult.rows[0].email) {
        const user = userResult.rows[0];
        const username = user.name || "User";

        await emailService.sendEmailVerifiedConfirmation({
          to: user.email,
          username: username,
          ipAddress: ipAddress, // This now includes location tracking
          timestamp: new Date().toLocaleString("en-IN", {
            timeZone: "Asia/Kolkata",
            dateStyle: "medium",
            timeStyle: "short",
          }),
        });
      }
    } catch (error) {
      console.error("Send verification confirmation error:", error);
    }
  }

  /**
   * Mask email
   */
  _maskEmail(email) {
    if (!email) return null;
    return email.replace(
      /(.{2})(.*)(@.*)/,
      (match, p1, p2, p3) => p1 + "*".repeat(Math.min(p2.length, 5)) + p3
    );
  }
}

module.exports = new EmailVerificationService();
