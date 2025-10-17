import { Routes, Route, useLocation } from "react-router-dom";
import Sidebar from "./components/sidebar";
import LoginForm from "./components/LoginForm";
import Dashboard from "./components/dashboard";
import UserManage from "./components/userManage";
import Subsidies from "./components/subsidies";
import FarmCrop from "./components/farmCrop";
import { Header } from "./components/header";
import { DESKTOP_BREAKPOINT } from "./constant";
import ProtectedRoute from "./components/protectedRoute";

// --- Constants (Must match constants in sidebar.jsx) ---
const EXPANDED_WIDTH = "220px";
const COLLAPSED_WIDTH = "60px";

function App() {
  const location = useLocation();
  const isLoginPage = location.pathname === "/";

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
