import React, { useEffect, useState, useCallback, useMemo } from "react";
import axios from "axios";
import { Search, Plus, Trash2, Edit, ExternalLink, MapPin } from "lucide-react";

// NOTE: This constant is assumed to be defined externally, keeping it here for context.
import { SERVER_IP } from "../constant";

const apiBase = `http://${SERVER_IP}:5000/api/subsidies`;

// --- State mapping logic is now handled by the backend's JOIN query ---

const Subsidies = () => {
  const [subsidies, setSubsidies] = useState([]);
  const [q, setQ] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [selectedSubsidy, setSelectedSubsidy] = useState(null);
  // Note: The subsidy object fetched from the backend now includes 'name' (state name)
  const [form, setForm] = useState({
    id: "",
    title: "",
    description: "",
    state_id: "",
    link: "",
  });
  const [formEdit, setFormEdit] = useState(false);
  const [msg, setMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");
  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [subsidyToDelete, setSubsidyToDelete] = useState(null);

  // NOTE: stateMap and state fetching simulation are removed
  // as the state name is now included in the main subsidy data fetch.

  const token = localStorage.getItem("token");

  // Fetch all subsidies from the backend
  // The backend now returns state name under the 'name' field for each subsidy.
  const fetchSubs = useCallback(async () => {
    setErrorMsg("");
    if (!token) {
      setErrorMsg("Authentication token missing. Cannot fetch data.");
      return;
    }
    try {
      const res = await axios.get(apiBase + "/getSubsidy", {
        headers: { Authorization: `Bearer ${token}` },
      });
      // The data structure here is assumed to be [{..., state_id: "X", name: "State Name"}, ...]
      setSubsidies(res.data || []);
      setMsg(""); // Clear status message after successful fetch
    } catch (e) {
      setErrorMsg(
        "Could not load subsidies: " + (e.response?.data?.message || e.message)
      );
    }
  }, [token]);

  useEffect(() => {
    fetchSubs();
  }, [fetchSubs]);

  const handleSearch = (e) => setQ(e.target.value);

  const resetForm = (show = false) => {
    setForm({ id: "", title: "", description: "", state_id: "", link: "" });
    setFormEdit(false);
    setShowForm(show);
    setMsg("");
    setErrorMsg("");
  };

  const openAddForm = () => {
    setSelectedSubsidy(null); // Close detail view if open
    resetForm(true);
  };

  const openEditForm = (sub) => {
    // Note: 'sub' now includes 'name' property from the backend
    setForm({ ...sub });
    setFormEdit(true);
    setShowForm(true);
    setSelectedSubsidy(null); // Close detail view when opening edit form
    setMsg("");
    setErrorMsg("");
  };

  const openDetailModal = (sub) => {
    setSelectedSubsidy(sub);
    setShowForm(false); // Ensure form is closed
    setMsg("");
    setErrorMsg("");
  };

  const closeDetailModal = () => setSelectedSubsidy(null);

  const handleChange = (e) =>
    setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = async (e) => {
    e.preventDefault();
    setMsg("");
    setErrorMsg("");

    try {
      const dataToSend = {
        id: form.id,
        title: form.title,
        description: form.description,
        state_id: form.state_id,
        link: form.link,
      };

      if (formEdit) {
        // Update existing subsidy
        await axios.put(apiBase + `/putSubsidy/${form.id}`, dataToSend, {
          headers: { Authorization: `Bearer ${token}` },
        });
        setMsg("Subsidy updated successfully!");
      } else {
        // Add new subsidy
        await axios.post(apiBase + "/postSubsidy", dataToSend, {
          headers: { Authorization: `Bearer ${token}` },
        });
        setMsg("Subsidy added successfully!");
      }
      fetchSubs();
      resetForm(false);
    } catch (err) {
      setErrorMsg(
        "Failed to save subsidy: " +
          (err.response?.data?.message || err.message)
      );
    }
  };

  // --- Delete Modal Handlers ---

  const handleDeleteClick = (subsidy) => {
    setSubsidyToDelete(subsidy);
    setIsConfirmOpen(true);
    setSelectedSubsidy(null); // Close detail modal when confirming delete
    setMsg("");
    setErrorMsg("");
  };

  const cancelDelete = () => {
    setIsConfirmOpen(false);
    setSubsidyToDelete(null);
  };

  const confirmDelete = async () => {
    setIsConfirmOpen(false);
    if (!subsidyToDelete) return;

    try {
      await axios.delete(apiBase + `/deleteSubsidy/${subsidyToDelete.id}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      // Optimistically update the list
      setSubsidies((prevSubs) =>
        prevSubs.filter((s) => s.id !== subsidyToDelete.id)
      );
      setMsg(`Subsidy "${subsidyToDelete.title}" deleted successfully.`);
    } catch (err) {
      setErrorMsg(
        "Delete failed: " + (err.response?.data?.message || err.message)
      );
    } finally {
      setSubsidyToDelete(null);
    }
  };

  // --- Filtering Logic ---

  const filteredSubs = useMemo(() => {
    if (!q) return subsidies;
    const lowerCaseQ = q.toLowerCase();

    return subsidies.filter(
      (s) =>
        String(s.title ?? "")
          .toLowerCase()
          .includes(lowerCaseQ) ||
        String(s.description ?? "")
          .toLowerCase()
          .includes(lowerCaseQ) ||
        // Search by State ID
        String(s.state_id ?? "")
          .toLowerCase()
          .includes(lowerCaseQ) ||
        // Search by State Name (now 'name' property)
        String(s.state_name ?? "")
          .toLowerCase()
          .includes(lowerCaseQ)
    );
  }, [subsidies, q]); // Removed getStateName from dependency array as it's gone

  // --- Styles ---

  const directoryStyles = `
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap');
    
    .directory-bg {
      font-family: 'Inter', sans-serif;
      padding: 30px;
      background: #f8f9fa; /* Light background */
      min-height: 100vh;
    }

    /* Header & Controls */
    .header-container {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 30px;
    }
    .main-title {
      font-size: 2.2rem;
      font-weight: 800;
      color: #1a202c;
    }

    .controls-group {
      display: flex;
      gap: 15px;
      align-items: center;
    }
    .search-box {
      position: relative;
    }
    .search-box input {
      width: 300px;
      padding: 10px 15px 10px 40px;
      border: 1px solid #e2e8f0;
      border-radius: 20px;
      font-size: 1rem;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
      transition: border-color 0.2s;
    }
    .search-box input:focus {
      border-color: #4f46e5;
      outline: none;
    }
    .search-box svg {
      position: absolute;
      left: 12px;
      top: 50%;
      transform: translateY(-50%);
      color: #6b7280;
      width: 20px;
      height: 20px;
    }
    
    .add-btn {
      background: #4f46e5;
      color: #fff;
      border: none;
      border-radius: 20px;
      padding: 10px 20px;
      cursor: pointer;
      font-size: 1rem;
      font-weight: 600;
      transition: background 0.2s, transform 0.1s;
      box-shadow: 0 4px 8px rgba(79, 70, 229, 0.3);
      display: flex;
      align-items: center;
    }
    .add-btn:hover {
      background: #4338ca;
      transform: translateY(-1px);
    }
    .add-btn svg {
      margin-right: 5px;
      width: 20px;
      height: 20px;
    }

    /* Status Messages */
    .status-msg, .error-msg {
      padding: 12px;
      margin-bottom: 20px;
      border-radius: 8px;
      font-weight: 500;
    }
    .status-msg {
      color: #059669;
      background-color: #d1fae5;
      border: 1px solid #a7f3d0;
    }
    .error-msg {
      color: #ef4444;
      background-color: #fee2e2;
      border: 1px solid #fecaca;
    }

    /* Card Grid */
    .subsidy-card-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 30px;
    }

    /* Single Card */
    .subsidy-card {
      background: #fff;
      border-radius: 16px;
      padding: 25px;
      box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
      border-left: 5px solid #4f46e5; /* Primary color border */
      transition: transform 0.2s ease, box-shadow 0.2s ease;
      cursor: pointer; 
    }
    .subsidy-card:hover {
      transform: translateY(-3px);
      box-shadow: 0 15px 20px -5px rgba(0, 0, 0, 0.1), 0 6px 10px -3px rgba(0, 0, 0, 0.05);
    }

    .card-title {
      font-size: 1.1rem;
      font-weight: 700;
      color: #1a202c;
      margin-bottom: 10px;
    }
    
    /* Description truncation style */
    .card-description {
      font-size: 0.95rem;
      color: #4a5568;
      line-height: 1.5;
      margin-bottom: 15px;
      overflow: hidden;
      display: -webkit-box;
      -webkit-line-clamp: 2; /* Limit to 2 lines */
      -webkit-box-orient: vertical;
    }
    
    .card-info-row {
      display: flex;
      align-items: center;
      font-size: 0.9rem;
      color: #6b7280;
      margin-top: 5px;
      font-weight: 600;
    }
    .card-info-row svg {
      margin-right: 8px;
      width: 16px;
      height: 16px;
      color: #10b981; 
    }
    
    /* Form & Detail Modals */
    .modal-overlay, .delete-modal-overlay {
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      background: rgba(0, 0, 0, 0.5);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
      backdrop-filter: blur(4px);
    }
    .modal {
      background: #fff;
      padding: 30px;
      border-radius: 12px;
      box-shadow: 0 5px 25px rgba(0,0,0,0.4);
      max-width: 600px;
      width: 90%;
      animation: fadeIn 0.3s;
      position: relative;
    }
    
    /* Detail Modal Specifics */
    .detail-modal .modal-title {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 10px;
    }
    .detail-modal-info p {
      margin-bottom: 15px;
      line-height: 1.6;
      color: #333;
    }
    .detail-modal-info strong {
      color: #1a202c;
      font-weight: 700;
      margin-right: 5px;
    }
    .detail-modal-info .info-block {
      background: #f0f4ff;
      border-radius: 8px;
      padding: 15px;
      margin-bottom: 20px;
    }
    
    /* Modal Buttons (reused) */
    .modal-title {
      font-size: 1.5rem;
      font-weight: 700;
      color: #1a202c;
      margin-bottom: 20px;
    }
    .form-group {
      margin-bottom: 15px;
    }
    .form-group label {
      display: block;
      font-size: 0.9rem;
      font-weight: 500;
      color: #4a5568;
      margin-bottom: 5px;
    }
    .modal input, .modal textarea {
      width: 100%;
      padding: 10px 12px;
      border: 1px solid #cbd5e1;
      border-radius: 8px;
      font-size: 1rem;
      box-sizing: border-box;
      resize: vertical;
    }
    .modal-actions {
      display: flex;
      justify-content: flex-end;
      gap: 10px;
      margin-top: 20px;
    }
    .modal-actions-start {
      justify-content: space-between;
    }
    .save-btn, .action-btn {
      background: #4f46e5;
      color: #fff;
      border: none;
      padding: 10px 20px;
      border-radius: 8px;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s;
    }
    .cancel-btn {
      background: #e2e8f0;
      color: #1a202c;
      border: none;
      padding: 10px 20px;
      border-radius: 8px;
      font-weight: 600;
      cursor: pointer;
    }
    .save-btn:hover, .action-btn:hover { background: #4338ca; }
    
    .delete-btn {
      background: #fee2e2;
      color: #ef4444;
      padding: 10px 20px;
      border-radius: 8px;
      font-weight: 600;
      cursor: pointer;
      border: none;
      transition: background 0.2s;
    }
    .delete-btn:hover {
      background: #fecaca;
    }
    
    .read-only-input {
      background-color: #f3f4f6;
      cursor: not-allowed;
    }

    /* Delete Modal Specifics */
    .delete-modal-content h3 {
      font-size: 1.5rem;
      color: #ef4444;
      margin-top: 0;
      margin-bottom: 15px;
      font-weight: 700;
    }
    .delete-modal-content p {
      margin-bottom: 25px;
      font-size: 1rem;
      color: #4a5568;
    }
    .confirm-delete-btn {
      background: #ef4444;
      color: #fff;
      border: none;
      padding: 10px 15px;
      border-radius: 8px;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s;
    }
    .confirm-delete-btn:hover {
      background: #dc2626;
    }

    /* Media Queries for Responsiveness */
    @media (max-width: 768px) {
      .directory-bg { 
        padding: 15px; 
      }
      .header-container { flex-direction: column; align-items: flex-start; gap: 15px; }
      .controls-group { width: 100%; justify-content: space-between; gap: 10px; }
      .search-box input { width: 100%; max-width: none; }
      .main-title { font-size: 1.8rem; }
      .add-btn { flex: 1; justify-content: center; }
      .subsidy-card-grid { grid-template-columns: 1fr; }
      .modal { max-width: 95%; }
    }
  `;

  // --- Detail Modal Component ---
  // Updated to receive and use 'subsidy.name' directly
  const DetailModal = ({ subsidy, onClose, onEdit, onDelete }) => (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal detail-modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-title">{subsidy.title}</div>

        <div className="detail-modal-info">
          <div className="info-block">
            <p>
              <strong>Description:</strong> {subsidy.description}
            </p>
          </div>

          <p>
            <strong>Subsidy ID:</strong> {subsidy.id}
          </p>

          {/* Display State Name using the 'name' field from the subsidy object */}
          <p>
            <strong>State:</strong> {subsidy.state_name || "N/A"}
            <span
              style={{
                fontSize: "0.85em",
                color: "#6b7280",
                marginLeft: "8px",
              }}
            >
              (ID: {subsidy.state_id})
            </span>
          </p>

          {subsidy.link && (
            <p className="card-link">
              <strong>Official Link:</strong>
              <a
                href={subsidy.link}
                target="_blank"
                rel="noopener noreferrer"
                style={{ marginLeft: "5px" }}
              >
                {subsidy.link} <ExternalLink size={14} />
              </a>
            </p>
          )}
        </div>

        <div className="modal-actions modal-actions-start">
          <div>
            <button className="delete-btn" onClick={() => onDelete(subsidy)}>
              <Trash2 size={16} /> Delete
            </button>
          </div>
          <div>
            <button
              className="action-btn"
              onClick={() => onEdit(subsidy)}
              style={{ marginRight: "10px" }}
            >
              <Edit size={16} /> Edit
            </button>
            <button className="cancel-btn" onClick={onClose}>
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <div className="directory-bg">
      <style>{directoryStyles}</style>

      {/* Header with Search and Add Button */}
      <div className="header-container">
        <div className="main-title">Subsidy Programs</div>
        <div className="controls-group">
          <div className="search-box">
            <Search />
            <input
              type="text"
              value={q}
              onChange={handleSearch}
              placeholder="Search by title, state, or description..."
            />
          </div>
          <button className="add-btn" onClick={openAddForm}>
            <Plus size={20} /> Add Subsidy
          </button>
        </div>
      </div>

      {/* Status Messages */}
      {msg && <div className="status-msg">{msg}</div>}
      {errorMsg && <div className="error-msg">{errorMsg}</div>}

      {/* Subsidy Card Grid */}
      <div className="subsidy-card-grid">
        {filteredSubs.length === 0 && (
          <div
            style={{
              textAlign: "center",
              color: "#6b7280",
              padding: "50px 0",
              gridColumn: "1 / -1",
            }}
          >
            No subsidies found matching "{q}" or the list is empty.
          </div>
        )}
        {filteredSubs.map((s) => (
          <div
            className="subsidy-card"
            key={s.id}
            onClick={() => openDetailModal(s)}
          >
            <div className="card-title">{s.title}</div>

            {/* Truncated description */}
            <div className="card-description">{s.description}</div>

            {/* START: Display State Name (now included in subsidy object) */}
            <div
              className="card-info-row"
              style={{
                marginTop: "10px",
                borderTop: "1px solid #f1f5f9",
                paddingTop: "10px",
              }}
            >
              <MapPin style={{ color: "#ef4444" }} />
              <span style={{ fontWeight: 700, color: "#1a202c" }}>State:</span>
              <span style={{ marginLeft: "5px", color: "#4f46e5" }}>
                {s.state_name || "N/A"}
              </span>
            </div>
            {/* END: State Name Display */}
          </div>
        ))}
      </div>

      {/* Detail Modal */}
      {selectedSubsidy && (
        <DetailModal
          subsidy={selectedSubsidy}
          onClose={closeDetailModal}
          onEdit={openEditForm}
          onDelete={handleDeleteClick}
          // Removed getStateName prop
        />
      )}

      {/* Add/Edit Subsidy Modal */}
      {showForm && (
        <div className="modal-overlay">
          <div className="modal">
            <div className="modal-title">
              {formEdit ? "Edit Subsidy" : "Add New Subsidy"}
            </div>
            <form onSubmit={handleSubmit} autoComplete="off">
              {/* ID Input Field - Required, Read-Only if editing */}
              <div className="form-group">
                <label>ID</label>
                <input
                  name="id"
                  value={form.id}
                  onChange={handleChange}
                  required
                  readOnly={formEdit} // Read-only if editing
                  placeholder={formEdit ? "Read-Only ID" : "Enter Unique ID"}
                  className={formEdit ? "read-only-input" : ""}
                />
                {formEdit && (
                  <small
                    style={{
                      color: "#6b7280",
                      display: "block",
                      marginTop: "5px",
                    }}
                  >
                    ID is read-only when editing.
                  </small>
                )}
              </div>

              <div className="form-group">
                <label>Title</label>
                <input
                  name="title"
                  value={form.title}
                  onChange={handleChange}
                  required
                />
              </div>
              <div className="form-group">
                <label>Description</label>
                <textarea
                  name="description"
                  value={form.description}
                  onChange={handleChange}
                  required
                />
              </div>
              <div className="form-group">
                <label>State ID</label>
                <input
                  name="state_id"
                  value={form.state_id}
                  onChange={handleChange}
                  required
                  placeholder="Enter State ID (e.g., 1)"
                />
                {/* When editing, show the current state name for reference */}
                {formEdit && form.name && (
                  <small
                    style={{
                      color: "#6b7280",
                      display: "block",
                      marginTop: "5px",
                    }}
                  >
                    Current State: {form.name}
                  </small>
                )}
              </div>

              <div className="form-group">
                <label>Link (URL)</label>
                <input
                  name="link"
                  type="url"
                  value={form.link}
                  onChange={handleChange}
                  placeholder="e.g., https://example.com/details"
                />
              </div>
              <div className="modal-actions">
                <button
                  className="cancel-btn"
                  type="button"
                  onClick={() => resetForm(false)}
                >
                  Cancel
                </button>
                <button className="save-btn" type="submit">
                  {formEdit ? "Update Subsidy" : "Save Subsidy"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {isConfirmOpen && subsidyToDelete && (
        <div className="delete-modal-overlay">
          <div className="modal delete-modal-content">
            <h3>Confirm Deletion</h3>
            <p>
              Are you sure you want to delete the subsidy program:
              <strong> {subsidyToDelete.title}</strong>? This action cannot be
              undone.
            </p>
            <div className="modal-actions">
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

export default Subsidies;
