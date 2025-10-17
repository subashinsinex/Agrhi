import React from "react";
import { NavLink, useNavigate } from "react-router-dom";
import {
  LogOut,
  Home,
  Users,
  Wheat,
  Pill,
  DollarSign,
  User,
  BarChart2,
  Lightbulb,
} from "lucide-react";

// --- Constants (Required for self-contained component styling) ---
const PRIMARY_COLOR = "#3742fa";
const EXPANDED_WIDTH = "220px"; // Full sidebar width
const COLLAPSED_WIDTH = "60px"; // Icon-only bar width
const DESKTOP_BREAKPOINT = 1024;

// Define module routes and icons
const modules = [
  { to: "/dashboard", label: "Dashboard", icon: <Home size={20} /> },
  { to: "/userManage", label: "User Management", icon: <Users size={20} /> },
  { to: "/crops", label: "Crops", icon: <Wheat size={20} /> },
  { to: "/diseases", label: "Disease & Remedies", icon: <Pill size={20} /> },
  { to: "/subsidies", label: "Subsidies", icon: <DollarSign size={20} /> },
  { to: "/farmcrop", label: "Farm Crop", icon: <Wheat size={20} /> },
  { to: "/account", label: "Account", icon: <User size={20} /> },
  { to: "/reports", label: "Reports", icon: <BarChart2 size={20} /> },
  { to: "/advisory", label: "Advisory", icon: <Lightbulb size={20} /> },
];

