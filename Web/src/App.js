import { lazy, Suspense, useEffect } from "react";
import { Routes, Route, useLocation, useNavigate } from "react-router-dom";
import { Header } from "./components/header";
import { DESKTOP_BREAKPOINT } from "./constant";
import ProtectedRoute from "./components/protectedRoute";

const Sidebar = lazy(() => import("./components/sidebar"));
const LoginForm = lazy(() => import("./components/LoginForm"));
const Dashboard = lazy(() => import("./components/dashboard"));
const UserManage = lazy(() => import("./components/userManage"));
const Subsidies = lazy(() => import("./components/subsidies"));
const FarmCrop = lazy(() => import("./components/farmCrop"));
const Master = lazy(() => import("./components/master"));
const Disease = lazy(() => import("./components/disease"));
const Report = lazy(() => import("./components/report"));
const Feedback = lazy(() => import("./components/feedback"));
const RetailManager = lazy(() => import("./components/retailManager"));
const MarketPlaceManagement = lazy(() => import("./components/marketPlaceManagement"));
const Account = lazy(() => import("./components/account"));
const ResetPassword = lazy(() => import("./components/resetPassword"));
const DeleteAccount = lazy(() => import("./components/deleteAccount"));
const Privacy = lazy(() => import("./components/privacy"));
const Home = lazy(() => import("./components/home"));
const AgrhiBackground = lazy(() => import("./parts/background"));
const NotFound = lazy(() => import("./components/public/NotFound"));

const COLLAPSED_WIDTH = "80px";

function App() {
  const location = useLocation();
  const navigate = useNavigate();

  const isResetPasswordPage = location.pathname.startsWith("/reset-password");
  const adminPaths = ["/dashboard", "/userManage", "/farmcrop", "/subsidies", "/master", "/diseases", "/reports", "/feedback", "/retail-manager", "/marketplace-management", "/account"];
  const useStandardLayout = adminPaths.includes(location.pathname);
  const showBackground = useStandardLayout || location.pathname === "/login" || isResetPasswordPage;

  useEffect(() => {
    if (!useStandardLayout) return;

    const refreshTriggerMinutes = 10;
    let refreshIntervalId;
    let clearRefreshTimeout;
    let clearLogoutTimeout;

    const handleLogout = () => {
      localStorage.removeItem("access_token");
      localStorage.removeItem("refresh_token");
      navigate("/login");
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
      {showBackground && <Suspense fallback={null}><AgrhiBackground /></Suspense>}

      <div className="admin-layout">
        {useStandardLayout && <Suspense fallback={null}><Sidebar /></Suspense>}

        <main
          className={
            useStandardLayout
              ? "admin-content admin-content--with-sidebar"
              : "admin-content admin-content--full"
          }
        >
          {useStandardLayout && <Header />}

          <Suspense fallback={<div className="route-loading" role="status"><span />Loading AGRHI…</div>}>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/login" element={<LoginForm />} />
            <Route path="/reset-password" element={<ResetPassword />} />

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
            <Route path="/delete-account" element={<DeleteAccount />} />
            <Route path="/privacy" element={<Privacy />} />
            <Route path="*" element={<NotFound />} />
          </Routes>
          </Suspense>
        </main>
      </div>

      <style>{`
        html,
        body,
        #root {
          min-height: 100%;
          margin: 0;
          padding: 0;
          font-family: "Inter", sans-serif;
          overflow-x: hidden;
        }

        .admin-layout {
          min-height: 100vh;
          display: flex;
          background: transparent;
        }

        .route-loading {
          min-height: 55vh;
          display: grid;
          place-content: center;
          gap: 12px;
          color: #07551f;
          font-size: 13px;
          font-weight: 700;
          text-align: center;
        }

        .route-loading span {
          width: 34px;
          height: 34px;
          margin: auto;
          border: 3px solid #dce6da;
          border-top-color: #2f7d1f;
          border-radius: 50%;
          animation: route-spin 0.8s linear infinite;
        }

        @keyframes route-spin { to { transform: rotate(360deg); } }

        .admin-content {
          flex: 1;
          box-sizing: border-box;
          min-width: 0;
          background: transparent;
        }

        .admin-content--with-sidebar {
          width: calc(100% - ${COLLAPSED_WIDTH});
          padding: 10px 10px 20px;
          margin-left: ${COLLAPSED_WIDTH};
        }

        .admin-content--full {
          width: 100%;
          margin-left: 0;
          padding: 0;
        }

        @media (max-width: ${DESKTOP_BREAKPOINT - 1}px) {
          .admin-content--with-sidebar {
            width: 100%;
            margin-left: 0;
            padding: 20px;
          }

          .admin-content--full {
            padding: 0;
          }
        }
      `}</style>
    </>
  );
}

export default App;
