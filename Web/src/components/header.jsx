import React from "react";
import { useLocation } from "react-router-dom";
import { DESKTOP_BREAKPOINT } from "../constant";

const Header = () => {
  const location = useLocation();

  const routeTitles = {
    "/dashboard": "Dashboard",
    "/subsidies": "Subsidies Programs",
    "/farmcrop": "Farm Crop Management",
    "/userManage": "User Management",
    "/crops": "Crops",
    "/diseases": "Disease & Remedies",
    "/account": "Account",
    "/reports": "Reports",
    "/advisory": "Advisory",
    "/": "Login",
  };

  const currentTitle = routeTitles[location.pathname] || "Admin Portal";

  // Hide header on login page
  if (location.pathname === "/") {
    return null;
  }

  return (
    <header className="admin-header">
      <style>{`
        .admin-header {
          background-color: #ffffff;
          height: 60px;
          width:100%;
          padding: 0 20px;
          display: flex;
          align-items: center;
          justify-content: space-between;
          border-bottom: 1px solid #e2e8f0;
          position: sticky;
          top: 0;
          z-index: 40;
        }

        .admin-header-title {
          font-size: 1.2rem;
          font-weight: 600;
          color: #1e293b;
          margin-left: auto;
        }

        .admin-header-logo {
          font-weight: 700;
          font-size: 1.1rem;
          color: #3742fa;
        }

        @media (max-width: ${DESKTOP_BREAKPOINT - 1}px) {
          .admin-header {
            /* Simple mobile layout (keep header visible) */
          }
        }
      `}</style>

      <div className="admin-header-logo">AGRHI ADMIN PORTAL</div>
      <div className="admin-header-title">{currentTitle}</div>
      <div style={{ minWidth: "24px" }}></div>
    </header>
  );
};

export { Header };
