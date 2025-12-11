// utils/emailTemplates.js

class EmailTemplates {
  /**
   * Password reset email template
   */
  passwordResetTemplate({
    username,
    resetUrl,
    mobile,
    ipAddress,
    location,
    timestamp,
  }) {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <title>Reset Your Password - Agrhi</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5; line-height: 1.6;">
  <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f5f5f5;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px; background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); overflow: hidden;">
          
          <!-- Header with Logo -->
          <tr>
            <td style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); padding: 40px 30px; text-align: center;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td align="center">
                    <table border="0" cellspacing="0" cellpadding="0" style="margin: 0 auto 15px auto;">
                      <tr>
                        <td width="70" height="70" align="center" valign="middle" style="background-color: #ffffff; border-radius: 50%;">
                          <div style="font-size: 36px; line-height: 70px; text-align: center;">🌱</div>
                        </td>
                      </tr>
                    </table>
                    <h1 style="color: #ffffff; margin: 0; font-size: 32px; font-weight: 600; letter-spacing: -0.5px;">Agrhi</h1>
                    <p style="color: rgba(255,255,255,0.9); margin: 8px 0 0 0; font-size: 14px;">Smart Agriculture Platform</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Main Content -->
          <tr>
            <td style="padding: 45px 40px;">
              <h2 style="color: #2c3e50; margin: 0 0 20px 0; font-size: 26px; font-weight: 600; line-height: 1.3;">Reset Your Password</h2>
              
              <p style="color: #4a5568; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
                Hello <strong style="color: #2c3e50;">${username}</strong>,
              </p>
              
              <p style="color: #4a5568; font-size: 16px; line-height: 1.6; margin: 0 0 25px 0;">
                We received a request to reset the password for your Agrhi account associated with:
              </p>
              
              <!-- Mobile Number Badge -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 30px 0;">
                <tr>
                  <td align="center">
                    <table border="0" cellspacing="0" cellpadding="0" style="background-color: #f7fafc; border: 2px solid #e2e8f0; border-radius: 8px;">
                      <tr>
                        <td style="padding: 15px 25px;">
                          <p style="margin: 0; color: #2d3748; font-size: 18px; font-weight: 600; letter-spacing: 1px; text-align: center;">
                            <span style="display: inline-block; vertical-align: middle; margin-right: 8px;">📱</span><span style="display: inline-block; vertical-align: middle;">${String(
                              mobile
                            ).slice(0, 2)}••••••${String(mobile).slice(
      -2
    )}</span>
                          </p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
              
              <p style="color: #4a5568; font-size: 16px; line-height: 1.6; margin: 0 0 30px 0;">
                To reset your password, click the button below. This link will expire in <strong>1 hour</strong> for security reasons.
              </p>
            </td>
          </tr>
          
          <!-- CTA Button -->
          <tr>
            <td align="center" style="padding: 0 40px 40px 40px;">
              <table role="presentation" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); border-radius: 8px; box-shadow: 0 4px 12px rgba(76, 175, 80, 0.3);">
                    <a href="${resetUrl}" target="_blank" style="display: inline-block; padding: 16px 48px; color: #ffffff; text-decoration: none; font-size: 16px; font-weight: 600; letter-spacing: 0.5px;">
                      Reset Password →
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Info Boxes -->
          <tr>
            <td style="padding: 0 40px 40px 40px;">
              
              <!-- Expiry Warning -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 20px 0;">
                <tr>
                  <td style="background-color: #fffbeb; border-left: 4px solid #f59e0b; border-radius: 6px; padding: 16px 20px;">
                    <p style="margin: 0; color: #92400e; font-size: 14px; line-height: 1.5;">
                      <strong style="font-size: 15px;"><span style="display: inline-block; vertical-align: middle; margin-right: 6px;">⏰</span><span style="display: inline-block; vertical-align: middle;">Link expires in 1 hour</span></strong><br>
                      For your security, this password reset link will expire after one hour.
                    </p>
                  </td>
                </tr>
              </table>
              
              <!-- Security Notice -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 25px 0;">
                <tr>
                  <td style="background-color: #fef2f2; border-left: 4px solid #ef4444; border-radius: 6px; padding: 16px 20px;">
                    <p style="margin: 0; color: #7f1d1d; font-size: 14px; line-height: 1.5;">
                      <strong style="font-size: 15px;"><span style="display: inline-block; vertical-align: middle; margin-right: 6px;">🔒</span><span style="display: inline-block; vertical-align: middle;">Didn't request this?</span></strong><br>
                      If you didn't request a password reset, you can safely ignore this email. Your password will remain unchanged.
                    </p>
                  </td>
                </tr>
              </table>
              
              <!-- Manual Link -->
              <div style="background-color: #f8fafc; border-radius: 6px; padding: 20px; margin: 0 0 25px 0;">
                <p style="margin: 0 0 10px 0; color: #64748b; font-size: 13px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px;">
                  Button not working?
                </p>
                <p style="margin: 0; color: #475569; font-size: 13px; line-height: 1.5;">
                  Copy and paste this link into your browser:
                </p>
                <p style="margin: 10px 0 0 0; word-break: break-all;">
                  <a href="${resetUrl}" style="color: #4CAF50; text-decoration: none; font-size: 12px;">${resetUrl}</a>
                </p>
              </div>
              
              <!-- Request Details -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="border-top: 1px solid #e5e7eb; padding-top: 20px;">
                <tr>
                  <td>
                    <p style="margin: 0 0 8px 0; color: #9ca3af; font-size: 12px; line-height: 1.5;">
                      <strong style="color: #6b7280;">Request Details:</strong>
                    </p>
                    <p style="margin: 0 0 4px 0; color: #9ca3af; font-size: 12px;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">📅</span><span style="display: inline-block; vertical-align: middle;">Time: ${timestamp}</span>
                    </p>
                    <p style="margin: 0 0 4px 0; color: #9ca3af; font-size: 12px;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">📍</span><span style="display: inline-block; vertical-align: middle;">Location: ${location}</span>
                    </p>
                    <p style="margin: 0; color: #9ca3af; font-size: 12px;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">🌐</span><span style="display: inline-block; vertical-align: middle;">IP Address: ${ipAddress}</span>
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="background-color: #f9fafb; padding: 30px 40px; border-top: 1px solid #e5e7eb;">
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%">
                <tr>
                  <td align="center">
                    <p style="margin: 0 0 10px 0; color: #9ca3af; font-size: 13px; line-height: 1.6;">
                      This is an automated security email from Agrhi.
                    </p>
                    <p style="margin: 0 0 15px 0; color: #9ca3af; font-size: 13px;">
                      Please do not reply to this message.
                    </p>
                    <p style="margin: 0; color: #9ca3af; font-size: 12px;">
                      © ${new Date().getFullYear()} Agrhi. All rights reserved.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
