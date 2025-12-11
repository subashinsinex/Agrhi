// services/forgotPasswordService.js
const crypto = require("crypto");
const bcrypt = require("bcrypt");
const pool = require("../db/database");
const emailService = require("./emailServices");

class ForgotPasswordService {
  /**
   * Request password reset
   */
  async requestPasswordReset({ mobile, ipAddress, userAgent }) {
    const genericResponse = {
      success: true,
      message:
        "If this mobile number is registered, a reset link has been sent to the associated email address.",
    };

    try {
      // Find user by phone_number in users_auth table
      const userResult = await pool.query(
        "SELECT user_id, email, phone_number FROM users_auth WHERE phone_number = $1",
        [mobile]
      );

      // If no user found, still return success (security best practice)
      if (userResult.rows.length === 0) {
        await this._addDelay(1000);
        return genericResponse;
      }

      const user = userResult.rows[0];

      // Check if user has email
      if (!user.email) {
        await this._addDelay(1000);
        return genericResponse;
      }

      // Check rate limiting (3 requests per 24 hours)
      const rateLimitExceeded = await this._checkRateLimit(user.user_id);
      if (rateLimitExceeded) {
        console.log(`Rate limit exceeded for user ${user.user_id}`);
        return genericResponse;
      }

      // Generate secure reset token
      const resetToken = crypto.randomBytes(32).toString("hex");
      const tokenHash = crypto
        .createHash("sha256")
        .update(resetToken)
        .digest("hex");

      // Token expires in 1 hour
      const expiresAt = new Date(Date.now() + 3600000);

      // Store token in database
      await pool.query(
        `INSERT INTO password_reset_tokens (
          user_id, 
          token_hash, 
          expires_at,
          ip_address,
          user_agent
        ) VALUES ($1, $2, $3, $4, $5)`,
        [user.user_id, tokenHash, expiresAt, ipAddress, userAgent]
      );

      // Get username from user_details table
      const userDetailsResult = await pool.query(
        "SELECT name FROM user_details WHERE user_id = $1",
        [user.user_id]
      );

      const username =
        userDetailsResult.rows.length > 0
          ? userDetailsResult.rows[0].name
          : "User";

      // Mask email for response
      const maskedEmail = this._maskEmail(user.email);

      // Send reset email
      const emailSent = await emailService.sendPasswordResetEmail({
        to: user.email,
        username: username,
        resetToken: resetToken,
        mobile: mobile,
        ipAddress: ipAddress,
      });

      if (!emailSent) {
        console.error(`Failed to send password reset email to ${user.email}`);
      }

      return {
        success: true,
        message:
          "If this mobile number is registered, a reset link has been sent to the associated email address.",
        emailHint: maskedEmail,
      };
    } catch (error) {
      console.error("Request password reset error:", error);
      throw error;
    }
  }

  /**
   * Verify reset token
   */
  async verifyResetToken(token) {
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
        [tokenHash]
      );

      if (result.rows.length === 0) {
        return {
          success: false,
          message: "Invalid or expired reset token",
        };
      }

      const data = result.rows[0];

