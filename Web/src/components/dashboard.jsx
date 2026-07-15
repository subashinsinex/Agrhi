import React from "react";
// Importing icons for the cards:
import {
  Users,
  LucideDatabase, // For Master (or another relevant icon like Wrench/Settings)
  Shield, // For Disease & Remedies
  IndianRupee, // For Subsidies
  Sprout, // For Farm Crop
  BarChart2, // For Reports
  MessageSquare, // For Advisory
  PersonStanding, // For Account
  Store, // For Retail Manager
} from "lucide-react";
import { useNavigate } from "react-router-dom";

// --- Module Data ---
const dashboardModules = [
  {
    title: "User Management",
    description: "View, add, edit, and delete user accounts.",
    icon: Users,
    color: "#4f46e5",
    path: "/userManage",
  },
  {
    title: "Master Data",
    description: "Manage core application settings and reference data.",
    icon: LucideDatabase,
    color: "#10b981",
    path: "/master",
  },
  {
    title: "Disease & Remedies",
    description: "Access and manage crop disease information and solutions.",
    icon: Shield,
    color: "#ef4444",
    path: "/diseases",
  },
  {
    title: "Subsidies",
    description: "Manage and track available government subsidies.",
    icon: IndianRupee,
    color: "#f59e0b",
    path: "/subsidies",
  },
  {
    title: "Farm Crop",
    description: "View and manage all available crop details.",
    icon: Sprout,
    color: "#06b6d4",
    path: "/farmcrop",
  },
  {
    title: "Account",
    description: "Manage personal profile.",
    icon: PersonStanding,
    color: "#6366f1",
    path: "/account",
  },
  {
    title: "Reports",
    description: "Generate and view system reports and analytics.",
    icon: BarChart2,
    color: "#f97316",
    path: "/reports",
  },
  {
    title: "Feedback",
    description: "Access and manage feedback and support.",
    icon: MessageSquare,
    color: "#84cc16",
    path: "/feedback",
  },
  {
    title: "Retail Manager",
    description: "Manage retailers and their products.",
    icon: Store,
    color: "#8b5cf6",
    path: "/retail-manager",
  },
  {
    title: "Marketplace Management",
    description: "Oversee marketplace activities and listings.",
    icon: Store,
    color: "#cabf23ff",
    path: "/marketplace-management",
  },
];

// NOTE: We assume the Dashboard component does NOT receive isSidebarOpen and toggleSidebar props
// as it is the primary content page. If a layout component provides them, they should be ignored
// or removed for simplicity on this page.