`;
  }

  /**
   * Password changed confirmation template
   */
  passwordChangedTemplate({ username, ipAddress, location, timestamp }) {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <title>Password Changed Successfully - Agrhi</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5; line-height: 1.6;">
  <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f5f5f5;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px; background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); overflow: hidden;">
          
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); padding: 40px 30px; text-align: center;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td align="center">
                    <table border="0" cellspacing="0" cellpadding="0" style="margin: 0 auto 15px auto;">
                      <tr>
                        <td width="70" height="70" align="center" valign="middle" style="background-color: #ffffff; border-radius: 50%;">
                          <div style="font-size: 36px; line-height: 70px; text-align: center;">🌱</div>
                        </td>
                      </tr>
                    </table>
                    <h1 style="color: #ffffff; margin: 0; font-size: 32px; font-weight: 600; letter-spacing: -0.5px;">Agrhi</h1>
                    <p style="color: rgba(255,255,255,0.9); margin: 8px 0 0 0; font-size: 14px;">Smart Agriculture Platform</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Success Icon -->
          <tr>
            <td align="center" style="padding: 40px 40px 20px 40px;">
              <table border="0" cellspacing="0" cellpadding="0" style="margin: 0 auto;">
                <tr>
                  <td width="80" height="80" align="center" valign="middle" style="background: linear-gradient(135deg, #10b981 0%, #059669 100%); border-radius: 50%; box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);">
                    <div style="font-size: 42px; line-height: 80px; text-align: center; color: #ffffff; font-weight: bold;">✓</div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Main Content -->
          <tr>
            <td style="padding: 20px 40px 40px 40px; text-align: center;">
              <h2 style="color: #2c3e50; margin: 0 0 15px 0; font-size: 26px; font-weight: 600;">Password Changed Successfully!</h2>
              
              <p style="color: #4a5568; font-size: 16px; line-height: 1.6; margin: 0 0 25px 0;">
                Hello <strong style="color: #2c3e50;">${username}</strong>,
              </p>
              
              <p style="color: #4a5568; font-size: 16px; line-height: 1.6; margin: 0 0 25px 0;">
                Your Agrhi account password was successfully changed.
              </p>
              
              <!-- Timestamp Badge -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 35px 0;">
                <tr>
                  <td align="center">
                    <table border="0" cellspacing="0" cellpadding="0" style="background-color: #ecfdf5; border: 2px solid #10b981; border-radius: 8px;">
                      <tr>
                        <td style="padding: 15px 25px;">
                          <p style="margin: 0; color: #047857; font-size: 14px; font-weight: 600; text-align: center;">
                            <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">🕐</span><span style="display: inline-block; vertical-align: middle;">${timestamp}</span>
                          </p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Alert Boxes -->
          <tr>
            <td style="padding: 0 40px 40px 40px;">
              
              <!-- Security Alert -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 20px 0;">
                <tr>
                  <td style="background-color: #fef2f2; border-left: 4px solid #ef4444; border-radius: 6px; padding: 20px;">
                    <p style="margin: 0 0 10px 0; color: #7f1d1d; font-size: 15px; font-weight: 600;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">🔐</span><span style="display: inline-block; vertical-align: middle;">Didn't make this change?</span>
                    </p>
                    <p style="margin: 0; color: #7f1d1d; font-size: 14px; line-height: 1.5;">
                      If you didn't change your password, your account may be compromised. Please contact our support team immediately to secure your account.
                    </p>
                  </td>
                </tr>
              </table>
              
              <!-- Security Tips -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 25px 0;">
                <tr>
                  <td style="background-color: #eff6ff; border-left: 4px solid #3b82f6; border-radius: 6px; padding: 20px;">
                    <p style="margin: 0 0 10px 0; color: #1e3a8a; font-size: 15px; font-weight: 600;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">💡</span><span style="display: inline-block; vertical-align: middle;">Security Best Practices</span>
                    </p>
                    <ul style="margin: 0; padding-left: 20px; color: #1e40af; font-size: 14px; line-height: 1.8;">
                      <li>Use a strong, unique password</li>
                      <li>Never share your password with anyone</li>
                      <li>Enable two-factor authentication if available</li>
                      <li>Change passwords regularly</li>
                    </ul>
                  </td>
                </tr>
              </table>
              
              <!-- Change Details -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="border-top: 1px solid #e5e7eb; padding-top: 20px;">
                <tr>
                  <td>
                    <p style="margin: 0 0 8px 0; color: #9ca3af; font-size: 12px; line-height: 1.5;">
                      <strong style="color: #6b7280;">Change Details:</strong>
                    </p>
                    <p style="margin: 0 0 4px 0; color: #9ca3af; font-size: 12px;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">📍</span><span style="display: inline-block; vertical-align: middle;">Location: ${location}</span>
                    </p>
                    <p style="margin: 0; color: #9ca3af; font-size: 12px;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">🌐</span><span style="display: inline-block; vertical-align: middle;">IP Address: ${ipAddress}</span>
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="background-color: #f9fafb; padding: 30px 40px; border-top: 1px solid #e5e7eb;">
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%">
                <tr>
                  <td align="center">
                    <p style="margin: 0 0 10px 0; color: #9ca3af; font-size: 13px; line-height: 1.6;">
                      This is an automated security notification from Agrhi.
                    </p>
                    <p style="margin: 0 0 10px 0; color: #9ca3af; font-size: 13px;">
                      Need help? Contact us at <a href="mailto:support@agrhi.com" style="color: #4CAF50; text-decoration: none;">support@agrhi.com</a>
                    </p>
                    <p style="margin: 0; color: #9ca3af; font-size: 12px;">
                      © ${new Date().getFullYear()} Agrhi. All rights reserved.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
`;
  }

  /**
   * Email verification OTP template
   */
  emailVerificationOTPTemplate({
    username,
    otp,
    ipAddress,
    location,
    timestamp,
  }) {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <title>Verify Your Email - Agrhi</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5; line-height: 1.6;">
  <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f5f5f5;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px; background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); overflow: hidden;">
          
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); padding: 40px 30px; text-align: center;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td align="center">
                    <table border="0" cellspacing="0" cellpadding="0" style="margin: 0 auto 15px auto;">
                      <tr>
                        <td width="70" height="70" align="center" valign="middle" style="background-color: #ffffff; border-radius: 50%;">
                          <div style="font-size: 36px; line-height: 70px; text-align: center;">🌱</div>
                        </td>
                      </tr>
                    </table>
                    <h1 style="color: #ffffff; margin: 0; font-size: 32px; font-weight: 600; letter-spacing: -0.5px;">Agrhi</h1>
                    <p style="color: rgba(255,255,255,0.9); margin: 8px 0 0 0; font-size: 14px;">Smart Agriculture Platform</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Main Content -->
          <tr>
            <td style="padding: 45px 40px 30px 40px;">
              <h2 style="color: #2c3e50; margin: 0 0 20px 0; font-size: 26px; font-weight: 600; line-height: 1.3;">Verify Your Email Address</h2>
              
              <p style="color: #4a5568; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
                Hello <strong style="color: #2c3e50;">${username}</strong>,
              </p>
              
              <p style="color: #4a5568; font-size: 16px; line-height: 1.6; margin: 0 0 30px 0;">
                Thank you for signing up! Use the verification code below to complete your email verification.
              </p>
            </td>
          </tr>
          
          <!-- OTP Code -->
          <tr>
            <td align="center" style="padding: 0 40px 35px 40px;">
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" style="background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%); border: 3px dashed #4CAF50; border-radius: 12px; padding: 30px;">
                <tr>
                  <td align="center">
                    <p style="margin: 0 0 10px 0; color: #6b7280; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px;">
                      Your Verification Code
                    </p>
                    <p style="margin: 0; color: #4CAF50; font-size: 42px; font-weight: bold; letter-spacing: 12px; font-family: 'Courier New', Courier, monospace;">
                      ${otp}
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Info Boxes -->
          <tr>
            <td style="padding: 0 40px 40px 40px;">
              
              <!-- Expiry Warning -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 20px 0;">
                <tr>
                  <td style="background-color: #fffbeb; border-left: 4px solid #f59e0b; border-radius: 6px; padding: 16px 20px;">
                    <p style="margin: 0; color: #92400e; font-size: 14px; line-height: 1.5;">
                      <strong style="font-size: 15px;"><span style="display: inline-block; vertical-align: middle; margin-right: 6px;">⏰</span><span style="display: inline-block; vertical-align: middle;">Valid for 10 minutes</span></strong><br>
                      This verification code will expire in 10 minutes for security reasons.
                    </p>
                  </td>
                </tr>
              </table>
              
              <!-- Security Notice -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 20px 0;">
                <tr>
                  <td style="background-color: #fef2f2; border-left: 4px solid #ef4444; border-radius: 6px; padding: 16px 20px;">
                    <p style="margin: 0; color: #7f1d1d; font-size: 14px; line-height: 1.5;">
                      <strong style="font-size: 15px;"><span style="display: inline-block; vertical-align: middle; margin-right: 6px;">🔒</span><span style="display: inline-block; vertical-align: middle;">Never share this code</span></strong><br>
                      Agrhi staff will never ask for your verification code. Do not share it with anyone.
                    </p>
                  </td>
                </tr>
              </table>
              
              <!-- Info Notice -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 25px 0;">
                <tr>
                  <td style="background-color: #eff6ff; border-left: 4px solid #3b82f6; border-radius: 6px; padding: 16px 20px;">
                    <p style="margin: 0; color: #1e3a8a; font-size: 14px; line-height: 1.5;">
                      <strong style="font-size: 15px;"><span style="display: inline-block; vertical-align: middle; margin-right: 6px;">💡</span><span style="display: inline-block; vertical-align: middle;">Didn't request this?</span></strong><br>
                      If you didn't request email verification, you can safely ignore this message.
                    </p>
                  </td>
                </tr>
              </table>
              
              <!-- Request Details -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="border-top: 1px solid #e5e7eb; padding-top: 20px;">
                <tr>
                  <td>
                    <p style="margin: 0 0 8px 0; color: #9ca3af; font-size: 12px; line-height: 1.5;">
                      <strong style="color: #6b7280;">Request Details:</strong>
                    </p>
                    <p style="margin: 0 0 4px 0; color: #9ca3af; font-size: 12px;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">📅</span><span style="display: inline-block; vertical-align: middle;">Time: ${timestamp}</span>
                    </p>
                    <p style="margin: 0 0 4px 0; color: #9ca3af; font-size: 12px;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">📍</span><span style="display: inline-block; vertical-align: middle;">Location: ${location}</span>
                    </p>
                    <p style="margin: 0; color: #9ca3af; font-size: 12px;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">🌐</span><span style="display: inline-block; vertical-align: middle;">IP Address: ${ipAddress}</span>
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="background-color: #f9fafb; padding: 30px 40px; border-top: 1px solid #e5e7eb;">
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%">
                <tr>
                  <td align="center">
                    <p style="margin: 0 0 10px 0; color: #9ca3af; font-size: 13px; line-height: 1.6;">
                      This is an automated security email from Agrhi.
                    </p>
                    <p style="margin: 0 0 15px 0; color: #9ca3af; font-size: 13px;">
                      Please do not reply to this message.
                    </p>
                    <p style="margin: 0; color: #9ca3af; font-size: 12px;">
                      © ${new Date().getFullYear()} Agrhi. All rights reserved.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
