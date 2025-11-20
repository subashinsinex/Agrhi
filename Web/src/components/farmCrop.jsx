import React, { useEffect, useState } from "react";
import { axiosInstance } from "../api/login";
import { SERVER_IP, SERVER_PORT } from "../constant";
// Icons for better visual appeal
import {
  FaSeedling,
  FaHome,
  FaPlus,
  FaPen,
  FaEye,
  FaTimes,
  FaSave,
  FaLandmark,
  FaMapMarkerAlt,
  FaTint,
  FaSun,
  FaFlask,
  FaSearch,
} from "react-icons/fa";

// --- COLOR DEFINITIONS ---
const PRIMARY_PURPLE = "#6c5ce7";
const PRIMARY_DARK = "#130f40";
const ACCENT_GREEN = "#2ecc71";
const BG_LIGHT = "#f5f7fa";
const TEXT_MUTED = "#666";
const BORDER_COLOR = "#e0e0e0";

// --- BASE STYLE FOR INPUT FIELDS (FIX for no-use-before-define) ---
// Extracted base properties to prevent circular reference within 'style' object.
const BASE_FIELD_STYLE = {
  padding: 14,
  borderRadius: 10,
  border: `1px solid ${BORDER_COLOR}`,
  fontSize: "1rem",
  width: "100%",
  boxSizing: "border-box",
  transition: "border-color 0.3s, box-shadow 0.3s",
};

