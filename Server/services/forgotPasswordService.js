// Forgot password service
const crypto = require("crypto");
const bcrypt = require("bcrypt");
const pool = require("../db/database");
const emailService = require("../utils/emailSender");
const logger = require("../utils/logger");

class ForgotPasswordService {
  // Request password reset link via mobile number
  async requestPasswordReset({ mobile, ipAddress, userAgent }) {
    const genericResponse = {
      success: true,
      message:
        "If this mobile number is registered, a reset link has been sent to the associated email address.",
    };

    try {
      // Fetch user by phone number
      const userResult = await pool.query(
        "SELECT user_id, email, phone_number FROM users_auth WHERE phone_number = $1",
        [mobile],
      );

      if (userResult.rows.length === 0) {
        logger.info(
          "requestPasswordReset - User not found, returning generic response",
          { mobile },
        );
        await this._addDelay(1000);
        return genericResponse;
      }

      const user = userResult.rows[0];

      if (!user.email) {
        logger.info(
          "requestPasswordReset - No email on file, returning generic response",
          {
            user_id: user.user_id,
          },
        );
        await this._addDelay(1000);
        return genericResponse;
      }

      // Check rate limit (3 requests per 24 hours)
      const rateLimitExceeded = await this._checkRateLimit(user.user_id);
      if (rateLimitExceeded) {
        logger.error("requestPasswordReset - Rate limit exceeded", {
          user_id: user.user_id,
        });
        return genericResponse;
      }

      // Generate and hash secure reset token
      const resetToken = crypto.randomBytes(32).toString("hex");
      const tokenHash = crypto
        .createHash("sha256")
        .update(resetToken)
        .digest("hex");
      const expiresAt = new Date(Date.now() + 3600000);

      // Store token in DB
      await pool.query(
        `INSERT INTO password_reset_tokens (
          user_id, token_hash, expires_at, ip_address, user_agent
        ) VALUES ($1, $2, $3, $4, $5)`,
        [user.user_id, tokenHash, expiresAt, ipAddress, userAgent],
      );

      logger.info("requestPasswordReset - Reset token stored", {
        user_id: user.user_id,
        expiresAt,
      });

      // Fetch username for email
      const userDetailsResult = await pool.query(
        "SELECT name FROM user_details WHERE user_id = $1",
        [user.user_id],
      );
      const username =
        userDetailsResult.rows.length > 0
          ? userDetailsResult.rows[0].name
          : "User";

      const maskedEmail = this._maskEmail(user.email);

      // Send reset email (non-critical, catch separately)
      try {
        await emailService.sendPasswordResetEmail({
          to: user.email,
          username,
          resetToken,
          mobile,
          ipAddress,
        });
        logger.info("requestPasswordReset - Reset email sent", {
          user_id: user.user_id,
          maskedEmail,
        });
      } catch (emailError) {
        logger.error("requestPasswordReset - Failed to send reset email", {
          user_id: user.user_id,
          emailError,
        });
      }

      return {
        success: true,
        message:
          "If this mobile number is registered, a reset link has been sent to the associated email address.",
        emailHint: maskedEmail,
      };
    } catch (error) {
      logger.error("requestPasswordReset - Error:", error);
      throw error;
    }
  }

  // Verify if reset token is valid and not expired
  async verifyResetToken(token) {
    logger.info("verifyResetToken - Verifying token");

    try {
      const tokenHash = crypto.createHash("sha256").update(token).digest("hex");

      const result = await pool.query(
        `SELECT 
          prt.user_id,
          prt.used,
          prt.expires_at,
          u.phone_number
        FROM password_reset_tokens prt
        JOIN users_auth u ON prt.user_id = u.user_id
        WHERE prt.token_hash = $1
        AND prt.expires_at > NOW()
        AND prt.used = FALSE`,
        [tokenHash],
      );

      if (result.rows.length === 0) {
        logger.error("verifyResetToken - Invalid or expired token");
        return { success: false, message: "Invalid or expired reset token" };
      }

      const data = result.rows[0];
      logger.info("verifyResetToken - Token valid", { user_id: data.user_id });

      return {
        success: true,
        message: "Token is valid",
        mobile: data.phone_number
          ? `${data.phone_number.slice(0, 2)}******${data.phone_number.slice(-2)}`
          : null,
      };
    } catch (error) {
      logger.error("verifyResetToken - Error:", error);
      throw error;
    }
  }

