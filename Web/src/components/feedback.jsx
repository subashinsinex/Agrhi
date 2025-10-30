import React, { useEffect, useState, useCallback, useMemo } from "react";
import { axiosInstance } from "../api/login";
import { Search, Trash2, Edit, MessageCircle, CheckCircle } from "lucide-react";
import { SERVER_IP } from "../constant";

const apiBase = `http://${SERVER_IP}:5000/api/feedback`;

// Feedback status constraints
const STATUS_OPTIONS = ["not_viewed", "viewed", "responsed", "solved"];

// --- 1. Define Color Variables as standalone constants ---
const primaryColor = "#6366f1";
const successColor = "#059669";
const dangerColor = "#ef4444";
const backgroundLight = "#f9fafb";
const backgroundDark = "#ffffff";
const textDark = "#1f2937";
const textLight = "#4b5563";
const borderColor = "#e5e7eb";
const shadowSm = "0 1px 3px 0 rgba(0,0,0,0.1), 0 1px 2px 0 rgba(0,0,0,0.06)";
const shadowMd =
  "0 4px 6px -1px rgba(0,0,0,0.1), 0 2px 4px -1px rgba(0,0,0,0.06)";

// --- 2. Use these constants to define the styles object ---
const styles = {
  // Main Layout Styles
  directoryBg: {
    padding: "30px",
    maxWidth: "1400px",
    margin: "0 auto",
    backgroundColor: backgroundLight,
  },
  headerContainer: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: "30px",
    flexWrap: "wrap",
    gap: "20px",
  },
  mainTitle: {
    fontSize: "2.5rem",
    fontWeight: "700",
    color: textDark,
  },
  controlsGroup: {
    display: "flex",
    gap: "15px",
    alignItems: "center",
  },

  // Search Box Styles
  searchBox: {
    display: "flex",
    alignItems: "center",
    padding: "10px 15px",
    border: `1px solid ${borderColor}`,
    borderRadius: "8px",
    backgroundColor: backgroundDark,
    boxShadow: shadowSm,
    transition: "all 0.3s ease",
  },
  searchInput: {
    border: "none",
    outline: "none",
    padding: "0 5px",
    fontSize: "1rem",
    color: textDark,
    width: "300px",
  },

  // Status/Error Messages
  statusMsg: {
    padding: "15px",
    marginBottom: "20px",
    borderRadius: "8px",
    fontWeight: "600",
    backgroundColor: "#d1fae5",
    color: successColor,
    border: `1px solid ${successColor}`,
  },
  errorMsg: {
    padding: "15px",
    marginBottom: "20px",
    borderRadius: "8px",
    fontWeight: "600",
    backgroundColor: "#fee2e2",
    color: dangerColor,
    border: `1px solid ${dangerColor}`,
  },

  // Card Grid Styles
  cardGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fill, minmax(300px, 1fr))",
    gap: "25px",
    marginTop: "20px",
  },
  cardBase: {
    backgroundColor: backgroundDark,
    borderRadius: "12px",
    padding: "20px",
    boxShadow: shadowMd,
    cursor: "pointer",
    display: "flex",
    flexDirection: "column",
    justifyContent: "space-between",
    borderLeft: `5px solid ${primaryColor}`,
  },
  cardTitle: {
    fontSize: "1.1rem",
    fontWeight: "700",
    color: textDark,
    marginBottom: "10px",
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
  },
  cardDescription: {
    fontSize: "0.9rem",
    color: textLight,
    marginBottom: "15px",
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
  },
  cardInfoRow: {
    display: "flex",
    alignItems: "center",
    fontSize: "0.85rem",
    color: textLight,
    marginBottom: "10px",
  },
  boldStatus: {
    color: primaryColor,
    textTransform: "capitalize",
  },

  // Modal Styles
  modalOverlay: {
    position: "fixed",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: "rgba(0, 0, 0, 0.6)",
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    zIndex: 1000,
  },
  modalBase: {
    backgroundColor: backgroundDark,
    borderRadius: "12px",
    padding: "30px",
    width: "90%",
    maxWidth: "500px",
    boxShadow: "0 10px 25px rgba(0, 0, 0, 0.2)",
  },
  modalTitle: {
    fontSize: "1.75rem",
    fontWeight: "700",
    color: textDark,
    marginBottom: "20px",
  },
  modalActions: {
    display: "flex",
    justifyContent: "flex-end",
    gap: "10px",
    marginTop: "20px",
  },
  modalActionsStart: {
    display: "flex",
    justifyContent: "flex-start",
    gap: "10px",
    marginTop: "20px",
    flexWrap: "wrap",
  },
  // Detail Modal specific
  detailModalInfo: {
    border: `1px solid ${borderColor}`,
    padding: "20px",
    borderRadius: "8px",
    backgroundColor: backgroundLight,
  },
  infoBlockP: {
    margin: "5px 0",
    lineHeight: 1.6,
    color: textLight,
  },
  infoBlockStrong: {
    color: textDark,
    fontWeight: "600",
    minWidth: "100px",
    display: "inline-block",
  },
};

