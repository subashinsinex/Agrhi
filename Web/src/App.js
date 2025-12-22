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
import Account from "./components/account";
import { Header } from "./components/header";
import { DESKTOP_BREAKPOINT } from "./constant";
import ProtectedRoute from "./components/protectedRoute";
import ResetPassword from "./components/resetPassword";

// --- Constants (Must match constants in sidebar.jsx) ---
const EXPANDED_WIDTH = "220px";
const COLLAPSED_WIDTH = "60px";

function App() {
  const location = useLocation();
  const navigate = useNavigate();

  const isLoginPage = location.pathname === "/";
  const isResetPasswordPage = location.pathname.startsWith("/reset-password");
  const useStandardLayout = !isLoginPage && !isResetPasswordPage;

  // Active timer for refreshing access_token
  useEffect(() => {
    // Only run timer if we are in the standard protected app routes
    if (!useStandardLayout) return;

    const refreshTriggerMinutes = 10;
    let refreshIntervalId;
    let clearRefreshTimeout;
    let clearLogoutTimeout;

    const handleLogout = () => {
      localStorage.removeItem("access_token");
      localStorage.removeItem("refresh_token");
      navigate("/");
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

    // First 10 mins - no refresh
    clearRefreshTimeout = setTimeout(() => {
      // Last 5 mins - start interval polling
      refreshIntervalId = setInterval(refreshAccessToken, 60 * 1000);
      // On expiry, clear refresh interval and force logout if not refreshed
      clearLogoutTimeout = setTimeout(() => {
        clearInterval(refreshIntervalId);
        handleLogout();
      }, 5 * 60 * 1000); // 5 mins
    }, refreshTriggerMinutes * 60 * 1000); // after first 10 mins

    return () => {
      clearTimeout(clearRefreshTimeout);
      clearTimeout(clearLogoutTimeout);
      clearInterval(refreshIntervalId);
    };
  }, [useStandardLayout, navigate]);

  return (
    <>
      <div className="admin-layout">
        {/* Sidebar: only for standard layout */}
        {useStandardLayout && <Sidebar />}

        {/* Main content: class depends on whether sidebar is present */}
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
            <Route path="/" element={<LoginForm />} />
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
        /* --- Base Layout Styles (Applies to all screens) --- */
        html, body, #root {
          height: 100%;
          margin: 0;
          padding: 0;
          font-family: 'Inter', sans-serif;
        }

        .admin-layout {
          min-height: 100vh;
          display: flex;
          background-color: #f8f9fa;
        }

        .admin-content {
          flex-grow: 1;
          margin-left: 0;
          padding: 20px;
          transition: margin-left 0.3s ease-out;
          width: 100%;
        }

        /* Content when sidebar is present (dashboard etc.) */
        @media (min-width: ${DESKTOP_BREAKPOINT}px) {
          .admin-content--with-sidebar {
            margin-left: ${COLLAPSED_WIDTH};
          }

          /* When sidebar expands on hover, shift main more */
          .sidebar:hover + .admin-content--with-sidebar {
            margin-left: ${EXPANDED_WIDTH};
          }
        }

        /* Content when sidebar is NOT present (login, reset-password) */
        .admin-content--full {
          margin-left: 0;
          padding: 0; /* let those pages control their own padding */
        }

        /* --- Mobile Styles --- */
        @media (max-width: ${DESKTOP_BREAKPOINT - 1}px) {
          .admin-content {
            margin-left: 0;
            padding: 0;
          }
        }
      `}</style>
    </>
  );
}

export default App;