// --- Sidebar Component ---
export default function Sidebar() {
  const navigate = useNavigate();
  const logout = () => {
    localStorage.removeItem("token");
    navigate("/");
  };

  return (
    <aside className="sidebar">
      <style>{`
                /* Font and Box Sizing Reset for Consistency */
                * {
                    box-sizing: border-box;
                    font-family: 'Inter', sans-serif;
                }
                
                /* --- Sidebar Base Styles --- */
                .sidebar{
                    width: ${COLLAPSED_WIDTH}; /* START AT COLLAPSED WIDTH */
                    height: 100vh;
                    background: #fff;
                    border-right: 1px solid #e2e8f0;
                    display: flex;
                    flex-direction: column; 
                    position: fixed;
                    top: 0;
                    left: 0;
                    z-index: 50;
                    transition: width 0.3s ease-out;
                    overflow-x: hidden; /* Crucial for hiding text */
                }

                /* Mobile/Small Screen */
                @media (max-width: ${DESKTOP_BREAKPOINT - 1}px) {
                    .sidebar {
                        width: 0;
                        border-right: none;
                        box-shadow: none;
                    }
                }

                /* Desktop Hover: Expand the sidebar */
                @media (min-width: ${DESKTOP_BREAKPOINT}px) {
                    .sidebar:hover {
                        width: ${EXPANDED_WIDTH};
                    }
                }

                /* Logo Section */
                .sb-logo{
                    font-weight:700;
                    font-size:1.3rem;
                    color:${PRIMARY_COLOR};
                    margin:28px 0 18px 0;
                    letter-spacing:.7px; 
                    white-space: nowrap;
                    flex-shrink: 0; 
                    
                    /* Initial Collapsed State */
                    opacity: 0;
                    padding: 0 18px; 
                    transition: opacity 0.3s, padding 0.3s;
                }
                
                @media (min-width: ${DESKTOP_BREAKPOINT}px) {
                    .sidebar:hover .sb-logo { 
                        opacity: 1;
                        padding: 0 34px; 
                    }
                }
                
                /* Menu Section */
                .sb-menu{
                    width:${EXPANDED_WIDTH}; /* Use expanded width so items lay out correctly inside the overflow:hidden parent */
                    list-style:none;
                    padding:0; 
                    flex-grow: 1; 
                    overflow-y: auto; 
                    overflow-x: hidden;
                }

                .sb-menu li{
                    padding:12px 38px 12px 18px; 
                    cursor:pointer;
                    transition:.18s;
                    display: flex;
                    align-items: center;
                    color: #4b5563;
                    white-space: nowrap; 
                }
                
                /* KEY FIX: Hide the text part in the collapsed state */
                .sb-menu li span{
                    margin-right:13px; 
                    font-size: 1.14rem;
                }
                .sb-menu li {
                    /* Initial collapsed state: Text is hidden */
                    color: transparent; 
                    transition: color 0.1s, background 0.18s; 
                }
                .sb-menu li span {
                    /* Icons MUST be visible */
                    color: #4b5563;
                    transition: color 0.1s;
                }

                /* Hover/Expanded State: Show text */
                @media (min-width: ${DESKTOP_BREAKPOINT}px) {
                    .sidebar:hover .sb-menu li {
                        color: #4b5563; /* Show text on sidebar hover */
                    }
                    .sidebar:hover .sb-menu li span {
                        color: #4b5563; /* Ensure icon color matches text color transition */
                    }

                    /* Active/Hover State */
                    .sb-menu li:hover{
                        background:#f0f3fa; 
                    }
                    .sidebar:hover .sb-menu li:hover, .sb-menu a.active li {
                        color:${PRIMARY_COLOR}; /* Use primary color for text on hover/active in expanded state */
                    }
                    .sidebar:hover .sb-menu li:hover span, .sb-menu a.active li span {
                        color:${PRIMARY_COLOR}; /* Use primary color for icon on hover/active in expanded state */
                    }

                    /* Active State (Collapsed or Expanded) */
                    .sb-menu a.active li{
                        background:#e8f0ff;
                        font-weight:600;
                        border-left: 4px solid ${PRIMARY_COLOR}; 
                        padding-left: 14px;
                        /* Ensure active icon is colored in collapsed state */
                        color: transparent; /* Text remains hidden in collapsed state */
                    }
                    .sb-menu a.active li span {
                        color: ${PRIMARY_COLOR}; /* ACTIVE ICON COLOR */
                    }

                    /* Active state when expanded (on hover) */
                    .sidebar:hover .sb-menu a.active li {
                        color:${PRIMARY_COLOR}; /* ACTIVE TEXT COLOR */
                    }
                }

                
                /* Logout Section */
                .sb-bottom{
                    margin-top:auto;
                    flex-shrink: 0; 
                }
                .sb-logout{
                    font-size:.96rem;
                    color:transparent; /* Start with text hidden */
                    cursor:pointer;
                    display: flex;
                    align-items: center;
                    white-space: nowrap;
                    transition: color 0.3s, margin 0.3s;
                    margin:12px 0 18px 18px; 
                }
                .sb-logout:hover {
                    color: #ef4444;
                }
                .sb-logout svg {
                    margin-right: 8px;
                    width: 18px;
                    height: 18px;
                    color:#9ea5c6; /* Icon color in collapsed state */
                    transition: color 0.3s;
                }
                
                @media (min-width: ${DESKTOP_BREAKPOINT}px) {
                    .sidebar:hover .sb-logout {
                        color: #9ea5c6; /* Show text on hover */
                        margin-left: 34px; 
                    }
                    .sidebar:hover .sb-logout:hover {
                        color: #ef4444; /* Hover color for text */
                    }
                    .sidebar:hover .sb-logout svg {
                        color: #9ea5c6; /* Ensure icon is visible on hover */
                    }
                }
            `}</style>

      {/* <div className="sb-logo">AGRHI Admin Portal</div> */}
      <ul className="sb-menu">
        {modules.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) => (isActive ? "active" : "")}
            style={{ textDecoration: "none" }}
          >
            <li>
              <span>{item.icon}</span>
              {item.label}
            </li>
          </NavLink>
        ))}
      </ul>
      <div className="sb-bottom">
        <div className="sb-logout" onClick={logout}>
          <LogOut /> Logout
        </div>
      </div>
    </aside>
  );
}
