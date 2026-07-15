const logger = require("./logger");
const web_ip = process.env.WEB_IP;
const web_port = process.env.WEB_PORT;
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

  // Password reset email
  async sendPasswordResetEmail({
    to,
    username,
    resetToken,
    mobile,
    ipAddress,
  }) {
    try {
      const resetUrl = `http://${web_ip}:${web_port}/reset-password?token=${resetToken}`;

      const location = await getLocationFromIP(ipAddress);

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

      logger.info(`Password reset email sent to ${to}`); 
      return true;
    } catch (error) {
      logger.error("Password reset email error:", error); 
      return false;
    }
  }

  // Password changed confirmation
  async sendPasswordChangedEmail({ to, username, ipAddress, timestamp }) {
    try {
      const location = await getLocationFromIP(ipAddress);

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

      logger.info(`Password changed email sent to ${to}`); 
      return true;
    } catch (error) {
      logger.error("Password changed email error:", error); 
      return false;
    }
  }

  // Email verification OTP
  async sendEmailVerificationOTP({ to, username, otp, ipAddress }) {
    try {
      const location = await getLocationFromIP(ipAddress);

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

      logger.info(`Email verification OTP sent to ${to}`); 
      return true;
    } catch (error) {
      logger.error("Email verification OTP error:", error); 
      return false;
    }
  }

  // Email verified confirmation
  async sendEmailVerifiedConfirmation({ to, username, ipAddress, timestamp }) {
    try {
      const location = await getLocationFromIP(ipAddress);

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

      logger.info(`Email verified confirmation sent to ${to}`); 
      return true;
    } catch (error) {
      logger.error("Email verified confirmation error:", error); 
      return false;
    }
  }

  // Test connection
  async testConnection() {
    try {
      await this.transporter.verify();
      logger.info("📧 Email service started successfully"); 
      return true;
    } catch (error) {
      logger.error("Email service error:", error); 
      return false;
    }
  }
}

module.exports = new EmailService();
