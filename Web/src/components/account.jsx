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
  Sprout, // Added Sprout for thematic relevance
  Tractor, // Added Tractor if available, otherwise fallback to generic
} from "lucide-react";
import { SERVER_ADDR } from "../constant";

const apiBase = `${SERVER_ADDR}/api/profile`;

// --- Thematic Sub-Component for Data ---
const DetailCard = ({ Icon, label, value }) => (
  <div className="ag-detail-card">
    <div className="ag-icon-box">
      <Icon size={22} strokeWidth={1.5} />
    </div>
    <div className="ag-detail-content">
      <span className="ag-label">{label}</span>
      <p className="ag-value">{value || "Not Provided"}</p>
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
      return payload.user_id || payload.userid;
    } catch {
      return "";
    }
  };

  const user_id = getUserIdFromToken();

  const fetchProfile = useCallback(async () => {
    setErrorMsg("");
    setMsg("Cultivating profile data..."); // Thematic loading text

    if (!access_token) {
      setErrorMsg("Authentication token missing.");
      setMsg("");
      return;
    }

    if (!user_id) {
      setErrorMsg("User Identity not found.");
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
        "Could not load details: " + (e.response?.data?.message || e.message)
      );
      setProfile(null);
      setMsg("");
    }
  }, [access_token, user_id]);

  useEffect(() => {
    fetchProfile();
  }, [fetchProfile]);

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

  // --- AGRICULTURE THEME CSS ---
  const CSS_STYLES = `
    /* --- Variables & Palette --- */
    :root {
        --ag-primary: #2e7d32;      /* Deep Forest Green */
        --ag-primary-light: #4caf50; /* Fresh Leaf Green */
        --ag-accent: #f9a825;       /* Harvest Gold/Sun */
        --ag-earth: #5d4037;        /* Soil Brown */
        --ag-bg-card: #ffffff;
        --ag-bg-hover: #f1f8e9;     /* Very Light Green Tint */
        --ag-text-dark: #1b3a23;    /* Dark Green/Black for text */
        --ag-text-muted: #557b5e;   /* Muted Green for labels */
        --ag-shadow: 0 10px 15px -3px rgba(46, 125, 50, 0.1), 0 4px 6px -2px rgba(46, 125, 50, 0.05);
    }

    /* --- Container --- */
    .app-container {
        padding: 40px 20px;
        height: 80px;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    }

    /* --- Feedback Messages --- */
    .status-message, .error-message {
        padding: 15px 20px;
        margin: 0 auto 20px auto;
        border-radius: 8px;
        max-width: 1000px;
        font-weight: 600;
        display: flex;
        align-items: center;
    }
    .status-message {
        background-color: #e8f5e9;
        color: #2e7d32;
        border-left: 5px solid #2e7d32;
    }
    .error-message {
        background-color: #ffebee;
        color: #c62828;
        border-left: 5px solid #c62828;
    }
    .loading-state {
        text-align: center;
        padding: 60px;
        font-size: 1.2rem;
        color: var(--ag-primary);
        font-weight: 500;
    }

    /* --- Main Profile Card Wrapper --- */
    .profile-wrapper {
        max-width: 900px;
        margin: 0 auto;
        background: var(--ag-bg-card);
        border-radius: 20px;
        overflow: hidden;
        box-shadow: var(--ag-shadow);
        border: 1px solid rgba(46, 125, 50, 0.1);
    }

    /* --- Profile Banner (The "Field") --- */
    .profile-banner {
        height: 140px;
        background: linear-gradient(135deg, var(--ag-primary) 0%, var(--ag-primary-light) 100%);
        position: relative;
        /* Subtle pattern overlay could go here */
    }

    /* --- Profile Header Content --- */
    .profile-header-content {
        padding: 0 40px;
        position: relative;
        margin-top: -50px; /* Pull content up over the banner */
        display: flex;
        flex-direction: column;
        align-items: flex-start;
        border-bottom: 1px solid #e0e0e0;
        padding-bottom: 30px;
        margin-bottom: 30px;
    }

    .avatar-container {
        width: 100px;
        height: 100px;
        background: white;
        border-radius: 50%;
        padding: 4px;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        display: flex;
        align-items: center;
        justify-content: center;
        margin-bottom: 15px;
    }

    .avatar-circle {
        width: 100%;
        height: 100%;
        background-color: var(--ag-bg-hover);
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        color: var(--ag-primary);
        border: 2px solid var(--ag-primary-light);
    }

    .user-identity {
        width: 100%;
    }

    .profile-name {
        font-size: 2rem;
        font-weight: 700;
        color: var(--ag-text-dark);
        margin: 0;
        line-height: 1.2;
    }

    .profile-badges {
        display: flex;
        gap: 10px;
        margin-top: 10px;
        flex-wrap: wrap;
    }

    .category-badge {
        display: inline-flex;
        align-items: center;
        background-color: var(--ag-accent);
        color: #fff; /* White text on gold */
        padding: 6px 16px;
        font-size: 0.85rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        /* "Leaf" shape border radius */
        border-radius: 16px 4px 16px 4px; 
        box-shadow: 0 2px 4px rgba(249, 168, 37, 0.3);
    }

    .id-badge {
        display: inline-flex;
        align-items: center;
        background-color: var(--ag-bg-hover);
        color: var(--ag-primary);
        padding: 6px 12px;
        font-size: 0.85rem;
        font-weight: 500;
        border-radius: 4px;
        border: 1px solid var(--ag-primary-light);
    }

    /* --- Data Grid --- */
    .info-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
        gap: 20px;
        padding: 0 40px 40px 40px;
    }

    /* --- Detail Cards --- */
    .ag-detail-card {
        display: flex;
        align-items: center;
        background-color: #fff;
        border: 1px solid #e0e0e0;
        padding: 20px;
        border-radius: 12px;
        transition: all 0.3s ease;
    }

    .ag-detail-card:hover {
        border-color: var(--ag-primary-light);
        box-shadow: 0 4px 12px rgba(46, 125, 50, 0.08);
        transform: translateY(-2px);
    }

    .ag-icon-box {
        width: 45px;
        height: 45px;
        background-color: var(--ag-bg-hover);
        border-radius: 10px;
        display: flex;
        align-items: center;
        justify-content: center;
        color: var(--ag-primary);
        margin-right: 15px;
        flex-shrink: 0;
    }

    .ag-detail-content {
        flex-grow: 1;
        overflow: hidden;
    }

    .ag-label {
        display: block;
        font-size: 0.75rem;
        color: var(--ag-text-muted);
        text-transform: uppercase;
        font-weight: 600;
        margin-bottom: 4px;
    }

    .ag-value {
        margin: 0;
        font-size: 1rem;
        color: var(--ag-text-dark);
        font-weight: 500;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    /* --- Responsive --- */
    @media (max-width: 600px) {
        .profile-header-content {
            align-items: center;
            text-align: center;
            margin-top: -40px;
        }
        .profile-badges {
            justify-content: center;
        }
        .info-grid {
            grid-template-columns: 1fr;
            padding: 0 20px 40px 20px;
        }
    }
  `;

  // --- Style Injection ---
  const StyleInjector = () => {
    useEffect(() => {
      let styleElement = document.getElementById("ag-account-styles");
      if (!styleElement) {
        styleElement = document.createElement("style");
        styleElement.id = "ag-account-styles";
        styleElement.textContent = CSS_STYLES;
        document.head.appendChild(styleElement);
      }
    }, []);
    return null;
  };

  return (
    <>
      <StyleInjector />

      <div className="app-container">
        {/* Messages */}
        {msg && (
          <div className="status-message">
            <Sprout size={18} style={{ marginRight: 10 }} /> {msg}
          </div>
        )}
        {errorMsg && <div className="error-message">🚨 {errorMsg}</div>}

        {/* Loading */}
        {!profile && !errorMsg && (
          <div className="loading-state">Harvesting User Data...</div>
        )}

        {/* Content */}
        {profile && (
          <div className="profile-wrapper">
            {/* 1. Gradient Banner (The Field) */}
            <div className="profile-banner"></div>

            {/* 2. Header Section (The Farmer) */}
            <div className="profile-header-content">
              <div className="avatar-container">
                <div className="avatar-circle">
                  <User size={40} />
                </div>
              </div>

              <div className="user-identity">
                <h2 className="profile-name">
                  {profile.name || "Unknown Cultivator"}
                </h2>

                <div className="profile-badges">
                  <div className="category-badge">
                    <Tractor
                      size={14}
                      className="mr-1"
                      style={{ marginRight: "6px" }}
                    />
                    {profile.user_category || "General User"}
                  </div>
                  <div className="id-badge">ID: {user_id}</div>
                </div>
              </div>
            </div>

            {/* 3. Data Grid (The Crops) */}
            <div className="info-grid">
              <DetailCard
                Icon={Mail}
                label="Email Address"
                value={profile.email}
              />
              <DetailCard
                Icon={Smartphone}
                label="Mobile Number"
                value={profile.phone_number}
              />
              <DetailCard
                Icon={Calendar}
                label="Date of Birth"
                value={formatDate(profile.dob)}
              />
              <DetailCard
                Icon={MapPin}
                label="Farm / Home Address"
                value={profile.address}
              />
              <DetailCard
                Icon={Lock}
                label="Region Pincode"
                value={profile.pincode}
              />
              <DetailCard
                Icon={ShieldCheck}
                label="Account Status"
                value="Verified & Active"
              />
            </div>
          </div>
        )}
      </div>
    </>
  );
};

export default Account;
