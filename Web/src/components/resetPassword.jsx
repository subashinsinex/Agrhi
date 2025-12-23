import React, { useState, useEffect, useCallback } from "react";
import { Lock, Eye, EyeOff, Check, AlertTriangle, Loader } from "lucide-react";
import { axiosInstance } from "../api/login";
import { SERVER_IP, SERVER_PORT } from "../constant";

const API_BASE_URL = `http://${SERVER_IP}:${SERVER_PORT}/api/forgot-password`;
const VERIFY_TOKEN_URL = `${API_BASE_URL}/verify-token`;
const RESET_PASSWORD_URL = `${API_BASE_URL}/reset`;

const ResetPasswordPage = () => {
  // --- State Variables ---
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const [status, setStatus] = useState({
    type: "info",
    message: "Initializing...",
    mobile: "",
  });
  const [isLoading, setIsLoading] = useState(false);
  const [isTokenValid, setIsTokenValid] = useState(false);
  const [token, setToken] = useState(null);

  // --- Derived State ---
  const passwordsMatch = newPassword === confirmPassword;
  const isPasswordValid = newPassword.length >= 8;

  // --- Helpers ---
  const getTokenFromUrl = useCallback(() => {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get("token");
  }, []);

  // --- 1. Token Verification ---
  useEffect(() => {
    const urlToken = getTokenFromUrl();
    setToken(urlToken);

    if (!urlToken) {
      setStatus({
        type: "error",
        message: "Token not found. Please check your email link.",
      });
      setIsTokenValid(false);
      return;
    }

    const verifyToken = async () => {
      setIsLoading(true);
      setStatus({ type: "info", message: "Verifying secure token..." });

      try {
        const response = await axiosInstance.post(VERIFY_TOKEN_URL, {
          token: urlToken,
        });

        if (response.data.success) {
          setIsTokenValid(true);
          const mobileEnd = response.data.mobile
            ? response.data.mobile
            : "****";
          setStatus({
            type: "success",
            message: `Token verified. Resetting for mobile ending in ${mobileEnd}.`,
            mobile: response.data.mobile,
          });
        } else {
          setIsTokenValid(false);
          setStatus({
            type: "error",
            message: response.data.message || "Invalid or expired token.",
          });
        }
      } catch (e) {
        console.error("Token verification error:", e);
        setIsTokenValid(false);
        setStatus({
          type: "error",
          message: "Network error. Could not verify token.",
        });
      } finally {
        setIsLoading(false);
      }
    };

    verifyToken();
  }, [getTokenFromUrl]);

  // --- 2. CSS Injection (Fixed ESLint Warning) ---
  useEffect(() => {
    const CSS_STYLES = `
      :root {
        --primary: #6366f1;
        --primary-hover: #4f46e5;
        --bg-gradient-start: #f8fafc;
        --bg-gradient-end: #e2e8f0;
        --text-main: #1e293b;
        --text-muted: #64748b;
        --border-color: #cbd5e1;
      }

      * { box-sizing: border-box; }

      .reset-page {
        min-height: 100vh;
        width: 100%;
        display: flex;
        justify-content: center;
        align-items: center;
        background: linear-gradient(135deg, var(--bg-gradient-start) 0%, var(--bg-gradient-end) 100%);
        padding: 20px;
        font-family: 'Inter', system-ui, -apple-system, sans-serif;
      }

      .reset-card {
        background: #ffffff;
        border-radius: 16px;
        box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
        padding: 40px 36px;
        width: 100%;
        max-width: 440px;
        position: relative;
      }

      .reset-header {
        text-align: center;
        margin-bottom: 32px;
      }

      .icon-container {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        margin-bottom: 16px;
        color: var(--text-main);
      }

      .reset-title {
        font-size: 1.5rem;
        font-weight: 700;
        color: var(--text-main);
        margin: 0;
      }

      /* --- FIXED SNACKBAR STYLES --- */
      .status-snackbar {
        position: fixed;
        top: 24px;
        left: 0;
        width: 100%;
        display: flex;
        justify-content: center;
        pointer-events: none;
        z-index: 9999;
      }

      .status-message {
        pointer-events: auto;
        display: inline-flex;
        align-items: center;
        padding: 10px 20px;
        border-radius: 50px;
        font-size: 0.9rem;
        font-weight: 600;
        box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
        max-width: 90%;
        width: auto;
        animation: slideDown 0.4s cubic-bezier(0.16, 1, 0.3, 1);
      }

      @keyframes slideDown {
        from { transform: translateY(-100%); opacity: 0; }
        to { transform: translateY(0); opacity: 1; }
      }

      .status-message.info { background-color: #3b82f6; color: white; }
      .status-message.success { background-color: #10b981; color: white; }
      .status-message.error { background-color: #ef4444; color: white; }

      .msg-icon { margin-right: 8px; flex-shrink: 0; }

      .form-group { margin-bottom: 20px; }

      label {
        display: block;
        font-size: 0.85rem;
        font-weight: 600;
        color: #475569;
        margin-bottom: 6px;
      }

      .input-wrapper {
        position: relative;
        display: flex;
        align-items: center;
      }

      .password-input {
        width: 100%;
        padding: 12px 40px 12px 14px;
        border: 1px solid var(--border-color);
        border-radius: 8px;
        font-size: 0.95rem;
        color: var(--text-main);
        transition: all 0.2s;
        outline: none;
        background: #f8fafc;
      }

      .password-input:focus {
        background: #fff;
        border-color: var(--primary);
        box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.15);
      }

      .password-input:disabled {
        background-color: #f1f5f9;
        cursor: not-allowed;
        color: #94a3b8;
      }

      .toggle-button {
        position: absolute;
        right: 12px;
        background: none;
        border: none;
        cursor: pointer;
        color: var(--text-muted);
        display: flex;
        align-items: center;
        padding: 4px;
        transition: color 0.2s;
      }

      .toggle-button:hover:not(:disabled) { color: var(--text-main); }

      .submit-btn {
        width: 100%;
        padding: 14px;
        background-color: #94a3b8;
        color: white;
        border: none;
        border-radius: 8px;
        font-size: 1rem;
        font-weight: 600;
        cursor: not-allowed;
        margin-top: 10px;
        display: flex;
        justify-content: center;
        align-items: center;
        gap: 8px;
        transition: all 0.2s;
      }

      .submit-btn:not(:disabled) {
        background-color: var(--primary);
        cursor: pointer;
        box-shadow: 0 4px 6px -1px rgba(99, 102, 241, 0.4);
      }

      .submit-btn:not(:disabled):hover {
        background-color: var(--primary-hover);
        transform: translateY(-1px);
      }

      .spin { animation: spin 1s linear infinite; }
      @keyframes spin { 100% { transform: rotate(360deg); } }
    `;

    let styleElement = document.getElementById("reset-password-styles");
    if (!styleElement) {
      styleElement = document.createElement("style");
      styleElement.id = "reset-password-styles";
      styleElement.textContent = CSS_STYLES;
      document.head.appendChild(styleElement);
    } else {
      styleElement.textContent = CSS_STYLES;
    }
  }, []);

  // --- Auto-hide Snackbar ---
  useEffect(() => {
    if (!status.message) return;
    if (status.type === "error") return;

    const timer = setTimeout(() => {
      setStatus((prev) => ({ ...prev, message: "" }));
    }, 4000);

    return () => clearTimeout(timer);
  }, [status.message, status.type]);

  // --- 3. Submit Handler ---
  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!isTokenValid) {
      setStatus({
        type: "error",
        message: "Cannot submit: Invalid or expired token.",
      });
      return;
    }

    if (!passwordsMatch || !isPasswordValid) {
      setStatus({
        type: "error",
        message: "Please fix validation errors before submitting.",
      });
      return;
    }

    setIsLoading(true);
    setStatus({ type: "info", message: "Updating password..." });

    try {
      const response = await axiosInstance.post(RESET_PASSWORD_URL, {
        token: token,
        newPassword: newPassword,
      });

      if (response.data.success) {
        setStatus({
          type: "success",
          message:
            "Now go to login page in your app. This webpage will close automatically in 10 secs.",
        });
        setNewPassword("");
        setConfirmPassword("");
        // prevent further edits
        setIsTokenValid(false);

        // Auto close / redirect after 10 seconds
        setTimeout(() => {
          // Try to close the window (works if opened by script)
          window.close();
          // If close is blocked, you can instead redirect:
          // window.location.href = "your-login-page-or-app-scheme";
        }, 10000);
      } else {
        setStatus({
          type: "error",
          message: response.data.message || "Reset failed.",
        });
      }
    } catch (e) {
      console.error("Reset error:", e);
      setStatus({
        type: "error",
        message: "Server connection failed.",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const toggleVisibility = (field) => {
    if (field === "new") setShowNewPassword(!showNewPassword);
    if (field === "confirm") setShowConfirmPassword(!showConfirmPassword);
  };

  // --- Render ---
  return (
    <>
      <div className="reset-page">
        {/* SNACKBAR COMPONENT */}
        {status.message && (
          <div className="status-snackbar">
            <div className={`status-message ${status.type}`}>
              {status.type === "error" && (
                <AlertTriangle size={18} className="msg-icon" />
              )}
              {status.type === "success" && (
                <Check size={18} className="msg-icon" />
              )}
              {status.type === "info" && (
                <Loader size={18} className="msg-icon spin" />
              )}
              <span>{status.message}</span>
            </div>
          </div>
        )}

        {/* Show reset card only when token is valid */}
        {isTokenValid && (
          <div className="reset-card">
            <div className="reset-header">
              <div className="icon-container">
                <Lock size={28} />
              </div>
              <h2 className="reset-title">Set New Password</h2>
            </div>

            <form onSubmit={handleSubmit}>
              {/* New Password */}
              <div className="form-group">
                <label htmlFor="newPassword">New Password</label>
                <div className="input-wrapper">
                  <input
                    id="newPassword"
                    type={showNewPassword ? "text" : "password"}
                    className="password-input"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    placeholder="Min 8 characters"
                    required
                    disabled={!isTokenValid || isLoading}
                  />
                  <button
                    type="button"
                    className="toggle-button"
                    onClick={() => toggleVisibility("new")}
                    disabled={!isTokenValid}
                  >
                    {showNewPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>
              </div>

              {/* Confirm Password */}
              <div className="form-group">
                <label htmlFor="confirmPassword">Confirm Password</label>
                <div className="input-wrapper">
                  <input
                    id="confirmPassword"
                    type={showConfirmPassword ? "text" : "password"}
                    className="password-input"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    placeholder="Re-enter password"
                    required
                    disabled={!isTokenValid || isLoading}
                  />
                  <button
                    type="button"
                    className="toggle-button"
                    onClick={() => toggleVisibility("confirm")}
                    disabled={!isTokenValid}
                  >
                    {showConfirmPassword ? (
                      <EyeOff size={18} />
                    ) : (
                      <Eye size={18} />
                    )}
                  </button>
                </div>
              </div>

              {/* Submit Button */}
              <button
                type="submit"
                className="submit-btn"
                disabled={
                  !isTokenValid ||
                  isLoading ||
                  !passwordsMatch ||
                  !isPasswordValid
                }
              >
                {isLoading ? (
                  <>
                    <Loader size={20} className="spin" />
                    <span>Resetting...</span>
                  </>
                ) : (
                  "Reset Password"
                )}
              </button>
            </form>
          </div>
        )}

        {/* Optional invalid token card */}
        {!isTokenValid && status.type === "error" && (
          <div className="reset-card">
            <div className="reset-header">
              <div className="icon-container">
                <AlertTriangle size={28} />
              </div>
              <h2 className="reset-title">Invalid or Expired Link</h2>
              <p style={{ color: "#64748b", marginTop: 8 }}>
                This reset link contains invalid or expired token. Please
                request a new password reset from the app.
              </p>
            </div>
          </div>
        )}
      </div>
    </>
  );
};

export default ResetPasswordPage;
