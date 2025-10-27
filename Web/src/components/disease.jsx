import React, { useEffect, useState, useCallback, useMemo } from "react";
import axios from "axios";
import {
  Search,
  Plus,
  Trash2,
  Edit,
  MapPin,
  Link,
  X,
  CornerDownRight,
  CheckCircle,
  AlertTriangle,
} from "lucide-react";
import { SERVER_IP } from "../constant";

// --- CSS String ---
// WARNING: Embedding a large block of CSS like this is generally discouraged
// in production React apps. It's done here only for the single-file requirement.
const componentStyles = `
/* --- Global Styles & Layout --- */

:root {
    --primary: #4CAF50; /* Green */
    --secondary: #1976D2; /* Blue */
    --tertiary: #607D8B; /* Grey-Blue */
    --danger: #D32F2F; /* Red */
    --background: #F4F6F8;
    --surface: #FFFFFF;
    --text-color: #333333;
    --border-color: #E0E0E0;
    --shadow-light: 0 2px 4px rgba(0, 0, 0, 0.05);
    --shadow-mid: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.app-container {
    padding: 30px;
    background-color: var(--background);
    min-height: 100vh;
}

/* --- Header and Controls --- */

.header-container {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 30px;
    flex-wrap: wrap;
    gap: 15px;
}

.main-title {
    font-size: 2em;
    font-weight: 600;
    color: var(--text-color);
}

.controls-group {
    display: flex;
    gap: 10px;
    align-items: center;
}

.search-box {
    display: flex;
    align-items: center;
    background: var(--surface);
    border: 1px solid var(--border-color);
    border-radius: 8px;
    padding: 8px 15px;
    box-shadow: var(--shadow-light);
}

.search-input {
    border: none;
    outline: none;
    padding: 0;
    font-size: 1em;
    width: 250px;
}

.search-icon {
    color: var(--tertiary);
    margin-left: 10px;
}

/* --- Buttons --- */

.btn {
    display: flex;
    align-items: center;
    padding: 10px 18px;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-weight: 500;
    transition: all 0.2s ease-in-out;
    gap: 5px;
}

.primary-btn {
    background-color: var(--primary);
    color: var(--surface);
}

.primary-btn:hover {
    background-color: #388E3C; /* Darker Green */
}

.secondary-btn {
    background-color: var(--secondary);
    color: var(--surface);
}

.secondary-btn:hover {
    background-color: #1565C0; /* Darker Blue */
}

.tertiary-btn {
    background-color: transparent;
    color: var(--tertiary);
    border: 1px solid var(--border-color);
}

.tertiary-btn:hover {
    background-color: #F0F0F0;
}

.delete-btn {
    background-color: var(--danger);
    color: var(--surface);
}

.delete-btn:hover {
    background-color: #C62828; /* Darker Red */
}

.icon-btn {
    padding: 8px;
    border-radius: 4px;
    background-color: transparent;
    color: var(--tertiary);
}

.icon-btn.edit-btn:hover {
    color: var(--secondary);
    background-color: #E3F2FD;
}

.icon-btn.delete-btn {
    color: var(--danger);
}

.icon-btn.delete-btn:hover {
    background-color: #FFEBEE;
}

.small-btn {
    padding: 6px 12px;
    font-size: 0.9em;
}

.unmap-btn {
    padding: 6px 10px;
    font-size: 0.9em;
    background-color: #FFC107; /* Amber */
    color: var(--text-color);
}
.unmap-btn:hover {
    background-color: #FFB300;
}

/* --- Status Messages --- */

.status-msg {
    display: flex;
    align-items: center;
    padding: 12px 20px;
    margin-bottom: 20px;
    border-radius: 8px;
    font-weight: 500;
    box-shadow: var(--shadow-light);
}

.status-msg.success {
    background-color: #E8F5E9; /* Light Green */
    color: #2E7D32; /* Dark Green */
    border: 1px solid #C8E6C9;
}

.status-msg.error {
    background-color: #FFEBEE; /* Light Red */
    color: #C62828; /* Dark Red */
    border: 1px solid #FFCDD2;
}

/* --- Card Grid (Main Content) --- */

.card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 20px;
}

.no-data-message {
    grid-column: 1 / -1;
    text-align: center;
    padding: 40px;
    font-size: 1.1em;
    color: var(--tertiary);
    background-color: var(--surface);
    border-radius: 8px;
}

.data-card {
    background-color: var(--surface);
    border-radius: 10px;
    padding: 20px;
    box-shadow: var(--shadow-mid);
    transition: transform 0.2s, box-shadow 0.2s;
    cursor: pointer;
    border-left: 5px solid var(--primary);
}

.data-card:hover {
    transform: translateY(-5px);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.15);
}

.card-title {
    font-size: 1.3em;
    font-weight: 600;
    color: var(--secondary);
    margin-bottom: 5px;
}

.card-description {
    font-size: 0.95em;
    color: var(--text-color);
    margin-bottom: 15px;
}

.card-info-row {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--tertiary);
    font-size: 0.9em;
}

.card-actions {
    margin-top: 15px;
    display: flex;
    justify-content: flex-end;
    gap: 10px;
}

/* Severity Indicators */
.severity-low { color: #4CAF50; font-weight: 600; }
.severity-medium { color: #FF9800; font-weight: 600; }
.severity-high { color: #D32F2F; font-weight: 600; }

/* --- Modals (General) --- */

.modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.6);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 1000;
}

.modal-dialog {
    background: var(--surface);
    border-radius: 12px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
    padding: 25px;
    max-width: 90%;
    max-height: 90vh;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
}

.small-modal {
    width: 400px;
}

.detail-modal {
    width: 650px;
}

.form-modal {
    width: 500px;
}

.large-modal {
    width: 800px;
    max-height: 80vh;
}

.modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: 15px;
    border-bottom: 1px solid var(--border-color);
    margin-bottom: 20px;
}

.modal-title {
    font-size: 1.5em;
    font-weight: 600;
    color: var(--secondary);
}

.close-btn {
    background: transparent;
    border: none;
    color: var(--tertiary);
    cursor: pointer;
    transition: color 0.2s;
}

.close-btn:hover {
    color: var(--danger);
}

.modal-body {
    flex-grow: 1;
    padding-right: 5px; /* Space for scrollbar */
}

.modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    padding-top: 20px;
    margin-top: 20px;
    border-top: 1px solid var(--border-color);
}

/* --- Form Styles --- */

.form-layout {
    display: flex;
    flex-direction: column;
    gap: 15px;
}

.form-group {
    display: flex;
    flex-direction: column;
}

.form-group label {
    font-weight: 500;
    color: var(--text-color);
    margin-bottom: 5px;
}

.form-group input,
.form-group select,
.select-input {
    padding: 10px 12px;
    border: 1px solid var(--border-color);
    border-radius: 6px;
    font-size: 1em;
    transition: border-color 0.2s;
}

.form-group input:focus,
.form-group select:focus,
.select-input:focus {
    border-color: var(--primary);
    outline: none;
    box-shadow: 0 0 0 2px rgba(76, 175, 80, 0.2);
}

.form-actions {
    margin-top: 10px;
    display: flex;
    gap: 10px;
}

/* --- Detail Modal Specific --- */

.detail-info-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 15px;
    margin-bottom: 25px;
    padding-bottom: 15px;
    border-bottom: 1px dashed var(--border-color);
}

.info-block strong {
    color: var(--secondary);
    display: block;
    margin-bottom: 4px;
}

.remedies-section h3 {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--text-color);
    margin-bottom: 15px;
    border-bottom: 2px solid var(--border-color);
    padding-bottom: 5px;
}

.remedy-list-mapped {
    list-style: none;
    padding: 0;
    margin-bottom: 20px;
}

.remedy-item-mapped {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: 12px;
    margin-bottom: 8px;
    background-color: #F8F9FA;
    border-radius: 6px;
    border-left: 4px solid var(--secondary);
}

.remedy-content {
    flex-grow: 1;
    padding-right: 15px;
}

.remedy-title {
    display: flex;
    align-items: center;
    font-size: 1.1em;
    color: var(--secondary);
}

.remedy-prevention {
    margin-top: 5px;
    font-size: 0.9em;
    color: var(--tertiary);
    margin-left: 24px; /* Align with title text */
}

.no-remedy-msg {
    color: var(--tertiary);
    font-style: italic;
    padding: 10px;
    text-align: center;
    background-color: #F0F0F0;
    border-radius: 6px;
}

/* --- Remedy Management Modal Specific --- */

.remedy-form-container {
    padding: 20px;
    border: 1px solid var(--border-color);
    border-radius: 8px;
    margin-bottom: 25px;
}

.remedy-form-container h3 {
    color: var(--primary);
    margin-top: 0;
    margin-bottom: 20px;
}

.remedy-list-container {
    max-height: 300px;
    overflow-y: auto;
    padding-right: 15px;
}

.remedy-list-container h3 {
    color: var(--text-color);
    margin-bottom: 15px;
}

.remedy-list-scrollable {
    list-style: none;
    padding: 0;
}

.remedy-list-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 0;
    border-bottom: 1px dashed var(--border-color);
}

.remedy-list-item:last-child {
    border-bottom: none;
}

.remedy-info {
    flex-grow: 1;
    display: flex;
    flex-direction: column;
}

.remedy-info strong {
    font-size: 1em;
    color: var(--text-color);
}

.remedy-desc {
    font-size: 0.85em;
    color: var(--tertiary);
    margin-top: 2px;
}

.item-actions {
    display: flex;
    gap: 8px;
}

/* --- Responsive Adjustments --- */
@media (max-width: 768px) {
    .header-container {
        flex-direction: column;
        align-items: flex-start;
    }

    .controls-group {
        flex-direction: column;
        align-items: stretch;
        width: 100%;
    }

    .search-box {
        width: 100%;
    }
    .search-input {
        width: 100%;
    }
    .btn {
        width: 100%;
        justify-content: center;
    }
    .modal-dialog {
        width: 95%;
        margin: 20px auto;
        padding: 20px;
    }

    .detail-info-grid {
        grid-template-columns: 1fr;
    }
    .modal-footer {
        flex-direction: column;
    }
}
`;
// --- End CSS String ---

