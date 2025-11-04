import React, { useEffect, useState, useCallback, useMemo } from "react";
import { axiosInstance } from "../api/login";
import { SERVER_IP } from "../constant";

// API base
const apiBase = `http://${SERVER_IP}:5000/api/farmcrop`;

const Master = () => {
  // Data states for each table
  const [soilTypes, setSoilTypes] = useState([]);
  const [irrigations, setIrrigations] = useState([]);
  const [waterSources, setWaterSources] = useState([]);
  const [cropTypes, setCropTypes] = useState([]);
  const [plants, setPlants] = useState([]);
  // Form states
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
  const access_token = localStorage.getItem("access_token");
  const authConfig = useMemo(
    () => ({ headers: { Authorization: `Bearer ${access_token}` } }),
    [access_token]
  );

  // Fetch all master data
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
      setCropTypes(cropRes.data);
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

  // Add
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
          if (!form.irrigation) {
            setErrorMsg("Irrigation method is required.");
            return;
          }
          endpoint = "addirrigations";
          body = { method_name: form.irrigation };
          break;
        case "water":
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

  // Confirm delete
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

  // --- STYLES OBJECTS ---
  const styles = {
    // General Page Styles
    container: {
      padding: "30px",
      fontFamily: "'Inter', sans-serif",
      minHeight: "100vh",
      background: "#eef2f6", // Light background for a clean look
      color: "#2c3e50",
    },
    header: {
      fontWeight: 800,
      fontSize: "2.5rem",
      marginBottom: "30px",
      color: "#3498db", // Primary color for heading
      borderBottom: "3px solid #3498db",
      paddingBottom: "10px",
    },
    grid: {
      display: "grid",
      gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))",
      gap: "30px",
    },

    // Alert Messages
    successAlert: {
      color: "#16a34a",
      background: "#dcfce7",
      padding: "15px",
      borderRadius: "10px",
      marginBottom: "20px",
      fontWeight: 600,
      borderLeft: "5px solid #16a34a",
      animation: "slideDown 0.5s ease-out",
    },
    errorAlert: {
      color: "#c0392b",
      background: "#fdecec",
      padding: "15px",
      borderRadius: "10px",
      marginBottom: "20px",
      fontWeight: 600,
      borderLeft: "5px solid #c0392b",
      animation: "slideDown 0.5s ease-out",
    },

    // Card Styles
    card: {
      background: "#ffffff",
      padding: "25px",
      borderRadius: "12px",
      boxShadow: "0 4px 12px rgba(0, 0, 0, 0.08)",
      transition: "transform 0.3s ease, box-shadow 0.3s ease",
      marginBottom: "0",
    },
    cardHover: {
      transform: "translateY(-5px)",
      boxShadow: "0 8px 20px rgba(0, 0, 0, 0.15)",
    },
    cardHeader: {
      fontSize: "1.5rem",
      color: "#2c3e50",
      marginBottom: "15px",
      paddingBottom: "10px",
      borderBottom: "2px solid #ecf0f1",
    },

    // Form/Input Styles
    inputGroup: {
      display: "flex",
      gap: "10px",
      marginBottom: "15px",
      flexWrap: "wrap",
    },
    input: {
      padding: "10px 15px",
      borderRadius: "6px",
      border: "1px solid #bdc3c7",
      flexGrow: 1,
      fontSize: "1rem",
      transition: "border-color 0.3s",
    },
    select: {
      padding: "10px 15px",
      borderRadius: "6px",
      border: "1px solid #bdc3c7",
      fontSize: "1rem",
      minWidth: "150px",
      transition: "border-color 0.3s",
    },
    inputFocus: {
      borderColor: "#3498db",
      outline: "none",
      boxShadow: "0 0 5px rgba(52, 152, 219, 0.3)",
    },

    // Button Styles
    addButton: {
      padding: "10px 20px",
      background: "#2ecc71", // Green for 'Add'
      color: "#ffffff",
      border: "none",
      borderRadius: "6px",
      cursor: "pointer",
      fontWeight: 600,
      transition: "background-color 0.3s ease, transform 0.1s ease",
    },
    addButtonHover: {
      background: "#27ae60",
      transform: "translateY(-1px)",
    },
    deleteButton: {
      padding: "5px 10px",
      background: "#e74c3c", // Red for 'Delete'
      color: "#ffffff",
      border: "none",
      borderRadius: "4px",
      cursor: "pointer",
      fontWeight: 500,
      marginLeft: "10px",
      transition: "background-color 0.3s ease",
    },
    deleteButtonHover: {
      background: "#c0392b",
    },

    // List Styles
    ul: {
      listStyleType: "none",
      padding: 0,
      marginTop: "15px",
    },
    li: {
      padding: "10px 0",
      borderBottom: "1px dotted #ecf0f1",
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center",
      fontSize: "0.95rem",
    },

    // Confirmation Modal Styles (mostly kept from original for functionality, but cleaner)
    modalOverlay: {
      position: "fixed",
      top: 0,
      left: 0,
      width: "100vw",
      height: "100vh",
      background: "rgba(44, 62, 80, 0.6)", // Darker, professional overlay
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      zIndex: 2000,
      backdropFilter: "blur(3px)",
      animation: "fadeIn 0.3s ease-out",
    },
    modalContent: {
      background: "#fff",
      padding: "30px",
      borderRadius: "12px",
      boxShadow: "0 10px 30px rgba(0,0,0,0.25)",
      minWidth: "350px",
      maxWidth: "450px",
      textAlign: "center",
      animation: "scaleIn 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275)",
    },
    modalHeader: {
      color: "#e74c3c",
      marginTop: 0,
      fontSize: "1.8rem",
      marginBottom: "15px",
    },
    modalActions: {
      display: "flex",
      gap: "15px",
      justifyContent: "center",
      marginTop: "25px",
    },
    cancelButton: {
      background: "#bdc3c7",
      color: "#2c3e50",
      padding: "10px 20px",
      borderRadius: "6px",
      border: "none",
      cursor: "pointer",
      fontWeight: 600,
      transition: "background-color 0.3s ease",
    },
    confirmButton: {
      background: "#e74c3c",
      color: "#fff",
      padding: "10px 20px",
      borderRadius: "6px",
      border: "none",
      cursor: "pointer",
      fontWeight: 600,
      transition: "background-color 0.3s ease",
    },
  };
  // --- END STYLES OBJECTS ---

  // Custom Stylesheet for keyframes and complex selectors (using a string for React style attribute)
  // NOTE: In a real project, this should be an external CSS file or a dedicated CSS-in-JS solution.
  // For this answer, we'll embed the necessary complex/hover styles using global style tags for demonstration.
  const GlobalStyles = () => (
    <style>{`
      /* Keyframes for animations */
      @keyframes fadeIn {
        from { opacity: 0; }
        to { opacity: 1; }
      }
      @keyframes slideDown {
        from { opacity: 0; transform: translateY(-20px); }
        to { opacity: 1; transform: translateY(0); }
      }
      @keyframes scaleIn {
        from { opacity: 0; transform: scale(0.8); }
        to { opacity: 1; transform: scale(1); }
      }
      
      /* Global Reset for clean component application */
      * {
          box-sizing: border-box;
      }

      /* Card Hover Effect */
      .master-card:hover {
          ${Object.entries(styles.cardHover)
            .map(
              ([k, v]) =>
                `${k.replace(
                  /([A-Z])/g,
                  (g) => `-${g[0].toLowerCase()}`
                )}: ${v};`
            )
            .join(" ")}
      }

      /* Input/Select Focus Effect */
      input:focus, select:focus {
          ${Object.entries(styles.inputFocus)
            .map(
              ([k, v]) =>
                `${k.replace(
                  /([A-Z])/g,
                  (g) => `-${g[0].toLowerCase()}`
                )}: ${v};`
            )
            .join(" ")}
      }

      /* Add Button Hover Effect */
      .add-button:hover {
          ${Object.entries(styles.addButtonHover)
            .map(
              ([k, v]) =>
                `${k.replace(
                  /([A-Z])/g,
                  (g) => `-${g[0].toLowerCase()}`
                )}: ${v};`
            )
            .join(" ")}
      }
      
      /* Delete Button Hover Effect */
      .delete-button:hover {
          ${Object.entries(styles.deleteButtonHover)
            .map(
              ([k, v]) =>
                `${k.replace(
                  /([A-Z])/g,
                  (g) => `-${g[0].toLowerCase()}`
                )}: ${v};`
            )
            .join(" ")}
      }
      
      /* Specific styling for the li items in Plants section for better alignment */
      .plants-list li {
          flex-direction: column;
          align-items: flex-start !important;
          gap: 5px;
      }
      .plants-list li > span {
          font-weight: 600;
          color: #3498db;
      }
      .plants-list li .details {
          font-size: 0.85rem;
          color: #7f8c8d;
      }
    `}</style>
  );

  // --- RENDERING ---
  const renderCard = (title, type, inputFields, listData, renderItem) => (
    <section key={type} className="master-card" style={styles.card}>
      <h3 style={styles.cardHeader}>{title}</h3>
      <div style={styles.inputGroup}>
        {inputFields}
        <button
          className="add-button"
          onClick={() => handleAdd(type)}
          style={styles.addButton}
        >
          Add {title.split(" ")[0]}
        </button>
      </div>
      <ul style={styles.ul} className={type === "plant" ? "plants-list" : ""}>
        {listData.length === 0 ? (
          <li
            style={{ ...styles.li, justifyContent: "center", color: "#95a5a6" }}
          >
            No {title.toLowerCase()} found.
          </li>
        ) : (
          listData.map(renderItem)
        )}
      </ul>
    </section>
  );

  return (
    <div style={styles.container}>
      <GlobalStyles />
      <h2 style={styles.header}>Master Data Management ⚙️</h2>

      {msg && <div style={styles.successAlert}>{msg}</div>}
      {errorMsg && <div style={styles.errorAlert}>{errorMsg}</div>}

      <div style={styles.grid}>
        {/* Soil Types Card */}
        {renderCard(
          "Soil Types",
          "soil",
          <input
            name="soilType"
            value={form.soilType}
            onChange={handleChange}
            placeholder="New soil type name"
            style={styles.input}
          />,
          soilTypes,
          (s) => (
            <li key={s.soil_type_id} style={styles.li}>
              <span>{s.name}</span>
              <button
                className="delete-button"
                onClick={() => openDelete("soil", s.soil_type_id)}
                style={styles.deleteButton}
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
          <input
            name="irrigation"
            value={form.irrigation}
            onChange={handleChange}
            placeholder="New irrigation method"
            style={styles.input}
          />,
          irrigations,
          (i) => (
            <li key={i.irrigation_id} style={styles.li}>
              <span>{i.method_name}</span>
              <button
                className="delete-button"
                onClick={() => openDelete("irrigation", i.irrigation_id)}
                style={styles.deleteButton}
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
          <input
            name="waterSource"
            value={form.waterSource}
            onChange={handleChange}
            placeholder="New water source"
            style={styles.input}
          />,
          waterSources,
          (w) => (
            <li key={w.water_src_id} style={styles.li}>
              <span>{w.source}</span>
              <button
                className="delete-button"
                onClick={() => openDelete("water", w.water_src_id)}
                style={styles.deleteButton}
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
          <input
            name="cropType"
            value={form.cropType}
            onChange={handleChange}
            placeholder="New crop type name"
            style={styles.input}
          />,
          cropTypes,
          (c) => (
            <li key={c.crop_type_id} style={styles.li}>
              <span>
                {c.crop_type_id} - {c.name}
              </span>
              <button
                className="delete-button"
                onClick={() => openDelete("crop", c.crop_type_id)}
                style={styles.deleteButton}
              >
                Delete
              </button>
            </li>
          )
        )}

        {/* Plants Card - Special Layout */}
        <section key="plant" className="master-card" style={styles.card}>
          <h3 style={styles.cardHeader}>Plants 🌳</h3>
          <div style={styles.inputGroup}>
            <input
              name="plantName"
              value={form.plantName}
              onChange={handleChange}
              placeholder="Plant name"
              style={{ ...styles.input, minWidth: "120px" }}
            />
            <select
              name="plantCropType"
              value={form.plantCropType}
              onChange={handleChange}
              style={styles.select}
            >
              <option value="">Select Crop Type</option>
              {cropTypes.map((ct) => (
                <option key={ct.crop_type_id} value={ct.crop_type_id}>
                  {ct.name}
                </option>
              ))}
            </select>
            <input
              name="plantWaterReq"
              value={form.plantWaterReq}
              onChange={handleChange}
              placeholder="Water Req"
              style={{ ...styles.input, minWidth: "100px" }}
            />
            <button
              className="add-button"
              onClick={() => handleAdd("plant")}
              style={styles.addButton}
            >
              Add Plant
            </button>
          </div>
          <ul style={styles.ul} className="plants-list">
            {plants.length === 0 ? (
              <li
                style={{
                  ...styles.li,
                  justifyContent: "center",
                  color: "#95a5a6",
                }}
              >
                No plants found.
              </li>
            ) : (
              plants.map((p) => (
                <li key={p.plant_id} style={styles.li}>
                  <span>{p.plant_name}</span>
                  <div className="details">
                    (Crop Type: **{p.crop_type_id}** | Water Req: **
                    {p.water_requirement}**)
                  </div>
                  <button
                    className="delete-button"
                    onClick={() => openDelete("plant", p.plant_id)}
                    style={{
                      ...styles.deleteButton,
                      alignSelf: "flex-end",
                      marginTop: 5,
                    }}
                  >
                    Delete
                  </button>
                </li>
              ))
            )}
          </ul>
        </section>
      </div>

      {/* Delete confirmation modal */}
      {isConfirmOpen && (
        <div style={styles.modalOverlay}>
          <div style={styles.modalContent}>
            <h3 style={styles.modalHeader}>Confirm Deletion ⚠️</h3>
            <p>
              Are you sure you want to delete this record? This action cannot be
              undone.
            </p>
            <div style={styles.modalActions}>
              <button onClick={cancelDelete} style={styles.cancelButton}>
                Cancel
              </button>
              <button onClick={confirmDelete} style={styles.confirmButton}>
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
