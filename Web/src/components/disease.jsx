import React, { useEffect, useState, useCallback, useMemo } from "react";
import { axiosInstance } from "../api/login";
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

// --- CSS String (Refactored to New 'userManage' Design with Primary Color #4F46E5) ---
const newComponentStyles = `
/* --- Global Variables (New Theme) --- */
:root {
    --primary-new: #4F46E5; /* Indigo */
    --secondary-new: #6c757d; /* Grey */
    --accent-new: #ffc107; /* Orange/Warning */
    --danger-new: #dc3545; /* Red */
    --background-new: #f8f9fa; /* Light Grey Background */
    --surface-new: #ffffff; /* White Card/Modal Surface */
    --text-new: #212529;
    --border-new: #e9ecef;
    --shadow-new: 0 0.5rem 1rem rgba(0, 0, 0, 0.05);
}

.app-container-new {
    padding: 20px;
    background-color: var(--background-new);
    min-height: 100vh;
    font-family: Arial, sans-serif;
}

/* --- Header and Controls --- */

.header-container-new {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 25px;
    flex-wrap: wrap;
    gap: 15px;
}

.main-title-new {
    font-size: 1.8em;
    font-weight: 700;
    color: #1A202C;
}

.controls-group-new {
    display: flex;
    gap: 10px;
    align-items: center;
}

.search-box-new {
    display: flex;
    align-items: center;
    background: var(--surface-new);
    border: 1px solid var(--border-new);
    border-radius: 4px;
    padding: 6px 12px;
    box-shadow: var(--shadow-new);
}

.search-input-new {
    border: none;
    outline: none;
    padding: 0;
    font-size: 1em;
    width: 200px;
}

.search-icon-new {
    color: var(--secondary-new);
    margin-right: 8px;
}

/* --- Buttons (Simplified) --- */

.btn-new {
    display: flex;
    align-items: center;
    padding: 8px 16px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-weight: 500;
    transition: all 0.2s ease-in-out;
    gap: 5px;
    font-size: 0.9em;
}

.btn-primary-new {
    background-color: var(--primary-new);
    color: var(--surface-new);
}

.btn-primary-new:hover {
    background-color: #4338CA; /* Darker Indigo Hover */
}

.btn-secondary-new {
    background-color: var(--secondary-new);
    color: var(--surface-new);
}

.btn-secondary-new:hover {
    background-color: #5a6268;
}

.btn-tertiary-new {
    background-color: transparent;
    color: var(--secondary-new);
    border: 1px solid var(--border-new);
}

.btn-tertiary-new:hover {
    background-color: #f0f0f0;
}

.btn-danger-new {
    background-color: var(--danger-new);
    color: var(--surface-new);
}

.btn-danger-new:hover {
    background-color: #bd2130;
}

.btn-icon-new {
    padding: 6px;
    border-radius: 4px;
    background-color: transparent;
    color: var(--secondary-new);
}

.btn-icon-new.edit-new:hover {
    color: var(--primary-new);
    background-color: #E5E4FF; /* Light Indigo Background Hover */
}

.btn-icon-new.delete-new {
    color: var(--danger-new);
}

.btn-icon-new.delete-new:hover {
    background-color: #ffe8e8;
}

.btn-small-new {
    padding: 6px 12px;
    font-size: 0.8em;
}

.btn-warning-new {
    padding: 6px 10px;
    font-size: 0.8em;
    background-color: var(--accent-new);
    color: var(--text-new);
}
.btn-warning-new:hover {
    background-color: #e0a800;
}

/* --- Status Messages --- */

.status-msg-new {
    display: flex;
    align-items: center;
    padding: 10px 15px;
    margin-bottom: 15px;
    border-radius: 4px;
    font-weight: 500;
    box-shadow: var(--shadow-new);
}

.status-success-new {
    background-color: #d4edda; /* Light Green */
    color: #155724; /* Dark Green */
    border: 1px solid #c3e6cb;
}

.status-error-new {
    background-color: #f8d7da; /* Light Red */
    color: #721c24; /* Dark Red */
    border: 1px solid #f5c6cb;
}

/* --- Card Grid (Main Content) --- */

.card-grid-new {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 15px;
}

.no-data-message-new {
    grid-column: 1 / -1;
    text-align: center;
    padding: 30px;
    font-size: 1em;
    color: var(--secondary-new);
    background-color: var(--surface-new);
    border-radius: 6px;
}

.data-card-new {
    background-color: var(--surface-new);
    border-radius: 6px;
    padding: 15px;
    box-shadow: var(--shadow-new);
    transition: transform 0.1s, box-shadow 0.1s;
    cursor: pointer;
    border-left: 4px solid var(--primary-new);
}

.data-card-new:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
}

.card-title-new {
    font-size: 1.2em;
    font-weight: 600;
    color: var(--primary-new);
    margin-bottom: 5px;
}

.card-description-new {
    font-size: 0.9em;
    color: var(--text-new);
    margin-bottom: 10px;
}

.card-info-row-new {
    display: flex;
    align-items: center;
    gap: 6px;
    color: var(--secondary-new);
    font-size: 0.85em;
}

.card-actions-new {
    margin-top: 10px;
    display: flex;
    justify-content: flex-end;
    gap: 5px;
}

/* Severity Indicators */
.severity-low-new { color: #28a745; font-weight: 600; } /* Green */
.severity-medium-new { color: var(--accent-new); font-weight: 600; } /* Orange */
.severity-high-new { color: var(--danger-new); font-weight: 600; } /* Red */

/* --- Modals (General) --- */

.modal-overlay-new {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 1000;
}

.modal-dialog-new {
    background: var(--surface-new);
    border-radius: 8px;
    box-shadow: 0 5px 15px rgba(0, 0, 0, 0.2);
    padding: 20px;
    max-width: 90%;
    max-height: 90vh;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
}

.small-modal-new {
    width: 350px;
}

.detail-modal-new {
    width: 600px;
}

.form-modal-new {
    width: 450px;
}

.large-modal-new {
    width: 750px;
    max-height: 80vh;
}

.modal-header-new {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: 10px;
    border-bottom: 1px solid var(--border-new);
    margin-bottom: 15px;
}

.modal-title-new {
    font-size: 1.3em;
    font-weight: 600;
    color: var(--primary-new);
}

.close-btn-new {
    background: transparent;
    border: none;
    color: var(--secondary-new);
    cursor: pointer;
    transition: color 0.2s;
}

.close-btn-new:hover {
    color: var(--danger-new);
}

.modal-body-new {
    flex-grow: 1;
    padding-right: 5px;
}

.modal-footer-new {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    padding-top: 15px;
    margin-top: 15px;
    border-top: 1px solid var(--border-new);
}

/* --- Form Styles --- */

.form-layout-new {
    display: flex;
    flex-direction: column;
    gap: 10px;
}

.form-group-new {
    display: flex;
    flex-direction: column;
}

.form-label-new {
    font-weight: 500;
    color: var(--text-new);
    margin-bottom: 4px;
    font-size: 0.9em;
}

.form-input-new,
.form-select-new {
    padding: 8px 10px;
    border: 1px solid var(--border-new);
    border-radius: 4px;
    font-size: 1em;
    transition: border-color 0.2s, box-shadow 0.2s;
}

.form-input-new:focus,
.form-select-new:focus {
    border-color: var(--primary-new);
    outline: none;
    box-shadow: 0 0 0 2px rgba(79, 70, 229, 0.15); /* New Indigo Shadow */
}

.form-actions-new {
    margin-top: 10px;
    display: flex;
    gap: 10px;
}

/* --- Detail Modal Specific --- */

.detail-info-grid-new {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 10px;
    margin-bottom: 20px;
    padding-bottom: 10px;
    border-bottom: 1px dashed var(--border-new);
}

.info-block-new strong {
    color: var(--primary-new);
    display: block;
    margin-bottom: 2px;
    font-size: 0.85em;
}

.remedies-section-new h3 {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--text-new);
    margin-bottom: 10px;
    border-bottom: 2px solid var(--primary-new);
    padding-bottom: 5px;
    font-size: 1.2em;
}

.remedy-list-mapped-new {
    list-style: none;
    padding: 0;
    margin-bottom: 15px;
}

.remedy-item-mapped-new {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: 10px;
    margin-bottom: 5px;
    background-color: #E5E4FF; /* Very Light Indigo */
    border-radius: 4px;
    border-left: 3px solid var(--primary-new);
}

.remedy-content-new {
    flex-grow: 1;
    padding-right: 10px;
}

.remedy-title-new {
    display: flex;
    align-items: center;
    font-size: 1em;
    color: var(--primary-new);
}

.remedy-prevention-new {
    margin-top: 3px;
    font-size: 0.8em;
    color: var(--secondary-new);
    margin-left: 20px;
}

.no-remedy-msg-new {
    color: var(--secondary-new);
    font-style: italic;
    padding: 8px;
    text-align: center;
    background-color: #e9ecef;
    border-radius: 4px;
}

/* --- Remedy Management Modal Specific --- */

.remedy-form-container-new {
    padding: 15px;
    border: 1px solid var(--border-new);
    border-radius: 6px;
    margin-bottom: 20px;
}

.remedy-form-container-new h3 {
    color: var(--primary-new);
    margin-top: 0;
    margin-bottom: 15px;
    font-size: 1.1em;
}

.remedy-list-container-new {
    max-height: 250px;
    overflow-y: auto;
    padding-right: 10px;
}

.remedy-list-container-new h3 {
    color: var(--text-new);
    margin-bottom: 10px;
}

.remedy-list-scrollable-new {
    list-style: none;
    padding: 0;
}

.remedy-list-item-new {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 0;
    border-bottom: 1px dashed var(--border-new);
}

.remedy-list-item-new:last-child {
    border-bottom: none;
}

.remedy-info-new {
    flex-grow: 1;
    display: flex;
    flex-direction: column;
}

.remedy-info-new strong {
    font-size: 0.9em;
    color: var(--text-new);
}

.remedy-desc-new {
    font-size: 0.75em;
    color: var(--secondary-new);
    margin-top: 2px;
}

.item-actions-new {
    display: flex;
    gap: 5px;
}

/* --- Responsive Adjustments --- */
@media (max-width: 768px) {
    .header-container-new {
        flex-direction: column;
        align-items: flex-start;
    }
    .controls-group-new {
        flex-direction: column;
        align-items: stretch;
        width: 100%;
    }
    .search-box-new {
        width: 100%;
    }
    .search-input-new {
        width: 100%;
    }
    .btn-new {
        width: 100%;
        justify-content: center;
    }
    .modal-dialog-new {
        width: 95%;
        margin: 15px auto;
        padding: 15px;
    }
    .detail-info-grid-new {
        grid-template-columns: 1fr;
    }
    .modal-footer-new {
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
    type === "error"
      ? "status-msg-new status-error-new"
      : "status-msg-new status-success-new";
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

  // --- CRUD Fetch Hooks (NO CHANGES) ---
  const fetchDiseases = useCallback(async () => {
    resetMessages();
    try {
      const res = await axiosInstance.get(`${apiBase}/diseases`, {
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
      const res = await axiosInstance.get(`${plantApiBase}/masters/plants`, {
        headers: { Authorization: `Bearer ${access_token}` },
      });
      setPlants(res.data || []);
    } catch {
      setPlants([]);
    }
  }, [access_token]);

  const fetchRemedies = useCallback(async () => {
    try {
      const res = await axiosInstance.get(`${apiBase}/remedies`, {
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

  // --- Disease CRUD Handlers (NO CHANGES) ---
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
      const remedyRes = await axiosInstance.get(
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
        await axiosInstance.put(
          `${apiBase}/updatediseases/${form.disease_id}`,
          form,
          {
            headers: { Authorization: `Bearer ${access_token}` },
          }
        );
        setMsg("Disease updated successfully! 脂");
      } else {
        await axiosInstance.post(`${apiBase}/creatediseases`, form, {
          headers: { Authorization: `Bearer ${access_token}` },
        });
        setMsg("Disease added successfully! 噫");
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
      await axiosInstance.delete(
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

  // Filtering (NO CHANGES)
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

  // --- Remedy CRUD Handlers (NO CHANGES) ---
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
        await axiosInstance.put(
          `${apiBase}/updateremedies/${remedyForm.remedy_id}`,
          remedyForm,
          { headers: { Authorization: `Bearer ${access_token}` } }
        );
        setMsg("Remedy updated successfully! 総");
      } else {
        await axiosInstance.post(`${apiBase}/createremedies`, remedyForm, {
          headers: { Authorization: `Bearer ${access_token}` },
        });
        setMsg("Remedy added successfully! 笨ｨ");
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
      await axiosInstance.delete(
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

  // --- Mapping remedies to diseases (NO CHANGES) ---
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
      await axiosInstance.post(
        `${apiBase}/remedies/map`,
        { disease_id: selectedDisease.disease_id, remedy_id: mappingRemedyId },
        { headers: { Authorization: `Bearer ${access_token}` } }
      );
      setMsg("Remedy mapped to disease successfully! 迫");
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
      await axiosInstance.delete(`${apiBase}/remedies/unmap`, {
        headers: { Authorization: `Bearer ${access_token}` },
        data: { disease_id: selectedDisease.disease_id, remedy_id },
      });
      setMsg("Remedy unmapped from disease. ｪ｢");
      // Re-fetch mapped remedies for the detail modal
      await openDetailModal(selectedDisease);
    } catch (err) {
      setErrorMsg(
        "Unmapping failed: " + (err.response?.data?.message || err.message)
      );
    }
  };

  // --- Render (UPDATED CLASS NAMES) ---
  return (
    <div className="app-container-new">
      {/* Inject CSS Styles */}
      <style>{newComponentStyles}</style>

      {/* Header and Controls */}
      <div className="header-container-new">
        <h1 className="main-title-new">Disease Management</h1>
        <div className="controls-group-new">
          <div className="search-box-new">
            <input
              placeholder="Search by name, severity, or plant..."
              value={q}
              onChange={handleSearch}
              className="search-input-new"
            />
            <Search className="search-icon-new" size={20} />
          </div>
          <button
            className="btn-new btn-primary-new"
            onClick={openAddDiseaseForm}
          >
            <Plus size={20} /> Add Disease
          </button>
          <button
            className="btn-new btn-secondary-new"
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
      <div className="card-grid-new">
        {filteredDiseases.length === 0 ? (
          <p className="no-data-message-new">
            No diseases found matching your search criteria.
          </p>
        ) : (
          filteredDiseases.map((disease) => (
            <div
              className="data-card-new disease-card"
              key={disease.disease_id}
              onClick={() => openDetailModal(disease)}
            >
              <h2 className="card-title-new">{disease.name}</h2>
              <p className="card-description-new">
                Severity:{" "}
                <span
                  className={`severity-${disease.severity?.toLowerCase()}-new`}
                >
                  {disease.severity}
                </span>
              </p>
              <div className="card-info-row-new">
                <MapPin size={16} />{" "}
                <span className="plant-name-new">{disease.plant_name}</span>
              </div>
              <div className="card-actions-new">
                <button
                  className="btn-new btn-icon-new edit-new"
                  onClick={(e) => {
                    e.stopPropagation();
                    openEditDiseaseForm(disease);
                  }}
                  title="Edit Disease"
                >
                  <Edit size={16} />
                </button>
                <button
                  className="btn-new btn-icon-new delete-new"
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
        <div className="modal-overlay-new">
          <div className="modal-dialog-new detail-modal-new">
            <div className="modal-header-new">
              <h2 className="modal-title-new">
                {selectedDisease.name} Details
              </h2>
              <button className="close-btn-new" onClick={closeDetailModal}>
                <X size={20} />
              </button>
            </div>
            <div className="modal-body-new">
              <div className="detail-info-grid-new">
                <div className="info-block-new">
                  <strong>ID:</strong> {selectedDisease.disease_id}
                </div>
                <div className="info-block-new">
                  <strong>Severity:</strong>{" "}
                  <span
                    className={`severity-${selectedDisease.severity?.toLowerCase()}-new`}
                  >
                    {selectedDisease.severity}
                  </span>
                </div>
                <div className="info-block-new">
                  <strong>Plant:</strong> {selectedDisease.plant_name}
                </div>
              </div>
              <div className="remedies-section-new">
                <h3>
                  Mapped Remedies <Link size={18} />
                </h3>
                <ul className="remedy-list-mapped-new">
                  {mappedRemedies.length === 0 ? (
                    <li className="no-remedy-msg-new">
                      No remedies currently mapped.
                    </li>
                  ) : (
                    mappedRemedies.map((rm) => (
                      <li key={rm.remedy_id} className="remedy-item-mapped-new">
                        <div className="remedy-content-new">
                          <strong className="remedy-title-new">
                            <CornerDownRight
                              size={16}
                              style={{ marginRight: "8px" }}
                            />
                            {rm.remedy}
                          </strong>
                          <p className="remedy-prevention-new">
                            Prevention: {rm.prevention}
                          </p>
                        </div>
                        <button
                          className="btn-new btn-warning-new"
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
                  className="btn-new btn-secondary-new btn-small-new"
                  onClick={openMappingDialog}
                >
                  <Plus size={16} /> Map New Remedy
                </button>
              </div>
            </div>
            <div className="modal-footer-new">
              <button
                className="btn-new btn-primary-new"
                onClick={() => openEditDiseaseForm(selectedDisease)}
              >
                <Edit size={16} /> Edit Disease
              </button>
              <button
                className="btn-new btn-danger-new"
                onClick={() => handleDeleteClick(selectedDisease)}
              >
                <Trash2 size={16} /> Delete Disease
              </button>
              <button
                className="btn-new btn-tertiary-new"
                onClick={closeDetailModal}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Disease Add/Edit Form Modal */}
      {showDiseaseForm && (
        <div className="modal-overlay-new">
          <div className="modal-dialog-new form-modal-new">
            <div className="modal-header-new">
              <h2 className="modal-title-new">
                {formEdit ? "Edit Disease" : "Add New Disease"}
              </h2>
              <button
                className="close-btn-new"
                onClick={() => resetDiseaseForm(false)}
              >
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleDiseaseSubmit} className="form-layout-new">
              <div className="form-group-new">
                <label htmlFor="disease-name" className="form-label-new">
                  Disease Name
                </label>
                <input
                  id="disease-name"
                  name="name"
                  value={form.name}
                  onChange={handleDiseaseChange}
                  required
                  className="form-input-new"
                />
              </div>
              <div className="form-group-new">
                <label htmlFor="disease-severity" className="form-label-new">
                  Severity
                </label>
                <input
                  id="disease-severity"
                  name="severity"
                  value={form.severity}
                  onChange={handleDiseaseChange}
                  required
                  className="form-input-new"
                />
              </div>
              <div className="form-group-new">
                <label htmlFor="disease-plant" className="form-label-new">
                  Associated Plant
                </label>
                <select
                  id="disease-plant"
                  name="plant_id"
                  value={form.plant_id}
                  onChange={handleDiseaseChange}
                  required
                  className="form-select-new"
                >
                  <option value="">Select Plant</option>
                  {plants.map((plant) => (
                    <option key={plant.plant_id} value={plant.plant_id}>
                      {plant.plant_name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="modal-footer-new">
                <button className="btn-new btn-primary-new" type="submit">
                  {formEdit ? "Save Changes" : "Add Disease"}
                </button>
                <button
                  className="btn-new btn-tertiary-new"
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
        <div className="modal-overlay-new">
          <div className="modal-dialog-new large-modal-new">
            <div className="modal-header-new">
              <h2 className="modal-title-new">Remedy Management</h2>
              <button
                className="close-btn-new"
                onClick={closeRemedyManagementModal}
              >
                <X size={20} />
              </button>
            </div>
            <div className="modal-body-new">
              {/* Remedy Add/Edit Form */}
              <div className="remedy-form-container-new">
                <h3>
                  {remedyEdit ? "Edit Existing Remedy" : "Add New Remedy"}
                </h3>
                <form onSubmit={handleRemedySubmit} className="form-layout-new">
                  <div className="form-group-new">
                    <label htmlFor="remedy-title" className="form-label-new">
                      Remedy Title
                    </label>
                    <input
                      id="remedy-title"
                      name="remedy"
                      value={remedyForm.remedy}
                      onChange={handleRemedyChange}
                      required
                      className="form-input-new"
                    />
                  </div>
                  <div className="form-group-new">
                    <label
                      htmlFor="remedy-prevention"
                      className="form-label-new"
                    >
                      Prevention/Description
                    </label>
                    <input
                      id="remedy-prevention"
                      name="prevention"
                      value={remedyForm.prevention}
                      onChange={handleRemedyChange}
                      required
                      className="form-input-new"
                    />
                  </div>
                  <div className="form-actions-new">
                    <button className="btn-new btn-primary-new" type="submit">
                      {remedyEdit ? "Save Changes" : "Add Remedy"}
                    </button>
                    {remedyEdit && (
                      <button
                        className="btn-new btn-tertiary-new"
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

              <div className="remedy-list-container-new">
                <h3>All Available Remedies ({remedies.length})</h3>
                <ul className="remedy-list-scrollable-new">
                  {remedies.map((rem) => (
                    <li key={rem.remedy_id} className="remedy-list-item-new">
                      <div className="remedy-info-new">
                        <strong>{rem.remedy}</strong>
                        <span className="remedy-desc-new">
                          {rem.prevention}
                        </span>
                      </div>
                      <div className="item-actions-new">
                        <button
                          className="btn-new btn-icon-new edit-new"
                          onClick={() => openRemedyEdit(rem)}
                          title="Edit Remedy"
                        >
                          <Edit size={16} />
                        </button>
                        <button
                          className="btn-new btn-icon-new delete-new"
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
            <div className="modal-footer-new">
              <button
                className="btn-new btn-tertiary-new"
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
        <div className="modal-overlay-new">
          <div className="modal-dialog-new small-modal-new">
            <div className="modal-header-new">
              <h2 className="modal-title-new">
                Map Remedy to "{selectedDisease.name}"
              </h2>
              <button className="close-btn-new" onClick={closeMappingDialog}>
                <X size={20} />
              </button>
            </div>
            <div className="modal-body-new">
              <div className="form-group-new">
                <label htmlFor="remedy-select" className="form-label-new">
                  Select Remedy to Map
                </label>
                <select
                  id="remedy-select"
                  value={mappingRemedyId}
                  onChange={(e) => setMappingRemedyId(e.target.value)}
                  className="form-select-new"
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
            <div className="modal-footer-new">
              <button
                className="btn-new btn-primary-new"
                type="button"
                onClick={handleMapRemedy}
                disabled={!mappingRemedyId}
              >
                Map Remedy
              </button>
              <button
                className="btn-new btn-tertiary-new"
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
        <div className="modal-overlay-new">
          <div className="modal-dialog-new small-modal-new delete-confirm-modal-new">
            <div className="modal-header-new">
              <h3 className="modal-title-new">Confirm Deletion</h3>
              <button className="close-btn-new" onClick={cancelDelete}>
                <X size={20} />
              </button>
            </div>
            <div className="modal-body-new">
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
            <div className="modal-footer-new">
              <button
                className="btn-new btn-danger-new"
                onClick={diseaseToDelete ? confirmDelete : confirmRemedyDelete}
              >
                <Trash2 size={16} /> Delete
              </button>
              <button
                className="btn-new btn-tertiary-new"
                onClick={cancelDelete}
              >
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