// API endpoints
const apiBase = `http://${SERVER_IP}:5000/api/diseaseRemedies`;
const plantApiBase = `http://${SERVER_IP}:5000/api/farmcrop`;

// Utility component for status messages
const StatusMessage = ({ msg, type }) => {
  if (!msg) return null;
  const Icon = type === "error" ? AlertTriangle : CheckCircle;
  const className =
    type === "error" ? "status-msg error" : "status-msg success";
  return (
    <div className={className}>
      <Icon size={20} style={{ marginRight: "8px" }} />
      <span>{msg}</span>
    </div>
  );
};

const Disease = () => {
  // State variables for data
  const [diseases, setDiseases] = useState([]);
  const [plants, setPlants] = useState([]);
  const [remedies, setRemedies] = useState([]);

  // UI state
  const [q, setQ] = useState("");
  const [msg, setMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");

  // Disease Management state
  const [showDiseaseForm, setShowDiseaseForm] = useState(false);
  const [form, setForm] = useState({
    disease_id: "",
    name: "",
    severity: "",
    plant_id: "",
  });
  const [formEdit, setFormEdit] = useState(false);
  const [selectedDisease, setSelectedDisease] = useState(null);
  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [diseaseToDelete, setDiseaseToDelete] = useState(null);

  // Remedy Management state
  const [showRemedyForm, setShowRemedyForm] = useState(false); // Used for Remedy Add/Edit/List modal
  const [remedyForm, setRemedyForm] = useState({
    remedy_id: "",
    remedy: "",
    prevention: "",
  });
  const [remedyEdit, setRemedyEdit] = useState(false);
  const [remedyToDelete, setRemedyToDelete] = useState(null);

  // Mapping state
  const [mappingRemedyId, setMappingRemedyId] = useState("");
  const [isMappingDialogOpen, setIsMappingDialogOpen] = useState(false);
  const [mappedRemedies, setMappedRemedies] = useState([]);

  // Auth token
  const access_token = localStorage.getItem("access_token");

  // --- Utility Functions ---
  const resetMessages = () => {
    setMsg("");
    setErrorMsg("");
  };

  // --- CRUD Fetch Hooks ---
  const fetchDiseases = useCallback(async () => {
    resetMessages();
    try {
      const res = await axios.get(`${apiBase}/diseases`, {
        headers: { Authorization: `Bearer ${access_token}` },
      });
      setDiseases(res.data || []);
    } catch (e) {
      setErrorMsg(
        "Could not load diseases: " + (e.response?.data?.message || e.message)
      );
    }
  }, [access_token]);

  const fetchPlants = useCallback(async () => {
    try {
      const res = await axios.get(`${plantApiBase}/masters/plants`, {
        headers: { Authorization: `Bearer ${access_token}` },
      });
      setPlants(res.data || []);
    } catch {
      setPlants([]);
    }
  }, [access_token]);

  const fetchRemedies = useCallback(async () => {
    try {
      const res = await axios.get(`${apiBase}/remedies`, {
        headers: { Authorization: `Bearer ${access_token}` },
      });
      setRemedies(res.data || []);
    } catch {
      setRemedies([]);
    }
  }, [access_token]);

  useEffect(() => {
    fetchDiseases();
    fetchPlants();
    fetchRemedies();
  }, [fetchDiseases, fetchPlants, fetchRemedies]);

  // --- Disease CRUD Handlers ---
  const handleSearch = (e) => setQ(e.target.value);

  const resetDiseaseForm = (show = false) => {
    setForm({ disease_id: "", name: "", severity: "", plant_id: "" });
    setFormEdit(false);
    setShowDiseaseForm(show);
    resetMessages();
  };

  const openAddDiseaseForm = () => {
    setSelectedDisease(null);
    resetDiseaseForm(true);
  };

  const openEditDiseaseForm = (d) => {
    setForm({ ...d });
    setFormEdit(true);
    setShowDiseaseForm(true);
    setSelectedDisease(null);
    resetMessages();
  };

  const openDetailModal = async (d) => {
    setSelectedDisease(d);
    setShowDiseaseForm(false);
    resetMessages();
    setMappedRemedies([]);

    // Fetch mapped remedies
    try {
      const remedyRes = await axios.get(
        `${apiBase}/diseases/${d.disease_id}/remedies`,
        { headers: { Authorization: `Bearer ${access_token}` } }
      );
      setMappedRemedies(remedyRes.data || []);
    } catch (err) {
      setMappedRemedies([]);
      setErrorMsg("Failed to load mapped remedies.");
    }
  };

  const closeDetailModal = () => setSelectedDisease(null);

  const handleDiseaseChange = (e) =>
    setForm({ ...form, [e.target.name]: e.target.value });

  const handleDiseaseSubmit = async (e) => {
    e.preventDefault();
    resetMessages();
    try {
      if (formEdit) {
        await axios.put(`${apiBase}/updatediseases/${form.disease_id}`, form, {
          headers: { Authorization: `Bearer ${access_token}` },
        });
        setMsg("Disease updated successfully! 🎉");
      } else {
        await axios.post(`${apiBase}/creatediseases`, form, {
          headers: { Authorization: `Bearer ${access_token}` },
        });
        setMsg("Disease added successfully! 🚀");
      }
      fetchDiseases();
      resetDiseaseForm(false);
    } catch (err) {
      setErrorMsg(
        "Failed to save disease: " +
          (err.response?.data?.message || err.message)
      );
    }
  };

  // Disease Delete
  const handleDeleteClick = (disease) => {
    setDiseaseToDelete(disease);
    setRemedyToDelete(null); // Ensure only one type of delete is active
    setIsConfirmOpen(true);
    setSelectedDisease(null);
    resetMessages();
  };

  const cancelDelete = () => {
    setIsConfirmOpen(false);
    setDiseaseToDelete(null);
    setRemedyToDelete(null);
  };

  const confirmDelete = async () => {
    setIsConfirmOpen(false);
    if (!diseaseToDelete) return;

    try {
      await axios.delete(
        `${apiBase}/deletediseases/${diseaseToDelete.disease_id}`,
        { headers: { Authorization: `Bearer ${access_token}` } }
      );
      setDiseases((prev) =>
        prev.filter((d) => d.disease_id !== diseaseToDelete.disease_id)
      );
      setMsg(`Disease "${diseaseToDelete.name}" deleted successfully.`);
    } catch (err) {
      setErrorMsg(
        "Delete failed: " + (err.response?.data?.message || err.message)
      );
    } finally {
      setDiseaseToDelete(null);
    }
  };

  // Filtering
  const filteredDiseases = useMemo(() => {
    if (!q) return diseases;
    const lowerQ = q.toLowerCase();
    return diseases.filter(
      (d) =>
        (d.name ?? "").toLowerCase().includes(lowerQ) ||
        (d.severity ?? "").toLowerCase().includes(lowerQ) ||
        (d.plant_name ?? "").toLowerCase().includes(lowerQ)
    );
  }, [diseases, q]);

  // --- Remedy CRUD Handlers ---
  const resetRemedyForm = () => {
    setRemedyForm({ remedy_id: "", remedy: "", prevention: "" });
    setRemedyEdit(false);
    resetMessages();
  };

  const openRemedyManagementModal = () => {
    resetRemedyForm();
    setShowRemedyForm(true); // Control for the main Remedy Management modal
  };

  const closeRemedyManagementModal = () => {
    resetRemedyForm();
    setShowRemedyForm(false);
  };

  const openRemedyEdit = (remedy) => {
    setRemedyForm({ ...remedy });
    setRemedyEdit(true);
    resetMessages();
  };

  const handleRemedyChange = (e) =>
    setRemedyForm({ ...remedyForm, [e.target.name]: e.target.value });

  const handleRemedySubmit = async (e) => {
    e.preventDefault();
    resetMessages();
    try {
      if (remedyEdit) {
        await axios.put(
          `${apiBase}/updateremedies/${remedyForm.remedy_id}`,
          remedyForm,
          { headers: { Authorization: `Bearer ${access_token}` } }
        );
        setMsg("Remedy updated successfully! 👍");
      } else {
        await axios.post(`${apiBase}/createremedies`, remedyForm, {
          headers: { Authorization: `Bearer ${access_token}` },
        });
        setMsg("Remedy added successfully! ✨");
      }
      fetchRemedies();
      resetRemedyForm(); // Clear the form after submission
    } catch (err) {
      setErrorMsg(
        "Failed to save remedy: " + (err.response?.data?.message || err.message)
      );
    }
  };

  // Remedy Delete
  const handleRemedyDeleteClick = (remedy) => {
    setRemedyToDelete(remedy);
    setDiseaseToDelete(null); // Ensure only one type of delete is active
    setIsConfirmOpen(true);
    resetMessages();
  };

  const confirmRemedyDelete = async () => {
    setIsConfirmOpen(false);
    if (!remedyToDelete) return;
    try {
      await axios.delete(
        `${apiBase}/deleteremedies/${remedyToDelete.remedy_id}`,
        { headers: { Authorization: `Bearer ${access_token}` } }
      );
      setRemedies((prev) =>
        prev.filter((r) => r.remedy_id !== remedyToDelete.remedy_id)
      );
      setMsg(`Remedy "${remedyToDelete.remedy}" deleted successfully.`);
      // If the remedy was mapped to the currently selected disease, update the mapped list
      if (selectedDisease) openDetailModal(selectedDisease);
    } catch (err) {
      setErrorMsg(
        "Delete failed: " + (err.response?.data?.message || err.message)
      );
    } finally {
      setRemedyToDelete(null);
    }
  };

  // --- Mapping remedies to diseases ---
  const openMappingDialog = () => {
    setIsMappingDialogOpen(true);
    setMappingRemedyId("");
    resetMessages();
  };

  const closeMappingDialog = () => {
    setIsMappingDialogOpen(false);
    setMappingRemedyId("");
  };

  const handleMapRemedy = async () => {
    if (!mappingRemedyId || !selectedDisease) {
      setErrorMsg("Select remedy and disease to map.");
      return;
    }
    resetMessages();
    try {
      await axios.post(
        `${apiBase}/remedies/map`,
        { disease_id: selectedDisease.disease_id, remedy_id: mappingRemedyId },
        { headers: { Authorization: `Bearer ${access_token}` } }
      );
      setMsg("Remedy mapped to disease successfully! 🔗");
      // Re-fetch mapped remedies for the detail modal
      await openDetailModal(selectedDisease);
      closeMappingDialog();
    } catch (err) {
      setErrorMsg(
        "Mapping failed: " + (err.response?.data?.message || err.message)
      );
    }
  };

  const handleUnmapRemedy = async (remedy_id) => {
    resetMessages();
    try {
      await axios.delete(`${apiBase}/remedies/unmap`, {
        headers: { Authorization: `Bearer ${access_token}` },
        data: { disease_id: selectedDisease.disease_id, remedy_id },
      });
      setMsg("Remedy unmapped from disease. 🪢");
      // Re-fetch mapped remedies for the detail modal
      await openDetailModal(selectedDisease);
    } catch (err) {
      setErrorMsg(
        "Unmapping failed: " + (err.response?.data?.message || err.message)
      );
    }
  };

  // --- Render ---
  return (
    <div className="app-container">
      {/* Inject CSS Styles */}
      <style>{componentStyles}</style>

      {/* Header and Controls */}
      <div className="header-container">
        <h1 className="main-title">Disease Management</h1>
        <div className="controls-group">
          <div className="search-box">
            <input
              placeholder="Search by name, severity, or plant..."
              value={q}
              onChange={handleSearch}
              className="search-input"
            />
            <Search className="search-icon" size={20} />
          </div>
          <button className="btn primary-btn" onClick={openAddDiseaseForm}>
            <Plus size={20} /> Add Disease
          </button>
          <button
            className="btn secondary-btn"
            style={{ marginLeft: 10 }}
            onClick={openRemedyManagementModal}
          >
            <Edit size={20} /> Manage Remedies
          </button>
        </div>
      </div>

      {/* Status Messages */}
      <StatusMessage msg={msg} type="success" />
      <StatusMessage msg={errorMsg} type="error" />

      {/* Disease Card Grid */}
      <div className="card-grid">
        {filteredDiseases.length === 0 ? (
          <p className="no-data-message">
            No diseases found matching your search criteria.
          </p>
        ) : (
          filteredDiseases.map((disease) => (
            <div
              className="data-card disease-card"
              key={disease.disease_id}
              onClick={() => openDetailModal(disease)}
            >
              <h2 className="card-title">{disease.name}</h2>
              <p className="card-description">
                Severity:{" "}
                <span className={`severity-${disease.severity?.toLowerCase()}`}>
                  {disease.severity}
                </span>
              </p>
              <div className="card-info-row">
                <MapPin size={16} />{" "}
                <span className="plant-name">{disease.plant_name}</span>
              </div>
              <div className="card-actions">
                <button
                  className="btn icon-btn edit-btn"
                  onClick={(e) => {
                    e.stopPropagation();
                    openEditDiseaseForm(disease);
                  }}
                  title="Edit Disease"
                >
                  <Edit size={16} />
                </button>
                <button
                  className="btn icon-btn delete-btn"
                  onClick={(e) => {
                    e.stopPropagation();
                    handleDeleteClick(disease);
                  }}
                  title="Delete Disease"
                >
                  <Trash2 size={16} />
                </button>
              </div>
            </div>
          ))
        )}
      </div>

      {/* --- MODALS --- */}

      {/* Disease Detail Modal */}
      {selectedDisease && (
        <div className="modal-overlay">
          <div className="modal-dialog detail-modal">
            <div className="modal-header">
              <h2 className="modal-title">{selectedDisease.name} Details</h2>
              <button className="close-btn" onClick={closeDetailModal}>
                <X size={20} />
              </button>
            </div>
            <div className="modal-body">
              <div className="detail-info-grid">
                <div className="info-block">
                  <strong>ID:</strong> {selectedDisease.disease_id}
                </div>
                <div className="info-block">
                  <strong>Severity:</strong>{" "}
                  <span
                    className={`severity-${selectedDisease.severity?.toLowerCase()}`}
                  >
                    {selectedDisease.severity}
                  </span>
                </div>
                <div className="info-block">
                  <strong>Plant:</strong> {selectedDisease.plant_name}
                </div>
              </div>
              <div className="remedies-section">
                <h3>
                  Mapped Remedies <Link size={18} />
                </h3>
                <ul className="remedy-list-mapped">
                  {mappedRemedies.length === 0 ? (
                    <li className="no-remedy-msg">
                      No remedies currently mapped.
                    </li>
                  ) : (
                    mappedRemedies.map((rm) => (
                      <li key={rm.remedy_id} className="remedy-item-mapped">
                        <div className="remedy-content">
                          <strong className="remedy-title">
                            <CornerDownRight
                              size={16}
                              style={{ marginRight: "8px" }}
                            />
                            {rm.remedy}
                          </strong>
                          <p className="remedy-prevention">
                            Prevention: {rm.prevention}
                          </p>
                        </div>
                        <button
                          className="btn unmap-btn"
                          onClick={() => handleUnmapRemedy(rm.remedy_id)}
                          title="Unmap Remedy"
                        >
                          <X size={16} /> Unmap
                        </button>
                      </li>
                    ))
                  )}
                </ul>
                <button
                  className="btn secondary-btn small-btn"
                  onClick={openMappingDialog}
                >
                  <Plus size={16} /> Map New Remedy
                </button>
              </div>
            </div>
            <div className="modal-footer">
              <button
                className="btn primary-btn"
                onClick={() => openEditDiseaseForm(selectedDisease)}
              >
                <Edit size={16} /> Edit Disease
              </button>
              <button
                className="btn delete-btn"
                onClick={() => handleDeleteClick(selectedDisease)}
              >
                <Trash2 size={16} /> Delete Disease
              </button>
              <button className="btn tertiary-btn" onClick={closeDetailModal}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Disease Add/Edit Form Modal */}
      {showDiseaseForm && (
        <div className="modal-overlay">
          <div className="modal-dialog form-modal">
            <div className="modal-header">
              <h2 className="modal-title">
                {formEdit ? "Edit Disease" : "Add New Disease"}
              </h2>
              <button
                className="close-btn"
                onClick={() => resetDiseaseForm(false)}
              >
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleDiseaseSubmit} className="form-layout">
              <div className="form-group">
                <label htmlFor="disease-name">Disease Name</label>
                <input
                  id="disease-name"
                  name="name"
                  value={form.name}
                  onChange={handleDiseaseChange}
                  required
                />
              </div>
              <div className="form-group">
                <label htmlFor="disease-severity">Severity</label>
                <input
                  id="disease-severity"
                  name="severity"
                  value={form.severity}
                  onChange={handleDiseaseChange}
                  required
                />
              </div>
              <div className="form-group">
                <label htmlFor="disease-plant">Associated Plant</label>
                <select
                  id="disease-plant"
                  name="plant_id"
                  value={form.plant_id}
                  onChange={handleDiseaseChange}
                  required
                >
                  <option value="">Select Plant</option>
                  {plants.map((plant) => (
                    <option key={plant.plant_id} value={plant.plant_id}>
                      {plant.plant_name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="modal-footer">
                <button className="btn primary-btn" type="submit">
                  {formEdit ? "Save Changes" : "Add Disease"}
                </button>
                <button
                  className="btn tertiary-btn"
                  type="button"
                  onClick={() => resetDiseaseForm(false)}
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Remedy Management Modal (Add/Edit and List) */}
      {showRemedyForm && (
        <div className="modal-overlay">
          <div className="modal-dialog large-modal">
            <div className="modal-header">
              <h2 className="modal-title">Remedy Management</h2>
              <button
                className="close-btn"
                onClick={closeRemedyManagementModal}
              >
                <X size={20} />
              </button>
            </div>
            <div className="modal-body">
              {/* Remedy Add/Edit Form */}
              <div className="remedy-form-container">
                <h3>
                  {remedyEdit ? "Edit Existing Remedy" : "Add New Remedy"}
                </h3>
                <form onSubmit={handleRemedySubmit} className="form-layout">
                  <div className="form-group">
                    <label htmlFor="remedy-title">Remedy Title</label>
                    <input
                      id="remedy-title"
                      name="remedy"
                      value={remedyForm.remedy}
                      onChange={handleRemedyChange}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label htmlFor="remedy-prevention">
                      Prevention/Description
                    </label>
                    <input
                      id="remedy-prevention"
                      name="prevention"
                      value={remedyForm.prevention}
                      onChange={handleRemedyChange}
                      required
                    />
                  </div>
                  <div className="form-actions">
                    <button className="btn primary-btn" type="submit">
                      {remedyEdit ? "Save Changes" : "Add Remedy"}
                    </button>
                    {remedyEdit && (
                      <button
                        className="btn tertiary-btn"
                        type="button"
                        onClick={resetRemedyForm}
                        style={{ marginLeft: "10px" }}
                      >
                        <Plus size={16} /> Add New
                      </button>
                    )}
                  </div>
                </form>
              </div>

              <div className="remedy-list-container">
                <h3>All Available Remedies ({remedies.length})</h3>
                <ul className="remedy-list-scrollable">
                  {remedies.map((rem) => (
                    <li key={rem.remedy_id} className="remedy-list-item">
                      <div className="remedy-info">
                        <strong>{rem.remedy}</strong>
                        <span className="remedy-desc">{rem.prevention}</span>
                      </div>
                      <div className="item-actions">
                        <button
                          className="btn icon-btn edit-btn"
                          onClick={() => openRemedyEdit(rem)}
                          title="Edit Remedy"
                        >
                          <Edit size={16} />
                        </button>
                        <button
                          className="btn icon-btn delete-btn"
                          onClick={() => handleRemedyDeleteClick(rem)}
                          title="Delete Remedy"
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
            <div className="modal-footer">
              <button
                className="btn tertiary-btn"
                onClick={closeRemedyManagementModal}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Mapping Dialog */}
      {isMappingDialogOpen && selectedDisease && (
        <div className="modal-overlay">
          <div className="modal-dialog small-modal">
            <div className="modal-header">
              <h2 className="modal-title">
                Map Remedy to "{selectedDisease.name}"
              </h2>
              <button className="close-btn" onClick={closeMappingDialog}>
                <X size={20} />
              </button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label htmlFor="remedy-select">Select Remedy to Map</label>
                <select
                  id="remedy-select"
                  value={mappingRemedyId}
                  onChange={(e) => setMappingRemedyId(e.target.value)}
                  className="select-input"
                >
                  <option value="">Select Remedy</option>
                  {remedies
                    .filter(
                      (rm) =>
                        !mappedRemedies.some(
                          (mr) => mr.remedy_id === rm.remedy_id
                        )
                    )
                    .map((rm) => (
                      <option key={rm.remedy_id} value={rm.remedy_id}>
                        {rm.remedy}
                      </option>
                    ))}
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button
                className="btn primary-btn"
                type="button"
                onClick={handleMapRemedy}
                disabled={!mappingRemedyId}
              >
                Map Remedy
              </button>
              <button
                className="btn tertiary-btn"
                type="button"
                onClick={closeMappingDialog}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Confirm Delete Modal (disease or remedy) */}
      {isConfirmOpen && (
        <div className="modal-overlay">
          <div className="modal-dialog small-modal delete-confirm-modal">
            <div className="modal-header">
              <h3 className="modal-title">Confirm Deletion</h3>
              <button className="close-btn" onClick={cancelDelete}>
                <X size={20} />
              </button>
            </div>
            <div className="modal-body">
              <p>
                {diseaseToDelete ? (
                  <>
                    Are you sure you want to delete the disease:{" "}
                    <strong>{diseaseToDelete?.name}</strong>? This action cannot
                    be undone.
                  </>
                ) : (
                  <>
                    Are you sure you want to delete the remedy:{" "}
                    <strong>{remedyToDelete?.remedy}</strong>? This action
                    cannot be undone and will unmap it from all diseases.
                  </>
                )}
              </p>
            </div>
            <div className="modal-footer">
              <button
                className="btn delete-btn"
                onClick={diseaseToDelete ? confirmDelete : confirmRemedyDelete}
              >
                <Trash2 size={16} /> Delete
              </button>
              <button className="btn tertiary-btn" onClick={cancelDelete}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Disease;
