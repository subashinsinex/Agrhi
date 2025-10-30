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

// --- Constants (Must match constants in sidebar.jsx) ---
const EXPANDED_WIDTH = "220px";
const COLLAPSED_WIDTH = "60px";

function App() {
  const location = useLocation();
  const isLoginPage = location.pathname === "/";
  const navigate = useNavigate();

  // Active timer for refreshing access_token
  useEffect(() => {
    // Only run timer if not on login page
    if (isLoginPage) return;

    // const accessTokenExpiryMinutes = 15;
    const refreshTriggerMinutes = 10;
    let refreshIntervalId;
    let clearRefreshTimeout;
    let clearLogoutTimeout;

    // const getTokenExpireTime = () => {
    //   // Option 1: If expiry time is stored
    //   // return parseInt(localStorage.getItem("access_token_expiry"));
    //   // Option 2: If JWT, decode exp field
    //   // For simplicity, assume token issued at login and expires after 15 mins
    //   return Date.now() + accessTokenExpiryMinutes * 60 * 1000;
    // };

    const refreshAccessToken = async () => {
      try {
        const refreshToken = localStorage.getItem("refresh_token");
        // Call your API refresh endpoint
        const response = await fetch("/api/refreshtoken", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ refreshToken }),
        });
        const data = await response.json();
        if (response.ok && data.access_token) {
          localStorage.setItem("access_token", data.access_token);
          // Optionally reset expiry time if provided
          // localStorage.setItem("access_token_expiry", Date.now() + accessTokenExpiryMinutes * 60 * 1000);
        } else {
          // If refresh fails, logout
          handleLogout();
        }
      } catch (err) {
        handleLogout();
      }
    };

    const handleLogout = () => {
      localStorage.removeItem("access_token");
      localStorage.removeItem("refresh_token");
      // Optionally clear any other session info
      navigate("/");
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
  }, [isLoginPage, navigate]);

  return (
    <>
      <div className="admin-layout">
        {/* 1. Sidebar Component (Always rendered) */}
        {!isLoginPage && <Sidebar />}

        {/* 2. Main Content Area */}
        <main className="admin-content">
          <Header />
          <Routes>
            <Route path="/" element={<LoginForm />} />
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
            {/* ... other routes ... */}
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
            padding: 20px;
            margin-left: 0; 
            transition: margin-left 0.3s ease-out;
            width: 100%; 
        }

        /* --- Desktop Responsive Shift (Content Area) --- */
        @media (min-width: ${DESKTOP_BREAKPOINT}px) {
            
            /* Permanent margin for the collapsed sidebar (60px) */
            .admin-content {
                margin-left: ${COLLAPSED_WIDTH}; 
            }

            /* Content shifts further right when sidebar is expanded (on hover) */
            .sidebar:hover + .admin-content {
                margin-left: ${EXPANDED_WIDTH};
            }
        }
        
        /* --- Mobile Styles --- */
        @media (max-width: ${DESKTOP_BREAKPOINT - 1}px) {
            .admin-content {
                margin-left: 0;
            }
        }
      `}</style>
    </>
  );
}

export default App;
