import React, { useEffect, useState, useCallback, useMemo } from "react";
import { axiosInstance } from "../api/login";
import { SERVER_IP } from "../constant";
// Import icons needed for the new design (Removed X and Search)
import { Plus, Settings, Zap, Droplet, Sun, Sprout } from "lucide-react";

// API base
const apiBase = `http://${SERVER_IP}:5000/api/farmcrop`;

const Master = ({ isSidebarOpen, toggleSidebar }) => {
  // Data states for each table
  const [soilTypes, setSoilTypes] = useState([]);
  const [irrigations, setIrrigations] = useState([]);
  const [waterSources, setWaterSources] = useState([]);
  const [cropTypes, setCropTypes] = useState([]);
  const [plants, setPlants] = useState([]);

  // Form states (Keys are 'soilType', 'irrigation', 'waterSource', 'cropType')
  const [form, setForm] = useState({
    soilType: "",
    irrigation: "",
    waterSource: "",
    cropType: "",
    plantName: "",
    plantCropType: "",
    plantWaterReq: "",
  });

  // List management
  const [msg, setMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");
  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [toDelete, setToDelete] = useState(null);

  // REMOVED: searchTerm and setSearchTerm (Line 46 warning)

  const access_token = localStorage.getItem("access_token");
  const authConfig = useMemo(
    () => ({ headers: { Authorization: `Bearer ${access_token}` } }),
    [access_token]
  );

  // Helper to map card type to the correct state key (FIX for the bug)
  const getFormKey = (type) => {
    switch (type) {
      case "soil":
        return "soilType";
      case "irrigation":
        return "irrigation";
      case "water":
        return "waterSource";
      case "crop":
        return "cropType";
      default:
        return type;
    }
  };

  // Fetch all master data (UNCHANGED BACKEND LOGIC)
  const fetchAll = useCallback(async () => {
    setErrorMsg("");
    if (!access_token) {
      setErrorMsg("Authentication token missing. Cannot fetch data.");
      return;
    }
    try {
      // GET all master tables in parallel
      const [soilRes, irrRes, waterRes, cropRes, plantRes] = await Promise.all([
        axiosInstance.get(`${apiBase}/masters/soiltypes`, authConfig),
        axiosInstance.get(`${apiBase}/masters/irrigations`, authConfig),
        axiosInstance.get(`${apiBase}/masters/watersources`, authConfig),
        axiosInstance.get(`${apiBase}/masters/croptypes`, authConfig),
        axiosInstance.get(`${apiBase}/masters/plants`, authConfig),
      ]);
      setSoilTypes(soilRes.data);
      setIrrigations(irrRes.data);
      setWaterSources(waterRes.data);
      setCropTypes(
        // Map crop types to include the details string for the card list display
        cropRes.data.map((c) => ({
          ...c,
          details: `${c.crop_type_id} - ${c.name}`,
        }))
      );
      setPlants(plantRes.data);
      setMsg("");
      setErrorMsg("");
    } catch (err) {
      setErrorMsg(
        "Could not load master data: " +
          (err.response?.data?.message || err.message)
      );
    }
  }, [access_token, authConfig]);

  useEffect(() => {
    fetchAll();
  }, [fetchAll]);

  // Reset form fields
  const resetForm = () =>
    setForm({
      soilType: "",
      irrigation: "",
      waterSource: "",
      cropType: "",
      plantName: "",
      plantCropType: "",
      plantWaterReq: "",
    });

  // Add (UNCHANGED BACKEND LOGIC)
  const handleAdd = async (type) => {
    setMsg("");
    setErrorMsg("");
    let endpoint = "",
      body = {};
    try {
      switch (type) {
        case "soil":
          if (!form.soilType) {
            setErrorMsg("Soil type name is required.");
            return;
          }
          endpoint = "addsoiltypes";
          body = { name: form.soilType };
          break;
        case "irrigation":
          // Validation works now because form.irrigation is correctly being updated
          if (!form.irrigation) {
            setErrorMsg("Irrigation method is required.");
            return;
          }
          endpoint = "addirrigations";
          body = { method_name: form.irrigation };
          break;
        case "water":
          // Validation works now because form.waterSource is correctly being updated
          if (!form.waterSource) {
            setErrorMsg("Water source is required.");
            return;
          }
          endpoint = "addwatersources";
          body = { source: form.waterSource };
          break;
        case "crop":
          if (!form.cropType) {
            setErrorMsg("Crop type name is required.");
            return;
          }
          endpoint = "addcroptypes";
          body = { name: form.cropType };
          break;
        case "plant":
          if (!form.plantName || !form.plantCropType || !form.plantWaterReq) {
            setErrorMsg(
              "Plant name, crop type, and water requirement are required."
            );
            return;
          }
          endpoint = "addplants";
          body = {
            plant_name: form.plantName,
            crop_type_id: form.plantCropType,
            water_requirement: form.plantWaterReq,
          };
          break;
        default:
          return;
      }
      await axiosInstance.post(
        `${apiBase}/masters/${endpoint}`,
        body,
        authConfig
      );
      setMsg(
        `${type.charAt(0).toUpperCase() + type.slice(1)} added successfully.`
      );
      fetchAll();
      resetForm();
    } catch (err) {
      setErrorMsg(
        "Add failed: " + (err.response?.data?.message || err.message)
      );
    }
  };

  // Confirm delete (UNCHANGED BACKEND LOGIC)
  const openDelete = (type, id) => {
    setToDelete({ type, id });
    setIsConfirmOpen(true);
  };

  const cancelDelete = () => {
    setIsConfirmOpen(false);
    setToDelete(null);
  };

  const confirmDelete = async () => {
    setMsg("");
    setErrorMsg("");
    setIsConfirmOpen(false);
    try {
      let endpoint = "";
      switch (toDelete.type) {
        case "soil":
          endpoint = `deletesoiltypes/${toDelete.id}`;
          break;
        case "irrigation":
          endpoint = `deleteirrigations/${toDelete.id}`;
          break;
        case "water":
          endpoint = `deletewatersources/${toDelete.id}`;
          break;
        case "crop":
          endpoint = `deletecroptypes/${toDelete.id}`;
          break;
        case "plant":
          endpoint = `deleteplants/${toDelete.id}`;
          break;
        default:
          return;
      }
      await axiosInstance.delete(`${apiBase}/masters/${endpoint}`, authConfig);
      setMsg(
        `${
          toDelete.type.charAt(0).toUpperCase() + toDelete.type.slice(1)
        } deleted successfully!`
      );
      fetchAll();
    } catch (err) {
      setErrorMsg(
        "Delete failed: " + (err.response?.data?.message || err.message)
      );
    } finally {
      setToDelete(null);
    }
  };

  // Form change handler
  const handleChange = (e) =>
    setForm({ ...form, [e.target.name]: e.target.value });

  // --- STYLES OBJECT (Copied and adapted from userManage.jsx) ---
  const cardStyles = `
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
  
  /* Main content area transition and positioning */
  .master-mgmt-bg {
    min-height: 100vh;
    padding: 20px 30px;
    background: #f8f9fa;
    font-family: 'Inter', sans-serif;
    transition: margin-left 0.3s ease-out; /* Add transition for smooth movement */
  }

  /* Desktop View: Sidebar always open */
  @media (min-width: 1024px) {
    .master-mgmt-bg.sidebar-open {
        margin-left: 220px; /* Offset for sidebar width */
    }
    .master-mgmt-bg.sidebar-closed {
        margin-left: 0;
    }
  }

  /* Header & Search */
  .header-container {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 30px;
    padding-bottom: 10px;
    border-bottom: 3px solid #e0e7ff; /* Lighter border for clean look */
  }
  .header-left {
    display: flex;
    align-items: center;
    font-size: 2rem;
    font-weight: 700;
    color: #1a202c;
  }
  .header-left svg {
    margin-left: 10px;
    color: #4f46e5;
  }
  .header-right {
    display: flex;
    align-items: center;
    gap: 15px;
  }
  
  /* Status Messages */
  .status-msg, .error-msg {
    padding: 12px;
    margin-bottom: 20px;
    border-radius: 8px;
    font-weight: 500;
    animation: fadeIn 0.3s ease-out;
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
  .master-card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 30px;
  }

  /* Single Card */
  .master-card {
    height: 820px;      /* Example: choose a size that fits your UI */
    min-height: 820px;
    max-height: 820px;
    display: flex;
    flex-direction: column;
    box-sizing: border-box;
    background: #fff;
    border-radius: 16px;
    padding: 25px;
    box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
    border: 1px solid #f0f4f8;
    transition: transform 0.2s ease, box-shadow 0.2s ease;
  }
  .master-card:hover {
      transform: translateY(-3px);
      box-shadow: 0 15px 20px -5px rgba(0, 0, 0, 0.1), 0 6px 10px -3px rgba(0, 0, 0, 0.05);
  }
  
  .card-header {
    font-size: 1.5rem;
    font-weight: 600;
    color: #1a202c;
    margin-bottom: 15px;
    padding-bottom: 15px;
    border-bottom: 1px solid #e0e7ff;
    display: flex;
    align-items: center;
    gap: 10px;
  }

  /* Form/Input Styles */
  .input-group {
    display: flex;
    gap: 10px;
    margin-bottom: 15px;
    flex-wrap: wrap;
    align-items: center;
  }
  input, select {
    padding: 10px 12px;
    border: 1px solid #cbd5e1;
    border-radius: 8px;
    font-size: 1rem;
    box-sizing: border-box;
    flex-grow: 1;
    min-width: 120px;
    transition: border-color 0.2s;
  }
  input:focus, select:focus {
      border-color: #4f46e5;
      outline: none;
      box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
  }
  
  /* Button Styles */
  .add-button {
    background: #4f46e5;
    color: #fff;
    border: none;
    border-radius: 8px;
    padding: 10px 15px;
    cursor: pointer;
    font-size: 0.95rem;
    font-weight: 600;
    transition: background 0.2s, transform 0.1s;
    box-shadow: 0 2px 4px rgba(79, 70, 229, 0.2);
    min-width: max-content;
  }
  .add-button:hover {
    background: #4338ca;
    transform: translateY(-1px);
  }
  
  .delete-button {
    background: #fee2e2;
    color: #ef4444;
    border: 1px solid #fecaca;
    padding: 6px 12px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.85rem;
    font-weight: 600;
    transition: background 0.2s;
  }
  .delete-button:hover {
    background: #fecaca;
  }
  
  /* List Styles */
  .data-list {
    flex: 1;
    overflow-y: auto;
    max-height: 500px;   /* Adjust as needed so input/buttons always visible */
    margin: 0;
    padding: 0;
  }
  .data-list li {
    padding: 10px 0;
    border-bottom: 1px dotted #e2e8f0;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 1rem;
    color: #4a5568;
  }
  .data-list li:last-child {
      border-bottom: none;
  }
  .data-list li span {
      font-weight: 500;
      color: #2c3e50;
  }
  
  /* Plants List Specific Styling */
  .plants-list li {
      flex-direction: column;
      align-items: flex-start !important;
      gap: 5px;
      padding: 12px 0;
  }
  .plants-list li span {
      font-weight: 600;
      font-size: 1.05rem;
      color: #4f46e5;
  }
  .plants-list li .details {
      font-size: 0.9rem;
      color: #6b7280;
      margin-left: 5px;
      font-family: monospace; /* Use monospace for UUIDs/IDs */
  }
  .plants-list .delete-btn-wrapper {
      width: 100%;
      display: flex;
      justify-content: flex-end;
      margin-top: 5px;
  }

  /* Modal Styles */
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background: rgba(0, 0, 0, 0.4);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    backdrop-filter: blur(2px);
    animation: fadeIn 0.3s;
  }
  .modal {
    background: #fff;
    padding: 30px;
    border-radius: 12px;
    box-shadow: 0 5px 15px rgba(0,0,0,0.3);
    max-width: 400px;
    width: 90%;
    animation: scaleIn 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
  }
  .modal h3 {
      font-size: 1.5rem;
      color: #ef4444;
      margin-top: 0;
      margin-bottom: 15px;
      font-weight: 700;
  }
  .modal p {
      margin-bottom: 25px;
      font-size: 1rem;
      color: #4a5568;
  }
  .modal-actions {
      display: flex;
      justify-content: flex-end;
      gap: 10px;
  }
  .confirm-delete-btn {
      background: #ef4444;
      color: #fff;
      border: none;
      padding: 10px 15px;
      border-radius: 6px;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s;
  }
  .confirm-delete-btn:hover {
      background: #dc2626;
  }
  .cancel-btn {
      background: #e2e8f0;
      color: #1a202c;
      padding: 10px 15px;
      border-radius: 6px;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s;
  }
  .cancel-btn:hover {
    background: #cbd5e1;
  }

  /* Keyframes */
  @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
  @keyframes scaleIn { from { opacity: 0; transform: scale(0.9); } to { opacity: 1; transform: scale(1); } }
  
  /* Media Queries */
  @media (max-width: 768px) {
    .master-card-grid { grid-template-columns: 1fr; }
    .header-left { font-size: 1.8rem; }
    .header-container { margin-bottom: 20px; }
  }
  `;
  // --- END STYLES OBJECT ---

  // Determine the main content class based on sidebar state (Desktop only)
  // Assuming this component is mounted inside the main layout like UserManage
  const mainContentClass = isSidebarOpen ? "sidebar-open" : "sidebar-closed";

  // --- RENDERING HELPER (Adapted to new design) ---
  const renderCard = (title, type, icon, placeholder, listData, renderItem) => {
    // FIX: Get the correct form key (name and value) for the input field
    const inputKey = getFormKey(type);

    return (
      <section key={type} className="master-card">
        <h3 className="card-header">
          {title} {icon}
        </h3>

        {/* Input Group based on type */}
        {type !== "plant" ? (
          <div className="input-group">
            <input
              name={inputKey} // FIX: Now uses 'soilType', 'irrigation', 'waterSource', or 'cropType'
              value={form[inputKey]} // FIX: Now uses the correct value from state
              onChange={handleChange}
              placeholder={placeholder}
            />
            <button className="add-button" onClick={() => handleAdd(type)}>
              Add
            </button>
          </div>
        ) : (
          // Plants has a dedicated multi-input layout (UNCHANGED)
          <div className="input-group">
            <input
              name="plantName"
              value={form.plantName}
              onChange={handleChange}
              placeholder="Plant Name"
              style={{ minWidth: "100px" }}
              required
            />
            <select
              name="plantCropType"
              value={form.plantCropType}
              onChange={handleChange}
              style={{ minWidth: "120px" }}
              required
            >
              <option value="">Select Crop Type</option>
              {cropTypes.map((ct) => (
                <option key={ct.crop_type_id} value={ct.crop_type_id}>
                  {ct.name}
                </option>
              ))}
            </select>
            <select
              name="plantWaterReq"
              value={form.plantWaterReq}
              onChange={handleChange}
              style={{ minWidth: "80px" }}
              required
            >
              <option value="">Water Req</option>
              {["Low", "Medium", "High"].map((req) => (
                <option key={req} value={req}>
                  {req}
                </option>
              ))}
            </select>
            <button className="add-button" onClick={() => handleAdd("plant")}>
              <Plus size={18} style={{ marginRight: "5px" }} /> Add Plant
            </button>
          </div>
        )}

        <ul className={`data-list ${type === "plant" ? "plants-list" : ""}`}>
          {listData.length === 0 ? (
            <li style={{ justifyContent: "center", color: "#6b7280" }}>
              No {title.toLowerCase()} found.
            </li>
          ) : (
            listData.map(renderItem)
          )}
        </ul>
      </section>
    );
  };

  return (
    <div className={`master-mgmt-bg ${mainContentClass}`}>
      <style>{cardStyles}</style>

      {/* Header (Simplified since this isn't a main navigational page like User Management) */}
      <div className="header-container">
        <div className="header-left">
          Master Data Management <Settings size={28} />
        </div>
        {/* The header-right area is left empty as there is no search/filter for master data */}
        <div className="header-right"></div>
      </div>

      {/* Status/Error Messages */}
      {msg && <div className="status-msg">{msg}</div>}
      {errorMsg && <div className="error-msg">{errorMsg}</div>}

      {/* Master Data Card Grid */}
      <div className="master-card-grid">
        {/* Soil Types Card */}
        {renderCard(
          "Soil Types",
          "soil",
          <Zap size={20} />,
          "New soil type name",
          soilTypes,
          (s) => (
            <li key={s.soil_type_id}>
              <span>{s.name}</span>
              <button
                className="delete-button"
                onClick={() => openDelete("soil", s.soil_type_id)}
              >
                Delete
              </button>
            </li>
          )
        )}

        {/* Irrigation Methods Card */}
        {renderCard(
          "Irrigation Methods",
          "irrigation",
          <Droplet size={20} />,
          "New irrigation method",
          irrigations,
          (i) => (
            <li key={i.irrigation_id}>
              <span>{i.method_name}</span>
              <button
                className="delete-button"
                onClick={() => openDelete("irrigation", i.irrigation_id)}
              >
                Delete
              </button>
            </li>
          )
        )}

        {/* Water Sources Card */}
        {renderCard(
          "Water Sources",
          "water",
          <Sun size={20} />,
          "New water source",
          waterSources,
          (w) => (
            <li key={w.water_src_id}>
              <span>{w.source}</span>
              <button
                className="delete-button"
                onClick={() => openDelete("water", w.water_src_id)}
              >
                Delete
              </button>
            </li>
          )
        )}

        {/* Crop Types Card */}
        {renderCard(
          "Crop Types",
          "crop",
          <Sprout size={20} />,
          "New crop type name",
          cropTypes,
          (c) => (
            <li key={c.crop_type_id}>
              <span>{c.name}</span>
              <button
                className="delete-button"
                onClick={() => openDelete("crop", c.crop_type_id)}
              >
                Delete
              </button>
            </li>
          )
        )}

        {/* Plants Card - Uses renderCard with type="plant" for its specific layout */}
        {renderCard(
          "Plants",
          "plant",
          <Sprout size={20} />,
          "", // Placeholder not used for 'plant'
          plants,
          (p) => (
            <li key={p.plant_id}>
              <span>{p.plant_name}</span>
              <div className="details">
                (Crop Type: **{p.crop_type_id}** | Water Req: **
                {p.water_requirement}**)
              </div>
              <div className="delete-btn-wrapper">
                <button
                  className="delete-button"
                  onClick={() => openDelete("plant", p.plant_id)}
                >
                  Delete
                </button>
              </div>
            </li>
          )
        )}
      </div>

      {/* Delete confirmation modal */}
      {isConfirmOpen && (
        <div className="modal-overlay">
          <div className="modal">
            <h3>Confirm Deletion ⚠️</h3>
            <p>
              Are you sure you want to delete this record? This action cannot be
              undone.
            </p>
            <div className="modal-actions">
              <button className="cancel-btn" onClick={cancelDelete}>
                Cancel
              </button>
              <button className="confirm-delete-btn" onClick={confirmDelete}>
                Delete Permanently
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Master;