      return {
        success: true,
        message: "Token is valid",
        mobile: data.phone_number
          ? `${data.phone_number.slice(0, 2)}******${data.phone_number.slice(
              -2
            )}`
          : null,
      };
    } catch (error) {
      console.error("Verify reset token error:", error);
      throw error;
    }
  }

  /**
   * Reset password
   */
  async resetPassword({ token, newPassword, ipAddress }) {
    const client = await pool.connect();

    try {
      const tokenHash = crypto.createHash("sha256").update(token).digest("hex");

      await client.query("BEGIN");

      // Find and lock the token
      const tokenResult = await client.query(
        `SELECT user_id, used, expires_at
        FROM password_reset_tokens
        WHERE token_hash = $1
        FOR UPDATE`,
        [tokenHash]
      );

      if (tokenResult.rows.length === 0) {
        await client.query("ROLLBACK");
        return {
          success: false,
          message: "Invalid reset token",
        };
      }

      const tokenData = tokenResult.rows[0];

      // Check if token expired
      if (new Date(tokenData.expires_at) < new Date()) {
        await client.query("ROLLBACK");
        return {
          success: false,
          message: "Reset token has expired",
        };
      }

      // Check if already used
      if (tokenData.used) {
        await client.query("ROLLBACK");
        return {
          success: false,
          message: "This reset link has already been used",
        };
      }

      const userId = tokenData.user_id;

      // Hash new password
      const hashedPassword = await bcrypt.hash(newPassword, 10);

      // Update password in users_auth table
      await client.query(
        "UPDATE users_auth SET password = $1 WHERE user_id = $2",
        [hashedPassword, userId]
      );

      // Update updated_at in user_details table
      await client.query(
        "UPDATE user_details SET updated_at = NOW() WHERE user_id = $1",
        [userId]
      );

      // Mark token as used
      await client.query(
        "UPDATE password_reset_tokens SET used = TRUE, used_at = NOW() WHERE token_hash = $1",
        [tokenHash]
      );

      await client.query("COMMIT");

      // Send confirmation email (async, don't wait)
      this._sendPasswordChangedEmail(userId, ipAddress);

      return {
        success: true,
        message: "Password reset successfully",
      };
    } catch (error) {
      await client.query("ROLLBACK");
      console.error("Reset password error:", error);
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Check reset status (rate limit info)
   */
  async checkResetStatus(mobile) {
    try {
      const userResult = await pool.query(
        "SELECT user_id FROM users_auth WHERE phone_number = $1",
        [mobile]
      );

      if (userResult.rows.length === 0) {
        return {
          success: true,
          canRequest: true,
          attemptsRemaining: 3,
        };
      }

      const userId = userResult.rows[0].user_id;

      const attemptsResult = await pool.query(
        `SELECT COUNT(*) as count
        FROM password_reset_tokens
        WHERE user_id = $1
        AND created_at > NOW() - INTERVAL '24 hours'`,
        [userId]
      );

      const attempts = parseInt(attemptsResult.rows[0].count);
      const remaining = Math.max(0, 3 - attempts);

      return {
        success: true,
        canRequest: remaining > 0,
        attemptsRemaining: remaining,
        attemptsUsed: attempts,
      };
    } catch (error) {
      console.error("Check reset status error:", error);
      throw error;
    }
  }

  /**
   * Check rate limiting (3 requests per 24 hours)
   */
  async _checkRateLimit(userId) {
    try {
      const result = await pool.query(
        `SELECT COUNT(*) as count
        FROM password_reset_tokens
        WHERE user_id = $1
        AND created_at > NOW() - INTERVAL '24 hours'`,
        [userId]
      );

      const count = parseInt(result.rows[0].count);
      return count >= 3;
    } catch (error) {
      console.error("Rate limit check error:", error);
      return false;
    }
  }

  /**
   * Send password changed confirmation email
   */
  async _sendPasswordChangedEmail(userId, ipAddress) {
    try {
      // Get user info from both tables
      const result = await pool.query(
        `SELECT ua.email, ud.name
        FROM users_auth ua
        LEFT JOIN user_details ud ON ua.user_id = ud.user_id
        WHERE ua.user_id = $1`,
        [userId]
      );

      if (result.rows.length > 0 && result.rows[0].email) {
        const user = result.rows[0];
        const username = user.name || "User";

        await emailService.sendPasswordChangedEmail({
          to: user.email,
          username: username,
          ipAddress: ipAddress,
          timestamp: new Date().toLocaleString("en-IN", {
            timeZone: "Asia/Kolkata",
          }),
        });
      }
    } catch (error) {
      console.error("Send password changed email error:", error);
      // Don't throw - this is non-critical
    }
  }

  /**
   * Mask email for display
   */
  _maskEmail(email) {
    if (!email) return null;
    return email.replace(
      /(.{2})(.*)(@.*)/,
      (match, p1, p2, p3) => p1 + "*".repeat(Math.min(p2.length, 5)) + p3
    );
  }

  /**
   * Add artificial delay (prevent timing attacks)
   */
  async _addDelay(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

module.exports = new ForgotPasswordService();