const Dashboard = () => {
  const navigate = useNavigate();
  // Inline styles using modern CSS for a beautiful, responsive grid design
  const dashboardStyles = `
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
    
    .dashboard-bg {
        min-height: 80vh;
        padding: 30px;
        background: transparent; /* Transparent to show Three.js background */
        font-family: 'Inter', sans-serif;
        overflow: auto;
        margin-top: calc(var(--header-height, 60px) + 20px); /* Adjust for header height */
        
    }

    .dashboard-header {
        margin-bottom: 40px;
        padding-bottom: 10px;
        border-bottom: 2px solid #e2e8f0;
    }
    .dashboard-header h1 {
        font-size: 2.5rem;
        font-weight: 800;
        color: #1a202c;
        margin: 0;
        display: flex;
        align-items: center;
    }
    .dashboard-header p {
        font-size: 1.1rem;
        color: #64748b;
        margin-top: 5px;
    }

    /* Card Grid */
    .dashboard-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
        gap: 30px;
        align-items: start;
    }

    /* Card Styling */
    .module-card {
        background:rgba(255, 255, 255, 0.50);
        backdrop-filter: blur(10px); /* Frosted glass effect */
        border: 1px solid rgba(255, 255, 255, 0.3);
        border-radius: 16px;
        padding: 25px;
        box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08); /* Stronger shadow for depth */
        border: 1px solid #e0e7ff;
        cursor: pointer;
        transition: transform 0.3s ease, box-shadow 0.3s ease;
        position: relative;
        overflow: hidden;
        display: flex;
        flex-direction: column;
        height: 100%;
        min-height: 220px;
    }
    .module-card:hover {
        transform: translateY(-5px);
        box-shadow: 0 15px 40px rgba(79, 70, 229, 0.2); /* Shadow with primary color hint */
    }

    .module-card p {
        flex: 1;
        margin: 0 0 18px 0;
        display: -webkit-box;
        -webkit-line-clamp: 3;
        -webkit-box-orient: vertical;
        overflow: hidden;
    }

    /* Card Header (Icon and Title) */
    .card-title-block {
        display: flex;
        align-items: center;
        margin-bottom: 18px;
        flex-shrink: 0;
    }
    .card-icon {
        width: 60px;
        height: 60px;
        border-radius: 12px;
        display: flex;
        justify-content: center;
        align-items: center;
        margin-right: 15px;
        color: white; /* Icon color is white */
        box-shadow: 0 4px 10px rgba(0, 0, 0, 0.2);
    }
    /* Dynamic background for icons based on module color */
    .card-icon-4f46e5 { background-color: #4f46e5; }
    .card-icon-10b981 { background-color: #10b981; }
    .card-icon-ef4444 { background-color: #ef4444; }
    .card-icon-f59e0b { background-color: #f59e0b; }
    .card-icon-06b6d4 { background-color: #06b6d4; }
    .card-icon-6366f1 { background-color: #6366f1; }
    .card-icon-f97316 { background-color: #f97316; }
    .card-icon-84cc16 { background-color: #84cc16; }
    .card-icon-8b5cf6 { background-color: #8b5cf6; }
    .card-icon-cabf23ff { background-color: #cabf23ff; }


    .card-title-block h2 {
        font-size: 1.4rem;
        font-weight: 700;
        color: #1a202c;
        margin: 0;
    }
    .card-title-block p {
        font-size: 0.95rem;
        color: #64748b;
        margin: 5px 0 0 0;
        line-height: 1.4;
    }
    
    /* Footer/Action Link */
    .card-footer {
        padding-top: 12px;
        border-top: 1px dashed #e2e8f0;
        margin-top: auto;
        display: flex;
        justify-content: flex-end;
        flex-shrink: 0;
    }
    .card-link {
        color: rgba(0, 0, 0, 1);
        font-weight: 600;
        text-decoration: none;
        font-size: 0.95rem;
        transition: color 0.2s;
    }
    .card-link:hover {
        color: rgba(5, 82, 25, 1);
        text-decoration: underline;
    }

    /* Decorative element/Overlay */
    .module-card::after {
        content: '';
        position: absolute;
        top: 0;
        right: 0;
        width: 10px;
        height: 100%;
        background: var(--card-color, #4f46e5); /* Uses the card's color */
        transition: width 0.3s ease;
        opacity: 0.1;
    }
    .module-card:hover::after {
        width: 100%;
        opacity: 0.05;
    }

    /* Media Queries */
    @media (max-width: 768px) {
        .dashboard-bg {
            padding: 15px;
        }
        .dashboard-header h1 {
            font-size: 2rem;
        }
        .dashboard-grid {
            gap: 20px;
        }
        .module-card {
            padding: 20px;
        }
    }
  `;

  // Function to navigate (using a simple console log for a React app without routing setup)
  const handleCardClick = (path) => {
    navigate(path);
    console.log(`Navigating to: ${path}`);
    // In a real application, you would use a router like:
    // navigate(path);
  };

  return (
    <div className="dashboard-bg">
      <style>{dashboardStyles}</style>

      {/* Module Cards Grid */}
      <div className="dashboard-grid">
        {dashboardModules.map((module) => {
          // Clean up the color for use in CSS class names
          const colorClass = module.color.replace("#", "card-icon-");
          const IconComponent = module.icon;

          return (
            <div
              className="module-card"
              key={module.title}
              onClick={() => handleCardClick(module.path)}
              style={{ "--card-color": module.color }} // Set CSS variable for the decorative stripe
              title={`Go to ${module.title}`}
            >
              <div className="card-title-block">
                {/* Icon with dynamic color class */}
                <div className={`card-icon ${colorClass}`}>
                  <IconComponent size={30} />
                </div>
                <div>
                  <h2>{module.title}</h2>
                </div>
              </div>
              <p>{module.description}</p>
              <div className="card-footer">
                <span className="card-link">Explore Module &rarr;</span>
              </div>
            </div>
          );
        })}
      </div>

      <div
        style={{
          marginTop: "50px",
          textAlign: "center",
          color: "#94a3b8",
          fontSize: "0.9rem",
        }}
      ></div>
    </div>
  );
};

export default Dashboard;
