import React, {
  useState,
  useEffect,
  useMemo,
  useCallback,
  useRef,
} from "react";
import { axiosInstance } from "../api/login";
import {
  Search,
  X,
  Copy,
  ClipboardCheck,
  Download,
  Printer,
  ChevronLeft,
  ChevronRight,
  Leaf,
  AlertCircle,
  RefreshCw,
  CheckCircle2,
  Calendar,
  User,
  ShieldCheck,
  Activity,
  ArrowUpRight,
  MapPin,
  Clock,
} from "lucide-react";
import { SERVER_IP, SERVER_PORT } from "../constant";

// --- Constants & Helper Configs ---
const apiBase = `http://${SERVER_IP}:${SERVER_PORT}/api/diseaseRemedies`;

/**
 * AGRHI THEME CONFIGURATION
 * Precise color palette based on corporate branding
 */
const THEME = {
  primary: "#1B3C35", // Deep Forest Green
  primaryLight: "#2D5A50",
  secondary: "#8BA888", // Sage Green
  accent: "#D9C5B2", // Sand Accent
  background: "transparent", // Off-white/Cream
  surface: "#FFFFFF",
  error: "#E74C3C",
  success: "#4A7C44",
  warning: "#F39C12",
  textMain: "#1A202C",
  textMuted: "#718096",
  border: "rgba(27, 60, 53, 0.1)",
};

/**
 * Report Component: Comprehensive Disease Analytics & Management Portal
 * Optimized for high-density data and precise UI alignment.
 */
