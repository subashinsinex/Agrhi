import React, { useEffect, useState, useCallback, useMemo } from "react";
import { axiosInstance } from "../api/login";
import { SERVER_ADDR } from "../constant";
import {
  Plus,
  Zap,
  Droplets,
  Sun,
  Sprout,
  Trash2,
  CheckCircle,
  AlertCircle,
  Layers,
  Database,
} from "lucide-react";

// API Base configuration
const apiBase = `${SERVER_ADDR}/api/farmcrop`;

const Master = ({ isSidebarOpen }) => {
  // --- STATE MANAGEMENT ---
  const [soilTypes, setSoilTypes] = useState([]);
  const [irrigations, setIrrigations] = useState([]);
  const [waterSources, setWaterSources] = useState([]);
  const [cropTypes, setCropTypes] = useState([]);
  const [plants, setPlants] = useState([]);

  // Unified Form State
  const [form, setForm] = useState({
    soilType: "",
    irrigation: "",
    waterSource: "",
    cropType: "",
    plantName: "",
    plantCropType: "",
    plantWaterReq: "",
  });

  // UI Feedback States
  const [msg, setMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");
  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [toDelete, setToDelete] = useState(null);

  // Authentication Setup
  const access_token = localStorage.getItem("access_token");
  const authConfig = useMemo(
    () => ({ headers: { Authorization: `Bearer ${access_token}` } }),
    [access_token]
  );

  // --- LOGIC & API CALLS ---

  const fetchAll = useCallback(async () => {
    setErrorMsg("");
    if (!access_token) {
      setErrorMsg("Authentication required. Please log in again.");
      return;
    }
    try {
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
      setCropTypes(cropRes.data);
      setPlants(plantRes.data);
    } catch (err) {
      setErrorMsg("Failed to synchronize master data with server.");
    }
  }, [access_token, authConfig]);

  useEffect(() => {
    fetchAll();
  }, [fetchAll]);

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleAdd = async (type) => {
    setMsg("");
    setErrorMsg("");
    let endpoint = "";
    let body = {};

    try {
      switch (type) {
        case "soil":
          if (!form.soilType) return setErrorMsg("Soil name is required.");
          endpoint = "addsoiltypes";
          body = { name: form.soilType };
          break;
        case "irrigation":
          if (!form.irrigation) return setErrorMsg("Method name is required.");
          endpoint = "addirrigations";
          body = { method_name: form.irrigation };
          break;
        case "water":
          if (!form.waterSource) return setErrorMsg("Source name is required.");
          endpoint = "addwatersources";
          body = { source: form.waterSource };
          break;
        case "crop":
          if (!form.cropType) return setErrorMsg("Category name is required.");
          endpoint = "addcroptypes";
          body = { name: form.cropType };
          break;
        case "plant":
          if (!form.plantName || !form.plantCropType || !form.plantWaterReq) {
            return setErrorMsg("All plant fields are required.");
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
      setMsg(`${type} entry successfully registered.`);
      fetchAll();
      // Reset specific form fields
      setForm((prev) => ({
        ...prev,
        soilType: "",
        irrigation: "",
        waterSource: "",
        cropType: "",
        plantName: "",
      }));
    } catch (err) {
      setErrorMsg(err.response?.data?.message || "Server rejected the entry.");
    }
  };

  const openDeleteModal = (type, id) => {
    setToDelete({ type, id });
    setIsConfirmOpen(true);
  };

  const confirmDelete = async () => {
    setIsConfirmOpen(false);
    if (!toDelete) return;

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
      setMsg("Record successfully deleted from registry.");
      fetchAll();
    } catch (err) {
      setErrorMsg(
        "Deletion failed: Ensure no dependencies exist for this record."
      );
    }
  };

  // --- STYLES (Matching Agri-Admin Theme) ---
  const styles = `
    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;700&family=Outfit:wght@300;400;600;700&display=swap');

    :root {
      --ag-forest: rgba(5, 82, 25, 1);
      --ag-sage: #8BA888;
      --ag-leaf: #4A7C44;
      --ag-sand: #F4F1EA;
      --ag-white: #FFFFFF;
      --ag-clay: #D9C5B2;
      --ag-shadow: rgba(27, 60, 53, 0.08);
      --radius-organic: 24px;
    }

    .ag-master-wrapper {
      min-height: 80vh;
      background: transparent;
      font-family: 'Outfit', sans-serif;
      padding: 30px;
      transition: margin-left 0.4s ease;
      color: var(--ag-forest);
    }

    @media (min-width: 1024px) {
      .ag-master-wrapper.sidebar-open { margin-left: 260px; }
    }

    .ag-header {
      margin-bottom: 30px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .ag-header h1 {
      font-size: 2.2rem;
      font-weight: 700;
      margin: 0;
      display: flex;
      align-items: center;
      gap: 15px;
    }

    /* Stats Overview Bar */
    .ag-stats-bar {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
      gap: 15px;
      margin-bottom: 35px;
    }

    .stat-pill {
      background: var(--ag-white);
      padding: 15px 20px;
      border-radius: 18px;
      box-shadow: 0 4px 12px var(--ag-shadow);
      border: 1px solid rgba(139, 168, 136, 0.2);
    }

    .stat-pill label {
      display: block;
      font-size: 0.7rem;
      text-transform: uppercase;
      font-weight: 700;
      color: var(--ag-sage);
      margin-bottom: 4px;
    }

    .stat-pill span {
      font-size: 1.5rem;
      font-weight: 700;
      color: var(--ag-forest);
    }

    /* Main Grid */
    .master-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 25px;
    }

    .master-card {
      background: var(--ag-white);
      border-radius: var(--radius-organic);
      padding: 25px;
      box-shadow: 0 10px 30px var(--ag-shadow);
      border: 1px solid rgba(139, 168, 136, 0.1);
      display: flex;
      flex-direction: column;
      height: 650px;
      box-sizing: border-box; /* FIX: Critical for input containment */
      position: relative;
    }

    .card-title {
      font-size: 1.25rem;
      font-weight: 700;
      margin-bottom: 20px;
      display: flex;
      align-items: center;
      gap: 12px;
      color: var(--ag-forest);
      border-bottom: 2px solid var(--ag-sand);
      padding-bottom: 15px;
    }

    /* Form Elements */
    .master-form {
      display: flex;
      gap: 10px;
      margin-bottom: 20px;
      width: 100%;
      box-sizing: border-box;
    }

    .master-input {
      flex: 1;
      padding: 12px 15px;
      border-radius: 12px;
      border: 1.5px solid #EAEAEA;
      background: #FAFAFA;
      font-family: inherit;
      font-size: 0.9rem;
      box-sizing: border-box; /* FIX: Prevents outbound */
      width: 100%;
      min-width: 0;
      transition: all 0.3s ease;
    }

    .master-input:focus {
      border-color: var(--ag-leaf);
      outline: none;
      background: #FFFFFF;
      box-shadow: 0 0 0 4px rgba(74, 124, 68, 0.1);
    }

    .btn-add {
      background: var(--ag-forest);
      color: white;
      border: none;
      border-radius: 12px;
      padding: 10px 18px;
      font-weight: 700;
      cursor: pointer;
      transition: all 0.3s ease;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .btn-add:hover {
      background: var(--ag-leaf);
      transform: translateY(-2px);
    }

    .btn-enroll {
      width: 100%;
      padding: 14px;
      margin-top: 5px;
      background: var(--ag-forest);
      color: white;
      border: none;
      border-radius: 12px;
      font-weight: 700;
      cursor: pointer;
      transition: 0.3s;
    }

    /* List Area & Scrollbar FIX */
    .master-list {
      flex: 1;
      overflow-y: auto;
      padding-right: 8px; /* Room for scrollbar */
      box-sizing: border-box;
    }

    /* Visible Persistent Scrollbar */
    .master-list::-webkit-scrollbar {
      width: 6px;
    }

    .master-list::-webkit-scrollbar-track {
      background: var(--ag-sand);
      border-radius: 10px;
    }

    .master-list::-webkit-scrollbar-thumb {
      background: var(--ag-clay);
      border-radius: 10px;
      border: 1px solid var(--ag-sand);
    }

    .master-list::-webkit-scrollbar-thumb:hover {
      background: var(--ag-sage);
    }

    .list-item {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 14px 18px;
      background: var(--ag-sand);
      margin-bottom: 10px;
      border-radius: 14px;
      transition: all 0.2s ease;
      animation: slideIn 0.3s ease-out;
    }

    .list-item:hover {
      background: #EBE8DE;
      transform: translateX(4px);
    }

    .item-info b {
      display: block;
      font-size: 0.95rem;
      color: var(--ag-forest);
    }

    .item-subtext {
      font-size: 0.75rem;
      color: var(--ag-sage);
      margin-top: 2px;
    }

    .btn-delete {
      color: #E74C3C;
      background: rgba(231, 76, 60, 0.1);
      border: none;
      width: 32px;
      height: 32px;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all 0.2s;
    }

    .btn-delete:hover {
      background: #E74C3C;
      color: white;
    }

    /* Alerts */
    .ag-alert {
      padding: 15px 20px;
      border-radius: 12px;
      margin-bottom: 25px;
      display: flex;
      align-items: center;
      gap: 12px;
      font-weight: 600;
      animation: fadeIn 0.4s ease;
    }
    .ag-alert.success { background: #E6F4EA; color: #1E7E34; border: 1px solid #B7E1CD; }
    .ag-alert.error { background: #FDECEA; color: #C53030; border: 1px solid #F5C6CB; }

    /* Modals */
    .modal-overlay {
      position: fixed;
      inset: 0;
      background: rgba(27, 60, 53, 0.5);
      backdrop-filter: blur(6px);
      z-index: 9999;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .modal-box {
      background: white;
      padding: 40px;
      border-radius: 30px;
      max-width: 400px;
      width: 90%;
      text-align: center;
      box-shadow: 0 20px 50px rgba(0,0,0,0.2);
    }

    @keyframes slideIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
  `;

  return (
    <div className={`ag-master-wrapper ${isSidebarOpen ? "sidebar-open" : ""}`}>
      <style>{styles}</style>

      {/* Overview Stats Bar */}
      <div className="ag-stats-bar">
        <div className="stat-pill">
          <label>Soil types</label>
          <span>{soilTypes.length}</span>
        </div>
        <div className="stat-pill">
          <label>irrigation Methods</label>
          <span>{irrigations.length}</span>
        </div>
        <div className="stat-pill">
          <label>Water Sources</label>
          <span>{waterSources.length}</span>
        </div>
        <div className="stat-pill">
          <label>Crop Types</label>
          <span>{cropTypes.length}</span>
        </div>
        <div className="stat-pill">
          <label>Plants</label>
          <span>{plants.length}</span>
        </div>
      </div>

      {/* Status Messages */}
      {msg && (
        <div className="ag-alert success">
          <CheckCircle size={20} /> {msg}
        </div>
      )}
      {errorMsg && (
        <div className="ag-alert error">
          <AlertCircle size={20} /> {errorMsg}
        </div>
      )}

      <div className="master-grid">
        {/* SOIL TYPES CARD */}
        <div className="master-card">
          <div className="card-title">
            <Zap size={22} color="#F1C40F" /> Soil Types
          </div>
          <div className="master-form">
            <input
              className="master-input"
              name="soilType"
              value={form.soilType}
              onChange={handleChange}
              placeholder="Alluvial, Black..."
            />
            <button className="btn-add" onClick={() => handleAdd("soil")}>
              <Plus size={20} />
            </button>
          </div>
          <div className="master-list">
            {soilTypes.map((s) => (
              <div className="list-item" key={s.soil_type_id}>
                <div className="item-info">
                  <b>{s.name}</b>
                </div>
                <button
                  className="btn-delete"
                  onClick={() => openDeleteModal("soil", s.soil_type_id)}
                >
                  <Trash2 size={16} />
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* IRRIGATION CARD */}
        <div className="master-card">
          <div className="card-title">
            <Droplets size={22} color="#3498DB" /> Irrigation Methods
          </div>
          <div className="master-form">
            <input
              className="master-input"
              name="irrigation"
              value={form.irrigation}
              onChange={handleChange}
              placeholder="Drip, Sprinkler..."
            />
            <button className="btn-add" onClick={() => handleAdd("irrigation")}>
              <Plus size={20} />
            </button>
          </div>
          <div className="master-list">
            {irrigations.map((i) => (
              <div className="list-item" key={i.irrigation_id}>
                <div className="item-info">
                  <b>{i.method_name}</b>
                </div>
                <button
                  className="btn-delete"
                  onClick={() => openDeleteModal("irrigation", i.irrigation_id)}
                >
                  <Trash2 size={16} />
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* WATER SOURCES CARD */}
        <div className="master-card">
          <div className="card-title">
            <Sun size={22} color="#E67E22" /> Water Sources
          </div>
          <div className="master-form">
            <input
              className="master-input"
              name="waterSource"
              value={form.waterSource}
              onChange={handleChange}
              placeholder="Well, Canal..."
            />
            <button className="btn-add" onClick={() => handleAdd("water")}>
              <Plus size={20} />
            </button>
          </div>
          <div className="master-list">
            {waterSources.map((w) => (
              <div className="list-item" key={w.water_src_id}>
                <div className="item-info">
                  <b>{w.source}</b>
                </div>
                <button
                  className="btn-delete"
                  onClick={() => openDeleteModal("water", w.water_src_id)}
                >
                  <Trash2 size={16} />
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* CROP CATEGORIES CARD */}
        <div className="master-card">
          <div className="card-title">
            <Layers size={22} color="#27AE60" /> Crop Categories
          </div>
          <div className="master-form">
            <input
              className="master-input"
              name="cropType"
              value={form.cropType}
              onChange={handleChange}
              placeholder="Cereals, Fruits..."
            />
            <button className="btn-add" onClick={() => handleAdd("crop")}>
              <Plus size={20} />
            </button>
          </div>
          <div className="master-list">
            {cropTypes.map((c) => (
              <div className="list-item" key={c.crop_type_id}>
                <div className="item-info">
                  <b>{c.name}</b>
                </div>
                <button
                  className="btn-delete"
                  onClick={() => openDeleteModal("crop", c.crop_type_id)}
                >
                  <Trash2 size={16} />
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* PLANT CATALOG CARD (FIXED) */}
        <div className="master-card">
          <div className="card-title">
            <Sprout size={22} color="#1B3C35" /> Plant Catalog
          </div>

          <div
            className="master-form"
            style={{ flexDirection: "column", gap: "8px" }}
          >
            <input
              className="master-input"
              name="plantName"
              value={form.plantName}
              onChange={handleChange}
              placeholder="Plant Name (e.g. Wheat)"
            />

            <div style={{ display: "flex", gap: "8px", width: "100%" }}>
              <select
                className="master-input"
                name="plantCropType"
                value={form.plantCropType}
                onChange={handleChange}
              >
                <option value="">Select Category</option>
                {cropTypes.map((ct) => (
                  <option key={ct.crop_type_id} value={ct.crop_type_id}>
                    {ct.name}
                  </option>
                ))}
              </select>

              <select
                className="master-input"
                name="plantWaterReq"
                value={form.plantWaterReq}
                onChange={handleChange}
              >
                <option value="">Water Req</option>
                {["Low", "Medium", "High"].map((r) => (
                  <option key={r} value={r}>
                    {r}
                  </option>
                ))}
              </select>
            </div>

            <button className="btn-enroll" onClick={() => handleAdd("plant")}>
              Add plant
            </button>
          </div>

          <div className="master-list">
            {plants.length > 0 ? (
              plants.map((p) => (
                <div className="list-item" key={p.plant_id}>
                  <div className="item-info">
                    <b>{p.plant_name}</b>
                    <div className="item-subtext">
                      Water Demand: {p.water_requirement}
                    </div>
                  </div>
                  <button
                    className="btn-delete"
                    onClick={() => openDeleteModal("plant", p.plant_id)}
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              ))
            ) : (
              <div
                style={{
                  textAlign: "center",
                  marginTop: "40px",
                  color: "#AAA",
                }}
              >
                <Database
                  size={40}
                  style={{ opacity: 0.3, marginBottom: "10px" }}
                />
                <p>No plants discovered</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* DELETION MODAL */}
      {isConfirmOpen && (
        <div className="modal-overlay">
          <div className="modal-box">
            <div
              style={{
                background: "#FDECEA",
                color: "#E74C3C",
                width: "60px",
                height: "60px",
                borderRadius: "50%",
                display: "flex",
                alignItems: "center",
                justifycontent: "center",
                margin: "0 auto 20px",
              }}
            >
              <AlertCircle size={32} />
            </div>
            <h3 style={{ margin: "0 0 10px 0", fontSize: "1.5rem" }}>
              delete Record?
            </h3>
            <p style={{ color: "#666", marginBottom: "30px" }}>
              This action will permanently remove this entry from the master
              database. This cannot be undone.
            </p>
            <div style={{ display: "flex", gap: "12px" }}>
              <button
                className="btn-enroll"
                style={{ background: "#E74C3C", margin: 0 }}
                onClick={confirmDelete}
              >
                Confirm Delete
              </button>
              <button
                className="btn-enroll"
                style={{ background: "#F0F0F0", color: "#333", margin: 0 }}
                onClick={() => setIsConfirmOpen(false)}
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

export default Master;
