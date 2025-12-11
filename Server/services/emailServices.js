// services/emailServices.js
const nodemailer = require("nodemailer");
const emailTemplates = require("../utils/emailTemplates");

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
      const resetUrl = `http://14.139.161.69:8080/reset-password?token=${resetToken}`;

      const html = emailTemplates.passwordResetTemplate({
        username,
        resetUrl,
        mobile,
        ipAddress,
        timestamp: new Date().toLocaleString("en-IN", {
          timeZone: "Asia/Kolkata",
        }),
      });

      await this.transporter.sendMail({
        from: `"Agrhi - No Reply" <${process.env.EMAIL_USER}>`,
        to,
        subject: "Reset Your Agrhi Password",
        html,
      });

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
      const html = emailTemplates.passwordChangedTemplate({
        username,
        ipAddress,
        timestamp,
      });

      await this.transporter.sendMail({
        from: `"Agrhi - No Reply" <${process.env.EMAIL_USER}>`,
        to,
        subject: "Your Agrhi Password Was Changed",
        html,
      });

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
      const html = emailTemplates.emailVerificationOTPTemplate({
        username,
        otp,
        ipAddress,
        timestamp: new Date().toLocaleString("en-IN", {
          timeZone: "Asia/Kolkata",
        }),
      });

      await this.transporter.sendMail({
        from: `"Agrhi - No Reply" <${process.env.EMAIL_USER}>`,
        to,
        subject: "Verify Your Agrhi Email Address",
        html,
      });

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
      const html = emailTemplates.emailVerifiedTemplate({
        username,
        ipAddress,
        timestamp,
      });

      await this.transporter.sendMail({
        from: `"Agrhi - No Reply" <${process.env.EMAIL_USER}>`,
        to,
        subject: "Email Verified Successfully - Agrhi",
        html,
      });

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

module.exports = new EmailService();
