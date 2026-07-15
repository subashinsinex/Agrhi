import React, { useEffect, useState, useCallback, useMemo } from "react";
import { axiosInstance } from "../api/login";
import {
  Search,
  Trash2,
  Edit,
  MessageSquare,
  CheckCircle2,
  X,
  AlertCircle,
  User,
  Sprout, // New Ag Icon
  Wheat, // New Ag Icon
  Tractor, // New Ag Icon
  Bug, // New Ag Icon
  Send,
  RefreshCw,
  Calendar,
} from "lucide-react";
import { SERVER_IP, SERVER_PORT } from "../constant";

const apiBase = `http://${SERVER_IP}:${SERVER_PORT}/api/feedback`;
const STATUS_OPTIONS = ["not_viewed", "viewed", "responsed", "solved"];

// --- AGRICULTURE THEME PALETTE ---
const THEME = {
  primary: "rgba(5, 82, 25, 1)", // Forest Green
  primaryLight: "#4caf50", // Leaf Green
  secondary: "#f9a825", // Harvest Gold
  earth: "#5d4037", // Soil Brown
  bgLight: "#f1f8e9", // Very light green tint
  surface: "#FFFFFF",
  error: "#c62828", // Red clay
  textDark: "rgba(5, 82, 25, 1)",
  textMuted: "#557b5e",
};

