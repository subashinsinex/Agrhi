// App.jsx

import { useEffect } from "react";
import { Routes, Route, useLocation, useNavigate } from "react-router-dom";
import Sidebar from "./components/sidebar";
import LoginForm from "./components/LoginForm";
import Dashboard from "./components/dashboard";
import UserManage from "./components/userManage";
import Subsidies from "./components/subsidies";
import FarmCrop from "./components/farmCrop";
import Master from "./components/master";
import Disease from "./components/disease";
import Report from "./components/report";
import Feedback from "./components/feedback";
import RetailManager from "./components/retailManager";
import MarketPlaceManagement from "./components/marketPlaceManagement";
import Account from "./components/account";
import { Header } from "./components/header";
import { DESKTOP_BREAKPOINT } from "./constant";
import ProtectedRoute from "./components/protectedRoute";
import ResetPassword from "./components/resetPassword";
import Home from "./components/home";

// Import the 3D Background component
import AgrhiBackground from "./parts/background";

// --- Constants (Must match constants in sidebar.jsx) ---
//const EXPANDED_WIDTH = "220px";
const COLLAPSED_WIDTH = "80px";

function App() {
  const location = useLocation();
  const navigate = useNavigate();

  const isLoginPage =
    location.pathname === "/" || location.pathname === "/login";
  const isResetPasswordPage = location.pathname.startsWith("/reset-password");
  const useStandardLayout = !isLoginPage && !isResetPasswordPage;

  // Active timer for refreshing access_token
  useEffect(() => {
    if (!useStandardLayout) return;

    const refreshTriggerMinutes = 10;
    let refreshIntervalId;
    let clearRefreshTimeout;
    let clearLogoutTimeout;

    const handleLogout = () => {
      localStorage.removeItem("access_token");
      localStorage.removeItem("refresh_token");
      navigate("/login"); // ← now correctly points to the login page
    };

    const refreshAccessToken = async () => {
      try {
        const refreshToken = localStorage.getItem("refresh_token");
        const response = await fetch("/api/refreshtoken", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ refreshToken }),
        });
        const data = await response.json();
        if (response.ok && data.access_token) {
          localStorage.setItem("access_token", data.access_token);
        } else {
          handleLogout();
        }
      } catch (err) {
        handleLogout();
      }
    };

    clearRefreshTimeout = setTimeout(
      () => {
        refreshIntervalId = setInterval(refreshAccessToken, 60 * 1000);
        clearLogoutTimeout = setTimeout(
          () => {
            clearInterval(refreshIntervalId);
            handleLogout();
          },
          5 * 60 * 1000,
        );
      },
      refreshTriggerMinutes * 60 * 1000,
    );

    return () => {
      clearTimeout(clearRefreshTimeout);
      clearLogoutTimeout = clearTimeout(clearLogoutTimeout);
      clearInterval(refreshIntervalId);
    };
  }, [useStandardLayout, navigate]);

  return (
    <>
      {/* 1. The 3D Animation Component 
          This will sit behind everything because of z-index: -1 
      */}
      <AgrhiBackground />

      <div className="admin-layout">
        {/* Sidebar: only for standard layout */}
        {useStandardLayout && <Sidebar />}

        {/* Main content */}
        <main
          className={
            useStandardLayout
              ? "admin-content admin-content--with-sidebar"
              : "admin-content admin-content--full"
          }
        >
          {/* Header: only for standard layout */}
          {useStandardLayout && <Header />}

          <Routes>
            {/* Public/Auth Routes */}
            <Route path="/" element={<Home />} /> {/* ← NEW home page */}
            <Route path="/login" element={<LoginForm />} />
            <Route path="/reset-password" element={<ResetPassword />} />
            {/* Protected Routes */}
            <Route
              path="/dashboard"
              element={
                <ProtectedRoute>
                  <Dashboard />
                </ProtectedRoute>
              }
            />
            <Route
              path="/userManage"
              element={
                <ProtectedRoute>
                  <UserManage />
                </ProtectedRoute>
              }
            />
            <Route
              path="/farmcrop"
              element={
                <ProtectedRoute>
                  <FarmCrop />
                </ProtectedRoute>
              }
            />
            <Route
              path="/subsidies"
              element={
                <ProtectedRoute>
                  <Subsidies />
                </ProtectedRoute>
              }
            />
            <Route
              path="/master"
              element={
                <ProtectedRoute>
                  <Master />
                </ProtectedRoute>
              }
            />
            <Route
              path="/diseases"
              element={
                <ProtectedRoute>
                  <Disease />
                </ProtectedRoute>
              }
            />
            <Route
              path="/reports"
              element={
                <ProtectedRoute>
                  <Report />
                </ProtectedRoute>
              }
            />
            <Route
              path="/feedback"
              element={
                <ProtectedRoute>
                  <Feedback />
                </ProtectedRoute>
              }
            />
            <Route
              path="/retail-manager"
              element={
                <ProtectedRoute>
                  <RetailManager />
                </ProtectedRoute>
              }
            />
            <Route
              path="/marketplace-management"
              element={
                <ProtectedRoute>
                  <MarketPlaceManagement />
                </ProtectedRoute>
              }
            />
            <Route
              path="/account"
              element={
                <ProtectedRoute>
                  <Account />
                </ProtectedRoute>
              }
            />
          </Routes>
        </main>
      </div>

      <style>{`
        /* --- IDLE: FULL CONTENT | HOVER: SIDEBAR OVERLAYS (NO SHIFT) --- */
        html, body, #root {
          height: 100vh;
          margin: 0;
          padding: 0;
          font-family: 'Inter', sans-serif;
          overflow-x: hidden;
        }

        .admin-layout {
          min-height: 100vh;
          display: flex;
          background-color: transparent;
        }

        /* ALWAYS: Content FULL viewport (no sidebar spacing ever) */
        .admin-content {
          flex: 1;
          padding: 20px 20px 20px ${COLLAPSED_WIDTH} !important;
          background-color: transparent;
          margin-left: 0 !important; /* FULL WIDTH ALWAYS */
          width: 100vw !important;
          transition: none !important; /* NO MOVEMENT */
          height: 100vh;
          overflow-y: compatible;
        }

        .admin-content > *:first-child {
          margin-top: 0;
        }
        .admin-content > *:last-child {
          margin-bottom: 0;
        }

        /* HOVER: Sidebar expands OVER content (NO content movement) */
        @media (min-width: ${DESKTOP_BREAKPOINT}px) {
          /* Sidebar ONLY changes - content stays STATIC */
        }

        .admin-content--full {
          margin-left: 0;
          width: 100vw;
          padding: 0;
        }

        @media (max-width: ${DESKTOP_BREAKPOINT - 1}px) {
          .admin-content {
            padding: 20px !important; 
          }
        }
      `}</style>
    </>
  );
}

export default App;