`;
  }

  /**
   * Email verified confirmation template
   */
  emailVerifiedTemplate({ username, ipAddress, location, timestamp }) {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <title>Email Verified - Agrhi</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5; line-height: 1.6;">
  <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f5f5f5;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px; background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); overflow: hidden;">
          
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); padding: 40px 30px; text-align: center;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td align="center">
                    <table border="0" cellspacing="0" cellpadding="0" style="margin: 0 auto 15px auto;">
                      <tr>
                        <td width="70" height="70" align="center" valign="middle" style="background-color: #ffffff; border-radius: 50%;">
                          <div style="font-size: 36px; line-height: 70px; text-align: center;">🌱</div>
                        </td>
                      </tr>
                    </table>
                    <h1 style="color: #ffffff; margin: 0; font-size: 32px; font-weight: 600; letter-spacing: -0.5px;">Agrhi</h1>
                    <p style="color: rgba(255,255,255,0.9); margin: 8px 0 0 0; font-size: 14px;">Smart Agriculture Platform</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Success Icon -->
          <tr>
            <td align="center" style="padding: 40px 40px 20px 40px;">
              <table border="0" cellspacing="0" cellpadding="0" style="margin: 0 auto;">
                <tr>
                  <td width="90" height="90" align="center" valign="middle" style="background: linear-gradient(135deg, #10b981 0%, #059669 100%); border-radius: 50%; box-shadow: 0 8px 24px rgba(16, 185, 129, 0.4);">
                    <div style="font-size: 50px; line-height: 90px; text-align: center; color: #ffffff; font-weight: bold;">✓</div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Main Content -->
          <tr>
            <td style="padding: 20px 40px 40px 40px; text-align: center;">
              <h2 style="color: #2c3e50; margin: 0 0 15px 0; font-size: 28px; font-weight: 600;">Email Verified Successfully!</h2>
              
              <p style="color: #4a5568; font-size: 16px; line-height: 1.6; margin: 0 0 25px 0;">
                Congratulations <strong style="color: #2c3e50;">${username}</strong>,
              </p>
              
              <p style="color: #4a5568; font-size: 16px; line-height: 1.6; margin: 0 0 25px 0;">
                Your email address has been successfully verified!
              </p>
              
              <!-- Timestamp Badge -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 35px 0;">
                <tr>
                  <td align="center">
                    <table border="0" cellspacing="0" cellpadding="0" style="background-color: #ecfdf5; border: 2px solid #10b981; border-radius: 8px;">
                      <tr>
                        <td style="padding: 15px 25px;">
                          <p style="margin: 0; color: #047857; font-size: 14px; font-weight: 600; text-align: center;">
                            <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">✓</span><span style="display: inline-block; vertical-align: middle;">Verified on ${timestamp}</span>
                          </p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Feature Boxes -->
          <tr>
            <td style="padding: 0 40px 40px 40px;">
              
              <!-- Welcome Box -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 20px 0;">
                <tr>
                  <td style="background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%); border-left: 4px solid #10b981; border-radius: 6px; padding: 20px;">
                    <p style="margin: 0 0 10px 0; color: #065f46; font-size: 16px; font-weight: 600;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">🎉</span><span style="display: inline-block; vertical-align: middle;">Welcome to Agrhi!</span>
                    </p>
                    <p style="margin: 0; color: #047857; font-size: 14px; line-height: 1.5;">
                      You now have full access to all features including plant disease detection, crop management, expert advice, and much more!
                    </p>
                  </td>
                </tr>
              </table>
              
              <!-- Benefits Box -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 20px 0;">
                <tr>
                  <td style="background-color: #eff6ff; border-left: 4px solid #3b82f6; border-radius: 6px; padding: 20px;">
                    <p style="margin: 0 0 12px 0; color: #1e3a8a; font-size: 15px; font-weight: 600;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">💡</span><span style="display: inline-block; vertical-align: middle;">Verified Email Benefits</span>
                    </p>
                    <ul style="margin: 0; padding-left: 20px; color: #1e40af; font-size: 14px; line-height: 1.8;">
                      <li>Password recovery access</li>
                      <li>Important notifications and updates</li>
                      <li>Enhanced account security</li>
                      <li>Priority support access</li>
                      <li>Exclusive feature announcements</li>
                    </ul>
                  </td>
                </tr>
              </table>
              
              <!-- Security Notice -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 25px 0;">
                <tr>
                  <td style="background-color: #fef2f2; border-left: 4px solid #ef4444; border-radius: 6px; padding: 16px 20px;">
                    <p style="margin: 0; color: #7f1d1d; font-size: 14px; line-height: 1.5;">
                      <strong style="font-size: 15px;"><span style="display: inline-block; vertical-align: middle; margin-right: 6px;">🔒</span><span style="display: inline-block; vertical-align: middle;">Security Notice</span></strong><br>
                      If you didn't verify this email address, please contact our support team immediately at <a href="mailto:support@agrhi.com" style="color: #7f1d1d; text-decoration: underline;">support@agrhi.com</a>
                    </p>
                  </td>
                </tr>
              </table>
              
              <!-- Verification Details -->
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%" style="border-top: 1px solid #e5e7eb; padding-top: 20px;">
                <tr>
                  <td>
                    <p style="margin: 0 0 8px 0; color: #9ca3af; font-size: 12px; line-height: 1.5;">
                      <strong style="color: #6b7280;">Verification Details:</strong>
                    </p>
                    <p style="margin: 0 0 4px 0; color: #9ca3af; font-size: 12px;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">📍</span><span style="display: inline-block; vertical-align: middle;">Location: ${location}</span>
                    </p>
                    <p style="margin: 0; color: #9ca3af; font-size: 12px;">
                      <span style="display: inline-block; vertical-align: middle; margin-right: 6px;">🌐</span><span style="display: inline-block; vertical-align: middle;">IP Address: ${ipAddress}</span>
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="background-color: #f9fafb; padding: 30px 40px; border-top: 1px solid #e5e7eb;">
              <table role="presentation" border="0" cellspacing="0" cellpadding="0" width="100%">
                <tr>
                  <td align="center">
                    <p style="margin: 0 0 10px 0; color: #9ca3af; font-size: 13px; line-height: 1.6;">
                      This is an automated confirmation from Agrhi.
                    </p>
                    <p style="margin: 0 0 10px 0; color: #9ca3af; font-size: 13px;">
                      Need help? Contact us at <a href="mailto:support@agrhi.com" style="color: #4CAF50; text-decoration: none;">support@agrhi.com</a>
                    </p>
                    <p style="margin: 0; color: #9ca3af; font-size: 12px;">
                      © ${new Date().getFullYear()} Agrhi. All rights reserved.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
`;
  }
}

module.exports = new EmailTemplates();
