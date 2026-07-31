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
    "/master": "Master Data",
    "/diseases": "Disease & Remedies",
    "/account": "Account",
    "/reports": "Reports",
    "/advisory": "Advisory",
    "/retail-manager": "Retail Manager",
    "/marketplace-management": "Marketplace Management",
    "/feedback": "Feedback",
    "/": "Login",
  };

  const currentTitle = routeTitles[location.pathname] || "Admin Portal";

  if (location.pathname === "/") {
    return null;
  }

  return (
    <div className="admin-header-wrap">
      <header className="admin-header">
        <style>{`
          .admin-header-wrap {
            position: sticky;
            top: 12px;
            z-index: 40;
            padding: 0 16px;
            background: transparent;
          }

          .admin-header {
            background: #ffffff;
            min-height: 64px;
            width: 100%;
            padding: 0 20px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border: 1px solid #e2e8f0;
            border-radius: 18px;
            box-shadow: 0 8px 24px rgba(15, 23, 42, 0.08);
          }

          .admin-header-title {
            font-size: 1.1rem;
            font-weight: 600;
            color: #1e293b;
            margin-left: auto;
          }

          .admin-header-logo {
            font-weight: 700;
            font-size: 1.05rem;
            color: rgba(5, 82, 25, 1);
            white-space: nowrap;
          }

          .admin-header-spacer {
            min-width: 24px;
          }

          @media (max-width: ${DESKTOP_BREAKPOINT - 1}px) {
            .admin-header-wrap {
              top: 10px;
              padding: 0 12px;
            }

            .admin-header {
              min-height: 58px;
              padding: 0 16px;
              border-radius: 16px;
            }

            .admin-header-logo {
              font-size: 0.95rem;
            }

            .admin-header-title {
              font-size: 1rem;
            }
          }

          @media (max-width: 640px) {
            .admin-header {
              gap: 12px;
              padding: 12px 14px;
              align-items: center;
            }

            .admin-header-logo {
              font-size: 0.88rem;
              max-width: 46%;
              overflow: hidden;
              text-overflow: ellipsis;
            }

            .admin-header-title {
              font-size: 0.95rem;
              margin-left: 0;
              text-align: right;
              flex: 1;
            }

            .admin-header-spacer {
              display: none;
            }
          }
        `}</style>

        <div className="admin-header-logo">AGRHI ADMIN PORTAL</div>
        <div className="admin-header-title">{currentTitle}</div>
        <div className="admin-header-spacer"></div>
      </header>
    </div>
  );
};

export { Header };
