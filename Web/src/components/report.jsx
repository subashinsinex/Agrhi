import React, { useState, useEffect, useMemo } from "react";
import { axiosInstance } from "../api/login";
import {
  Search,
  ExternalLink,
  AlertTriangle,
  CheckCircle,
  Eye,
  X,
  Copy,
} from "lucide-react";
import { SERVER_IP, SERVER_PORT } from "../constant";

// API endpoint
const apiBase = `http://${SERVER_IP}:${SERVER_PORT}/api/diseaseRemedies`;

/**
 * Renders a status message with an appropriate icon.
 */
const StatusMessage = ({ msg, type }) => {
  if (!msg) return null;
  const Icon = type === "error" ? AlertTriangle : CheckCircle;
  const className = `status-msg ${
    type === "error" ? "error-style" : "success-style"
  }`;

  const style = {
    padding: "10px 15px",
    borderRadius: "6px",
    margin: "15px 0 10px 0",
    display: "flex",
    alignItems: "center",
    background: type === "error" ? "#fdebeb" : "#e6f7e9",
    color: type === "error" ? "#c70000" : "#1c6a30",
    border: `1px solid ${type === "error" ? "#f0a8a8" : "#aedaa5"}`,
  };

  return (
    <div className={className} style={style}>
      <Icon size={18} style={{ marginRight: 8, flexShrink: 0 }} />
      <span style={{ fontSize: 15 }}>{msg}</span>
    </div>
  );
};

/**
 * Component for displaying disease detection reports.
 */