const Report = () => {
  // --- State Management ---
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState("");
  const [selectedReport, setSelectedReport] = useState(null);
  const [filterType, setFilterType] = useState("all");
  const [sortBy, setSortBy] = useState("newest");
  const [msg, setMsg] = useState({ text: "", type: "" });
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage] = useState(8);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const access_token = localStorage.getItem("access_token");
  const modalRef = useRef();

  // --- API Communications ---
  const showToast = useCallback((text, type = "success") => {
    setMsg({ text, type });
    setTimeout(() => setMsg({ text: "", type: "" }), 4000);
  }, []);

  const fetchReports = useCallback(async () => {
    setIsRefreshing(true);
    setLoading(true);
    try {
      const res = await axiosInstance.get(
        `${apiBase}/disease-analysis-results`,
        {
          headers: { Authorization: `Bearer ${access_token}` },
        }
      );
      // Ensure data is an array
      setReports(Array.isArray(res.data) ? res.data : []);
    } catch (err) {
      showToast("Sync Error: Unable to reach the diagnosis server.", "error");
      console.error("API Error:", err);
    } finally {
      setLoading(false);
      setIsRefreshing(false);
    }
  }, [access_token, showToast]);

  useEffect(() => {
    fetchReports();
  }, [fetchReports]);

  // --- Logic & Filtering ---
  const filteredReports = useMemo(() => {
    let result = [...reports];

    // Search Filtering
    if (q) {
      const lowerQ = q.toLowerCase();
      result = result.filter(
        (r) =>
          (r.user_name ?? "").toLowerCase().includes(lowerQ) ||
          (r.plant_name ?? "").toLowerCase().includes(lowerQ) ||
          (r.disease_name ?? "").toLowerCase().includes(lowerQ) ||
          (r.id ?? "").toLowerCase().includes(lowerQ)
      );
    }

    // Plant Category Filtering
    if (filterType !== "all") {
      result = result.filter(
        (r) => r.plant_name?.toLowerCase() === filterType.toLowerCase()
      );
    }

    // Sorting Logic
    result.sort((a, b) => {
      if (sortBy === "newest")
        return new Date(b.created_at || 0) - new Date(a.created_at || 0);
      if (sortBy === "oldest")
        return new Date(a.created_at || 0) - new Date(b.created_at || 0);
      if (sortBy === "confidence")
        return parseFloat(b.confidence) - parseFloat(a.confidence);
      return 0;
    });

    return result;
  }, [reports, q, filterType, sortBy]);

  const uniquePlants = useMemo(() => {
    const plants = reports.map((r) => r.plant_name).filter(Boolean);
    return ["all", ...new Set(plants)];
  }, [reports]);

  // --- Pagination Logic ---
  const indexOfLastItem = currentPage * itemsPerPage;
  const indexOfFirstItem = indexOfLastItem - itemsPerPage;
  const currentItems = filteredReports.slice(indexOfFirstItem, indexOfLastItem);
  const totalPages = Math.ceil(filteredReports.length / itemsPerPage);

  // --- Interaction Handlers ---
  const handleCopyLink = (url) => {
    const fullUrl = `http://${SERVER_IP}:${SERVER_PORT}${url}`;
    navigator.clipboard.writeText(fullUrl).then(() => {
      showToast("🔗 Analysis link copied to clipboard!");
    });
  };

  const downloadReport = (report) => {
    const element = document.createElement("a");
    const content = {
      report_id: report.id,
      timestamp: new Date().toISOString(),
      diagnosis: {
        plant: report.plant_name,
        disease: report.disease_name,
        confidence: `${(parseFloat(report.confidence) * 100).toFixed(2)}%`,
      },
      remedy: report.remedy,
      user: report.user_name || "Anonymous",
    };
    const file = new Blob([JSON.stringify(content, null, 2)], {
      type: "application/json",
    });
    element.href = URL.createObjectURL(file);
    element.download = `AGRHI_Report_${report.id.substring(0, 8)}.json`;
    document.body.appendChild(element);
    element.click();
    document.body.removeChild(element);
  };

  const printDiagnosis = () => {
    window.print();
  };

  const getConfidenceColor = (val) => {
    const num = parseFloat(val) * 100;
    if (num >= 90) return THEME.success;
    if (num >= 75) return THEME.warning;
    return THEME.error;
  };

  // --- Enhanced CSS-in-JS ---
  const styles = `
    @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap');

    :root {
      --primary: ${THEME.primary};
      --secondary: ${THEME.secondary};
      --bg: ${THEME.background};
    }

    .ag-main-wrapper {
      min-height: 100vh;
      background: ${THEME.background};
      padding: 40px;
      font-family: 'Outfit', sans-serif;
      color: ${THEME.textMain};
    }

    /* Top Navigation Alignment */
    .ag-top-nav {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 40px;
      padding: 20px;
      background: white;
      border-radius: 24px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.03);
    }

    .ag-header-left h1 {
      font-size: 1.8rem;
      font-weight: 800;
      margin: 0;
      color: ${THEME.primary};
      letter-spacing: -0.5px;
    }

    .ag-controls {
      display: flex;
      gap: 12px;
      align-items: center;
    }

    .search-bar {
      position: relative;
      width: 320px;
    }

    .search-bar input {
      width: 100%;
      padding: 12px 16px 12px 48px;
      border-radius: 14px;
      border: 1.5px solid ${THEME.border};
      background: ${THEME.background};
      font-size: 0.95rem;
      outline: none;
      transition: all 0.2s ease;
    }

    .search-bar input:focus {
      border-color: ${THEME.primary};
      background: white;
      box-shadow: 0 0 0 4px rgba(27, 60, 53, 0.05);
    }

    .ag-select {
      padding: 12px 16px;
      border-radius: 14px;
      border: 1.5px solid ${THEME.border};
      background: white;
      font-weight: 600;
      font-size: 0.9rem;
      color: ${THEME.primary};
      cursor: pointer;
      outline: none;
    }

    /* Stats Grid Alignment */
    .ag-stats-row {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 20px;
      margin-bottom: 40px;
    }

    .stat-card {
      background: white;
      padding: 24px;
      border-radius: 24px;
      display: flex;
      align-items: center;
      gap: 18px;
      transition: transform 0.2s ease;
      border: 1px solid rgba(0,0,0,0.02);
    }

    .stat-card:hover { transform: translateY(-3px); }

    .stat-icon {
      width: 56px;
      height: 56px;
      border-radius: 16px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: ${THEME.background};
      color: ${THEME.primary};
    }

    /* Corrected Report Grid Alignment */
    .report-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 30px;
    }

    .report-card {
      background: white;
      border-radius: 28px;
      overflow: hidden;
      box-shadow: 0 10px 25px rgba(27, 60, 53, 0.04);
      border: 1px solid rgba(0,0,0,0.03);
      display: flex;
      flex-direction: column;
      height: 100%; /* Ensures all cards in row are same height */
      transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    }

    .report-card:hover {
      transform: translateY(-10px);
      box-shadow: 0 20px 40px rgba(27, 60, 53, 0.08);
      border-color: ${THEME.secondary};
    }

    .image-fixed-container {
      width: 100%;
      height: 200px;
      overflow: hidden;
      position: relative;
      background: #eee;
    }

    .image-fixed-container img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }

    .confidence-badge {
      position: absolute;
      top: 15px;
      right: 15px;
      padding: 6px 12px;
      border-radius: 10px;
      background: rgba(255,255,255,0.95);
      backdrop-filter: blur(8px);
      font-size: 0.75rem;
      font-weight: 800;
      box-shadow: 0 4px 10px rgba(0,0,0,0.1);
    }

    .card-content {
      padding: 24px;
      flex-grow: 1; /* Pushes button to bottom */
      display: flex;
      flex-direction: column;
    }

    .card-id-tag {
      font-family: 'JetBrains Mono', monospace;
      font-size: 0.65rem;
      color: ${THEME.textMuted};
      margin-bottom: 8px;
      text-transform: uppercase;
    }

    .card-title {
      font-size: 1.25rem;
      font-weight: 800;
      color: ${THEME.primary};
      margin-bottom: 12px;
      line-height: 1.2;
    }

    .remedy-preview {
      font-size: 0.9rem;
      color: ${THEME.textMuted};
      line-height: 1.6;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
      margin-bottom: 20px;
      min-height: 2.8em;
    }

    .btn-view-detail {
      width: 100%;
      padding: 14px;
      border-radius: 16px;
      background: ${THEME.primary};
      color: white;
      font-weight: 700;
      border: none;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      margin-top: auto; /* Alignment Anchor */
      transition: background 0.2s ease;
    }

    .btn-view-detail:hover { background: ${THEME.primaryLight}; }

    /* Horizontal Modal Styling - Fixed Close Button */
    .modal-overlay {
      position: fixed;
      inset: 0;
      background: rgba(10, 25, 22, 0.85);
      backdrop-filter: blur(12px);
      z-index: 5000;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
      animation: fadeIn 0.3s ease;
    }

    .modal-container {
      background: white;
      width: 100%;
      max-width: 1100px;
      height: 650px;
      border-radius: 32px;
      display: flex;
      overflow: hidden;
      position: relative;
      box-shadow: 0 40px 100px rgba(0,0,0,0.4);
    }

    .modal-side-image {
      width: 45%;
      height: 100%;
      background: #000;
      position: relative;
    }

    .modal-side-image img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }

    .modal-side-content {
      width: 55%;
      padding: 48px;
      display: flex;
      flex-direction: column;
      overflow-y: auto;
    }

    .close-trigger {
      position: absolute;
      top: 24px;
      right: 24px;
      width: 44px;
      height: 44px;
      border-radius: 50%;
      background: ${THEME.background};
      border: none;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all 0.2s ease;
      z-index: 10;
    }

    .close-trigger:hover {
      background: ${THEME.error};
      color: white;
      transform: rotate(90deg);
    }

    .remedy-scroll-box {
      margin-top: 24px;
      padding: 24px;
      background: ${THEME.background};
      border-radius: 20px;
      border: 1px dashed ${THEME.secondary};
      flex-grow: 1;
    }

    /* Animation Keyframes */
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }

    .spin { animation: spin 1s linear infinite; }
    @keyframes spin {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }

    /* Pagination */
    .pagination-bar {
      display: flex;
      justify-content: center;
      gap: 12px;
      margin-top: 50px;
    }

    .page-node {
      width: 44px;
      height: 44px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: white;
      border: 1px solid ${THEME.border};
      cursor: pointer;
      font-weight: 700;
      transition: all 0.2s ease;
    }

    .page-node.active {
      background: ${THEME.primary};
      color: white;
      border-color: ${THEME.primary};
    }

    @media (max-width: 1000px) {
      .modal-container { flex-direction: column; height: 90vh; }
      .modal-side-image, .modal-side-content { width: 100%; }
      .modal-side-image { height: 300px; }
      .ag-stats-row { grid-template-columns: repeat(2, 1fr); }
    }
  `;

  return (
    <div className="ag-main-wrapper">
      <style>{styles}</style>

      {/* --- Top Dashboard Header --- */}
      <header className="ag-top-nav">
        <div className="ag-header-left">
          <p
            style={{
              fontSize: "0.75rem",
              fontWeight: 800,
              color: THEME.secondary,
              textTransform: "uppercase",
              marginBottom: 4,
            }}
          >
            System Intelligence
          </p>
          <h1>Detection Reports</h1>
        </div>

        <div className="ag-controls">
          <div className="search-bar">
            <Search
              style={{
                position: "absolute",
                left: 16,
                top: "50%",
                transform: "translateY(-50%)",
                color: THEME.secondary,
              }}
              size={18}
            />
            <input
              placeholder="Search by ID, User or Crop..."
              value={q}
              onChange={(e) => {
                setQ(e.target.value);
                setCurrentPage(1);
              }}
            />
          </div>

          <select
            className="ag-select"
            onChange={(e) => setFilterType(e.target.value)}
          >
            {uniquePlants.map((p) => (
              <option key={`opt-${p}`} value={p}>
                {p.toUpperCase()}
              </option>
            ))}
          </select>

          <select
            className="ag-select"
            onChange={(e) => setSortBy(e.target.value)}
          >
            <option value="newest">Newest First</option>
            <option value="oldest">Oldest First</option>
            <option value="confidence">Highest Confidence</option>
          </select>

          <button
            className="page-node"
            onClick={fetchReports}
            disabled={isRefreshing}
            title="Refresh Data"
          >
            <RefreshCw size={18} className={isRefreshing ? "spin" : ""} />
          </button>
        </div>
      </header>

      {/* --- Executive Summary Stats --- */}
      <div className="ag-stats-row">
        {[
          {
            label: "Total Diagnoses",
            val: reports.length,
            icon: <Activity />,
            color: THEME.primary,
          },
          {
            label: "High Accuracy",
            val: reports.filter((r) => parseFloat(r.confidence) > 0.85).length,
            icon: <ShieldCheck />,
            color: THEME.success,
          },
          {
            label: "Critical risk",
            val: reports.filter((r) =>
              r.disease_name?.toLowerCase().includes("rust")
            ).length,
            icon: <AlertCircle />,
            color: THEME.error,
          },
          {
            label: "Active Users",
            val: new Set(reports.map((r) => r.user_name)).size,
            icon: <User />,
            color: THEME.warning,
          },
        ].map((stat, i) => (
          <div className="stat-card" key={`stat-${i}`}>
            <div className="stat-icon" style={{ color: stat.color }}>
              {stat.icon}
            </div>
            <div>
              <div
                style={{
                  fontSize: "0.85rem",
                  fontWeight: 600,
                  color: THEME.textMuted,
                }}
              >
                {stat.label}
              </div>
              <div style={{ fontSize: "1.5rem", fontWeight: 800 }}>
                {stat.val}
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* --- Main Content Area --- */}
      {loading ? (
        <div style={{ textAlign: "center", padding: "120px 0" }}>
          <RefreshCw
            className="spin"
            size={48}
            style={{ color: THEME.secondary, marginBottom: 20 }}
          />
          <h2 style={{ fontWeight: 700, color: THEME.primary }}>
            Synchronizing AGRHI Cloud Database...
          </h2>
        </div>
      ) : (
        <>
          <div className="report-grid">
            {currentItems.map((report, index) => (
              /* FIXED: Key is now unique even if IDs repeat */
              <div className="report-card" key={`${report.id}-${index}`}>
                <div className="image-fixed-container">
                  <img
                    src={`http://${SERVER_IP}:${SERVER_PORT}${report.image_url}`}
                    alt="Plant View"
                    onError={(e) => {
                      e.target.src =
                        "https://via.placeholder.com/400x300?text=No+Image+Available";
                    }}
                  />
                  <div
                    className="confidence-badge"
                    style={{ color: getConfidenceColor(report.confidence) }}
                  >
                    {(parseFloat(report.confidence) * 100).toFixed(0)}% MATCH
                  </div>
                </div>

                <div className="card-content">
                  <div className="card-id-tag">
                    REF: {report.id?.substring(0, 13)}...
                  </div>
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: 6,
                      marginBottom: 4,
                    }}
                  >
                    <Leaf size={14} className="text-secondary" />
                    <span
                      style={{
                        fontSize: "0.75rem",
                        fontWeight: 800,
                        color: THEME.secondary,
                        textTransform: "uppercase",
                      }}
                    >
                      {report.plant_name}
                    </span>
                  </div>
                  <h3 className="card-title">{report.disease_name}</h3>
                  <p className="remedy-preview">
                    {report.remedy ||
                      "No specific biological remedy recorded for this detection instance."}
                  </p>

                  <div
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                      marginBottom: 20,
                    }}
                  >
                    <div
                      style={{ display: "flex", alignItems: "center", gap: 6 }}
                    >
                      <div
                        style={{
                          width: 24,
                          height: 24,
                          borderRadius: "50%",
                          background: "#eee",
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                        }}
                      >
                        <User size={12} />
                      </div>
                      <span style={{ fontSize: "0.8rem", fontWeight: 600 }}>
                        {report.user_name || "Guest User"}
                      </span>
                    </div>
                    <div
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: 4,
                        color: THEME.textMuted,
                      }}
                    >
                      <Clock size={12} />
                      <span style={{ fontSize: "0.75rem" }}>
                        {new Date(
                          report.created_at || Date.now()
                        ).toLocaleDateString()}
                      </span>
                    </div>
                  </div>

                  <button
                    className="btn-view-detail"
                    onClick={() => setSelectedReport(report)}
                  >
                    View Analysis Detail <ArrowUpRight size={18} />
                  </button>
                </div>
              </div>
            ))}
          </div>

          {/* Pagination Footer */}
          {totalPages > 1 && (
            <div className="pagination-bar">
              <button
                className="page-node"
                disabled={currentPage === 1}
                onClick={() => setCurrentPage((c) => c - 1)}
              >
                <ChevronLeft size={20} />
              </button>

              {[...Array(totalPages)].map((_, i) => (
                <button
                  key={`page-${i}`}
                  className={`page-node ${
                    currentPage === i + 1 ? "active" : ""
                  }`}
                  onClick={() => setCurrentPage(i + 1)}
                >
                  {i + 1}
                </button>
              ))}

              <button
                className="page-node"
                disabled={currentPage === totalPages}
                onClick={() => setCurrentPage((c) => c + 1)}
              >
                <ChevronRight size={20} />
              </button>
            </div>
          )}
        </>
      )}

      {/* --- FIXED: Comprehensive Diagnostic Modal --- */}
      {selectedReport && (
        <div className="modal-overlay" onClick={() => setSelectedReport(null)}>
          <div
            className="modal-container"
            onClick={(e) => e.stopPropagation()} // Prevents closing when clicking inside
            ref={modalRef}
          >
            {/* FIXED: Modal Close Button */}
            <button
              className="close-trigger"
              onClick={(e) => {
                e.stopPropagation();
                setSelectedReport(null);
              }}
            >
              <X size={22} />
            </button>

            <div className="modal-side-image">
              <img
                src={`http://${SERVER_IP}:${SERVER_PORT}${selectedReport.image_url}`}
                alt="Large Analysis"
              />
              <div
                style={{
                  position: "absolute",
                  bottom: 30,
                  left: 30,
                  right: 30,
                }}
              >
                <div
                  style={{
                    background: "rgba(0,0,0,0.6)",
                    backdropFilter: "blur(10px)",
                    padding: 20,
                    borderRadius: 20,
                    color: "white",
                  }}
                >
                  <div
                    style={{
                      fontSize: "0.7rem",
                      textTransform: "uppercase",
                      opacity: 0.8,
                      marginBottom: 5,
                    }}
                  >
                    AI Precision Mapping
                  </div>
                  <div
                    style={{ display: "flex", alignItems: "center", gap: 10 }}
                  >
                    <div style={{ fontSize: "2rem", fontWeight: 800 }}>
                      {(parseFloat(selectedReport.confidence) * 100).toFixed(2)}
                      %
                    </div>
                    <div style={{ fontSize: "0.85rem", lineHeight: 1.2 }}>
                      Probability score for <br />
                      <strong>{selectedReport.disease_name}</strong>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="modal-side-content">
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 12,
                  marginBottom: 10,
                }}
              >
                <span
                  style={{
                    padding: "6px 12px",
                    background: THEME.background,
                    borderRadius: 8,
                    fontSize: "0.75rem",
                    fontWeight: 800,
                    color: THEME.primary,
                  }}
                >
                  CASE ID: {selectedReport.id?.substring(0, 8)}
                </span>
                <span
                  style={{
                    padding: "6px 12px",
                    background: "rgba(74, 124, 68, 0.1)",
                    borderRadius: 8,
                    fontSize: "0.75rem",
                    fontWeight: 800,
                    color: THEME.success,
                  }}
                >
                  VERIFIED
                </span>
              </div>

              <h2
                style={{
                  fontSize: "2.4rem",
                  fontWeight: 800,
                  color: THEME.primary,
                  margin: "0 0 20px 0",
                }}
              >
                Analysis Report
              </h2>

              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: "1fr 1fr",
                  gap: 30,
                  marginBottom: 30,
                }}
              >
                <div className="detail-field">
                  <p
                    style={{
                      margin: "0 0 5px 0",
                      fontSize: "0.7rem",
                      fontWeight: 800,
                      color: THEME.secondary,
                      textTransform: "uppercase",
                    }}
                  >
                    Farmer Information
                  </p>
                  <div
                    style={{ display: "flex", alignItems: "center", gap: 10 }}
                  >
                    <User size={18} />
                    <span style={{ fontSize: "1.1rem", fontWeight: 600 }}>
                      {selectedReport.user_name || "Guest Access"}
                    </span>
                  </div>
                </div>
                <div className="detail-field">
                  <p
                    style={{
                      margin: "0 0 5px 0",
                      fontSize: "0.7rem",
                      fontWeight: 800,
                      color: THEME.secondary,
                      textTransform: "uppercase",
                    }}
                  >
                    Plant Category
                  </p>
                  <div
                    style={{ display: "flex", alignItems: "center", gap: 10 }}
                  >
                    <Leaf size={18} />
                    <span style={{ fontSize: "1.1rem", fontWeight: 600 }}>
                      {selectedReport.plant_name}
                    </span>
                  </div>
                </div>
                <div className="detail-field">
                  <p
                    style={{
                      margin: "0 0 5px 0",
                      fontSize: "0.7rem",
                      fontWeight: 800,
                      color: THEME.secondary,
                      textTransform: "uppercase",
                    }}
                  >
                    Location Metadata
                  </p>
                  <div
                    style={{ display: "flex", alignItems: "center", gap: 10 }}
                  >
                    <MapPin size={18} />
                    <span style={{ fontSize: "1.1rem", fontWeight: 600 }}>
                      Regional Sector A-12
                    </span>
                  </div>
                </div>
                <div className="detail-field">
                  <p
                    style={{
                      margin: "0 0 5px 0",
                      fontSize: "0.7rem",
                      fontWeight: 800,
                      color: THEME.secondary,
                      textTransform: "uppercase",
                    }}
                  >
                    Timestamp
                  </p>
                  <div
                    style={{ display: "flex", alignItems: "center", gap: 10 }}
                  >
                    <Calendar size={18} />
                    <span style={{ fontSize: "1.1rem", fontWeight: 600 }}>
                      {new Date(
                        selectedReport.created_at || Date.now()
                      ).toLocaleString()}
                    </span>
                  </div>
                </div>
              </div>

              <div className="remedy-scroll-box">
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 8,
                    marginBottom: 15,
                  }}
                >
                  <ClipboardCheck size={20} className="text-secondary" />
                  <h4
                    style={{
                      margin: 0,
                      fontSize: "0.9rem",
                      fontWeight: 800,
                      textTransform: "uppercase",
                    }}
                  >
                    Biological Intervention Strategy
                  </h4>
                </div>
                <p style={{ lineHeight: 1.8, fontSize: "1rem", color: "#444" }}>
                  {selectedReport.remedy}
                </p>
              </div>

              <div style={{ display: "flex", gap: 12, marginTop: 30 }}>
                <button
                  className="btn-view-detail"
                  style={{ flex: 1 }}
                  onClick={() => handleCopyLink(selectedReport.image_url)}
                >
                  <Copy size={18} /> Copy Asset Link
                </button>
                <button
                  className="btn-view-detail"
                  style={{
                    flex: 1,
                    background: "#F1F3F1",
                    color: THEME.primary,
                  }}
                  onClick={() => downloadReport(selectedReport)}
                >
                  <Download size={18} /> Export Data
                </button>
                <button
                  className="btn-view-detail"
                  style={{ width: "auto", background: THEME.secondary }}
                  onClick={printDiagnosis}
                >
                  <Printer size={18} />
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* --- Notification Toast System --- */}
      {msg.text && (
        <div
          className="toast"
          style={{
            position: "fixed",
            bottom: 40,
            left: "50%",
            transform: "translateX(-50%)",
            background: msg.type === "error" ? THEME.error : THEME.primary,
            color: "white",
            padding: "16px 32px",
            borderRadius: "100px",
            display: "flex",
            alignItems: "center",
            gap: 12,
            zIndex: 9999,
            boxShadow: "0 20px 40px rgba(0,0,0,0.2)",
            animation: "slideUp 0.4s ease",
          }}
        >
          {msg.type === "error" ? (
            <AlertCircle size={20} />
          ) : (
            <CheckCircle2 size={20} />
          )}
          <span style={{ fontWeight: 700 }}>{msg.text}</span>
        </div>
      )}

      {/* --- No Data State --- */}
      {!loading && filteredReports.length === 0 && (
        <div
          style={{
            textAlign: "center",
            padding: "120px 0",
            background: "white",
            borderRadius: "40px",
            border: `2px dashed ${THEME.border}`,
          }}
        >
          <div
            style={{
              width: 80,
              height: 80,
              background: THEME.background,
              borderRadius: "50%",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              margin: "0 auto 24px",
            }}
          >
            <Search size={40} style={{ color: THEME.secondary }} />
          </div>
          <h2 style={{ color: THEME.primary, fontWeight: 800 }}>
            No Matching Records Found
          </h2>
          <p
            style={{
              color: THEME.textMuted,
              maxWidth: 400,
              margin: "10px auto",
            }}
          >
            We couldn't find any diagnosis reports matching your current search
            parameters. Try adjusting your filters or search keywords.
          </p>
          <button
            style={{
              marginTop: 20,
              padding: "12px 24px",
              background: THEME.primary,
              color: "white",
              border: "none",
              borderRadius: "12px",
              fontWeight: 700,
              cursor: "pointer",
            }}
            onClick={() => {
              setQ("");
              setFilterType("all");
            }}
          >
            Reset All Filters
          </button>
        </div>
      )}

      {/* Global CSS Animations */}
      <style>{`
        @keyframes slideUp {
          from { opacity: 0; transform: translate(-50%, 20px); }
          to { opacity: 1; transform: translate(-50%, 0); }
        }
        @media print {
          .ag-top-nav, .ag-stats-row, .pagination-bar, .close-trigger, .ag-controls { display: none !important; }
          .modal-overlay { position: absolute; background: white; padding: 0; }
          .modal-container { box-shadow: none; width: 100%; height: auto; }
          .modal-side-image { display: none; }
          .modal-side-content { width: 100%; padding: 0; }
        }
      `}</style>
    </div>
  );
};

export default Report;
