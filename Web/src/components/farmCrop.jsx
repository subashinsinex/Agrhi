// src/pages/farmCrop.jsx
import React, { useEffect, useState } from "react";
import {
  FaSeedling,
  FaHome,
  FaPlus,
  FaPen,
  FaTimes,
  FaSave,
  FaLandmark,
  FaMapMarkerAlt,
  FaTint,
  FaSun,
  FaFlask,
  FaSearch,
  FaHistory,
  FaLeaf,
} from "react-icons/fa";
import { axiosInstance } from "../api/login";
import { SERVER_IP, SERVER_PORT } from "../constant";

// --- THEME CONSTANTS ---
const COLORS = {
  primary: "rgba(5, 82, 25, 1)", // Forest Green
  primaryDark: "#1B5E20",
  secondary: "#81C784", // Light Green
  accent: "#FFA000", // Harvest Gold (for alerts/highlights)
  bg: "#F4F7F4", // Minty Off-White
  cardBg: "#FFFFFF",
  text: "#263238",
  textLight: "#546E7A",
  border: "#E0E0E0",
  danger: "#D32F2F",
  successBg: "#E8F5E9",
  successText: "#2E7D32",
};

// --- STYLES OBJECT ---
const styles = {
  pageWrapper: {
    minHeight: "100vh",
    background: "transparent",
    padding: "40px",
    fontFamily: "'Outfit', 'Segoe UI', sans-serif",
    color: COLORS.text,
  },
  // Header Section
  headerRow: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    flexWrap: "wrap",
    gap: 20,
    marginBottom: 40,
  },
  titleBlock: {
    display: "flex",
    flexDirection: "column",
  },
  title: {
    fontSize: "2rem",
    fontWeight: 800,
    color: COLORS.primaryDark,
    margin: 0,
    letterSpacing: "-0.5px",
  },
  subtitle: {
    color: COLORS.textLight,
    fontSize: "1rem",
    marginTop: 5,
  },
  controlsBlock: {
    display: "flex",
    gap: 15,
    alignItems: "center",
  },
  searchBar: {
    background: "#fff",
    borderRadius: "12px",
    padding: "10px 20px",
    display: "flex",
    alignItems: "center",
    gap: 12,
    boxShadow: "0 4px 15px rgba(0,0,0,0.05)",
    width: 300,
    border: `1px solid ${COLORS.border}`,
  },
  searchInput: {
    border: "none",
    outline: "none",
    width: "100%",
    fontSize: "0.95rem",
    color: COLORS.text,
  },
  primaryBtn: {
    background: `linear-gradient(135deg, ${COLORS.primary} 0%, ${COLORS.primaryDark} 100%)`,
    color: "#fff",
    border: "none",
    padding: "12px 24px",
    borderRadius: "12px",
    display: "flex",
    alignItems: "center",
    gap: 10,
    cursor: "pointer",
    fontWeight: 600,
    fontSize: "0.95rem",
    boxShadow: "0 4px 15px rgba(46, 125, 50, 0.3)",
    transition: "transform 0.2s",
  },

  // Stats Dashboard
  statsRow: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
    gap: 24,
    marginBottom: 40,
  },
  statCard: {
    background: "#fff",
    borderRadius: 16,
    padding: "20px 24px",
    display: "flex",
    alignItems: "center",
    gap: 20,
    boxShadow: "0 10px 25px rgba(0,0,0,0.04)",
    border: "1px solid rgba(0,0,0,0.02)",
    position: "relative",
    overflow: "hidden",
  },
  statIconBox: {
    width: 56,
    height: 56,
    borderRadius: 14,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background: COLORS.successBg,
    color: COLORS.primary,
    fontSize: "1.5rem",
  },
  statInfo: {
    display: "flex",
    flexDirection: "column",
  },
  statLabel: {
    fontSize: "0.85rem",
    fontWeight: 600,
    color: COLORS.textLight,
    textTransform: "uppercase",
    letterSpacing: "0.5px",
  },
  statValue: {
    fontSize: "1.8rem",
    fontWeight: 800,
    color: COLORS.text,
    lineHeight: 1.2,
  },

  // Form Section (Add/Edit Farm)
  formPanel: {
    background: "#fff",
    borderRadius: 20,
    boxShadow: "0 20px 40px rgba(0,0,0,0.08)",
    padding: 32,
    marginBottom: 40,
    border: `1px solid ${COLORS.secondary}40`,
  },
  formHeader: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 24,
    paddingBottom: 16,
    borderBottom: `1px dashed ${COLORS.border}`,
  },
  formTitle: {
    fontSize: "1.4rem",
    fontWeight: 700,
    color: COLORS.primaryDark,
    display: "flex",
    alignItems: "center",
    gap: 10,
  },
  formGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(250px, 1fr))",
    gap: 24,
  },
  fieldGroup: {
    display: "flex",
    flexDirection: "column",
    gap: 8,
  },
  label: {
    fontSize: "0.85rem",
    fontWeight: 600,
    color: COLORS.textLight,
  },
  input: {
    padding: "12px 16px",
    borderRadius: 10,
    border: `1px solid ${COLORS.border}`,
    fontSize: "0.95rem",
    width: "100%",
    boxSizing: "border-box",
    transition: "all 0.2s",
    background: "#FAFAFA",
  },

  // Farm Cards Grid
  farmsGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(360px, 1fr))",
    gap: 30,
    alignItems: "start",
  },
  farmCard: {
    background: "#fff",
    borderRadius: 20,
    boxShadow: "0 10px 30px rgba(0,0,0,0.06)",
    transition: "all 0.3s ease",
    border: "1px solid rgba(0,0,0,0.03)",
    overflow: "hidden",
    display: "flex",
    flexDirection: "column",
  },
  farmCardHeader: {
    padding: "20px 24px",
    background: `linear-gradient(to right, ${COLORS.primaryDark}08, transparent)`,
    borderBottom: `1px solid ${COLORS.border}`,
    display: "flex",
    justifyContent: "space-between",
    alignItems: "flex-start",
  },
  farmIdentity: {
    display: "flex",
    gap: 14,
    alignItems: "center",
  },
  farmIcon: {
    width: 48,
    height: 48,
    borderRadius: 12,
    background: COLORS.primary,
    color: "#fff",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    fontSize: "1.2rem",
    boxShadow: "0 4px 10px rgba(46, 125, 50, 0.4)",
  },
  farmName: {
    fontSize: "1.2rem",
    fontWeight: 700,
    color: COLORS.text,
  },
  farmMeta: {
    fontSize: "0.8rem",
    color: COLORS.textLight,
    marginTop: 2,
  },
  farmBody: {
    padding: "20px 24px",
  },
  tagGrid: {
    display: "grid",
    gridTemplateColumns: "1fr 1fr",
    gap: 12,
    marginBottom: 20,
  },
  infoPill: {
    background: COLORS.bg,
    padding: "8px 12px",
    borderRadius: 8,
    fontSize: "0.85rem",
    color: COLORS.text,
    display: "flex",
    alignItems: "center",
    gap: 8,
    border: "1px solid transparent",
  },
  activeCropBanner: {
    background: COLORS.successBg,
    color: COLORS.successText,
    padding: "8px 12px",
    borderRadius: 8,
    fontSize: "0.85rem",
    fontWeight: 600,
    display: "flex",
    alignItems: "center",
    gap: 8,
    marginTop: 10,
  },
  farmFooter: {
    padding: "16px 24px",
    borderTop: `1px solid ${COLORS.border}`,
    display: "flex",
    justifyContent: "flex-end",
    gap: 10,
    background: "#FAFAFA",
  },
  ghostBtn: {
    background: "transparent",
    border: `1px solid ${COLORS.border}`,
    color: COLORS.textLight,
    padding: "8px 16px",
    borderRadius: 8,
    fontSize: "0.85rem",
    fontWeight: 600,
    cursor: "pointer",
    display: "flex",
    alignItems: "center",
    gap: 6,
    transition: "all 0.2s",
  },

  // Modal (Reused Logic)
  modalOverlay: {
    position: "fixed",
    inset: 0,
    background: "rgba(19, 15, 64, 0.6)", // Darker overlay
    backdropFilter: "blur(4px)",
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    zIndex: 1100,
    animation: "fadeIn 0.2s",
  },
  modalContent: {
    background: "#fff",
    width: "90%",
    maxWidth: 650,
    borderRadius: 24,
    padding: 30,
    boxShadow: "0 25px 50px rgba(0,0,0,0.25)",
    maxHeight: "85vh",
    overflowY: "auto",
    position: "relative",
  },
  modalHeader: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 24,
  },
  modalTitle: {
    fontSize: "1.5rem",
    fontWeight: 700,
    color: COLORS.primaryDark,
    display: "flex",
    alignItems: "center",
    gap: 10,
  },

  // Alerts
  alert: {
    padding: "16px",
    borderRadius: 12,
    marginBottom: 20,
    display: "flex",
    alignItems: "center",
    gap: 12,
    fontSize: "0.9rem",
    fontWeight: 500,
  },
};

