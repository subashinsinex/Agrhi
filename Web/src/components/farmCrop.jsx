import React, { useEffect, useState, useCallback, useMemo } from "react";
import axios from "axios";
import {
  Search,
  Plus,
  Trash2,
  Edit,
  X,
  Layers,
  Droplet,
  MapPin,
  Zap,
  Leaf,
  Users,
  Maximize,
} from "lucide-react";
// Removed unused 'Calendar' import to clear ESLint warning.

// FIX: Since '../constant' could not be resolved, we will define a placeholder IP here.
// You MUST replace 'localhost' with your actual server IP address before deployment.
const SERVER_IP = "localhost";

// --- API Configuration ---
// Note: apiBase is constructed using the defined SERVER_IP
const apiBase = `http://${SERVER_IP}:5000/api/farmcrop`;

// --- Initial State Templates ---
const initialFarmForm = {
  farm_id: "",
  owner_name: "", // For display/lookup
  farm_size: "",
  survey_number: "",
  pincode: "",
  soil_type_id: "",
  irrigation_id: "",
  water_source_id: "",
};

const initialCropForm = {
  crop_id: "",
  farm_id: "", // Populated by the selected farm
  crop_type_id: "",
  plant_id: "",
  sowing_date: "",
  expected_harvest_date: "",
};

// Helper component for displaying confirmation message (simulating alert/confirm replacement)
const CustomModal = ({ title, children, isOpen, onClose, actions }) => {
  if (!isOpen) return null;

  return (
    <div className="modal-overlay">
      <div className="modal-content">
        <div className="modal-header">
          <h3 className="modal-title">{title}</h3>
          <button onClick={onClose} className="close-btn">
            <X size={20} />
          </button>
        </div>
        <div className="modal-body">{children}</div>
        {actions && <div className="modal-actions">{actions}</div>}
      </div>
    </div>
  );
};