// --- STYLE DEFINITIONS ---
const style = {
  pageContainer: {
    padding: "40px 20px",
    background: BG_LIGHT,
    minHeight: "100vh",
    fontFamily: "'Inter', Arial, sans-serif",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
  },
  contentWrapper: { width: "100%", maxWidth: 1200 },
  pageTitle: {
    fontWeight: 800,
    color: PRIMARY_DARK,
    marginBottom: "2rem",
    fontSize: "2.5rem",
    display: "flex",
    alignItems: "center",
    gap: "15px",
  },
  farmCard: {
    background: "#fff",
    borderRadius: 16,
    boxShadow: "0 10px 40px rgba(0, 0, 0, 0.08)",
    margin: "2rem 0",
    padding: "2.5rem",
    width: "100%",
    transition: "transform 0.3s ease-in-out", // Animation
    "&:hover": { transform: "translateY(-5px)" },
  },
  cropCard: {
    background: "#ffffff",
    borderRadius: 10,
    margin: "0.75rem 0",
    padding: "1.5rem",
    borderLeft: `5px solid ${ACCENT_GREEN}`,
    fontSize: "0.95rem",
    boxShadow: "0 2px 10px rgba(0, 0, 0, 0.05)",
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
    gap: "10px 30px",
    transition: "all 0.3s", // Animation
    "&:hover": { borderLeftColor: PRIMARY_PURPLE, background: "#f9faff" },
  },
  addEditFormCard: {
    // Unified style for add/edit forms
    background: "#fff",
    borderRadius: 12,
    boxShadow: "0 6px 20px rgba(0, 0, 0, 0.05)",
    margin: "1.5rem 0",
    padding: "2rem",
    borderTop: `5px solid ${PRIMARY_PURPLE}`,
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(250px, 1fr))",
    gap: "20px",
  },
  formField: {
    ...BASE_FIELD_STYLE, // Use the base style
    "&:focus": {
      borderColor: PRIMARY_PURPLE,
      boxShadow: "0 0 0 3px rgba(108, 92, 231, 0.1)",
    },
  },
  primaryButton: {
    background: PRIMARY_PURPLE,
    color: "#fff",
    padding: "1rem 2.5rem",
    borderRadius: 10,
    border: "none",
    fontWeight: 700,
    fontSize: "1.1rem",
    cursor: "pointer",
    marginBottom: "1.5rem",
    boxShadow: "0 6px 20px rgba(108, 92, 231, 0.3)",
    transition: "background 0.3s, transform 0.1s", // Animation
    display: "flex",
    alignItems: "center",
    gap: "10px",
    "&:hover": { background: PRIMARY_DARK, transform: "translateY(-1px)" },
    "&:active": { transform: "translateY(0)" },
  },
  submitButton: {
    background: ACCENT_GREEN,
    color: "#fff",
    fontWeight: 700,
    border: "none",
    cursor: "pointer",
    padding: 14,
    borderRadius: 10,
    fontSize: "1rem",
    width: "100%",
    boxSizing: "border-box",
    gridColumn: "span 1",
    transition: "background 0.3s", // Animation
    "&:hover": { background: "#27ae60" },
  },
  cancelButton: {
    background: BORDER_COLOR,
    color: PRIMARY_DARK,
    fontWeight: 600,
    border: "none",
    cursor: "pointer",
    padding: 14,
    borderRadius: 10,
    fontSize: "1rem",
    width: "100%",
    boxSizing: "border-box",
    gridColumn: "span 1",
    transition: "background 0.3s", // Animation
    "&:hover": { background: "#ccc" },
  },
  secondaryButtonBase: {
    background: "#fff",
    color: PRIMARY_PURPLE,
    border: `1px solid ${PRIMARY_PURPLE}`,
    fontWeight: 600,
    padding: "0.8rem 1.2rem",
    borderRadius: 8,
    cursor: "pointer",
    fontSize: "0.9rem",
    transition: "all 0.3s", // Animation
    display: "flex",
    alignItems: "center",
    gap: "8px",
    "&:hover": {
      background: PRIMARY_PURPLE,
      color: "#fff",
      boxShadow: "0 2px 10px rgba(108, 92, 231, 0.2)",
    },
  },
  farmHeader: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    paddingBottom: "1.5rem",
    borderBottom: `1px solid ${BORDER_COLOR}`,
    flexWrap: "wrap",
    gap: "20px",
  },
  farmOwnerName: {
    margin: "0 0 4px 0",
    fontWeight: 700,
    color: PRIMARY_DARK,
    fontSize: "2rem",
  },
  farmIdLabel: { color: TEXT_MUTED, fontSize: "1rem", fontWeight: 500 },
  actionButtons: {
    display: "flex",
    gap: 10,
    flexWrap: "wrap",
    justifyContent: "flex-end",
  },
  farmDetailsGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))",
    gap: "20px 40px",
    marginTop: "2rem",
    fontSize: "1rem",
    color: TEXT_MUTED,
  },
  detailItem: {
    display: "flex",
    gap: "8px",
    alignItems: "center",
  },
  boldDetail: {
    color: PRIMARY_DARK,
    fontWeight: 600,
    fontSize: "1.05rem",
  },
  cropHistoryTitle: {
    margin: "0 0 1.5rem 0",
    color: PRIMARY_DARK,
    fontWeight: 700,
    fontSize: "1.8rem",
    paddingTop: "2rem",
    borderTop: `1px solid ${BORDER_COLOR}`,
    marginTop: "2.5rem",
  },
  errorMsgBox: {
    color: "#a00000",
    background: "#ffeded",
    border: "1px solid #e74c3c",
    padding: "1rem",
    borderRadius: 8,
    marginTop: "1.5rem",
    fontWeight: 500,
    gridColumn: "1 / -1", // Span all columns in the grid
  },
  successMsg: {
    color: ACCENT_GREEN,
    background: "#e9fff4",
    border: `1px solid ${ACCENT_GREEN}`,
    padding: "1rem",
    marginTop: "1.5rem",
    borderRadius: 8,
    fontWeight: 500,
    gridColumn: "1 / -1",
  },
  // Icon style for details
  detailIcon: {
    color: PRIMARY_PURPLE,
    minWidth: "20px",
  },
  // Style for the search bar
  searchContainer: {
    marginBottom: "20px",
    display: "flex",
    alignItems: "center",
    gap: "10px",
    width: "100%",
    maxWidth: "500px",
  },
  searchInput: {
    ...BASE_FIELD_STYLE, // FIX: Use BASE_FIELD_STYLE instead of style.formField
    flexGrow: 1,
    paddingLeft: "40px", // Make space for the icon
    position: "relative",
  },
  searchIcon: {
    position: "absolute",
    left: "15px",
    color: TEXT_MUTED,
  },
};

// --- FORM MODELS (unchanged) ---
const initialFarmForm = {
  phone_number: "",
  farm_size: "",
  survey_number: "",
  pincode: "",
  soil_type_ids: [],
  irrigation_ids: [],
  water_src_ids: [],
};

const initialCropForm = {
  farm_id: "",
  plant_name: "",
  planting_date: "",
  harvest_date: "",
  field_size: "",
  status: "",
  isactive: true,
};

const apiBase = `http://${SERVER_IP}:${SERVER_PORT}/api/farmcrop`;