const Feedback = () => {
  const [feedbacks, setFeedbacks] = useState([]);
  const [q, setQ] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [formEdit, setFormEdit] = useState(false);
  const [form, setForm] = useState({
    id: "",
    user_id: "",
    message: "",
    isproblem: false,
    reply: "",
    status: STATUS_OPTIONS[0],
  });
  const [selectedFeedback, setSelectedFeedback] = useState(null);
  const [msg, setMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");
  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [feedbackToDelete, setFeedbackToDelete] = useState(null);

  const accesstoken = localStorage.getItem("access_token");

  // Fetch all feedbacks
  const fetchFeedbacks = useCallback(async () => {
    setErrorMsg("");
    if (!accesstoken) {
      setErrorMsg("Authentication/access token missing. Cannot fetch data.");
      return;
    }
    try {
      const res = await axiosInstance.get(`${apiBase}/getfeedback`, {
        headers: { Authorization: `Bearer ${accesstoken}` },
      });
      setFeedbacks(res.data);
      setMsg("");
    } catch (e) {
      setErrorMsg(
        `Could not load feedback: ${e.response?.data?.message || e.message}`
      );
    }
  }, [accesstoken]);

  useEffect(() => {
    fetchFeedbacks();
  }, [fetchFeedbacks]);

  const handleSearch = (e) => setQ(e.target.value);

  // Reset form for edit/reply
  const resetForm = (show = false) => {
    setForm({
      id: "",
      user_id: "",
      message: "",
      isproblem: false,
      reply: "",
      status: STATUS_OPTIONS[0],
    });
    setFormEdit(false);
    setShowForm(show);
    setMsg("");
    setErrorMsg("");
  };

  // Open edit form
  const openEditForm = (fb) => {
    setForm({ ...fb });
    setFormEdit(true);
    setShowForm(true);
    setSelectedFeedback(null);
    setMsg("");
    setErrorMsg("");
  };

  // Open feedback details modal
  const openDetailModal = (fb) => {
    setSelectedFeedback(fb);
    setShowForm(false);
    setMsg("");
    setErrorMsg("");
  };

  // Close feedback details modal
  const closeDetailModal = () => {
    setSelectedFeedback(null);
  };

  // Handle form change
  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    setForm((prev) => ({
      ...prev,
      [name]: type === "checkbox" ? checked : value,
    }));
  };

  // Update feedback (Reply/Status only)
  const handleSubmit = async (e) => {
    e.preventDefault();
    setMsg("");
    setErrorMsg("");
    // Ensure this is only run in edit mode
    if (!formEdit) {
      setErrorMsg("Error: Cannot submit new feedback from this panel.");
      return;
    }
    try {
      // API call to update reply
      await axiosInstance.put(
        `${apiBase}/reply/${form.id}`,
        { reply: form.reply },
        { headers: { Authorization: `Bearer ${accesstoken}` } }
      );
      // API call to update status
      await axiosInstance.put(
        `${apiBase}/status/${form.id}`,
        { status: form.status },
        { headers: { Authorization: `Bearer ${accesstoken}` } }
      );

      setMsg("Feedback updated successfully!");
      fetchFeedbacks();
      resetForm(false);
    } catch (err) {
      setErrorMsg(
        `Failed to save feedback: ${err.response?.data?.message || err.message}`
      );
    }
  };

  // Delete modal handlers
  const handleDeleteClick = (fb) => {
    setFeedbackToDelete(fb);
    setIsConfirmOpen(true);
    setSelectedFeedback(null);
    setMsg("");
    setErrorMsg("");
  };

  const cancelDelete = () => {
    setIsConfirmOpen(false);
    setFeedbackToDelete(null);
  };

  const confirmDelete = async () => {
    setIsConfirmOpen(false);
    if (!feedbackToDelete) return;
    try {
      // You must implement a backend delete endpoint for feedbacks
      await axiosInstance.delete(`${apiBase}/delete/${feedbackToDelete.id}`, {
        headers: { Authorization: `Bearer ${accesstoken}` },
      });
      setFeedbacks((prev) => prev.filter((f) => f.id !== feedbackToDelete.id));
      setMsg(`Feedback ${feedbackToDelete.id} deleted successfully.`);
    } catch (err) {
      setErrorMsg(
        `Delete failed: ${err.response?.data?.message || err.message}`
      );
    } finally {
      setFeedbackToDelete(null);
    }
  };

  // Filter logic
  const filteredFeedbacks = useMemo(() => {
    if (!q) return feedbacks;
    const lowerQ = q.toLowerCase();
    return feedbacks.filter(
      (f) =>
        (f.message || "").toLowerCase().includes(lowerQ) ||
        (f.reply || "").toLowerCase().includes(lowerQ) ||
        (f.status || "").toLowerCase().includes(lowerQ) ||
        (f.user_id || "").toString().includes(lowerQ)
    );
  }, [feedbacks, q]);

  // --- Page/UI ---
  return (
    <div style={styles.directoryBg}>
      {/* INLINE CSS BLOCK FOR ADVANCED STYLES (Animations, Hovers, Media Queries) */}
      <style>
        {`
          /* Variables for consistent color scheme */
          :root {
            --primary-color: ${primaryColor};
            --success-color: ${successColor};
            --danger-color: ${dangerColor};
            --text-dark: ${textDark};
            --border-color: ${borderColor};
            --background-dark: ${backgroundDark};
          }
          
          /* General Styles (using the existing element class names) */
          
          .search-box:focus-within {
            border-color: var(--primary-color);
            box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.2);
          }

          /* Buttons */
          .add-btn {
            background-color: var(--primary-color);
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 1rem;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 8px;
            transition: background-color 0.3s ease, transform 0.1s ease;
            box-shadow: ${shadowSm};
          }
          .add-btn:hover {
            background-color: #4f46e5;
            transform: translateY(-1px);
          }
          
          .delete-btn, .action-btn, .cancel-btn, .confirm-delete-btn, .save-btn {
            padding: 8px 15px;
            border-radius: 6px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.3s ease;
            display: flex;
            align-items: center;
            gap: 5px;
            font-size: 0.9rem;
            border: 1px solid transparent;
          }
          
          .delete-btn { background-color: var(--danger-color); color: white; }
          .delete-btn:hover { background-color: #b91c1c; box-shadow: ${shadowSm}; }

          .action-btn { background-color: var(--primary-color); color: white; }
          .action-btn:hover { background-color: #4f46e5; box-shadow: ${shadowSm}; }

          .cancel-btn { background-color: var(--border-color); color: var(--text-dark); border-color: var(--border-color); }
          .cancel-btn:hover { background-color: #d1d5db; }

          .save-btn { background-color: ${successColor}; color: white; }
          .save-btn:hover { background-color: #047857; }

          .confirm-delete-btn { background-color: var(--danger-color); color: white; }
          .confirm-delete-btn:hover { background-color: #b91c1c; }


          /* Card Grid */
          .subsidy-card {
            transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
          }
          .subsidy-card:hover {
            transform: translateY(-5px) scale(1.02);
            box-shadow: 0 10px 20px rgba(0, 0, 0, 0.15);
          }
          
          /* Form Elements */
          .form-group input:not([type="checkbox"]),
          .form-group textarea,
          .form-group select {
            width: 100%;
            padding: 10px;
            border: 1px solid var(--border-color);
            border-radius: 6px;
            font-size: 1rem;
            color: var(--text-dark);
            background-color: var(--background-dark);
            transition: border-color 0.2s ease;
            box-sizing: border-box;
          }
          .form-group input:focus,
          .form-group textarea:focus,
          .form-group select:focus {
            outline: none;
            border-color: var(--primary-color);
            box-shadow: 0 0 0 1px var(--primary-color);
          }
          .form-group textarea {
            min-height: 100px;
            resize: vertical;
          }
          input[readonly], textarea[readonly] {
            background-color: #f3f4f6;
            cursor: not-allowed;
            opacity: 0.8;
          }

          /* Modal Animations */
          @keyframes slideIn {
            from { opacity: 0; transform: scale(0.9) translateY(20px); }
            to { opacity: 1; transform: scale(1) translateY(0); }
          }
          .modal {
            transform: scale(0.95);
            animation: slideIn 0.3s forwards cubic-bezier(0.175, 0.885, 0.32, 1.275);
          }

          /* Responsive Adjustments */
          @media (max-width: 768px) {
            .header-container {
              flex-direction: column;
              align-items: flex-start;
            }
            .main-title { font-size: 2rem; }
            .controls-group {
              width: 100%;
              flex-direction: column;
              gap: 10px;
            }
            .search-box, .search-box input { width: 100%; }
            /* REMOVED .add-btn WIDE STYLES */
            .subsidy-card-grid { grid-template-columns: 1fr; }
            .modal { padding: 20px; }
            .modal-actions, .modal-actions-start { flex-direction: column; }
            .modal-actions button, .modal-actions-start button { width: 100%; }
          }
        `}
      </style>

      <div className="header-container" style={styles.headerContainer}>
        <div className="main-title" style={styles.mainTitle}>
          User Feedback
        </div>
        <div className="controls-group" style={styles.controlsGroup}>
          <div className="search-box" style={styles.searchBox}>
            <Search size={20} style={{ color: textLight }} />
            <input
              type="text"
              value={q}
              onChange={handleSearch}
              placeholder="Search by message, reply, status or user id..."
              style={styles.searchInput}
            />
          </div>
          {/* REMOVED: "Add Feedback" button */}
        </div>
      </div>

      {msg && (
        <div className="status-msg" style={styles.statusMsg}>
          {msg}
        </div>
      )}
      {errorMsg && (
        <div className="error-msg" style={styles.errorMsg}>
          {errorMsg}
        </div>
      )}

      <div className="subsidy-card-grid" style={styles.cardGrid}>
        {filteredFeedbacks.length === 0 ? (
          <div
            style={{
              textAlign: "center",
              color: textLight,
              padding: "50px 0",
              gridColumn: "1/-1",
            }}
          >
            No feedback found matching search or the list is empty.
          </div>
        ) : (
          filteredFeedbacks.map((f) => (
            <div
              className="subsidy-card"
              key={f.id}
              onClick={() => openDetailModal(f)}
              style={styles.cardBase}
            >
              <div className="card-title" style={styles.cardTitle}>
                {f.message}
              </div>
              <div className="card-description" style={styles.cardDescription}>
                {f.reply ? (
                  <>Response: {f.reply}</>
                ) : (
                  <span style={{ color: dangerColor }}>No reply yet</span>
                )}
              </div>
              <div className="card-info-row" style={styles.cardInfoRow}>
                <MessageCircle
                  style={{ marginRight: 6, color: primaryColor }}
                  size={16}
                />
                User: {f.user_id}
                <CheckCircle
                  style={{
                    marginLeft: 12,
                    marginRight: 6,
                    color: successColor,
                  }}
                  size={16}
                />
                Status: <b style={styles.boldStatus}>{f.status}</b>
              </div>
              <button
                className="delete-btn"
                onClick={(e) => {
                  e.stopPropagation();
                  handleDeleteClick(f);
                }}
              >
                <Trash2 size={16} /> Delete
              </button>
            </div>
          ))
        )}
      </div>

      {/* Detail Modal */}
      {selectedFeedback && (
        <div
          className="modal-overlay"
          style={styles.modalOverlay}
          onClick={closeDetailModal}
        >
          <div
            className="modal detail-modal"
            style={{ ...styles.modalBase, maxWidth: "600px" }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="modal-title" style={styles.modalTitle}>
              {selectedFeedback.message}
            </div>
            <div className="detail-modal-info" style={styles.detailModalInfo}>
              <div className="info-block">
                <p style={styles.infoBlockP}>
                  <strong style={styles.infoBlockStrong}>ID:</strong>{" "}
                  {selectedFeedback.id}
                </p>
                <p style={styles.infoBlockP}>
                  <strong style={styles.infoBlockStrong}>User:</strong>{" "}
                  {selectedFeedback.user_id}
                </p>
                <p style={styles.infoBlockP}>
                  <strong style={styles.infoBlockStrong}>Problem:</strong>{" "}
                  {selectedFeedback.isproblem ? "Yes" : "No"}
                </p>
                <p style={styles.infoBlockP}>
                  <strong style={styles.infoBlockStrong}>Status:</strong>{" "}
                  {selectedFeedback.status}
                </p>
                <p style={styles.infoBlockP}>
                  <strong style={styles.infoBlockStrong}>Response:</strong>{" "}
                  {selectedFeedback.reply ? (
                    selectedFeedback.reply
                  ) : (
                    <span style={{ color: dangerColor }}>No reply yet</span>
                  )}
                </p>
              </div>
            </div>
            <div
              className="modal-actions modal-actions-start"
              style={styles.modalActionsStart}
            >
              <button
                className="delete-btn"
                onClick={() => handleDeleteClick(selectedFeedback)}
              >
                <Trash2 size={16} /> Delete
              </button>
              <button
                className="action-btn"
                onClick={() => openEditForm(selectedFeedback)}
              >
                <Edit size={16} /> Edit / Reply
              </button>
              <button className="cancel-btn" onClick={closeDetailModal}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Edit/Reply Feedback Modal */}
      {showForm && (
        <div className="modal-overlay" style={styles.modalOverlay}>
          <div className="modal" style={styles.modalBase}>
            <div className="modal-title" style={styles.modalTitle}>
              Edit/Reply Feedback
            </div>
            <form onSubmit={handleSubmit} autoComplete="off">
              <div className="form-group">
                <label>User ID</label>
                <input
                  name="user_id"
                  value={form.user_id}
                  onChange={handleChange}
                  readOnly // Always read-only now
                  placeholder="User ID"
                />
              </div>
              <div className="form-group">
                <label>Feedback Message</label>
                <textarea
                  name="message"
                  value={form.message}
                  onChange={handleChange}
                  readOnly // Always read-only now
                  placeholder="Feedback Message"
                />
              </div>
              <div className="form-group">
                <label>
                  <input
                    type="checkbox"
                    name="isproblem"
                    checked={form.isproblem}
                    onChange={handleChange}
                    disabled // Should always be disabled on an admin review form
                  />{" "}
                  This is a problem report?
                </label>
              </div>
              {/* Only show reply/status fields when editing */}
              <>
                <div className="form-group">
                  <label>Reply/Response</label>
                  <textarea
                    name="reply"
                    value={form.reply}
                    onChange={handleChange}
                    required
                    placeholder="Admin response"
                  />
                </div>
                <div className="form-group">
                  <label>Status</label>
                  <select
                    name="status"
                    value={form.status}
                    onChange={handleChange}
                    required
                  >
                    {STATUS_OPTIONS.map((s) => (
                      <option value={s} key={s}>
                        {s}
                      </option>
                    ))}
                  </select>
                </div>
              </>
              <div className="modal-actions" style={styles.modalActions}>
                <button
                  className="cancel-btn"
                  type="button"
                  onClick={() => resetForm(false)}
                >
                  Cancel
                </button>
                <button className="save-btn" type="submit">
                  Update Feedback
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {isConfirmOpen && feedbackToDelete && (
        <div className="delete-modal-overlay" style={styles.modalOverlay}>
          <div
            className="modal delete-modal-content"
            style={{ ...styles.modalBase, maxWidth: "400px" }}
          >
            <h3>Confirm Deletion</h3>
            <p>
              Are you sure you want to delete feedback{" "}
              <strong>{feedbackToDelete.id}</strong>? This action cannot be
              undone.
            </p>
            <div className="modal-actions" style={styles.modalActions}>
              <button className="cancel-btn" onClick={cancelDelete}>
                Cancel
              </button>
              <button className="confirm-delete-btn" onClick={confirmDelete}>
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Feedback;