// --- LOGIC (UNCHANGED) ---
const apiBase = `http://${SERVER_IP}:${SERVER_PORT}/api/farmcrop`;

const initialFarmForm = {
  phone_number: "",
  farm_size: "",
  survey_number: "",
  soil_type_ids: [],
  irrigation_ids: [],
  water_src_ids: [],
  owner_name: "",
  location: "",
};

const initialCropForm = {
  farm_id: "",
  plant_id: "",
  planting_date: "",
  harvest_date: "",
  field_size: "",
  status: "",
  is_active: true,
};

const FarmCrop = () => {
  // DATA STATES
  const [farms, setFarms] = useState([]);
  const [crops, setCrops] = useState([]);
  const [soilTypes, setSoilTypes] = useState([]);
  const [irrigations, setIrrigations] = useState([]);
  const [waterSources, setWaterSources] = useState([]);
  const [plants, setPlants] = useState([]);
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState("");

  // UI STATES
  const [searchTerm, setSearchTerm] = useState("");

  // FORM STATES
  const [farmForm, setFarmForm] = useState(initialFarmForm);
  const [showFarmForm, setShowFarmForm] = useState(false);
  const [editFarmId, setEditFarmId] = useState(null);
  const [editFarmForm, setEditFarmForm] = useState(initialFarmForm);

  // MODAL STATES
  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [showCropFormModal, setShowCropFormModal] = useState(false);
  const [selectedFarmForModal, setSelectedFarmForModal] = useState(null);
  const [selectedCropForEdit, setSelectedCropForEdit] = useState(null);
  const [cropForm, setCropForm] = useState(initialCropForm);

  // NOTIFICATION STATES
  const [farmStatusMsg, setFarmStatusMsg] = useState("");
  const [farmErrorMsg, setFarmErrorMsg] = useState("");
  const [cropStatusMsg, setCropStatusMsg] = useState("");
  const [cropErrorMsg, setCropErrorMsg] = useState("");

  const cropsForFarm = (farmId) =>
    crops.filter((c) => String(c.farm_id) === String(farmId));

  // --- API CALLS ---
  const fetchData = () => {
    const accessToken = localStorage.getItem("access_token");
    if (!accessToken) {
      setErrorMsg("Authentication: access token missing.");
      setLoading(false);
      return;
    }
    setLoading(true);
    Promise.all([
      axiosInstance.get(`${apiBase}/farms`, {
        headers: { Authorization: `Bearer ${accessToken}` },
      }),
      axiosInstance.get(`${apiBase}/crops`, {
        headers: { Authorization: `Bearer ${accessToken}` },
      }),
    ])
      .then(([farmRes, cropRes]) => {
        setFarms(farmRes.data ?? []);
        setCrops(cropRes.data ?? []);
      })
      .catch((err) =>
        setErrorMsg(
          `Error loading data: ${err.response?.data?.message || err.message}`
        )
      )
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    fetchData();
  }, []);

  useEffect(() => {
    if (
      !showFarmForm &&
      !editFarmId &&
      !showCropFormModal &&
      !selectedCropForEdit
    )
      return;

    const accessToken = localStorage.getItem("access_token");
    const headers = { Authorization: `Bearer ${accessToken}` };
    const fetchMaster = (endpoint, setter) =>
      axiosInstance
        .get(`${apiBase}/masters/${endpoint}`, { headers })
        .then((res) => setter(res.data))
        .catch(() => setter([]));

    fetchMaster("soiltypes", setSoilTypes);
    fetchMaster("irrigations", setIrrigations);
    fetchMaster("watersources", setWaterSources);
    fetchMaster("plants", setPlants);
  }, [showFarmForm, editFarmId, showCropFormModal, selectedCropForEdit]);

  // --- HANDLERS ---
  const handleFarmInput = (e, isEdit = false) => {
    const { name, value } = e.target;
    if (isEdit) setEditFarmForm((p) => ({ ...p, [name]: value }));
    else setFarmForm((p) => ({ ...p, [name]: value }));
  };

  const handleMultiSelect = (e, isEdit = false) => {
    const { name, options } = e.target;
    const values = Array.from(options)
      .filter((o) => o.selected)
      .map((o) => o.value);
    if (isEdit) setEditFarmForm((p) => ({ ...p, [name]: values }));
    else setFarmForm((p) => ({ ...p, [name]: values }));
  };

  const submitFarm = async (e) => {
    e.preventDefault();
    setFarmStatusMsg("");
    setFarmErrorMsg("");
    try {
      const accessToken = localStorage.getItem("access_token");
      const headers = { Authorization: `Bearer ${accessToken}` };
      if (editFarmId) {
        await axiosInstance.put(
          `${apiBase}/updatefarms/${editFarmId}`,
          editFarmForm,
          { headers }
        );
        setFarmStatusMsg("Farm updated successfully!");
      } else {
        await axiosInstance.post(`${apiBase}/addfarms`, farmForm, { headers });
        setFarmStatusMsg("Farm added successfully!");
      }
      setTimeout(() => {
        setShowFarmForm(false);
        setEditFarmId(null);
        setFarmForm(initialFarmForm);
        setFarmStatusMsg("");
        fetchData();
      }, 1000);
    } catch (err) {
      setFarmErrorMsg(
        err.response?.data?.message || "Unable to save farm, verify inputs."
      );
    }
  };

  const handleCropInput = (e) => {
    const { name, value } = e.target;
    setCropForm((p) => ({ ...p, [name]: value }));
  };

  const submitCrop = async (e) => {
    e.preventDefault();
    setCropStatusMsg("");
    setCropErrorMsg("");
    try {
      const accessToken = localStorage.getItem("access_token");
      const headers = { Authorization: `Bearer ${accessToken}` };

      // Helper to find soil type name just for data consistency in backend payload
      // (This logic was in original code, preserving it)
      const getSoilName = (sid) =>
        soilTypes.find((t) => String(t.soil_type_id) === String(sid))?.name ||
        "";

      if (selectedCropForEdit) {
        const payload = {
          ...cropForm,
          soil_type_name: getSoilName(cropForm.soil_type_id),
        };
        await axiosInstance.put(
          `${apiBase}/updatecrops/${selectedCropForEdit.user_crop_id}`,
          payload,
          { headers }
        );
        setCropStatusMsg("Crop updated successfully!");
      } else {
        const payload = {
          ...cropForm,
          soil_type_name: getSoilName(cropForm.soil_type_id),
        };
        await axiosInstance.post(`${apiBase}/addcrops`, payload, { headers });
        setCropStatusMsg("Crop added successfully!");
      }

      setTimeout(() => {
        fetchData();
        setCropStatusMsg("");
        if (showHistoryModal) {
          // If we edited from history, go back to history?
          // Or close crop modal.
          setShowCropFormModal(false);
          setSelectedCropForEdit(null);
          // Re-opening history might require refetching farm data inside modal
          // but crops are fetched globally, so it should be fine.
          setShowHistoryModal(true);
        } else {
          setShowCropFormModal(false);
        }
      }, 1000);
    } catch (err) {
      setCropErrorMsg(
        err.response?.data?.message || "Unable to save crop details."
      );
    }
  };

  // --- FILTERS & STATS ---
  const filteredFarms = farms.filter((farm) => {
    if (!searchTerm) return true;
    return (farm.owner_name || "")
      .toLowerCase()
      .includes(searchTerm.toLowerCase());
  });

  const totalFarms = farms.length;
  const totalCrops = crops.length;
  const activeCropsCount = crops.filter((c) => c.status !== "Harvested").length;

  return (
    <div style={styles.pageWrapper}>
      {/* Global Global CSS Reset/Utilities */}
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&display=swap');
        
        * { box-sizing: border-box; }
        
        /* Smooth Scrollbar */
        ::-webkit-scrollbar { width: 8px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: #CBD5E0; border-radius: 4px; }
        ::-webkit-scrollbar-thumb:hover { background: #A0AEC0; }

        button:active { transform: scale(0.98); }
        
        input:focus, select:focus {
          border-color: ${COLORS.primary} !important;
          box-shadow: 0 0 0 3px rgba(46, 125, 50, 0.15) !important;
          background: #fff !important;
          outline: none;
        }

        .farm-card:hover {
          transform: translateY(-5px);
          box-shadow: 0 20px 40px rgba(0,0,0,0.08) !important;
        }

        .ghost-btn:hover {
          background: ${COLORS.successBg} !important;
          color: ${COLORS.primary} !important;
          border-color: ${COLORS.primary} !important;
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }
      `}</style>

      {/* --- HEADER --- */}
      <div style={styles.headerRow}>
        <div style={styles.titleBlock}>
          <h1 style={styles.title}>Farm & Crop Manager</h1>
          <span style={styles.subtitle}>
            Monitor fields, track harvests, and manage agricultural assets.
          </span>
        </div>

        <div style={styles.controlsBlock}>
          <div style={styles.searchBar}>
            <FaSearch color={COLORS.textLight} />
            <input
              style={styles.searchInput}
              placeholder="Find farmer..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <button
            style={styles.primaryBtn}
            onClick={() => {
              setFarmForm(initialFarmForm);
              setShowFarmForm(true);
              setEditFarmId(null);
            }}
          >
            <FaPlus /> New Farm
          </button>
        </div>
      </div>

      {/* --- DASHBOARD STATS --- */}
      <div style={styles.statsRow}>
        <div style={styles.statCard}>
          <div style={styles.statIconBox}>
            <FaLandmark />
          </div>
          <div style={styles.statInfo}>
            <span style={styles.statLabel}>Total Farms</span>
            <span style={styles.statValue}>{totalFarms}</span>
          </div>
        </div>
        <div style={styles.statCard}>
          <div style={styles.statIconBox}>
            <FaLeaf />
          </div>
          <div style={styles.statInfo}>
            <span style={styles.statLabel}>Total Crops</span>
            <span style={styles.statValue}>{totalCrops}</span>
          </div>
        </div>
        <div style={styles.statCard}>
          <div style={styles.statIconBox}>
            <FaSun />
          </div>
          <div style={styles.statInfo}>
            <span style={styles.statLabel}>Active Fields</span>
            <span style={styles.statValue}>{activeCropsCount}</span>
          </div>
        </div>
      </div>

      {/* --- NOTIFICATIONS --- */}
      {errorMsg && (
        <div
          style={{
            ...styles.alert,
            background: "#FFEBEE",
            color: COLORS.danger,
          }}
        >
          <FaTimes /> {errorMsg}
        </div>
      )}
      {(cropStatusMsg || cropErrorMsg) && !showCropFormModal && (
        <div style={{ marginBottom: 20 }}>
          {cropStatusMsg && (
            <div
              style={{
                ...styles.alert,
                background: COLORS.successBg,
                color: COLORS.successText,
              }}
            >
              <FaSun /> {cropStatusMsg}
            </div>
          )}
        </div>
      )}

      {/* --- FARM FORM (INLINE PANEL) --- */}
      {showFarmForm && (
        <div style={{ ...styles.formPanel, animation: "fadeIn 0.4s ease" }}>
          <div style={styles.formHeader}>
            <div style={styles.formTitle}>
              {editFarmId ? <FaPen /> : <FaPlus />}
              {editFarmId ? "Edit Farm Details" : "Register New Farm"}
            </div>
            <button
              onClick={() => {
                setShowFarmForm(false);
                setEditFarmId(null);
              }}
              style={{
                border: "none",
                background: "transparent",
                cursor: "pointer",
                color: COLORS.textLight,
              }}
            >
              <FaTimes size={20} />
            </button>
          </div>

          <form onSubmit={submitFarm}>
            <div style={styles.formGrid}>
              {/* Left Col: Personal */}
              <div style={styles.fieldGroup}>
                <label style={styles.label}>OWNER NAME</label>
                <input
                  name="owner_name"
                  placeholder="e.g. Ramesh Kumar"
                  style={styles.input}
                  value={
                    editFarmId ? editFarmForm.owner_name : farmForm.owner_name
                  }
                  onChange={(e) => handleFarmInput(e, !!editFarmId)}
                  required
                />
              </div>

              <div style={styles.fieldGroup}>
                <label style={styles.label}>CONTACT NUMBER</label>
                <input
                  name="phone_number"
                  placeholder="e.g. 9876543210"
                  style={styles.input}
                  value={
                    editFarmId
                      ? editFarmForm.phone_number
                      : farmForm.phone_number
                  }
                  onChange={(e) => handleFarmInput(e, !!editFarmId)}
                  required
                />
              </div>

              <div style={styles.fieldGroup}>
                <label style={styles.label}>LOCATION / VILLAGE</label>
                <input
                  name="location"
                  placeholder="e.g. Madurai North"
                  style={styles.input}
                  value={editFarmId ? editFarmForm.location : farmForm.location}
                  onChange={(e) => handleFarmInput(e, !!editFarmId)}
                  required
                />
              </div>

              {/* Middle Col: Land Details */}
              <div style={styles.fieldGroup}>
                <label style={styles.label}>SURVEY NUMBER</label>
                <input
                  name="survey_number"
                  placeholder="e.g. 234/A"
                  style={styles.input}
                  value={
                    editFarmId
                      ? editFarmForm.survey_number
                      : farmForm.survey_number
                  }
                  onChange={(e) => handleFarmInput(e, !!editFarmId)}
                  required
                />
              </div>

              <div style={styles.fieldGroup}>
                <label style={styles.label}>FARM SIZE (ACRES)</label>
                <input
                  type="number"
                  name="farm_size"
                  placeholder="0.0"
                  step="0.1"
                  style={styles.input}
                  value={
                    editFarmId ? editFarmForm.farm_size : farmForm.farm_size
                  }
                  onChange={(e) => handleFarmInput(e, !!editFarmId)}
                  required
                />
              </div>

              {/* Right Col: Technical */}
              <div style={styles.fieldGroup}>
                <label style={styles.label}>SOIL TYPE</label>
                <select
                  multiple
                  name="soil_type_ids"
                  style={{ ...styles.input, height: "100%" }}
                  value={
                    editFarmId
                      ? editFarmForm.soil_type_ids
                      : farmForm.soil_type_ids
                  }
                  onChange={(e) => handleMultiSelect(e, !!editFarmId)}
                  required
                >
                  {soilTypes.map((t) => (
                    <option key={t.soil_type_id} value={t.soil_type_id}>
                      {t.name}
                    </option>
                  ))}
                </select>
              </div>

              <div style={styles.fieldGroup}>
                <label style={styles.label}>IRRIGATION</label>
                <select
                  multiple
                  name="irrigation_ids"
                  style={styles.input}
                  value={
                    editFarmId
                      ? editFarmForm.irrigation_ids
                      : farmForm.irrigation_ids
                  }
                  onChange={(e) => handleMultiSelect(e, !!editFarmId)}
                  required
                >
                  {irrigations.map((ir) => (
                    <option key={ir.irrigation_id} value={ir.irrigation_id}>
                      {ir.method_name}
                    </option>
                  ))}
                </select>
              </div>

              <div style={styles.fieldGroup}>
                <label style={styles.label}>WATER SOURCE</label>
                <select
                  multiple
                  name="water_src_ids"
                  style={styles.input}
                  value={
                    editFarmId
                      ? editFarmForm.water_src_ids
                      : farmForm.water_src_ids
                  }
                  onChange={(e) => handleMultiSelect(e, !!editFarmId)}
                  required
                >
                  {waterSources.map((ws) => (
                    <option key={ws.water_src_id} value={ws.water_src_id}>
                      {ws.source}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div
              style={{
                marginTop: 30,
                display: "flex",
                gap: 15,
                justifyContent: "flex-end",
                alignItems: "center",
              }}
            >
              {farmStatusMsg && (
                <span
                  style={{
                    color: COLORS.successText,
                    fontWeight: 600,
                    marginRight: "auto",
                  }}
                >
                  {farmStatusMsg}
                </span>
              )}
              {farmErrorMsg && (
                <span
                  style={{
                    color: COLORS.danger,
                    fontWeight: 600,
                    marginRight: "auto",
                  }}
                >
                  {farmErrorMsg}
                </span>
              )}

              <button
                type="button"
                className="ghost-btn"
                style={styles.ghostBtn}
                onClick={() => {
                  setShowFarmForm(false);
                  setEditFarmId(null);
                }}
              >
                Cancel
              </button>
              <button type="submit" style={styles.primaryBtn}>
                <FaSave /> {editFarmId ? "Update Farm" : "Save Farm"}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* --- FARM LIST GRID --- */}
      {loading ? (
        <div style={{ textAlign: "center", padding: 60, color: COLORS.text }}>
          <FaSeedling
            className="spin"
            size={30}
            style={{ marginBottom: 15, color: COLORS.secondary }}
          />
          <p>Fetching agricultural data...</p>
        </div>
      ) : filteredFarms.length === 0 ? (
        <div
          style={{
            textAlign: "center",
            padding: 80,
            background: "#fff",
            borderRadius: 20,
            border: `2px dashed ${COLORS.border}`,
          }}
        >
          <FaHome size={40} color={COLORS.border} />
          <h3 style={{ color: COLORS.textLight, marginTop: 15 }}>
            No Farms Found
          </h3>
          <p style={{ color: COLORS.textLight, fontSize: "0.9rem" }}>
            Get started by adding a new farm record.
          </p>
        </div>
      ) : (
        <div style={styles.farmsGrid}>
          {filteredFarms.map((farm) => {
            const farmCrops = cropsForFarm(farm.farm_id);
            const activeCount = farmCrops.filter(
              (c) => c.status !== "Harvested"
            ).length;

            return (
              <div
                key={farm.farm_id}
                style={styles.farmCard}
                className="farm-card"
              >
                <div style={styles.farmCardHeader}>
                  <div style={styles.farmIdentity}>
                    <div style={styles.farmIcon}>
                      <FaHome />
                    </div>
                    <div>
                      <div style={styles.farmName}>{farm.owner_name}</div>
                      <div style={styles.farmMeta}>ID: #{farm.farm_id}</div>
                    </div>
                  </div>
                  {activeCount > 0 && (
                    <div
                      style={{
                        background: COLORS.successBg,
                        color: COLORS.successText,
                        padding: "4px 8px",
                        borderRadius: 6,
                        fontSize: "0.75rem",
                        fontWeight: 700,
                      }}
                    >
                      ACTIVE
                    </div>
                  )}
                </div>

                <div style={styles.farmBody}>
                  <div style={styles.tagGrid}>
                    <div style={styles.infoPill}>
                      <FaMapMarkerAlt color={COLORS.secondary} />
                      <div
                        style={{
                          overflow: "hidden",
                          textOverflow: "ellipsis",
                          whiteSpace: "nowrap",
                        }}
                      >
                        {farm.location}
                      </div>
                    </div>
                    <div style={styles.infoPill}>
                      <FaLandmark color={COLORS.secondary} />
                      {farm.farm_size} Acre
                    </div>
                    <div style={styles.infoPill}>
                      <FaFlask color={COLORS.secondary} />
                      <div
                        style={{
                          overflow: "hidden",
                          textOverflow: "ellipsis",
                          whiteSpace: "nowrap",
                        }}
                      >
                        {Array.isArray(farm.soil_types)
                          ? farm.soil_types[0]
                          : farm.soil_type || "Soil N/A"}
                      </div>
                    </div>
                    <div style={styles.infoPill}>
                      <FaTint color={COLORS.secondary} />
                      <div
                        style={{
                          overflow: "hidden",
                          textOverflow: "ellipsis",
                          whiteSpace: "nowrap",
                        }}
                      >
                        {Array.isArray(farm.irrigation_methods)
                          ? farm.irrigation_methods[0]
                          : farm.irrigation || "Irrig. N/A"}
                      </div>
                    </div>
                  </div>

                  <div style={styles.activeCropBanner}>
                    <FaSeedling />
                    {activeCount} Active Crops
                  </div>
                </div>

                <div style={styles.farmFooter}>
                  <button
                    className="ghost-btn"
                    style={styles.ghostBtn}
                    onClick={() => {
                      setSelectedFarmForModal(farm);
                      setShowHistoryModal(true);
                    }}
                    title="History"
                  >
                    <FaHistory />
                  </button>
                  <button
                    className="ghost-btn"
                    style={styles.ghostBtn}
                    onClick={() => {
                      setSelectedFarmForModal(farm);
                      setCropForm({
                        ...initialCropForm,
                        farm_id: farm.farm_id,
                      });
                      setSelectedCropForEdit(null);
                      setShowCropFormModal(true);
                      setCropStatusMsg("");
                      setCropErrorMsg("");
                    }}
                    title="Add Crop"
                  >
                    <FaPlus /> Crop
                  </button>
                  <button
                    className="ghost-btn"
                    style={styles.ghostBtn}
                    onClick={() => {
                      setEditFarmId(farm.farm_id);
                      setEditFarmForm({
                        ...farm,
                        soil_type_ids: farm.soil_type_ids || [],
                        irrigation_ids: farm.irrigation_ids || [],
                        water_src_ids: farm.water_src_ids || [],
                      });
                      setShowFarmForm(true);
                      window.scrollTo({ top: 0, behavior: "smooth" });
                    }}
                    title="Edit Farm"
                  >
                    <FaPen /> Edit
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* --- CROP HISTORY MODAL --- */}
      {showHistoryModal && selectedFarmForModal && (
        <div
          style={styles.modalOverlay}
          onClick={() => setShowHistoryModal(false)}
        >
          <div style={styles.modalContent} onClick={(e) => e.stopPropagation()}>
            <div style={styles.modalHeader}>
              <div style={styles.modalTitle}>
                <FaHistory color={COLORS.primary} />
                History: {selectedFarmForModal.owner_name}
              </div>
              <button
                onClick={() => setShowHistoryModal(false)}
                style={{
                  background: "none",
                  border: "none",
                  cursor: "pointer",
                  color: COLORS.textLight,
                }}
              >
                <FaTimes size={20} />
              </button>
            </div>

            {cropsForFarm(selectedFarmForModal.farm_id).length === 0 ? (
              <div
                style={{
                  textAlign: "center",
                  padding: "40px",
                  color: COLORS.textLight,
                }}
              >
                No crop history available.
              </div>
            ) : (
              <div
                style={{
                  display: "flex",
                  flexDirection: "column",
                  gap: 15,
                }}
              >
                {cropsForFarm(selectedFarmForModal.farm_id).map((crop) => (
                  <div
                    key={crop.user_crop_id}
                    style={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      padding: 16,
                      background: "#F9FAFB",
                      borderRadius: 12,
                      borderLeft: `4px solid ${
                        crop.status === "Harvested"
                          ? COLORS.secondary
                          : COLORS.primary
                      }`,
                    }}
                  >
                    <div>
                      <div
                        style={{
                          fontWeight: 700,
                          color: COLORS.text,
                          fontSize: "1rem",
                        }}
                      >
                        {crop.plant_name || crop.plantname}
                      </div>
                      <div
                        style={{
                          fontSize: "0.85rem",
                          color: COLORS.textLight,
                          marginTop: 4,
                        }}
                      >
                        <span style={{ marginRight: 10 }}>
                          <FaMapMarkerAlt
                            size={10}
                            style={{ marginRight: 4 }}
                          />
                          {crop.field_size || crop.fieldsize} Acres
                        </span>
                        <span>
                          Status: <b>{crop.status}</b>
                        </span>
                      </div>
                    </div>
                    <button
                      className="ghost-btn"
                      style={styles.ghostBtn}
                      onClick={() => {
                        setShowHistoryModal(false);
                        setSelectedCropForEdit(crop);
                        const toDate = (d) =>
                          d ? new Date(d).toISOString().split("T")[0] : "";
                        setCropForm({
                          ...crop,
                          planting_date: toDate(crop.planting_date),
                          harvest_date: toDate(crop.harvest_date),
                          farm_id: crop.farm_id,
                        });
                        setShowCropFormModal(true);
                      }}
                    >
                      <FaPen size={12} /> Edit
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* --- ADD / EDIT CROP MODAL --- */}
      {showCropFormModal && (
        <div
          style={styles.modalOverlay}
          onClick={() => setShowCropFormModal(false)}
        >
          <div style={styles.modalContent} onClick={(e) => e.stopPropagation()}>
            <div style={styles.modalHeader}>
              <div style={styles.modalTitle}>
                {selectedCropForEdit ? <FaPen /> : <FaPlus />}
                {selectedCropForEdit ? "Edit Crop Details" : "Add New Crop"}
              </div>
              <button
                onClick={() => setShowCropFormModal(false)}
                style={{
                  background: "none",
                  border: "none",
                  cursor: "pointer",
                  color: COLORS.textLight,
                }}
              >
                <FaTimes size={20} />
              </button>
            </div>

            {cropErrorMsg && (
              <div
                style={{
                  ...styles.alert,
                  background: "#FFEBEE",
                  color: COLORS.danger,
                }}
              >
                {cropErrorMsg}
              </div>
            )}

            <form onSubmit={submitCrop}>
              <div style={styles.formGrid}>
                <div style={styles.fieldGroup}>
                  <label style={styles.label}>PLANT VARIETY</label>
                  <select
                    name="plant_id"
                    style={styles.input}
                    value={cropForm.plant_id || ""}
                    onChange={handleCropInput}
                    required
                  >
                    <option value="">Select Plant...</option>
                    {plants.map((p) => (
                      <option key={p.plant_id} value={p.plant_id}>
                        {p.plant_name}
                      </option>
                    ))}
                  </select>
                </div>
                <div style={styles.fieldGroup}>
                  <label style={styles.label}>FIELD SIZE (Acres)</label>
                  <input
                    type="number"
                    name="field_size"
                    style={styles.input}
                    value={cropForm.field_size || ""}
                    onChange={handleCropInput}
                    required
                  />
                </div>
                <div style={styles.fieldGroup}>
                  <label style={styles.label}>PLANTING DATE</label>
                  <input
                    type="date"
                    name="planting_date"
                    style={styles.input}
                    value={cropForm.planting_date || ""}
                    onChange={handleCropInput}
                    required
                  />
                </div>
                <div style={styles.fieldGroup}>
                  <label style={styles.label}>HARVEST DATE</label>
                  <input
                    type="date"
                    name="harvest_date"
                    style={styles.input}
                    value={cropForm.harvest_date || ""}
                    onChange={handleCropInput}
                    required
                  />
                </div>
                <div style={styles.fieldGroup}>
                  <label style={styles.label}>CURRENT STATUS</label>
                  <input
                    name="status"
                    list="statusOptions"
                    style={styles.input}
                    placeholder="e.g. Growing"
                    value={cropForm.status || ""}
                    onChange={handleCropInput}
                    required
                  />
                  <datalist id="statusOptions">
                    <option value="Planted" />
                    <option value="Growing" />
                    <option value="Harvested" />
                    <option value="Failed" />
                  </datalist>
                </div>
              </div>

              <div
                style={{
                  marginTop: 30,
                  display: "flex",
                  gap: 15,
                  justifyContent: "flex-end",
                }}
              >
                <button
                  type="button"
                  className="ghost-btn"
                  style={styles.ghostBtn}
                  onClick={() => setShowCropFormModal(false)}
                >
                  Cancel
                </button>
                <button type="submit" style={styles.primaryBtn}>
                  <FaSave /> {selectedCropForEdit ? "Update Crop" : "Save Crop"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default FarmCrop;