const FarmCrop = () => {
  const [farms, setFarms] = useState([]);
  const [crops, setCrops] = useState([]);
  const [soilTypes, setSoilTypes] = useState([]);
  const [irrigations, setIrrigations] = useState([]);
  const [plants, setPlants] = useState([]);
  const [waterSources, setWaterSources] = useState([]);
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState("");
  // ADDED: Search state
  const [searchTerm, setSearchTerm] = useState("");
  // ADD AND EDIT STATE
  const [farmForm, setFarmForm] = useState(initialFarmForm);
  const [cropForm, setCropForm] = useState(initialCropForm);
  const [showAddFarm, setShowAddFarm] = useState(false);
  const [showAddCrop, setShowAddCrop] = useState(null);
  const [showCropsForFarm, setShowCropsForFarm] = useState(null);

  // EDIT STATE
  const [showEditFarm, setShowEditFarm] = useState(null);
  const [editFarmForm, setEditFarmForm] = useState(initialFarmForm);
  const [showEditCrop, setShowEditCrop] = useState(null);
  const [editCropForm, setEditCropForm] = useState(initialCropForm);

  // STATUS/ERRORS
  const [farmStatusMsg, setFarmStatusMsg] = useState("");
  const [farmErrorMsg, setFarmErrorMsg] = useState("");
  const [cropStatusMsg, setCropStatusMsg] = useState("");
  const [cropErrorMsg, setCropErrorMsg] = useState("");

  // --- DATA FETCH (unchanged logic) ---
  const fetchData = () => {
    const access_token = localStorage.getItem("access_token");
    if (!access_token) {
      setErrorMsg("Authentication: access_token missing.");
      setLoading(false);
      return;
    }
    setLoading(true);
    Promise.all([
      axiosInstance.get(`${apiBase}/farms`, {
        headers: { Authorization: `Bearer ${access_token}` },
      }),
      axiosInstance.get(`${apiBase}/crops`, {
        headers: { Authorization: `Bearer ${access_token}` },
      }),
    ])
      .then(([farmRes, cropRes]) => {
        setFarms(farmRes.data ?? []);
        setCrops(cropRes.data ?? []);
      })
      .catch((err) =>
        setErrorMsg(
          "Error loading farms/crops: " +
            (err.response?.data?.message || err.message)
        )
      )
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    fetchData();
  }, []);

  // --- MASTER TABLES (unchanged logic) ---
  useEffect(() => {
    if (showAddFarm || showEditFarm || showAddCrop || showEditCrop) {
      const access_token = localStorage.getItem("access_token");
      const headers = { Authorization: `Bearer ${access_token}` };
      // Helper to fetch masters and handle errors silently
      const fetchMaster = (endpoint, setter) => {
        axiosInstance
          .get(`${apiBase}/masters/${endpoint}`, { headers })
          .then((res) => setter(res.data))
          .catch(() => setter([]));
      };

      fetchMaster("soiltypes", setSoilTypes);
      fetchMaster("irrigations", setIrrigations);
      fetchMaster("watersources", setWaterSources);
      fetchMaster("plants", setPlants);
    }
  }, [showAddFarm, showEditFarm, showAddCrop, showEditCrop]);

  // --- FARMS AND CROPS (unchanged logic) ---
  const cropsForFarm = (farm_id) =>
    crops.filter((crop) => String(crop.farm_id) === String(farm_id));

  // --- FARM FILTERING LOGIC (unchanged) ---
  const filteredFarms = farms.filter((farm) => {
    if (!searchTerm) return true; // Show all if no search term
    const ownerName = farm.owner_name ? farm.owner_name.toLowerCase() : "";
    return ownerName.includes(searchTerm.toLowerCase());
  });

  // --- ADD (unchanged logic) ---
  const openAddFarm = () => {
    setFarmForm(initialFarmForm);
    setShowAddFarm(true);
    setFarmStatusMsg("");
    setFarmErrorMsg("");
  };
  const closeAddFarm = () => setShowAddFarm(false);
  const handleFarmInput = (e) =>
    setFarmForm({ ...farmForm, [e.target.name]: e.target.value });
  const submitAddFarm = async (e) => {
    e.preventDefault();
    setFarmStatusMsg("");
    setFarmErrorMsg("");
    try {
      const access_token = localStorage.getItem("access_token");
      await axiosInstance.post(`${apiBase}/addfarms`, farmForm, {
        headers: { Authorization: `Bearer ${access_token}` },
      });
      setFarmStatusMsg("Farm added successfully!");
      setShowAddFarm(false); // Close form on success
      setFarmForm(initialFarmForm);
      fetchData();
    } catch (err) {
      setFarmErrorMsg(err.response?.data?.message || err.message);
    }
  };

  const openAddCrop = (farm_id) => {
    // CRITICAL: Need to clear soil_type_id in initialCropForm so the select shows the placeholder
    setCropForm({ ...initialCropForm, farm_id, soil_type_id: "" });
    setShowAddCrop(farm_id);
    setCropStatusMsg("");
    setCropErrorMsg("");
  };
  const closeAddCrop = () => setShowAddCrop(null);
  const handleCropInput = (e) =>
    setCropForm({ ...cropForm, [e.target.name]: e.target.value });
  const submitAddCrop = async (e) => {
    e.preventDefault();
    setCropStatusMsg("");
    setCropErrorMsg("");
    try {
      const access_token = localStorage.getItem("access_token");
      // RESOLVE SOIL TYPE NAME FOR ADD
      const soilTypeName =
        soilTypes.find(
          (type) => String(type.soil_type_id) === String(cropForm.soil_type_id)
        )?.name || "";
      await axiosInstance.post(
        `${apiBase}/addcrops`,
        { ...cropForm, soil_type_name: soilTypeName },
        {
          headers: { Authorization: `Bearer ${access_token}` },
        }
      );
      setCropStatusMsg("Crop added successfully!");
      setShowAddCrop(null);
      setCropForm(initialCropForm);
      fetchData();
    } catch (err) {
      setCropErrorMsg(err.response?.data?.message || err.message);
    }
  };

  const handleMultiSelect = (e) => {
    const { name, options } = e.target;
    const values = Array.from(options)
      .filter((o) => o.selected)
      .map((o) => o.value);
    setFarmForm({ ...farmForm, [name]: values });
  };

  const handleEditMultiSelect = (e) => {
    const { name, options } = e.target;
    const values = Array.from(options)
      .filter((o) => o.selected)
      .map((o) => o.value);
    setEditFarmForm({ ...editFarmForm, [name]: values });
  };

  // --- EDIT FARMS (unchanged logic) ---
  const openEditFarm = (farm) => {
    // Ensure IDs are strings for select value matching
    setEditFarmForm({
      ...farm,
      farm_size: farm.farm_size || "",
      survey_number: farm.survey_number || "",
      pincode: farm.pincode || "",
      soil_type_ids: farm.soil_type_ids || [], // <-- ensure array
      irrigation_ids: farm.irrigation_ids || [],
      water_src_ids: farm.water_src_ids || [],
    });
    setShowEditFarm(farm.farm_id);
    setFarmStatusMsg("");
    setFarmErrorMsg("");
  };
  const closeEditFarm = () => setShowEditFarm(null);
  const handleEditFarmInput = (e) =>
    setEditFarmForm({ ...editFarmForm, [e.target.name]: e.target.value });
  const submitEditFarm = async (e) => {
    e.preventDefault();
    setFarmStatusMsg("");
    setFarmErrorMsg("");
    try {
      const access_token = localStorage.getItem("access_token");
      await axiosInstance.put(
        `${apiBase}/updatefarms/${editFarmForm.farm_id}`,
        editFarmForm,
        {
          headers: { Authorization: `Bearer ${access_token}` },
        }
      );
      setFarmStatusMsg("Farm updated successfully!");
      closeEditFarm();
      fetchData();
    } catch (err) {
      setFarmErrorMsg(err.response?.data?.message || err.message);
    }
  };

  // --- EDIT CROPS (CRITICAL FIX applied: Set correct soil_type_id in openEditCrop) ---
  const openEditCrop = (crop) => {
    setCropStatusMsg(""); // Clear status for edit form
    setCropErrorMsg(""); // Clear error for edit form

    // Always start by resetting options to prevent using stale data

    // Utility to ensure YYYY-MM-DD (for input type=date)
    const formatDate = (dateString) => {
      if (!dateString) return "";
      try {
        return new Date(dateString).toISOString().split("T")[0];
      } catch {
        return "";
      }
    };

    // Always set selected values as strings for select fields
    setEditCropForm({
      ...crop,

      planting_date: formatDate(crop.planting_date),
      harvest_date: formatDate(crop.harvest_date),
    });
    setShowEditCrop(crop.user_crop_id);
  };

  const closeEditCrop = () => setShowEditCrop(null);
  const handleEditCropInput = (e) =>
    setEditCropForm({ ...editCropForm, [e.target.name]: e.target.value });
  const submitEditCrop = async (e) => {
    e.preventDefault();
    setCropStatusMsg("");
    setCropErrorMsg("");
    try {
      const access_token = localStorage.getItem("access_token");
      // CRITICAL: always resolve soil_type_name
      const soilTypeName =
        soilTypes.find(
          (type) =>
            String(type.soil_type_id) === String(editCropForm.soil_type_id)
        )?.name || "";
      const payload = { ...editCropForm, soil_type_name: soilTypeName };
      await axiosInstance.put(
        `${apiBase}/updatecrops/${editCropForm.user_crop_id}`,
        payload,
        { headers: { Authorization: `Bearer ${access_token}` } }
      );
      setCropStatusMsg("Crop updated successfully!");
      closeEditCrop();
      fetchData();
    } catch (err) {
      setCropErrorMsg(err.response?.data?.message || err.message);
    }
  };

  // --- UI RENDER ---
  return (
    <div style={style.pageContainer}>
      <div style={style.contentWrapper}>
        <div style={style.pageTitle}>
          <FaSeedling size={40} color={PRIMARY_PURPLE} /> Farm Management
          Dashboard
        </div>
        {/* Farm Actions and Search */}
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            flexWrap: "wrap",
            gap: "15px",
            marginBottom: "1.5rem",
          }}
        >
          <button style={style.primaryButton} onClick={openAddFarm}>
            <FaPlus /> Add New Farm
          </button>
          <div style={{ ...style.searchContainer, marginBottom: 0 }}>
            <FaSearch style={style.searchIcon} />
            <input
              type="text"
              placeholder="Search by Farmer Name..."
              style={style.searchInput}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
        </div>
        {/* END Farm Actions and Search */}

        {/* Add Farm Form */}
        {showAddFarm && (
          <form style={style.addEditFormCard} onSubmit={submitAddFarm}>
            <input
              name="phone_number"
              style={style.formField}
              value={farmForm.phone_number}
              placeholder="Phone Number"
              onChange={handleFarmInput}
              required
            />
            <input
              name="farm_size"
              type="number"
              style={style.formField}
              value={farmForm.farm_size}
              placeholder="📏 Farm Size (e.g., Acres)"
              onChange={handleFarmInput}
              required
            />
            <input
              name="survey_number"
              style={style.formField}
              value={farmForm.survey_number}
              placeholder="# Survey Number"
              onChange={handleFarmInput}
              required
            />
            <input
              name="pincode"
              type="text"
              pattern="\d*" // Basic pattern for numbers
              style={style.formField}
              value={farmForm.pincode}
              placeholder="📍 Pincode"
              onChange={handleFarmInput}
              required
            />
            <select
              name="soil_type_ids"
              multiple
              style={style.formField}
              value={farmForm.soil_type_ids}
              onChange={handleMultiSelect}
              required
            >
              <option value="" disabled>
                Select Soil Types
              </option>
              {soilTypes.map((type) => (
                <option key={type.soil_type_id} value={type.soil_type_id}>
                  {type.name}
                </option>
              ))}
            </select>
            <select
              name="irrigation_ids"
              multiple
              style={style.formField}
              value={farmForm.irrigation_ids}
              onChange={handleMultiSelect}
              required
            >
              <option value="" disabled>
                Select Irrigation Methods
              </option>
              {irrigations.map((irr) => (
                <option key={irr.irrigation_id} value={irr.irrigation_id}>
                  {irr.method_name}
                </option>
              ))}
            </select>
            <select
              name="water_src_ids"
              multiple
              style={style.formField}
              value={farmForm.water_src_ids}
              onChange={handleMultiSelect}
              required
            >
              <option value="" disabled>
                Select Water Sources
              </option>
              {waterSources.map((ws) => (
                <option key={ws.water_src_id} value={ws.water_src_id}>
                  {ws.source}
                </option>
              ))}
            </select>
            <div
              style={{
                display: "flex",
                gap: "10px",
                gridColumn: "span 2 / span 2",
              }}
            >
              <button
                type="submit"
                style={{ ...style.submitButton, background: PRIMARY_PURPLE }}
              >
                <FaSave /> Save Farm
              </button>
              <button
                type="button"
                style={style.cancelButton}
                onClick={closeAddFarm}
              >
                <FaTimes /> Cancel
              </button>
            </div>
            {farmStatusMsg && (
              <div style={style.successMsg}>
                <FaSun /> {farmStatusMsg}
              </div>
            )}
            {farmErrorMsg && (
              <div style={style.errorMsgBox}>⚠️ {farmErrorMsg}</div>
            )}
          </form>
        )}

        {/* Edit Farm Form */}
        {showEditFarm && (
          <form style={style.addEditFormCard} onSubmit={submitEditFarm}>
            <input
              name="farm_size"
              type="number"
              style={style.formField}
              value={editFarmForm.farm_size}
              placeholder="📏 Farm Size (e.g., Acres)"
              onChange={handleEditFarmInput}
              required
            />
            <input
              name="survey_number"
              style={style.formField}
              value={editFarmForm.survey_number}
              placeholder="# Survey Number"
              onChange={handleEditFarmInput}
              required
            />
            <input
              name="pincode"
              type="text"
              pattern="\d*"
              style={style.formField}
              value={editFarmForm.pincode}
              placeholder="📍 Pincode"
              onChange={handleEditFarmInput}
              required
            />
            <select
              name="soil_type_ids"
              multiple
              style={style.formField}
              value={editFarmForm.soil_type_ids}
              onChange={handleEditMultiSelect}
              required
            >
              <option value="" disabled>
                Select Soil Types
              </option>
              {soilTypes.map((type) => (
                <option key={type.soil_type_id} value={type.soil_type_id}>
                  {type.name}
                </option>
              ))}
            </select>
            <select
              name="irrigation_ids"
              multiple
              style={style.formField}
              value={editFarmForm.irrigation_ids}
              onChange={handleEditMultiSelect}
              required
            >
              <option value="">💧 Select Irrigation Method</option>
              {irrigations.map((irr) => (
                <option key={irr.irrigation_id} value={irr.irrigation_id}>
                  {irr.method_name}
                </option>
              ))}
            </select>
            <select
              name="water_src_ids"
              multiple
              style={style.formField}
              value={editFarmForm.water_src_ids}
              onChange={handleEditMultiSelect}
              required
            >
              <option value="">🌊 Select Water Source</option>
              {waterSources.map((ws) => (
                <option key={ws.water_src_id} value={ws.water_src_id}>
                  {ws.source}
                </option>
              ))}
            </select>
            <div
              style={{
                display: "flex",
                gap: "10px",
                gridColumn: "span 2 / span 2",
              }}
            >
              <button type="submit" style={style.submitButton}>
                <FaPen /> Update Farm
              </button>
              <button
                type="button"
                style={style.cancelButton}
                onClick={closeEditFarm}
              >
                <FaTimes /> Cancel
              </button>
            </div>
            {farmStatusMsg && (
              <div style={style.successMsg}>
                <FaSun /> {farmStatusMsg}
              </div>
            )}
            {farmErrorMsg && (
              <div style={style.errorMsgBox}>⚠️ {farmErrorMsg}</div>
            )}
          </form>
        )}

        {/* Render Farms and Crop History */}
        <div style={{ marginTop: "1.5rem" }}>
          {errorMsg && <div style={style.errorMsgBox}>Error: {errorMsg}</div>}
          {loading ? (
            <div
              style={{
                fontStyle: "italic",
                color: TEXT_MUTED,
                textAlign: "center",
                padding: "3rem",
              }}
            >
              Loading farms and crops...
            </div>
          ) : farms.length === 0 ? (
            <div
              style={{
                padding: "3rem",
                textAlign: "center",
                color: TEXT_MUTED,
                border: "2px dashed #ccc",
                borderRadius: 12,
                marginTop: "2rem",
              }}
            >
              <FaLandmark size={40} color={TEXT_MUTED} />
              <p style={{ marginTop: "10px" }}>
                No farms found. Add one to begin!
              </p>
            </div>
          ) : filteredFarms.length === 0 ? (
            <div
              style={{
                padding: "3rem",
                textAlign: "center",
                color: TEXT_MUTED,
                border: "2px dashed #ccc",
                borderRadius: 12,
                marginTop: "2rem",
              }}
            >
              <FaSearch size={40} color={TEXT_MUTED} />
              <p style={{ marginTop: "10px" }}>
                No farms found matching **"{searchTerm}"**.
              </p>
            </div>
          ) : (
            filteredFarms.map((farm) => (
              <div key={farm.farm_id} style={style.farmCard}>
                <div style={style.farmHeader}>
                  <div>
                    <h3 style={style.farmOwnerName}>
                      <FaHome
                        size={24}
                        style={{ marginRight: "10px", color: PRIMARY_PURPLE }}
                      />
                      {farm.owner_name ?? "Owner Unknown"}
                    </h3>
                    <div style={style.farmIdLabel}>
                      Farm ID: **{farm.farm_id}**
                    </div>
                  </div>
                  <div style={style.actionButtons}>
                    <button
                      onClick={() =>
                        setShowCropsForFarm(
                          showCropsForFarm === farm.farm_id
                            ? null
                            : farm.farm_id
                        )
                      }
                      style={{
                        ...style.secondaryButtonBase,
                        ...(showCropsForFarm === farm.farm_id
                          ? {
                              background: PRIMARY_PURPLE,
                              color: "#fff",
                              border: "none",
                            }
                          : {}),
                      }}
                    >
                      {showCropsForFarm === farm.farm_id ? (
                        <FaTimes />
                      ) : (
                        <FaEye />
                      )}
                      {showCropsForFarm === farm.farm_id
                        ? "Hide History"
                        : "View History"}
                    </button>
                    <button
                      onClick={() => openAddCrop(farm.farm_id)}
                      style={style.secondaryButtonBase}
                    >
                      <FaPlus /> Add Crop
                    </button>
                    <button
                      onClick={() => openEditFarm(farm)}
                      style={style.secondaryButtonBase}
                    >
                      <FaPen /> Edit Farm
                    </button>
                  </div>
                </div>
                {/* Details */}
                <div style={style.farmDetailsGrid}>
                  <div style={style.detailItem}>
                    <FaMapMarkerAlt style={style.detailIcon} />
                    <span style={style.boldDetail}>Survey Number:</span>{" "}
                    {farm.survey_number ?? "NA"}
                  </div>
                  <div className={style.detailItem}>
                    <FaFlask style={style.detailIcon} />
                    <span style={style.boldDetail}>Soil Type:</span>
                    {/* CHANGE HERE */}
                    {Array.isArray(farm.soil_types)
                      ? farm.soil_types.join(", ")
                      : farm.soil_type || "NA"}
                  </div>
                  <div style={style.detailItem}>
                    <FaLandmark style={style.detailIcon} />
                    <span style={style.boldDetail}>Size (Acre):</span>{" "}
                    {farm.farm_size ?? "NA"}
                  </div>
                  <div style={style.detailItem}>
                    <FaMapMarkerAlt style={style.detailIcon} />
                    <span style={style.boldDetail}>Pincode:</span>{" "}
                    {farm.pincode ?? "NA"}
                  </div>
                  <div className={style.detailItem}>
                    <FaTint style={style.detailIcon} />
                    <span style={style.boldDetail}>Irrigation:</span>
                    {Array.isArray(farm.irrigation_methods)
                      ? farm.irrigation_methods.join(", ")
                      : farm.irrigation || "NA"}
                  </div>
                  <div className={style.detailItem}>
                    <FaTint style={style.detailIcon} />
                    <span style={style.boldDetail}>Water Source:</span>
                    {Array.isArray(farm.water_sources)
                      ? farm.water_sources.join(", ")
                      : farm.water_source || "NA"}
                  </div>
                </div>

                {/* Crop History SECTION */}
                {showCropsForFarm === farm.farm_id && (
                  <div style={{ marginTop: "2rem" }}>
                    <h4 style={style.cropHistoryTitle}>🌾 Crop History</h4>
                    {cropsForFarm(farm.farm_id).length === 0 ? (
                      <div
                        style={{
                          color: TEXT_MUTED,
                          padding: "1.5rem",
                          background: "#fafafa",
                          borderRadius: 8,
                          border: "1px dashed #eee",
                          textAlign: "center",
                        }}
                      >
                        No crops found for this farm.
                      </div>
                    ) : (
                      cropsForFarm(farm.farm_id).map((crop) => (
                        <div key={crop.user_crop_id}>
                          <div style={style.cropCard}>
                            {/* Details */}
                            <div style={style.detailItem}>
                              <FaSeedling style={{ color: ACCENT_GREEN }} />
                              <span style={style.boldDetail}>
                                Plant Name:
                              </span>{" "}
                              {crop.plant_name ?? "NA"}
                            </div>
                            <div style={style.detailItem}>
                              <FaLandmark style={style.detailIcon} />
                              <span style={style.boldDetail}>
                                Field Size:
                              </span>{" "}
                              {crop.field_size ?? "NA"}
                            </div>
                            <div style={style.detailItem}>
                              <span style={style.boldDetail}>Planted:</span>{" "}
                              {crop.planting_date
                                ? new Date(
                                    crop.planting_date
                                  ).toLocaleDateString()
                                : "NA"}
                            </div>
                            <div style={style.detailItem}>
                              <span style={style.boldDetail}>Harvest:</span>{" "}
                              {crop.harvest_date
                                ? new Date(
                                    crop.harvest_date
                                  ).toLocaleDateString()
                                : "NA"}
                            </div>
                            <div style={style.detailItem}>
                              <FaTint style={style.detailIcon} />
                              <span style={style.boldDetail}>
                                Water Req:
                              </span>{" "}
                              {crop.water_requirement ?? "NA"}
                            </div>

                            <div style={style.detailItem}>
                              <span style={style.boldDetail}>Status:</span>{" "}
                              <span
                                style={{
                                  color:
                                    crop.status === "Harvested"
                                      ? ACCENT_GREEN
                                      : PRIMARY_PURPLE,
                                  fontWeight: 700,
                                }}
                              >
                                {crop.status ?? "NA"}
                              </span>
                            </div>

                            <div
                              style={{
                                gridColumn: "span 1 / span 1",
                                display: "flex",
                                justifyContent: "flex-end",
                              }}
                            >
                              <button
                                onClick={() => openEditCrop(crop)}
                                style={style.secondaryButtonBase}
                              >
                                <FaPen /> Edit Crop
                              </button>
                            </div>
                          </div>
                          {/* --- EDIT CROP FORM --- */}
                          {showEditCrop === crop.user_crop_id && (
                            <form
                              onSubmit={submitEditCrop}
                              style={{
                                ...style.addEditFormCard,
                                borderTop: `5px solid ${ACCENT_GREEN}`,
                                marginTop: "15px",
                              }}
                            >
                              <select
                                name="plant_id"
                                style={style.formField}
                                value={editCropForm.plant_id}
                                onChange={handleEditCropInput}
                                required
                              >
                                <option value="">Select Plant</option>
                                {plants.map((type) => (
                                  <option
                                    key={type.plant_id}
                                    value={type.plant_id}
                                  >
                                    {type.plant_name}
                                  </option>
                                ))}
                              </select>
                              <input
                                name="planting_date"
                                type="date"
                                style={style.formField}
                                value={editCropForm.planting_date}
                                placeholder="Planting Date"
                                onChange={handleEditCropInput}
                                required
                              />
                              <input
                                name="harvest_date"
                                type="date"
                                style={style.formField}
                                value={editCropForm.harvest_date}
                                placeholder="Harvest Date"
                                onChange={handleEditCropInput}
                                required
                              />
                              <input
                                name="field_size"
                                type="number"
                                style={style.formField}
                                value={editCropForm.field_size}
                                placeholder="Field Size (e.g., Acres)"
                                onChange={handleEditCropInput}
                                required
                              />
                              <input
                                name="status"
                                style={style.formField}
                                value={editCropForm.status}
                                placeholder="Crop Status (e.g., Growing, Planted, Harvested)"
                                onChange={handleEditCropInput}
                                required
                              />

                              <div
                                style={{
                                  display: "flex",
                                  gap: "10px",
                                  gridColumn: "span 2 / span 2",
                                }}
                              >
                                <button
                                  type="submit"
                                  style={style.submitButton}
                                >
                                  <FaSave /> Update Crop
                                </button>
                                <button
                                  type="button"
                                  style={style.cancelButton}
                                  onClick={closeEditCrop}
                                >
                                  <FaTimes /> Cancel
                                </button>
                              </div>
                              {cropStatusMsg && (
                                <div style={style.successMsg}>
                                  <FaSun /> {cropStatusMsg}
                                </div>
                              )}
                              {cropErrorMsg && (
                                <div style={style.errorMsgBox}>
                                  ⚠️ {cropErrorMsg}
                                </div>
                              )}
                            </form>
                          )}
                        </div>
                      ))
                    )}
                  </div>
                )}
                {/* Add Crop Form */}
                {showAddCrop === farm.farm_id && (
                  <form
                    onSubmit={submitAddCrop}
                    style={{
                      ...style.addEditFormCard,
                      borderTop: `5px solid ${PRIMARY_PURPLE}`,
                      marginTop: "20px",
                    }}
                  >
                    <select
                      name="plant_id"
                      style={style.formField}
                      value={cropForm.plant_id} // CRITICAL: Use cropForm for Add Crop
                      onChange={handleCropInput}
                      required
                    >
                      <option value="">🧪 Select Plant</option>
                      {plants.map((type) => (
                        <option key={type.plant_id} value={type.plant_id}>
                          {type.plant_name}
                        </option>
                      ))}
                    </select>
                    <input
                      name="planting_date"
                      type="date"
                      style={style.formField}
                      value={cropForm.planting_date}
                      placeholder="Planting Date"
                      onChange={handleCropInput}
                      required
                    />
                    <input
                      name="harvest_date"
                      type="date"
                      style={style.formField}
                      value={cropForm.harvest_date}
                      placeholder="Harvest Date"
                      onChange={handleCropInput}
                      required
                    />
                    <input
                      name="field_size"
                      type="number"
                      style={style.formField}
                      value={cropForm.field_size}
                      placeholder="📏 Field Size (e.g., Acres)"
                      onChange={handleCropInput}
                      required
                    />
                    <input
                      name="status"
                      style={style.formField}
                      value={cropForm.status}
                      placeholder="🌱 Status (e.g., Growing, Planted, Harvested)"
                      onChange={handleCropInput}
                      required
                    />

                    <div
                      style={{
                        display: "flex",
                        gap: "10px",
                        gridColumn: "span 2 / span 2",
                      }}
                    >
                      <button
                        type="submit"
                        style={{
                          ...style.submitButton,
                          background: PRIMARY_PURPLE,
                        }}
                      >
                        <FaSave /> Save Crop
                      </button>
                      <button
                        type="button"
                        style={style.cancelButton}
                        onClick={closeAddCrop}
                      >
                        <FaTimes /> Cancel
                      </button>
                    </div>
                    {cropStatusMsg && (
                      <div style={style.successMsg}>
                        <FaSun /> {cropStatusMsg}
                      </div>
                    )}
                    {cropErrorMsg && (
                      <div style={style.errorMsgBox}>⚠️ {cropErrorMsg}</div>
                    )}
                  </form>
                )}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};

export default FarmCrop;