  // Reset password using valid token
  async resetPassword({ token, newPassword, ipAddress }) {
    logger.info("resetPassword - Attempt", { ipAddress });

    try {
      const tokenHash = crypto.createHash("sha256").update(token).digest("hex");

      await pool.query("BEGIN");

      // Fetch and lock token row
      const tokenResult = await pool.query(
        `SELECT user_id, used, expires_at
        FROM password_reset_tokens
        WHERE token_hash = $1
        FOR UPDATE`,
        [tokenHash],
      );

      if (tokenResult.rows.length === 0) {
        await pool.query("ROLLBACK");
        logger.error("resetPassword - Token not found");
        return { success: false, message: "Invalid reset token" };
      }

      const tokenData = tokenResult.rows[0];

      if (new Date(tokenData.expires_at) < new Date()) {
        await pool.query("ROLLBACK");
        logger.error("resetPassword - Token expired", {
          user_id: tokenData.user_id,
        });
        return { success: false, message: "Reset token has expired" };
      }

      if (tokenData.used) {
        await pool.query("ROLLBACK");
        logger.error("resetPassword - Token already used", {
          user_id: tokenData.user_id,
        });
        return {
          success: false,
          message: "This reset link has already been used",
        };
      }

      const userId = tokenData.user_id;

      // Hash and update new password
      const hashedPassword = await bcrypt.hash(newPassword, 10);
      await pool.query(
        "UPDATE users_auth SET password = $1 WHERE user_id = $2",
        [hashedPassword, userId],
      );

      await pool.query(
        "UPDATE user_details SET updated_at = NOW() WHERE user_id = $1",
        [userId],
      );

      // Mark token as used
      await pool.query(
        "UPDATE password_reset_tokens SET used = TRUE, used_at = NOW() WHERE token_hash = $1",
        [tokenHash],
      );

      await pool.query("COMMIT");
      logger.info("resetPassword - Password reset successful", { userId });

      // Send confirmation email async (non-blocking)
      this._sendPasswordChangedEmail(userId, ipAddress);

      return { success: true, message: "Password reset successfully" };
    } catch (error) {
      await pool.query("ROLLBACK");
      logger.error("resetPassword - Error:", error);
      throw error;
    }
  }

  // Check remaining reset attempts for a mobile number
  async checkResetStatus(mobile) {
    logger.info("checkResetStatus - Checking", { mobile });

    try {
      const userResult = await pool.query(
        "SELECT user_id FROM users_auth WHERE phone_number = $1",
        [mobile],
      );

      if (userResult.rows.length === 0) {
        logger.info("checkResetStatus - User not found, returning default", {
          mobile,
        });
        return { success: true, canRequest: true, attemptsRemaining: 3 };
      }

      const userId = userResult.rows[0].user_id;

      const attemptsResult = await pool.query(
        `SELECT COUNT(*) as count
        FROM password_reset_tokens
        WHERE user_id = $1
        AND created_at > NOW() - INTERVAL '24 hours'`,
        [userId],
      );

      const attempts = parseInt(attemptsResult.rows[0].count);
      const remaining = Math.max(0, 3 - attempts);

      logger.info("checkResetStatus - Status fetched", {
        userId,
        attempts,
        remaining,
      });

      return {
        success: true,
        canRequest: remaining > 0,
        attemptsRemaining: remaining,
        attemptsUsed: attempts,
      };
    } catch (error) {
      logger.error("checkResetStatus - Error:", error);
      throw error;
    }
  }

  // Check if user exceeded 3 reset requests in 24 hours
  async _checkRateLimit(userId) {
    try {
      const result = await pool.query(
        `SELECT COUNT(*) as count
        FROM password_reset_tokens
        WHERE user_id = $1
        AND created_at > NOW() - INTERVAL '24 hours'`,
        [userId],
      );

      const count = parseInt(result.rows[0].count);
      logger.info("_checkRateLimit", { userId, count });
      return count >= 3;
    } catch (error) {
      logger.error("_checkRateLimit - Error:", error);
      return false;
    }
  }

  // Send password changed confirmation email
  async _sendPasswordChangedEmail(userId, ipAddress) {
    try {
      const result = await pool.query(
        `SELECT ua.email, ud.name
        FROM users_auth ua
        LEFT JOIN user_details ud ON ua.user_id = ud.user_id
        WHERE ua.user_id = $1`,
        [userId],
      );

      if (result.rows.length > 0 && result.rows[0].email) {
        const user = result.rows[0];
        const username = user.name || "User";

        await emailService.sendPasswordChangedEmail({
          to: user.email,
          username,
          ipAddress,
          timestamp: new Date().toLocaleString("en-IN", {
            timeZone: "Asia/Kolkata",
            dateStyle: "medium",
            timeStyle: "short",
          }),
        });

        logger.info("_sendPasswordChangedEmail - Confirmation email sent", {
          userId,
        });
      }
    } catch (error) {
      logger.error("_sendPasswordChangedEmail - Error (non-critical):", error);
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

  // Add artificial delay to prevent timing attacks
  async _addDelay(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

module.exports = new ForgotPasswordService();
