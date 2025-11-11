import React, { useEffect, useState, useCallback } from "react";
import { axiosInstance } from "../api/login";
import {
  User,
  Mail,
  Smartphone,
  Calendar,
  MapPin,
  Lock,
  ShieldCheck,
  Zap,
} from "lucide-react";
import { SERVER_IP,SERVER_PORT } from "../constant";

const apiBase = `http://${SERVER_IP}:${SERVER_PORT}/api/profile`; // Adjust path per your backend

// Sub-Component for Clean Detail Rows
const DetailRow = ({ Icon, label, value }) => (
  <div className="detail-row">
    <Icon size={20} className="detail-icon" />
    <div className="detail-content">
      <span className="detail-label">{label}</span>
      <p className="detail-value">{value}</p>
    </div>
  </div>
);

const Account = () => {
  const [profile, setProfile] = useState(null);
  const [msg, setMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");
  const access_token = localStorage.getItem("access_token");

  // Get user_id from JWT
  const getUserIdFromToken = () => {
    try {
      const token = access_token;
      if (!token) return "";
      const payload = JSON.parse(atob(token.split(".")[1]));
      return payload.user_id || payload.userid; // adjust field per your JWT
    } catch {
      return "";
    }
  };

  const user_id = getUserIdFromToken();

  const fetchProfile = useCallback(async () => {
    setErrorMsg("");
    setMsg("Fetching profile data...");

    if (!access_token) {
      setErrorMsg("Authentication token missing. Cannot fetch data.");
      setMsg("");
      return;
    }

    if (!user_id) {
      setErrorMsg("User ID not found. Not logged in?");
      setMsg("");
      return;
    }

    try {
      const res = await axiosInstance.get(
        `${apiBase}/getUserDetails/${user_id}`,
        {
          headers: { Authorization: `Bearer ${access_token}` },
        }
      );
      setProfile(res.data);
      setMsg("Profile loaded successfully.");
    } catch (e) {
      setErrorMsg(
        "Could not load account details: " +
          (e.response?.data?.message || e.message)
      );
      setProfile(null);
      setMsg("");
    }
  }, [access_token, user_id]);

  useEffect(() => {
    fetchProfile();
  }, [fetchProfile]);

  // Helper function to format date
  const formatDate = (dateString) => {
    if (!dateString) return "N/A";
    try {
      return new Date(dateString).toLocaleDateString("en-US", {
        year: "numeric",
        month: "long",
        day: "numeric",
      });
    } catch {
      return dateString;
    }
  };

  // --- CSS Styles (Modified for Full Width) ---
  const CSS_STYLES = `
    /* --- Global Reset & Colors --- */
    :root {
        --primary-color: #4f46e5; /* Indigo/Purple */
        --text-dark: #1f2937;
        --text-medium: #6b7280;
        --border-light: #e5e7eb;
        --background-light: #f4f7f9;
    }

    /* --- Layout Container --- */
    .app-container {
        padding: 30px;
        background-color: var(--background-light);
        min-height: calc(100vh - 60px); 
    }

    /* --- Header --- */
    .header-bar {
        display: flex;
        align-items: center;
        margin-bottom: 30px;
        padding-bottom: 15px;
        border-bottom: 1px solid var(--border-light);
    }

    .header-title {
        font-size: 2rem;
        font-weight: 700;
        color: var(--text-dark);
        margin: 0;
    }

    .header-icon {
        color: var(--primary-color);
        margin-right: 10px;
    }

    /* --- Messages --- */
    .status-message, .error-message {
        padding: 12px;
        margin-bottom: 20px;
        border-radius: 6px;
        font-weight: 500;
    }
    .status-message {
        background-color: #e6f7e9;
        color: #38a169;
        border: 1px solid #b2f5b8;
    }
    .error-message {
        background-color: #fee2e2;
        color: #dc2626;
        border: 1px solid #fca5a5;
    }

    .loading-state {
        text-align: center;
        padding: 50px;
        font-size: 1.1rem;
        color: var(--text-medium);
    }

    /* --- Profile Grid Layout (Full Width) --- */
    .profile-content-wrapper {
        /* Now acts as a centered container for the single card */
        max-width: 1000px; /* Set a max width for elegance */
        margin: 0 auto;
    }

    /* --- Main Profile Card --- */
    .profile-card {
        background-color: #ffffff;
        border-radius: 10px;
        box-shadow: 0 4px 10px rgba(0, 0, 0, 0.05);
        padding: 30px;
        height: fit-content;
    }

    /* Profile Header Section */
    .profile-header {
        display: flex;
        align-items: center;
        padding-bottom: 20px;
        margin-bottom: 20px;
        border-bottom: 1px solid var(--border-light);
    }

    .avatar-placeholder {
        width: 60px;
        height: 60px;
        border-radius: 50%;
        background-color: var(--primary-color);
        display: flex;
        align-items: center;
        justify-content: center;
        margin-right: 20px;
        flex-shrink: 0;
    }

    .profile-name {
        font-size: 1.5rem;
        font-weight: 600;
        color: var(--text-dark);
        margin: 0 0 5px 0;
    }

    .profile-category {
        font-size: 0.9rem;
        color: var(--primary-color);
        display: flex;
        align-items: center;
        font-weight: 500;
    }

    .mr-1 { margin-right: 5px; } 

    /* Details Grid */
    .info-details-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
        gap: 15px;
    }

    /* Detail Row Sub-Component */
    .detail-row {
        display: flex;
        padding: 10px 0;
    }

    .detail-icon {
        color: var(--primary-color);
        margin-right: 15px;
        margin-top: 2px;
        flex-shrink: 0;
    }

    .detail-content {
        flex-grow: 1;
    }

    .detail-label {
        display: block;
        font-size: 0.8rem;
        color: var(--text-medium);
        margin-bottom: 2px;
        font-weight: 500;
        text-transform: uppercase;
    }

    .detail-value {
        font-size: 1rem;
        color: var(--text-dark);
        font-weight: 400;
        margin: 0;
    }

    /* --- Responsiveness --- */
    @media (max-width: 600px) {
        .app-container {
            padding: 15px;
        }
        .profile-header {
            flex-direction: column;
            text-align: center;
        }
        .avatar-placeholder {
            margin-right: 0;
            margin-bottom: 15px;
        }
        .info-details-grid {
            grid-template-columns: 1fr;
        }
    }
  `;

  // --- Component to inject styles ---
  const StyleInjector = () => {
    useEffect(() => {
      let styleElement = document.getElementById("account-styles");
      if (!styleElement) {
        styleElement = document.createElement("style");
        styleElement.id = "account-styles";
        styleElement.textContent = CSS_STYLES;
        document.head.appendChild(styleElement);
      }
    }, []);
    return null;
  };

  // --- Page UI ---
  return (
    <>
      <StyleInjector />

      <div className="app-container">
        <div className="header-bar">
          <Zap size={30} className="header-icon" />
          <h1 className="header-title">Account Details</h1>
        </div>

        {/* Messages */}
        {msg && <div className="status-message">{msg}</div>}
        {errorMsg && <div className="error-message">🚨 {errorMsg}</div>}

        {/* Loading State */}
        {!profile && !errorMsg && (
          <div className="loading-state">Loading Account Details...</div>
        )}

        {/* Profile Card Layout (Now full width) */}
        {profile && (
          <div className="profile-content-wrapper">
            <div className="profile-card">
              {/* Top Section - Name and Category */}
              <div className="profile-header">
                <div className="avatar-placeholder">
                  <User size={36} className="text-white" />
                </div>
                <div className="info-main">
                  <h2 className="profile-name">
                    {profile.name || "User Name Not Set"}
                  </h2>
                  <div className="profile-category">
                    <ShieldCheck size={16} className="mr-1" />
                    **{profile.user_category || "General User"}**
                  </div>
                </div>
              </div>

              {/* Detailed Information Grid */}
              <div className="info-details-grid">
                <DetailRow
                  Icon={Mail}
                  label="Email Address"
                  value={profile.email}
                />
                <DetailRow
                  Icon={Smartphone}
                  label="Phone Number"
                  value={profile.phone_number || "N/A"}
                />
                <DetailRow
                  Icon={Calendar}
                  label="Date of Birth"
                  value={formatDate(profile.dob)}
                />
                <DetailRow
                  Icon={MapPin}
                  label="Address"
                  value={profile.address || "N/A"}
                />
                <DetailRow
                  Icon={Lock}
                  label="Pincode"
                  value={profile.pincode || "N/A"}
                />
                <DetailRow Icon={User} label="User ID" value={user_id} />
              </div>
            </div>

            {/* The action-card component has been removed from here */}
          </div>
        )}
      </div>
    </>
  );
};

export default Account;