const Feedback = () => {
  const [feedbacks, setFeedbacks] = useState([]);
  const [q, setQ] = useState("");
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [selectedFeedback, setSelectedFeedback] = useState(null);
  const [msg, setMsg] = useState({ text: "", type: "" });
  const [feedbackToDelete, setFeedbackToDelete] = useState(null);

  const [form, setForm] = useState({
    id: "",
    user_id: "",
    message: "",
    isproblem: false,
    reply: "",
    status: STATUS_OPTIONS[0],
  });

  const accesstoken = localStorage.getItem("access_token");

  // --- API Handlers ---
  const showToast = (text, type = "success") => {
    setMsg({ text, type });
    setTimeout(() => setMsg({ text: "", type: "" }), 4000);
  };

  const fetchFeedbacks = useCallback(async () => {
    setLoading(true);
    try {
      const res = await axiosInstance.get(`${apiBase}/getfeedback`, {
        headers: { Authorization: `Bearer ${accesstoken}` },
      });
      setFeedbacks(res.data || []);
    } catch (e) {
      showToast("Sync Error: Unable to get data", "error");
    } finally {
      setLoading(false);
    }
  }, [accesstoken]);

  useEffect(() => {
    fetchFeedbacks();
  }, [fetchFeedbacks]);

  // --- Logic ---
  const filteredFeedbacks = useMemo(() => {
    if (!q) return feedbacks;
    const lowerQ = q.toLowerCase();
    return feedbacks.filter(
      (f) =>
        (f.message || "").toLowerCase().includes(lowerQ) ||
        (f.reply || "").toLowerCase().includes(lowerQ) ||
        (f.user_id || "").toString().includes(lowerQ)
    );
  }, [feedbacks, q]);

  const stats = useMemo(
    () => ({
      total: feedbacks.length,
      pending: feedbacks.filter((f) => f.status === "not_viewed").length,
      solved: feedbacks.filter((f) => f.status === "solved").length,
      problems: feedbacks.filter((f) => f.isproblem).length,
    }),
    [feedbacks]
  );

  // --- Interaction Handlers ---
  const openEdit = (fb) => {
    setForm({ ...fb });
    setShowForm(true);
    setSelectedFeedback(null);
  };

  const handleUpdate = async (e) => {
    e.preventDefault();
    try {
      await axiosInstance.put(
        `${apiBase}/reply/${form.id}`,
        { reply: form.reply },
        { headers: { Authorization: `Bearer ${accesstoken}` } }
      );
      await axiosInstance.put(
        `${apiBase}/status/${form.id}`,
        { status: form.status },
        { headers: { Authorization: `Bearer ${accesstoken}` } }
      );
      showToast("Feedback got: Response sent");
      fetchFeedbacks();
      setShowForm(false);
    } catch (err) {
      showToast("Update failed: Check connection", "error");
    }
  };

  const confirmDelete = async () => {
    try {
      await axiosInstance.delete(`${apiBase}/delete/${feedbackToDelete.id}`, {
        headers: { Authorization: `Bearer ${accesstoken}` },
      });
      showToast(`Weeded out entry #${feedbackToDelete.id}`);
      setFeedbacks((prev) => prev.filter((f) => f.id !== feedbackToDelete.id));
    } catch (err) {
      showToast("Deletion failed", "error");
    } finally {
      setFeedbackToDelete(null);
    }
  };

  /* const formatDate = (dateStr) => {
    if (!dateStr) return "Unknown Date";
    return new Date(dateStr).toLocaleDateString();
  }; */

  // --- CSS Styles ---
  const styles = `
    @import url('https://fonts.googleapis.com/css2?family=Segoe+UI:wght@400;600;700&display=swap');

    .ag-root {
      min-height: 80vh;
      padding: 30px;
      font-family: 'Segoe UI', sans-serif;
      color: ${THEME.textDark};
      background: transparent;
    }

    /* Header */
    .ag-header {
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
      margin-bottom: 30px;
      border-bottom: 1px solid rgba(46, 125, 50, 0.2);
      padding-bottom: 20px;
    }
    .ag-header h1 {
      font-size: 2.2rem;
      font-weight: 700;
      color: ${THEME.primary};
      margin: 0;
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .ag-subtitle {
        color: ${THEME.secondary};
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 1px;
        font-size: 0.85rem;
        margin-bottom: 5px;
    }

    /* Search Bar */
    .ag-search-wrapper {
        position: relative;
        display: flex;
        gap: 10px;
    }
    .ag-search-input {
        padding: 10px 15px 10px 40px;
        border-radius: 20px;
        border: 1px solid ${THEME.primaryLight};
        background: white;
        width: 300px;
        outline: none;
        color: ${THEME.textDark};
        transition: box-shadow 0.2s;
    }
    .ag-search-input:focus {
        box-shadow: 0 0 0 3px rgba(76, 175, 80, 0.2);
    }

    /* Stats Row */
    .ag-stats-container {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        gap: 20px;
        margin-bottom: 40px;
    }
    .ag-stat-card {
        background: white;
        padding: 20px;
        border-radius: 12px;
        box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05);
        border-left: 5px solid ${THEME.primary};
        display: flex;
        align-items: center;
        gap: 15px;
    }
    .ag-stat-icon-box {
        width: 45px;
        height: 45px;
        background: ${THEME.bgLight};
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        color: ${THEME.primary};
    }
    .ag-stat-info h3 { margin: 0; font-size: 1.8rem; font-weight: 700; color: ${THEME.textDark}; }
    .ag-stat-info span { font-size: 0.8rem; color: ${THEME.textMuted}; text-transform: uppercase; font-weight: 600; }

    /* Grid */
    .ag-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
        gap: 25px;
    }
    .ag-card {
        background: white;
        border-radius: 16px;
        padding: 25px;
        position: relative;
        border: 1px solid #e0e0e0;
        transition: transform 0.2s, box-shadow 0.2s;
        display: flex;
        flex-direction: column;
    }
    .ag-card:hover {
        transform: translateY(-5px);
        box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
        border-color: ${THEME.primaryLight};
    }

    /* Status Badges - Leaf Shape */
    .ag-badge {
        position: absolute;
        top: 20px;
        right: 20px;
        padding: 5px 12px;
        border-radius: 12px 0 12px 0; /* Leaf Shape */
        font-size: 0.7rem;
        font-weight: 700;
        text-transform: uppercase;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    /* Typography in Card */
    .ag-card-meta {
        font-size: 0.85rem;
        color: ${THEME.textMuted};
        margin-bottom: 12px;
        display: flex;
        align-items: center;
        gap: 6px;
    }
    .ag-card-msg {
        font-size: 1.1rem;
        font-weight: 600;
        color: ${THEME.textDark};
        margin-bottom: 20px;
        line-height: 1.5;
        flex-grow: 1;
        white-space: pre-wrap;
        word-break: break-word;
    }
    .ag-reply-preview {
        background: ${THEME.bgLight};
        padding: 12px;
        border-radius: 8px;
        font-size: 0.9rem;
        color: ${THEME.textDark};
        border-left: 3px solid ${THEME.secondary};
        margin-bottom: 20px;
    }

    /* Buttons */
    .ag-btn {
        padding: 10px 16px;
        border-radius: 8px;
        border: none;
        font-weight: 600;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        transition: 0.2s;
    }
    .ag-btn-primary { background: ${THEME.primary}; color: white; }
    .ag-btn-primary:hover { background: ${THEME.primaryLight}; }
    .ag-btn-outline { background: transparent; border: 1px solid ${THEME.primary}; color: ${THEME.primary}; }
    .ag-btn-danger { background: #ffebee; color: ${THEME.error}; }
    .ag-btn-danger:hover { background: #ffcdd2; }

    /* Modal */
    .ag-modal-overlay {
        position: fixed;
        inset: 0;
        background: rgba(27, 58, 35, 0.8); /* Dark Green Overlay */
        backdrop-filter: blur(4px);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 1000;
        padding: 20px;
    }
    .ag-modal-content {
        background: white;
        width: 100%;
        max-width: 900px;
        border-radius: 20px;
        overflow: hidden;
        display: flex;
        box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
    }
    .ag-modal-left {
        width: 35%;
        background: linear-gradient(135deg, ${THEME.primary} 0%, ${THEME.primaryLight} 100%);
        color: white;
        padding: 40px;
        display: flex;
        flex-direction: column;
        justify-content: center;
    }
    .ag-modal-right {
        width: 65%;
        padding: 40px;
        position: relative;
    }
    
    /* Inputs */
    .ag-form-group { margin-bottom: 20px; }
    .ag-label { display: block; font-size: 0.8rem; font-weight: 700; color: ${THEME.textMuted}; margin-bottom: 8px; text-transform: uppercase; }
    .ag-input-area {
        width: 100%;
        padding: 12px;
        border-radius: 8px;
        border: 1px solid #ddd;
        font-family: inherit;
        background: #fafafa;
        resize: vertical;
    }
    .ag-select {
        width: 100%;
        padding: 12px;
        border-radius: 8px;
        border: 1px solid #ddd;
        background: white;
    }

    /* Toast */
    .ag-toast {
        position: fixed;
        bottom: 30px;
        left: 50%;
        transform: translateX(-50%);
        background: ${THEME.primary};
        color: white;
        padding: 12px 24px;
        border-radius: 30px;
        box-shadow: 0 10px 15px rgba(0,0,0,0.2);
        z-index: 2000;
        display: flex;
        align-items: center;
        gap: 10px;
    }

    /* Loading Spinner */
    .spin { animation: spin 1s linear infinite; }
    @keyframes spin { 100% { transform: rotate(360deg); } }

    /* Responsive */
    @media(max-width: 768px) {
        .ag-modal-content { flex-direction: column; max-height: 90vh; overflow-y: auto; }
        .ag-modal-left, .ag-modal-right { width: 100%; padding: 25px; }
        .ag-header { flex-direction: column; align-items: flex-start; gap: 15px; }
        .ag-search-wrapper { width: 100%; }
        .ag-search-input { width: 100%; }
    }
  `;

  return (
    <div className="ag-root">
      <style>{styles}</style>

      {/* --- HEADER --- */}
      <div className="ag-header">
        <div></div>
        <div className="ag-search-wrapper">
          <Search
            size={18}
            style={{
              position: "absolute",
              left: 12,
              top: 12,
              color: THEME.textMuted,
            }}
          />
          <input
            className="ag-search-input"
            placeholder="Search crop reports, users..."
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
          <button className="ag-btn ag-btn-outline" onClick={fetchFeedbacks}>
            <RefreshCw size={18} />
          </button>
        </div>
      </div>

      {/* --- STATS PLOTS --- */}
      <div className="ag-stats-container">
        <div className="ag-stat-card">
          <div className="ag-stat-icon-box">
            <Wheat size={24} />
          </div>
          <div className="ag-stat-info">
            <span>Total Feedback</span>
            <h3>{stats.total}</h3>
          </div>
        </div>
        <div
          className="ag-stat-card"
          style={{ borderLeftColor: THEME.secondary }}
        >
          <div className="ag-stat-icon-box" style={{ color: THEME.secondary }}>
            <Sprout size={24} />
          </div>
          <div className="ag-stat-info">
            <span>Pending</span>
            <h3>{stats.pending}</h3>
          </div>
        </div>
        <div className="ag-stat-card" style={{ borderLeftColor: THEME.error }}>
          <div className="ag-stat-icon-box" style={{ color: THEME.error }}>
            <Bug size={24} />
          </div>
          <div className="ag-stat-info">
            <span>Issues</span>
            <h3>{stats.problems}</h3>
          </div>
        </div>
        <div
          className="ag-stat-card"
          style={{ borderLeftColor: THEME.primaryLight }}
        >
          <div
            className="ag-stat-icon-box"
            style={{ color: THEME.primaryLight }}
          >
            <Tractor size={24} />
          </div>
          <div className="ag-stat-info">
            <span>solved</span>
            <h3>{stats.solved}</h3>
          </div>
        </div>
      </div>

      {/* --- FEEDBACK FIELD (GRID) --- */}
      {loading ? (
        <div
          style={{
            textAlign: "center",
            padding: "80px",
            color: THEME.textMuted,
          }}
        >
          <RefreshCw className="spin" size={40} style={{ marginBottom: 10 }} />
          <p>Gathering field data...</p>
        </div>
      ) : (
        <div className="ag-grid">
          {filteredFeedbacks.map((f) => (
            <div
              key={f.id}
              className="ag-card"
              onClick={() => setSelectedFeedback(f)}
            >
              {/* Status Badge */}
              <div
                className="ag-badge"
                style={{
                  backgroundColor:
                    f.status === "not_viewed"
                      ? "#ffebee"
                      : f.status === "solved"
                      ? "#e8f5e9"
                      : THEME.bgLight,
                  color:
                    f.status === "not_viewed"
                      ? THEME.error
                      : f.status === "solved"
                      ? THEME.primary
                      : THEME.secondary,
                }}
              >
                {f.status.replace("_", " ")}
              </div>

              {/* User Info */}
              {/* User Info */}
              <div className="ag-card-meta">
                <User size={14} />
                {f.user_name ? <> {f.user_name} </> : <> ID: {f.user_id} </>}
                {f.isproblem && (
                  <span
                    style={{
                      color: THEME.error,
                      display: "flex",
                      alignItems: "center",
                      gap: 4,
                    }}
                  >
                    <AlertCircle size={12} /> BUG
                  </span>
                )}
              </div>

              {/* Message Content */}
              <div
                className="ag-card-msg"
                style={{
                  background: THEME.bgLight,
                  padding: 15,
                  borderRadius: 8,
                  color: THEME.textDark,
                  whiteSpace: "pre-wrap",
                  wordBreak: "break-word",
                }}
              >
                {showForm ? form.message : f.message}
              </div>

              {/* Reply Preview */}
              <div className="ag-reply-preview">
                {f.reply ? (
                  <div style={{ display: "flex", gap: 6 }}>
                    <Send size={14} style={{ marginTop: 3 }} /> {f.reply}
                  </div>
                ) : (
                  <span style={{ color: THEME.error, fontStyle: "italic" }}>
                    Waiting for Response...
                  </span>
                )}
              </div>

              {/* Actions */}
              <div style={{ display: "flex", gap: "10px", marginTop: "auto" }}>
                <button
                  className="ag-btn ag-btn-primary"
                  style={{ flex: 1 }}
                  onClick={(e) => {
                    e.stopPropagation();
                    openEdit(f);
                  }}
                >
                  <Edit size={16} /> Reply
                </button>
                <button
                  className="ag-btn ag-btn-danger"
                  onClick={(e) => {
                    e.stopPropagation();
                    setFeedbackToDelete(f);
                  }}
                >
                  <Trash2 size={16} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* --- EDIT / VIEW MODAL --- */}
      {(showForm || selectedFeedback) && (
        <div
          className="ag-modal-overlay"
          onClick={() => {
            setShowForm(false);
            setSelectedFeedback(null);
          }}
        >
          <div
            className="ag-modal-content"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Left Side: Context */}
            <div className="ag-modal-left">
              <MessageSquare
                size={48}
                style={{ opacity: 0.8, marginBottom: 20 }}
              />
              <h2 style={{ margin: 0 }}>Inquiry Details</h2>
              <p style={{ opacity: 0.9 }}>
                Reference ID #{showForm ? form.id : selectedFeedback.id}
              </p>

              <div
                style={{
                  marginTop: 30,
                  paddingTop: 30,
                  borderTop: "1px solid rgba(255,255,255,0.2)",
                }}
              >
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 10,
                    marginBottom: 10,
                  }}
                >
                  <User size={18} />
                  <strong>
                    {showForm
                      ? form.user_name || `ID: ${form.user_id}`
                      : selectedFeedback.user_name ||
                        `ID: ${selectedFeedback.user_id}`}
                  </strong>
                </div>

                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <Calendar size={18} />
                  {showForm ? "Editing Record" : "Viewing Record"}
                </div>
              </div>
            </div>

            {/* Right Side: Form */}
            <div className="ag-modal-right">
              <button
                onClick={() => {
                  setShowForm(false);
                  setSelectedFeedback(null);
                }}
                style={{
                  position: "absolute",
                  top: 20,
                  right: 20,
                  border: "none",
                  background: "transparent",
                  cursor: "pointer",
                }}
              >
                <X size={24} color={THEME.textMuted} />
              </button>

              <div className="ag-form-group">
                <label className="ag-label">Farmer's Message</label>
                <div
                  style={{
                    background: THEME.bgLight,
                    padding: 15,
                    borderRadius: 8,
                    color: THEME.textDark,
                  }}
                >
                  {showForm ? form.message : selectedFeedback.message}
                </div>
              </div>

              {showForm ? (
                <form onSubmit={handleUpdate}>
                  <div className="ag-form-group">
                    <label className="ag-label">Your Response</label>
                    <textarea
                      className="ag-input-area"
                      rows={4}
                      value={form.reply}
                      onChange={(e) =>
                        setForm({ ...form, reply: e.target.value })
                      }
                      placeholder="Type your guidance here..."
                    />
                  </div>
                  <div className="ag-form-group">
                    <label className="ag-label">Update Status</label>
                    <select
                      className="ag-select"
                      value={form.status}
                      onChange={(e) =>
                        setForm({ ...form, status: e.target.value })
                      }
                    >
                      {STATUS_OPTIONS.map((opt) => (
                        <option key={opt} value={opt}>
                          {opt.replace("_", " ").toUpperCase()}
                        </option>
                      ))}
                    </select>
                  </div>
                  <button
                    type="submit"
                    className="ag-btn ag-btn-primary"
                    style={{ width: "100%" }}
                  >
                    <CheckCircle2 size={18} /> Update Record
                  </button>
                </form>
              ) : (
                <div className="ag-form-group">
                  <label className="ag-label">Current Response</label>
                  <div
                    style={{
                      border: `1px dashed ${THEME.primary}`,
                      padding: 15,
                      borderRadius: 8,
                      color: THEME.textMuted,
                      marginBottom: 20,
                    }}
                  >
                    {selectedFeedback.reply || "No response recorded yet."}
                  </div>
                  <button
                    className="ag-btn ag-btn-outline"
                    style={{ width: "100%" }}
                    onClick={() => openEdit(selectedFeedback)}
                  >
                    <Edit size={16} /> Modify Response
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* --- DELETE CONFIRMATION --- */}
      {feedbackToDelete && (
        <div className="ag-modal-overlay">
          <div
            className="ag-modal-content"
            style={{
              maxWidth: 400,
              flexDirection: "column",
              textAlign: "center",
              padding: 30,
            }}
          >
            <div style={{ margin: "0 auto 20px", color: THEME.error }}>
              <Trash2 size={48} />
            </div>
            <h3 style={{ margin: "0 0 10px" }}>Delete this record?</h3>
            <p style={{ color: THEME.textMuted, marginBottom: 25 }}>
              Are you sure you want to delete Feedback #{feedbackToDelete.id}?
              This action cannot be undone.
            </p>
            <div style={{ display: "flex", gap: 10 }}>
              <button
                className="ag-btn ag-btn-outline"
                style={{ flex: 1 }}
                onClick={() => setFeedbackToDelete(null)}
              >
                Cancel
              </button>
              <button
                className="ag-btn ag-btn-primary"
                style={{ flex: 1, background: THEME.error }}
                onClick={confirmDelete}
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}

      {/* --- TOAST NOTIFICATION --- */}
      {msg.text && (
        <div
          className="ag-toast"
          style={{
            background: msg.type === "error" ? THEME.error : THEME.primary,
          }}
        >
          {msg.type === "error" ? (
            <AlertCircle size={20} />
          ) : (
            <CheckCircle2 size={20} />
          )}
          {msg.text}
        </div>
      )}
    </div>
  );
};

export default Feedback;