const Report = () => {
  const [reports, setReports] = useState([]);
  const [q, setQ] = useState("");
  const [loading, setLoading] = useState(true);
  const [selectedReport, setSelectedReport] = useState(null);
  const [msg, setMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");
  const access_token = localStorage.getItem("access_token");

  // Helper to clear temporary messages after a delay
  const clearMessages = () => {
    setTimeout(() => {
      setMsg("");
      setErrorMsg("");
    }, 4000);
  };

  const fetchReports = async () => {
    setLoading(true);
    setMsg("");
    setErrorMsg("");
    try {
      const res = await axiosInstance.get(
        `${apiBase}/disease-analysis-results`,
        {
          headers: { Authorization: `Bearer ${access_token}` },
        }
      );
      setReports(res.data || []);
      setMsg("Reports loaded successfully.");
    } catch (err) {
      setErrorMsg(
        "Could not load reports: " +
          (err.response?.data?.message || err.message || "Unknown error")
      );
    }
    setLoading(false);
    clearMessages();
  };

  useEffect(() => {
    fetchReports();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleSearch = (e) => setQ(e.target.value);

  const openDetailModal = (report) => setSelectedReport(report);
  const closeDetailModal = () => setSelectedReport(null);

  // Confidence color based on value (assuming 0 to 100 for percentage)
  const confColor = (c) => {
    // SAFETY FIX: Convert to number first, defaulting to 0
    const numC = Number(c) || 0;
    return numC >= 90 ? "#28a745" : numC >= 70 ? "#ffc107" : "#dc3545";
  };

  // Search by any main text field
  const filteredReports = useMemo(() => {
    if (!q) return reports;
    const lowerQ = q.toLowerCase();
    return reports.filter(
      (r) =>
        (r.user_name ?? "").toLowerCase().includes(lowerQ) ||
        (r.plant_name ?? "").toLowerCase().includes(lowerQ) ||
        (r.disease_name ?? "").toLowerCase().includes(lowerQ) ||
        (r.remedy ?? "").toLowerCase().includes(lowerQ) ||
        // SAFETY FIX: Apply Number() coercion before toFixed()
        ((Number(r.confidence) || 0).toFixed(0).toString() + "%").includes(
          lowerQ
        )
    );
  }, [reports, q]);

  // Function to copy image URL and show message
  const handleCopyLink = () => {
    if (selectedReport?.image_url) {
      navigator.clipboard.writeText(selectedReport.image_url);
      setMsg("Image URL copied to clipboard!");
      clearMessages();
    }
  };

  // --- Report Card Component ---
  const ReportCard = ({ r, confColor, openDetailModal }) => (
    <div
      className="data-card report-card"
      key={r.id}
      style={{
        border: "1px solid #e0e0e0",
        borderRadius: 12,
        background: "#fff",
        padding: "18px 18px",
        display: "flex",
        flexDirection: "column",
        minHeight: 300,
        boxShadow: "0 4px 12px rgba(0,0,0,0.05)",
        transition: "transform 0.2s, box-shadow 0.2s",
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.transform = "translateY(-3px)";
        e.currentTarget.style.boxShadow = "0 6px 15px rgba(0,0,0,0.1)";
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.transform = "translateY(0)";
        e.currentTarget.style.boxShadow = "0 4px 12px rgba(0,0,0,0.05)";
      }}
    >
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          marginBottom: 10,
          borderBottom: "1px solid #f0f0f0",
          paddingBottom: 8,
        }}
      >
        <div style={{ display: "flex", alignItems: "center" }}>
          <Eye size={16} style={{ marginRight: 6, color: "#007bff" }} />
          <span style={{ fontWeight: 600, fontSize: 16 }}>
            {r.user_name || "Unknown User"}
          </span>
        </div>
        <span style={{ fontSize: 14, color: "#6c757d", fontWeight: 500 }}>
          {r.plant_name}
        </span>
      </div>

      {r.image_url && (
        <a
          href={`http://${SERVER_IP}:${SERVER_PORT}${r.image_url}`}
          target="_blank"
          rel="noopener noreferrer"
          title="View Original Image"
          style={{
            display: "block",
            marginBottom: "12px",
            width: "100%",
            textAlign: "center",
            minHeight: 120,
          }}
        >
          <img
            src={`http://${SERVER_IP}:${SERVER_PORT}${r.image_url}`}
            alt={`Detection for ${r.disease_name}`}
            style={{
              border: "2px solid #ddd",
              maxWidth: "100%",
              height: 120,
              width: "auto",
              borderRadius: 8,
              objectFit: "contain",
              background: "#fafafa",
            }}
            onError={(e) => {
              e.currentTarget.src =
                'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%"><rect width="100%" height="100%" fill="#eee"/><text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" font-size="12" fill="#888">Image Not Found</text></svg>';
              e.currentTarget.style.objectFit = "cover";
              e.currentTarget.style.height = "120px";
            }}
          />
          <ExternalLink
            size={15}
            style={{ marginLeft: 8, verticalAlign: "middle", color: "#007bff" }}
          />
        </a>
      )}

      <div style={{ fontSize: 15, marginBottom: 8, flexGrow: 1 }}>
        <p style={{ margin: "4px 0" }}>
          <b>Disease:</b> {r.disease_name}
        </p>
        <p
          style={{
            margin: "4px 0",
            whiteSpace: "nowrap",
            overflow: "hidden",
            textOverflow: "ellipsis",
          }}
          title={r.remedy}
        >
          <b>Remedy:</b> {r.remedy}
        </p>
      </div>

      <div
        style={{
          marginTop: "auto",
          paddingTop: 10,
          borderTop: "1px solid #f0f0f0",
          width: "100%",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
        }}
      >
        <div
          style={{
            fontSize: 16,
            fontWeight: 700,
            color: confColor(r.confidence),
          }}
        >
          {/* CONFIDENCE FIX: Removed * 100, Added Number() coercion for safety */}
          Confidence:{" "}
          <span style={{ marginLeft: 4 }}>
            {(Number(r.confidence) || 0).toFixed(1)}%
          </span>
        </div>
        <button
          className="btn primary-btn"
          onClick={() => openDetailModal(r)}
          style={{
            fontSize: 14,
            fontWeight: 500,
            padding: "6px 12px",
            background: "#007bff",
            color: "#fff",
            border: "none",
            borderRadius: 6,
            cursor: "pointer",
          }}
        >
          Details
        </button>
      </div>
    </div>
  );
  // --- End of ReportCard component ---

  return (
    <div
      className="report-bg"
      style={{ padding: "25px", minHeight: "100vh", background: "#f4f7f9" }}
    >
      {/* Header and controls */}
      <div
        className="header-container"
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          marginBottom: 20,
          flexWrap: "wrap",
          gap: 15,
        }}
      >
        <h1
          className="main-title"
          style={{ fontSize: "1.8rem", color: "#343a40" }}
        >
          Disease Detection Reports
        </h1>
        <div
          className="controls-group"
          style={{
            display: "flex",
            alignItems: "center",
            position: "relative",
          }}
        >
          <input
            className="search-input"
            style={{
              minWidth: 300,
              padding: "10px 15px 10px 40px",
              borderRadius: 8,
              border: "1px solid #ced4da",
              fontSize: 16,
            }}
            placeholder="Search by user, plant, disease, remedy..."
            value={q}
            onChange={handleSearch}
          />
          <Search
            className="search-icon"
            size={20}
            style={{ position: "absolute", left: 10, color: "#6c757d" }}
          />
        </div>
      </div>

      <StatusMessage msg={msg} type="success" />
      <StatusMessage msg={errorMsg} type="error" />

      {/* Reports Grid */}
      {loading ? (
        <div
          className="loading-msg"
          style={{
            textAlign: "center",
            marginTop: 50,
            fontSize: 18,
            color: "#007bff",
          }}
        >
          Loading analysis reports...
        </div>
      ) : filteredReports.length === 0 ? (
        <p
          className="no-data-message"
          style={{
            textAlign: "center",
            marginTop: 50,
            fontSize: 16,
            color: "#6c757d",
          }}
        >
          No analysis results found matching your search.
        </p>
      ) : (
        <div
          className="card-grid"
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))",
            gap: "25px",
            marginTop: "30px",
          }}
        >
          {filteredReports.map((r) => (
            <ReportCard
              key={r.id}
              r={r}
              confColor={confColor}
              openDetailModal={openDetailModal}
            />
          ))}
        </div>
      )}

      {/* Detail Modal for Report */}
      {selectedReport && (
        <div
          className="modal-overlay"
          style={{
            position: "fixed",
            top: 0,
            left: 0,
            width: "100vw",
            height: "100vh",
            background: "rgba(0,0,0,.5)",
            zIndex: 1000,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
          }}
          onClick={closeDetailModal}
        >
          <div
            className="modal-dialog detail-modal"
            style={{
              background: "#fff",
              borderRadius: 12,
              maxWidth: 450,
              width: "90%",
              padding: "20px",
              boxShadow: "0 5px 25px rgba(0,0,0,0.2)",
              position: "relative",
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div
              className="modal-header"
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                borderBottom: "1px solid #eee",
                paddingBottom: 10,
                marginBottom: 15,
              }}
            >
              <h2
                className="modal-title"
                style={{
                  fontSize: "1.5rem",
                  fontWeight: 700,
                  color: "#343a40",
                }}
              >
                Detection Details
              </h2>
              <button
                className="close-btn"
                style={{
                  border: "none",
                  background: "none",
                  cursor: "pointer",
                  padding: 4,
                  color: "#6c757d",
                }}
                onClick={closeDetailModal}
                title="Close"
              >
                <X size={24} />
              </button>
            </div>
            <div className="modal-body" style={{ fontSize: 16 }}>
              <div style={{ marginBottom: 15, lineHeight: 1.6 }}>
                <b>User:</b> {selectedReport.user_name || "N/A"} <br />
                <b>User ID:</b> {selectedReport.user_id || "N/A"} <br />
                <b>Plant:</b> {selectedReport.plant_name} <br />
                <b>Disease:</b> {selectedReport.disease_name}
                <br />
                <b>Remedy:</b> {selectedReport.remedy}
                <br />
                <b>Confidence:</b>
                <span
                  style={{
                    color: confColor(selectedReport.confidence),
                    fontWeight: 700,
                    marginLeft: 6,
                  }}
                >
                  {/* CONFIDENCE FIX: Removed * 100, Added Number() coercion for safety */}
                  {(Number(selectedReport.confidence) || 0).toFixed(1)}%
                </span>
              </div>
              <div style={{ marginTop: 15, textAlign: "center" }}>
                <a
                  href={`http://${SERVER_IP}:${SERVER_PORT}${selectedReport.image_url}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{ display: "inline-block", position: "relative" }}
                  title="View full size image"
                >
                  <img
                    src={`http://${SERVER_IP}:${SERVER_PORT}${selectedReport.image_url}`}
                    alt="Detection"
                    style={{
                      border: "1px solid #ced4da",
                      width: "100%",
                      maxWidth: 300,
                      minHeight: 100,
                      maxHeight: 200,
                      marginBottom: 8,
                      objectFit: "contain",
                      borderRadius: 8,
                      background: "#fff",
                    }}
                    onError={(e) => {
                      e.currentTarget.src =
                        'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%"><rect width="100%" height="100%" fill="#eee"/><text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" font-size="14" fill="#888">Image Not Found</text></svg>';
                      e.currentTarget.style.objectFit = "cover";
                      e.currentTarget.style.height = "150px";
                    }}
                  />
                  <ExternalLink
                    size={16}
                    style={{
                      position: "absolute",
                      top: 5,
                      right: 5,
                      color: "#007bff",
                    }}
                  />
                </a>
                <button
                  className="btn tertiary-btn"
                  style={{
                    display: "block",
                    margin: "10px auto 0 auto",
                    padding: "8px 15px",
                    fontSize: "0.95em",
                    background: "#f8f9fa",
                    color: "#007bff",
                    border: "1px solid #007bff",
                    borderRadius: 6,
                    cursor: "pointer",
                  }}
                  onClick={handleCopyLink}
                >
                  <Copy
                    size={14}
                    style={{ marginRight: 5, verticalAlign: "middle" }}
                  />{" "}
                  Copy Image Link
                </button>
              </div>
            </div>
            <div
              className="modal-footer"
              style={{
                marginTop: 20,
                paddingTop: 10,
                borderTop: "1px solid #eee",
                textAlign: "right",
              }}
            >
              <button
                className="btn secondary-btn"
                onClick={closeDetailModal}
                style={{
                  padding: "8px 20px",
                  background: "#6c757d",
                  color: "#fff",
                  border: "none",
                  borderRadius: 6,
                  cursor: "pointer",
                }}
                autoFocus
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Report;