const FarmCrop = () => {
  // --- Main Data States ---
  const [farms, setFarms] = useState([]);
  const [crops, setCrops] = useState([]);
  const [lookups, setLookups] = useState({}); // Stores all dropdown data
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState("");

  // --- UI States ---
  const [selectedFarmId, setSelectedFarmId] = useState(null);
  const [isFarmFormOpen, setIsFarmFormOpen] = useState(false);
  const [isCropFormOpen, setIsCropFormOpen] = useState(false);
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);
  const [currentFarmForm, setCurrentFarmForm] = useState(initialFarmForm);
  const [currentCropForm, setCurrentCropForm] = useState(initialCropForm);
  const [formType, setFormType] = useState(null); // 'farm' or 'crop'
  const [isEditing, setIsEditing] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");

  // --- Data Fetching Logic (CRUD operations assumed for Farm/Crop) ---

  const fetchData = useCallback(async () => {
    setIsLoading(true);
    setErrorMessage("");
    try {
      // 1. Fetch Farms
      const farmResponse = await axios.get(`${apiBase}/farms`);
      setFarms(farmResponse.data);

      // 2. Fetch Crops
      const cropResponse = await axios.get(`${apiBase}/crops`);
      setCrops(cropResponse.data);

      // 3. Fetch Lookup Data (Explicitly fetching all required lookup lists)
      const lookupEndpoints = [
        "soilTypes",
        "irrigations",
        "waterSources",
        "cropTypes",
        "plants",
      ];

      const lookupPromises = lookupEndpoints.map((endpoint) =>
        // Note: The endpoint path is lowercased, but the key saved is as defined above.
        axios
          .get(`${apiBase}/${endpoint.toLowerCase()}`)
          .then((res) => ({ key: endpoint, data: res.data }))
      );

      const lookupResults = await Promise.all(lookupPromises);

      const newLookups = lookupResults.reduce((acc, current) => {
        acc[current.key] = current.data;
        return acc;
      }, {});

      setLookups(newLookups);

      // Select the first farm by default if data exists
      if (farmResponse.data.length > 0) {
        setSelectedFarmId(farmResponse.data[0].farm_id);
      }
    } catch (error) {
      console.error("Error fetching data:", error.message || error);
      setErrorMessage(
        "Failed to load application data. Check backend status and console. The configured IP is: " +
          SERVER_IP
      );
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // --- Form & Modal Handlers ---

  const handleOpenFarmForm = (farm = null) => {
    if (farm) {
      setCurrentFarmForm(farm);
      setIsEditing(true);
    } else {
      setCurrentFarmForm(initialFarmForm);
      setIsEditing(false);
    }
    setFormType("farm");
    setIsFarmFormOpen(true);
  };

  const handleOpenCropForm = (crop = null) => {
    if (!selectedFarmId) {
      setErrorMessage("Please select a farm before adding a crop.");
      return;
    }
    if (crop) {
      setCurrentCropForm(crop);
      setIsEditing(true);
    } else {
      setCurrentCropForm({ ...initialCropForm, farm_id: selectedFarmId });
      setIsEditing(false);
    }
    setFormType("crop");
    setIsCropFormOpen(true);
  };

  const handleCloseForm = () => {
    setIsFarmFormOpen(false);
    setIsCropFormOpen(false);
    setCurrentFarmForm(initialFarmForm);
    setCurrentCropForm(initialCropForm);
    setFormType(null);
    setErrorMessage(""); // Clear error on close
  };

  const handleFormChange = (e, formType) => {
    const { name, value } = e.target;
    if (formType === "farm") {
      setCurrentFarmForm((prev) => ({ ...prev, [name]: value }));
    } else {
      setCurrentCropForm((prev) => ({ ...prev, [name]: value }));
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setErrorMessage("");

    let dataToSave;
    let endpoint;

    if (formType === "farm") {
      dataToSave = currentFarmForm;
      endpoint = `${apiBase}/farms`;
      // Simple validation example
      if (
        !dataToSave.owner_name ||
        !dataToSave.farm_size ||
        !dataToSave.soil_type_id
      ) {
        setErrorMessage("Please fill out all required farm fields.");
        return;
      }
    } else if (formType === "crop") {
      dataToSave = currentCropForm;
      endpoint = `${apiBase}/crops`;
      // Simple validation example
      if (
        !dataToSave.plant_id ||
        !dataToSave.sowing_date ||
        !dataToSave.expected_harvest_date
      ) {
        setErrorMessage("Please fill out all required crop fields.");
        return;
      }
    } else {
      return;
    }

    try {
      if (isEditing) {
        // UPDATE
        await axios.put(
          `${endpoint}/${
            formType === "farm" ? dataToSave.farm_id : dataToSave.crop_id
          }`,
          dataToSave
        );
      } else {
        // CREATE
        await axios.post(endpoint, dataToSave);
      }
      handleCloseForm();
      fetchData(); // Refresh data
    } catch (error) {
      console.error(`Error saving ${formType}:`, error.response?.data || error);
      setErrorMessage(`Failed to save ${formType}. Try again.`);
    }
  };

  const [itemToDelete, setItemToDelete] = useState(null); // {type: 'farm'/'crop', id: '...'}

  const handleDelete = (type, id) => {
    setItemToDelete({ type, id });
    setIsDeleteModalOpen(true);
  };

  const handleConfirmDelete = async () => {
    if (!itemToDelete) return;
    setErrorMessage("");

    const { type, id } = itemToDelete;
    const endpoint = `${apiBase}/${type}s/${id}`;

    try {
      await axios.delete(endpoint);
      setIsDeleteModalOpen(false);
      fetchData(); // Refresh data
      // If deleting the selected farm, reset selection
      if (type === "farm" && id === selectedFarmId) {
        setSelectedFarmId(null);
      }
    } catch (error) {
      console.error(`Error deleting ${type}:`, error.response?.data || error);
      setErrorMessage(`Failed to delete ${type}. Try again.`);
      setIsDeleteModalOpen(false);
    }
  };

  // --- Computed/Filtered Data ---

  const selectedFarm = useMemo(() => {
    return farms.find((f) => f.farm_id === selectedFarmId);
  }, [farms, selectedFarmId]);

  // FIX: Added (farm.owner_name || "") to handle cases where owner_name is null/undefined,
  // preventing the TypeError: Cannot read properties of null (reading 'toLowerCase').
  const filteredFarms = useMemo(() => {
    return farms.filter((farm) =>
      (farm.owner_name || "").toLowerCase().includes(searchTerm.toLowerCase())
    );
  }, [farms, searchTerm]);

  const cropsForSelectedFarm = useMemo(() => {
    return crops.filter((crop) => crop.farm_id === selectedFarmId);
  }, [crops, selectedFarmId]);

  // --- Lookup Helpers ---

  const getLookupName = (type, id) => {
    const list = lookups[type] || [];
    const item = list.find((i) => i.id === id);
    return item ? item.name : "N/A";
  };

  // --- Component Render ---

  if (isLoading) {
    return <div className="loading-state">Loading farm data...</div>;
  }

  // Injecting standard CSS styles directly into the component
  const styles = (
    <style>
      {`
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
        
        /* --- Base & Utility --- */
        :root {
          --color-primary: #10b981; /* Emerald-500 */
          --color-primary-dark: #059669; /* Emerald-600 */
          --color-secondary: #f9fafb; /* Gray-50 */
          --color-text-dark: #1f2937; /* Gray-800 */
          --color-text-light: #ffffff;
          --color-danger: #ef4444; /* Red-500 */
          --color-border: #e5e7eb; /* Gray-200 */
          --color-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -2px rgba(0, 0, 0, 0.1);
        }

        .app-container {
          font-family: 'Inter', sans-serif;
          min-height: 100vh;
          background-color: var(--color-secondary);
          color: var(--color-text-dark);
          padding: 20px;
        }

        /* --- Header --- */
        .header-bar {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 20px;
          padding: 15px 20px;
          background-color: var(--color-text-light);
          border-radius: 12px;
          box-shadow: var(--color-shadow);
        }
        
        .header-title {
          font-size: 1.5rem;
          font-weight: 700;
          display: flex;
          align-items: center;
          gap: 10px;
        }

        .search-bar {
          display: flex;
          align-items: center;
          border: 1px solid var(--color-border);
          border-radius: 8px;
          padding: 8px 12px;
          background-color: #fff;
          width: 300px; /* Default desktop size */
        }
        
        .search-bar input {
          border: none;
          outline: none;
          flex-grow: 1;
          margin-left: 10px;
          font-size: 1rem;
          color: var(--color-text-dark);
        }

        /* --- Buttons --- */
        .btn {
          display: flex;
          align-items: center;
          gap: 5px;
          padding: 10px 15px;
          border-radius: 8px;
          font-weight: 500;
          cursor: pointer;
          transition: background-color 0.2s, box-shadow 0.2s;
          border: none;
        }

        .btn-primary {
          background-color: var(--color-primary);
          color: var(--color-text-light);
          box-shadow: 0 2px 4px rgba(16, 185, 129, 0.4);
        }

        .btn-primary:hover {
          background-color: var(--color-primary-dark);
        }

        .btn-secondary {
          background-color: var(--color-border);
          color: var(--color-text-dark);
        }
        .btn-secondary:hover {
          background-color: #d1d5db; /* Gray-300 */
        }

        .action-icon-btn {
          background: none;
          border: none;
          cursor: pointer;
          padding: 5px;
          border-radius: 4px;
          transition: background-color 0.15s;
          color: #4b5563; /* Gray-600 */
        }
        .action-icon-btn:hover {
          background-color: var(--color-border);
        }
        .action-icon-btn.delete {
          color: var(--color-danger);
        }
        .action-icon-btn.delete:hover {
          background-color: #fee2e2; /* Red-100 */
        }
        .action-icon-btn.edit {
          color: #2563eb; /* Blue-600 */
        }
        .action-icon-btn.edit:hover {
          background-color: #eff6ff; /* Blue-50 */
        }
        
        /* --- Layout --- */
        .main-layout {
          display: grid;
          grid-template-columns: 1fr 3fr; /* Farm list on left, detail on right */
          gap: 20px;
        }

        /* --- Farm List (Left Panel) --- */
        .farm-list-panel {
          background-color: var(--color-text-light);
          border-radius: 12px;
          box-shadow: var(--color-shadow);
          padding: 20px;
          min-height: 600px;
        }
        
        .farm-list-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 15px;
          padding-bottom: 10px;
          border-bottom: 1px solid var(--color-border);
        }

        .farm-list-item {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 15px;
          border-radius: 8px;
          margin-bottom: 10px;
          transition: background-color 0.2s, box-shadow 0.2s;
          border: 1px solid transparent;
        }
        
        .farm-list-item > div:first-child {
            flex-grow: 1;
            cursor: pointer;
        }
        
        .farm-list-item:hover {
          background-color: #f3f4f6; /* Gray-100 */
        }

        .farm-list-item.selected {
          background-color: #d1fae5; /* Emerald-100 */
          border-color: var(--color-primary);
          box-shadow: 0 1px 3px rgba(16, 185, 129, 0.2);
        }

        .farm-item-title {
          font-weight: 600;
          font-size: 1.1rem;
          color: var(--color-primary-dark);
        }

        .farm-item-details {
          display: flex;
          justify-content: space-between;
          margin-top: 5px;
          font-size: 0.9rem;
          color: #6b7280; /* Gray-500 */
        }
        
        .farm-actions {
          display: flex;
          gap: 5px;
          flex-shrink: 0;
        }

        /* --- Farm Detail & Crops (Right Panel) --- */
        .detail-panel {
          display: flex;
          flex-direction: column;
          gap: 20px;
        }
        
        .detail-card {
          background-color: var(--color-text-light);
          border-radius: 12px;
          box-shadow: var(--color-shadow);
          padding: 25px;
        }
        
        .farm-details-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
          gap: 20px;
          margin-top: 15px;
        }
        
        .detail-item {
          display: flex;
          align-items: center;
          gap: 10px;
          padding: 10px;
          background-color: var(--color-secondary);
          border-radius: 8px;
        }
        
        .detail-label {
          font-size: 0.85rem;
          font-weight: 500;
          color: #6b7280;
        }
        
        .detail-value {
          font-weight: 600;
          color: var(--color-text-dark);
        }

        /* --- Crop Table --- */
        .crop-table-container {
          overflow-x: auto;
          margin-top: 15px;
        }
        
        .crop-table {
          width: 100%;
          border-collapse: collapse;
          text-align: left;
        }

        .crop-table th, .crop-table td {
          padding: 12px 15px;
          border-bottom: 1px solid var(--color-border);
        }

        .crop-table th {
          background-color: #f3f4f6; /* Gray-100 */
          font-weight: 600;
          font-size: 0.9rem;
          color: #4b5563; /* Gray-600 */
        }
        
        .crop-table tr:last-child td {
          border-bottom: none;
        }
        
        .crop-table tbody tr:hover {
          background-color: #fafafb;
        }

        /* --- Modal (Form) Styles --- */
        .modal-overlay {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background-color: rgba(0, 0, 0, 0.5);
          display: flex;
          justify-content: center;
          align-items: center;
          z-index: 1000;
        }

        .modal-content {
          background-color: var(--color-text-light);
          padding: 30px;
          border-radius: 12px;
          box-shadow: var(--color-shadow);
          width: 90%;
          max-width: 600px;
          max-height: 90vh;
          overflow-y: auto;
          position: relative;
        }

        .modal-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 20px;
          padding-bottom: 10px;
          border-bottom: 1px solid var(--color-border);
        }

        .modal-title {
          font-size: 1.25rem;
          font-weight: 600;
        }

        .close-btn {
          background: none;
          border: none;
          cursor: pointer;
          color: #6b7280;
          transition: color 0.2s;
        }
        .close-btn:hover {
          color: var(--color-text-dark);
        }

        .form-grid {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 20px;
        }
        
        .form-group {
          display: flex;
          flex-direction: column;
          gap: 5px;
        }
        
        .form-group label {
          font-weight: 500;
          font-size: 0.9rem;
          color: #374151; /* Gray-700 */
        }
        
        .form-group input, .form-group select {
          padding: 10px;
          border: 1px solid var(--color-border);
          border-radius: 6px;
          transition: border-color 0.2s;
          font-size: 1rem;
        }
        
        .form-group input:focus, .form-group select:focus {
          border-color: var(--color-primary);
          outline: none;
          box-shadow: 0 0 0 2px rgba(16, 185, 129, 0.2);
        }

        .modal-actions {
          display: flex;
          justify-content: flex-end;
          gap: 10px;
          margin-top: 25px;
          padding-top: 15px;
          border-top: 1px solid var(--color-border);
        }
        
        .error-message {
          color: var(--color-danger);
          background-color: #fee2e2;
          padding: 10px;
          border-radius: 6px;
          margin-bottom: 15px;
          font-weight: 500;
        }
        
        /* Specific Delete Modal Styles */
        .delete-modal-content {
          max-width: 400px;
          text-align: center;
        }
        
        .delete-modal-content .modal-body {
          font-size: 1.1rem;
          margin-bottom: 20px;
        }
        
        .btn-delete-confirm {
          background-color: var(--color-danger);
          color: var(--color-text-light);
        }
        .btn-delete-confirm:hover {
          background-color: #b91c1c; /* Red-700 */
        }
        
        .loading-state, .empty-state {
          padding: 40px;
          text-align: center;
          font-size: 1.2rem;
          color: #6b7280;
        }
        
        /* --- Mobile Responsiveness --- */
        @media (max-width: 900px) {
          .main-layout {
            grid-template-columns: 1fr; /* Stack panels vertically */
          }
          
          .farm-list-panel {
            min-height: auto;
          }
          
          .header-bar {
            flex-direction: column;
            align-items: stretch;
            gap: 15px;
          }
          
          .search-bar {
            width: 100%;
          }
          
          .farm-list-header {
            flex-direction: column;
            align-items: stretch;
            gap: 10px;
          }
          
          .farm-details-grid {
             grid-template-columns: 1fr; /* Single column for details */
          }
          
          .form-grid {
             grid-template-columns: 1fr; /* Single column for forms */
          }
        }
      `}
    </style>
  );

  const FarmForm = () => (
    <form onSubmit={handleSave}>
      <div className="form-grid">
        <div className="form-group">
          <label htmlFor="owner_name">Owner Name</label>
          <input
            type="text"
            id="owner_name"
            name="owner_name"
            value={currentFarmForm.owner_name}
            onChange={(e) => handleFormChange(e, "farm")}
            required
            placeholder="John Doe"
          />
        </div>
        <div className="form-group">
          <label htmlFor="farm_size">Farm Size (Acres)</label>
          <input
            type="number"
            id="farm_size"
            name="farm_size"
            value={currentFarmForm.farm_size}
            onChange={(e) => handleFormChange(e, "farm")}
            required
            placeholder="e.g., 10.5"
            step="0.1"
          />
        </div>
        <div className="form-group">
          <label htmlFor="survey_number">Survey Number</label>
          <input
            type="text"
            id="survey_number"
            name="survey_number"
            value={currentFarmForm.survey_number}
            onChange={(e) => handleFormChange(e, "farm")}
            placeholder="e.g., K-45/A"
          />
        </div>
        <div className="form-group">
          <label htmlFor="pincode">Pincode</label>
          <input
            type="text"
            id="pincode"
            name="pincode"
            value={currentFarmForm.pincode}
            onChange={(e) => handleFormChange(e, "farm")}
            placeholder="e.g., 123456"
          />
        </div>
        <div className="form-group">
          <label htmlFor="soil_type_id">Soil Type</label>
          <select
            id="soil_type_id"
            name="soil_type_id"
            value={currentFarmForm.soil_type_id}
            onChange={(e) => handleFormChange(e, "farm")}
            required
          >
            <option value="">Select Soil Type</option>
            {(lookups.soilTypes || []).map((type) => (
              <option key={type.id} value={type.id}>
                {type.name}
              </option>
            ))}
          </select>
        </div>
        <div className="form-group">
          <label htmlFor="irrigation_id">Irrigation Method</label>
          <select
            id="irrigation_id"
            name="irrigation_id"
            value={currentFarmForm.irrigation_id}
            onChange={(e) => handleFormChange(e, "farm")}
          >
            <option value="">Select Irrigation</option>
            {(lookups.irrigations || []).map((method) => (
              <option key={method.id} value={method.id}>
                {method.name}
              </option>
            ))}
          </select>
        </div>
        <div className="form-group">
          <label htmlFor="water_source_id">Water Source</label>
          <select
            id="water_source_id"
            name="water_source_id"
            value={currentFarmForm.water_source_id}
            onChange={(e) => handleFormChange(e, "farm")}
          >
            <option value="">Select Water Source</option>
            {(lookups.waterSources || []).map((source) => (
              <option key={source.id} value={source.id}>
                {source.name}
              </option>
            ))}
          </select>
        </div>
      </div>
    </form>
  );

  const CropForm = () => (
    <form onSubmit={handleSave}>
      <div className="form-grid">
        <div className="form-group">
          <label htmlFor="crop_type_id">Crop Type</label>
          <select
            id="crop_type_id"
            name="crop_type_id"
            value={currentCropForm.crop_type_id}
            onChange={(e) => handleFormChange(e, "crop")}
            required
          >
            <option value="">Select Crop Type</option>
            {(lookups.cropTypes || []).map((type) => (
              <option key={type.id} value={type.id}>
                {type.name}
              </option>
            ))}
          </select>
        </div>
        <div className="form-group">
          <label htmlFor="plant_id">Plant Name</label>
          <select
            id="plant_id"
            name="plant_id"
            value={currentCropForm.plant_id}
            onChange={(e) => handleFormChange(e, "crop")}
            required
          >
            <option value="">Select Plant</option>
            {(lookups.plants || []).map((plant) => (
              <option key={plant.id} value={plant.id}>
                {plant.name}
              </option>
            ))}
          </select>
        </div>
        <div className="form-group">
          <label htmlFor="sowing_date">Sowing Date</label>
          <input
            type="date"
            id="sowing_date"
            name="sowing_date"
            value={currentCropForm.sowing_date}
            onChange={(e) => handleFormChange(e, "crop")}
            required
          />
        </div>
        <div className="form-group">
          <label htmlFor="expected_harvest_date">Expected Harvest Date</label>
          <input
            type="date"
            id="expected_harvest_date"
            name="expected_harvest_date"
            value={currentCropForm.expected_harvest_date}
            onChange={(e) => handleFormChange(e, "crop")}
            required
          />
        </div>
        <input
          type="hidden"
          name="farm_id"
          value={currentCropForm.farm_id}
          readOnly
        />
      </div>
    </form>
  );

  return (
    <div className="app-container">
      {styles}
      <div className="header-bar">
        <h1 className="header-title">
          <Leaf size={30} color="#10b981" /> Farm & Crop Management
        </h1>
        <div className="search-bar">
          <Search size={20} color="#6b7280" />
          <input
            type="text"
            placeholder="Search farms by owner name..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <button
          className="btn btn-primary"
          onClick={() => handleOpenFarmForm(null)}
        >
          <Plus size={20} /> New Farm
        </button>
      </div>

      {errorMessage && <div className="error-message">{errorMessage}</div>}

      {farms.length === 0 && !isLoading ? (
        <div className="empty-state">No farms found. Add your first farm!</div>
      ) : (
        <div className="main-layout">
          {/* Farm List Panel */}
          <div className="farm-list-panel">
            <div className="farm-list-header">
              <h2 style={{ fontSize: "1.2rem", fontWeight: 600 }}>Farm List</h2>
              {filteredFarms.length > 0 && (
                <span style={{ fontSize: "0.9rem", color: "#6b7280" }}>
                  {filteredFarms.length} Farms
                </span>
              )}
            </div>
            {filteredFarms.map((farm) => (
              <div
                key={farm.farm_id}
                className={`farm-list-item ${
                  farm.farm_id === selectedFarmId ? "selected" : ""
                }`}
              >
                <div
                  onClick={() => setSelectedFarmId(farm.farm_id)}
                  style={{ cursor: "pointer" }}
                >
                  <div className="farm-item-title">
                    {farm.owner_name || "Untitled Farm"}'s Farm
                  </div>
                  <div className="farm-item-details">
                    <span>Size: **{farm.farm_size}** Acres</span>
                    <span>
                      Soil: **{getLookupName("soilTypes", farm.soil_type_id)}**
                    </span>
                  </div>
                </div>
                <div className="farm-actions">
                  <button
                    className="action-icon-btn edit"
                    onClick={() => handleOpenFarmForm(farm)}
                    title="Edit Farm"
                  >
                    <Edit size={16} />
                  </button>
                  <button
                    className="action-icon-btn delete"
                    onClick={() => handleDelete("farm", farm.farm_id)}
                    title="Delete Farm"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>
            ))}
            {filteredFarms.length === 0 && searchTerm && (
              <div className="empty-state">No farms match "{searchTerm}".</div>
            )}
          </div>

          {/* Farm Details and Crops Panel */}
          <div className="detail-panel">
            {selectedFarm ? (
              <>
                <div className="detail-card">
                  <div className="farm-list-header">
                    <h2 className="header-title">
                      <Users size={24} color="#059669" /> Farm Details:{" "}
                      {selectedFarm.owner_name || "Untitled Farm"}
                    </h2>
                  </div>
                  <div className="farm-details-grid">
                    <div className="detail-item">
                      <Maximize size={20} color="#374151" />
                      <div>
                        <div className="detail-label">Size (Acres)</div>
                        <div className="detail-value">
                          {selectedFarm.farm_size || "N/A"}
                        </div>
                      </div>
                    </div>
                    <div className="detail-item">
                      <MapPin size={20} color="#374151" />
                      <div>
                        <div className="detail-label">Survey No.</div>
                        <div className="detail-value">
                          {selectedFarm.survey_number || "N/A"}
                        </div>
                      </div>
                    </div>
                    <div className="detail-item">
                      <Layers size={20} color="#374151" />
                      <div>
                        <div className="detail-label">Soil Type</div>
                        <div className="detail-value">
                          {getLookupName(
                            "soilTypes",
                            selectedFarm.soil_type_id
                          )}
                        </div>
                      </div>
                    </div>
                    <div className="detail-item">
                      <Droplet size={20} color="#374151" />
                      <div>
                        <div className="detail-label">Irrigation</div>
                        <div className="detail-value">
                          {getLookupName(
                            "irrigations",
                            selectedFarm.irrigation_id
                          )}
                        </div>
                      </div>
                    </div>
                    <div className="detail-item">
                      <Zap size={20} color="#374151" />
                      <div>
                        <div className="detail-label">Water Source</div>
                        <div className="detail-value">
                          {getLookupName(
                            "waterSources",
                            selectedFarm.water_source_id
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Crops Table */}
                <div className="detail-card">
                  <div className="farm-list-header">
                    <h2 className="header-title">
                      <Leaf size={24} color="#059669" /> Crops Planted
                    </h2>
                    <button
                      className="btn btn-primary"
                      onClick={() => handleOpenCropForm(null)}
                    >
                      <Plus size={20} /> Add Crop
                    </button>
                  </div>
                  <div className="crop-table-container">
                    <table className="crop-table">
                      <thead>
                        <tr>
                          <th>Plant</th>
                          <th>Type</th>
                          <th>Sowing Date</th>
                          <th>Harvest Date</th>
                          <th>Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {cropsForSelectedFarm.length > 0 ? (
                          cropsForSelectedFarm.map((crop) => (
                            <tr key={crop.crop_id}>
                              <td>{getLookupName("plants", crop.plant_id)}</td>
                              <td>
                                {getLookupName("cropTypes", crop.crop_type_id)}
                              </td>
                              <td>
                                {new Date(
                                  crop.sowing_date
                                ).toLocaleDateString()}
                              </td>
                              <td>
                                {new Date(
                                  crop.expected_harvest_date
                                ).toLocaleDateString()}
                              </td>
                              <td>
                                <div className="farm-actions">
                                  <button
                                    className="action-icon-btn edit"
                                    onClick={() => handleOpenCropForm(crop)}
                                    title="Edit Crop"
                                  >
                                    <Edit size={16} />
                                  </button>
                                  <button
                                    className="action-icon-btn delete"
                                    onClick={() =>
                                      handleDelete("crop", crop.crop_id)
                                    }
                                    title="Delete Crop"
                                  >
                                    <Trash2 size={16} />
                                  </button>
                                </div>
                              </td>
                            </tr>
                          ))
                        ) : (
                          <tr>
                            <td colSpan="5" className="empty-state">
                              No crops planted on this farm.
                            </td>
                          </tr>
                        )}
                      </tbody>
                    </table>
                  </div>
                </div>
              </>
            ) : (
              <div className="empty-state detail-card">
                Select a farm from the list to view its details and crops.
              </div>
            )}
          </div>
        </div>
      )}

      {/* Farm/Crop Form Modal */}
      <CustomModal
        title={
          isEditing
            ? `Edit ${formType === "farm" ? "Farm" : "Crop"}`
            : `Add New ${formType === "farm" ? "Farm" : "Crop"}`
        }
        isOpen={isFarmFormOpen || isCropFormOpen}
        onClose={handleCloseForm}
        actions={
          <>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={handleCloseForm}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              onClick={handleSave}
            >
              Save Changes
            </button>
          </>
        }
      >
        {formType === "farm" && <FarmForm />}
        {formType === "crop" && <CropForm />}
      </CustomModal>

      {/* Delete Confirmation Modal */}
      <CustomModal
        title={`Confirm Delete ${itemToDelete?.type}`}
        isOpen={isDeleteModalOpen}
        onClose={() => setIsDeleteModalOpen(false)}
        actions={
          <>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setIsDeleteModalOpen(false)}
            >
              Cancel
            </button>
            <button
              type="button"
              className="btn btn-delete-confirm"
              onClick={handleConfirmDelete}
            >
              <Trash2 size={16} /> Delete
            </button>
          </>
        }
      >
        <div className="delete-modal-content">
          <p className="modal-body">
            Are you sure you want to permanently delete this{" "}
            {itemToDelete?.type}? This action cannot be undone.
          </p>
        </div>
      </CustomModal>
    </div>
  );
};

export default FarmCrop;
