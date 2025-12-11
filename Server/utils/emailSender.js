// utils/emailSender.js
const nodemailer = require("nodemailer");
const emailTemplates = require("./emailTemplates");
const { getLocationFromIP } = require("./ipGeolocation");

class EmailService {
  constructor() {
    this.transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASSWORD,
      },
    });
  }

  /**
   * Send password reset email
   */
  async sendPasswordResetEmail({
    to,
    username,
    resetToken,
    mobile,
    ipAddress,
  }) {
    try {
      const resetUrl = `${process.env.FRONTEND_URL}/reset-password?token=${resetToken}`;

      // Get location from IP
      const location = await getLocationFromIP(ipAddress);

      // Generate timestamp
      const timestamp = new Date().toLocaleString("en-IN", {
        timeZone: "Asia/Kolkata",
        dateStyle: "medium",
        timeStyle: "short",
      });

      const html = emailTemplates.passwordResetTemplate({
        username,
        resetUrl,
        mobile,
        ipAddress,
        location,
        timestamp,
      });

      await this.transporter.sendMail({
        from: `"Agrhi - No Reply" <${process.env.EMAIL_USER}>`,
        to,
        subject: "Reset Your Password - Agrhi",
        html,
      });

      console.log(`✅ Password reset email sent to ${to}`);
      return true;
    } catch (error) {
      console.error("Send password reset email error:", error);
      return false;
    }
  }

  /**
   * Send password changed confirmation email
   */
  async sendPasswordChangedEmail({ to, username, ipAddress, timestamp }) {
    try {
      // Get location from IP
      const location = await getLocationFromIP(ipAddress);

      // Generate timestamp if not provided
      const formattedTimestamp =
        timestamp ||
        new Date().toLocaleString("en-IN", {
          timeZone: "Asia/Kolkata",
          dateStyle: "medium",
          timeStyle: "short",
        });

      const html = emailTemplates.passwordChangedTemplate({
        username,
        ipAddress,
        location,
        timestamp: formattedTimestamp,
      });

      await this.transporter.sendMail({
        from: `"Agrhi - No Reply" <${process.env.EMAIL_USER}>`,
        to,
        subject: "Password Changed Successfully - Agrhi",
        html,
      });

      console.log(`✅ Password changed email sent to ${to}`);
      return true;
    } catch (error) {
      console.error("Send password changed email error:", error);
      return false;
    }
  }

  /**
   * Send email verification OTP
   */
  async sendEmailVerificationOTP({ to, username, otp, ipAddress }) {
    try {
      // Get location from IP
      const location = await getLocationFromIP(ipAddress);

      // Generate timestamp
      const timestamp = new Date().toLocaleString("en-IN", {
        timeZone: "Asia/Kolkata",
        dateStyle: "medium",
        timeStyle: "short",
      });

      const html = emailTemplates.emailVerificationOTPTemplate({
        username,
        otp,
        ipAddress,
        location,
        timestamp,
      });

      await this.transporter.sendMail({
        from: `"Agrhi - No Reply" <${process.env.EMAIL_USER}>`,
        to,
        subject: "Verify Your Email - Agrhi",
        html,
      });

      console.log(`✅ Email verification OTP sent to ${to}`);
      return true;
    } catch (error) {
      console.error("Send email verification OTP error:", error);
      return false;
    }
  }

  /**
   * Send email verified confirmation
   */
  async sendEmailVerifiedConfirmation({ to, username, ipAddress, timestamp }) {
    try {
      // Get location from IP
      const location = await getLocationFromIP(ipAddress);

      // Generate timestamp if not provided
      const formattedTimestamp =
        timestamp ||
        new Date().toLocaleString("en-IN", {
          timeZone: "Asia/Kolkata",
          dateStyle: "medium",
          timeStyle: "short",
        });

      const html = emailTemplates.emailVerifiedTemplate({
        username,
        ipAddress,
        location,
        timestamp: formattedTimestamp,
      });

      await this.transporter.sendMail({
        from: `"Agrhi - No Reply" <${process.env.EMAIL_USER}>`,
        to,
        subject: "Email Verified Successfully - Agrhi",
        html,
      });

      console.log(`✅ Email verified confirmation sent to ${to}`);
      return true;
    } catch (error) {
      console.error("Send email verified confirmation error:", error);
      return false;
    }
  }

  /**
   * Test email configuration
   */
  async testConnection() {
    try {
      await this.transporter.verify();
      console.log("✅ Email service is ready");
      return true;
    } catch (error) {
      console.error("❌ Email service error:", error);
      return false;
    }
  }
}

// IMPORTANT: Export as instance (not class)
module.exports = new EmailService();
