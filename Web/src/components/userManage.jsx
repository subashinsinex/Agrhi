import React, {
  useEffect,
  useState,
  useCallback,
  useMemo,
  useRef,
} from "react";
import { axiosInstance } from "../api/login";
import {
  X,
  Mail,
  Phone,
  MapPin,
  Calendar,
  Search,
  Plus,
  Trash2,
  Edit,
  Users,
  Sprout,
  ShieldCheck,
  CheckCircle,
  AlertCircle,
  ShoppingBag,
  User,
  Leaf,
  Wind,
  CloudSun,
} from "lucide-react";

import { SERVER_IP, SERVER_PORT } from "../constant";

// --- CONFIGURATION & THEME HELPERS ---

const categoryOptions = [
  {
    id: "582d0c0c-8bf2-4753-8c6c-1a398930b0e7",
    label: "Farmer",
    color: "#4CAF50",
    bg: "#E8F5E9",
  },
  {
    id: "c944ecb8-524d-483f-9610-ed9e2e985e49",
    label: "Expert",
    color: "#2E7D32",
    bg: "#C8E6C9",
  },
  {
    id: "4bf987aa-5067-4f07-a827-9c685e1fd1c1",
    label: "Admin",
    color: "#1B5E20",
    bg: "#A5D6A7",
  },
  {
    id: "c7f2d8e1-9a54-4a6c-8e37-5d2b1f8c4e12",
    label: "Retailer",
    color: "#05410eff",
    bg: "#FFF3E0",
  },
  {
    id: "a3e9a9b4-4c2d-4b1f-9b3b-23f5c4a7d901",
    label: "Consumer",
    color: "#012c0bff",
    bg: "#FFF8E1",
  },
];

const getCategoryDetails = (id) => {
  return (
    categoryOptions.find((c) => c.id.toString() === id.toString()) || {
      label: "User",
      color: "#666",
      bg: "#f0f0f0",
    }
  );
};

const apiBase = `http://${SERVER_IP}:${SERVER_PORT}/api/users`;

const UserManage = ({ isSidebarOpen, toggleSidebar }) => {
  // State Management
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusMsg, setStatusMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");
  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [userToDelete, setUserToDelete] = useState(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [isFormVisible, setIsFormVisible] = useState(false);
  const formOverlayRef = useRef(null);

  // Dashboard Analytics (Simulated/Calculated)
  const stats = useMemo(
    () => ({
      total: users.length,
      farmers: users.filter((u) => u.category_id === categoryOptions[0].id)
        .length,
      experts: users.filter((u) => u.category_id === categoryOptions[1].id)
        .length,
      admins: users.filter((u) => u.category_id === categoryOptions[2].id)
        .length,
      retailers: users.filter((u) => u.category_id === categoryOptions[3].id)
        .length,
      consumers: users.filter((u) => u.category_id === categoryOptions[4].id)
        .length,
    }),
    [users],
  );

  // Form State
  const [form, setForm] = useState({
    name: "",
    dob: "",
    address: "",
    pincode: "",
    phone_number: "",
    email: "",
    password: "",
    category_id: "",
  });
  const [isEdit, setIsEdit] = useState(false);
  const formSectionRef = useRef(null);
  const access_token = localStorage.getItem("access_token");

  // Add this handler for clicking outside modal
  const handleOverlayClick = useCallback((e) => {
    if (formOverlayRef.current && !formOverlayRef.current.contains(e.target)) {
      resetForm(false);
    }
  }, []);

  // --- API OPERATIONS ---

  const fetchUsers = useCallback(async () => {
    setLoading(true);
    setErrorMsg("");
    if (!access_token) {
      setErrorMsg("Unauthorized: Please log in again.");
      setLoading(false);
      return;
    }
    try {
      const res = await axiosInstance.get(`${apiBase}/getUser`, {
        headers: { Authorization: `Bearer ${access_token}` },
      });

      const processed = res.data.map((u) => {
        let formattedDob = "Not Set";
        if (u.dob) {
          const date = new Date(u.dob);
          formattedDob = date.toLocaleDateString("en-GB", {
            day: "2-digit",
            month: "short",
            year: "numeric",
          });
        }
        return {
          ...u,
          categoryInfo: getCategoryDetails(u.category_id),
          formatted_dob: formattedDob,
        };
      });
      setUsers(processed || []);
    } catch (err) {
      setErrorMsg(
        "Failed to synchronize records: " +
          (err.response?.data?.message || err.message),
      );
    } finally {
      setLoading(false);
    }
  }, [access_token]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  const handleChange = (e) =>
    setForm({ ...form, [e.target.name]: e.target.value });

  const resetForm = (showForm = true) => {
    setForm({
      name: "",
      dob: "",
      address: "",
      pincode: "",
      phone_number: "",
      email: "",
      password: "",
      category_id: "",
    });
    setIsEdit(false);
    setErrorMsg("");
    setStatusMsg("");
    setIsFormVisible(showForm);
  };

  const handleAddNewUser = () => {
    if (isFormVisible && !isEdit) {
      setIsFormVisible(false);
    } else {
      resetForm(true);
      setTimeout(() => {
        formSectionRef.current?.scrollIntoView({
          behavior: "smooth",
          block: "start",
        });
      }, 100);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setStatusMsg("");
    setErrorMsg("");
    try {
      if (isEdit) {
        await axiosInstance.put(`${apiBase}/putUser/${form.user_id}`, form, {
          headers: { Authorization: `Bearer ${access_token}` },
        });
        setStatusMsg("Profile updated successfully.");
      } else {
        await axiosInstance.post(`${apiBase}/postUser`, form, {
          headers: { Authorization: `Bearer ${access_token}` },
        });
        setStatusMsg("New member enrolled successfully.");
      }
      fetchUsers();
      setIsFormVisible(false);
    } catch (err) {
      setErrorMsg(
        err?.response?.data?.message ||
          "Operation failed. Please check inputs.",
      );
    }
  };

  const handleEdit = (user) => {
    setForm({
      user_id: user.user_id,
      name: user.name,
      dob: user.dob ? user.dob.split("T")[0] : "",
      address: user.address || "",
      pincode: user.pincode || "",
      phone_number: user.phone_number || "",
      email: user.email,
      password: "",
      category_id: user.category_id,
    });
    setIsEdit(true);
    setIsFormVisible(true);
    // Scroll ONLY to form (remove window.scrollTo)
    setTimeout(() => {
      formSectionRef.current?.scrollIntoView({
        behavior: "smooth",
        block: "start",
      });
    }, 100);
  };

  const filteredUsers = useMemo(() => {
    return users.filter(
      (u) =>
        u.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        u.email.toLowerCase().includes(searchTerm.toLowerCase()),
    );
  }, [users, searchTerm]);

  // --- STYLING (AGRICULTURE MINIMALISM) ---

  const styles = `
    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;700&family=Outfit:wght@300;400;600;700&display=swap');

    :root {
      --ag-forest: rgba(5, 82, 25, 1);
      --ag-sage: #8BA888;
      --ag-leaf: #4A7C44;
      --ag-sand: #F4F1EA;
      --ag-clay: #D9C5B2;
      --ag-white: #FFFFFF;
      --ag-slate: #34495E;
      --ag-shadow: rgba(27, 60, 53, 0.08);
      --radius-organic: 24px;
      --transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    }

    .ag-wrapper {
      min-height: 100vh;
      background: transparent; /* Show Three.js background */
      font-family: 'Outfit', sans-serif;
      padding: 30px;
      transition: margin-left 0.4s ease;
      color: var(--ag-forest);
      
    }

    @media (min-width: 1024px) {
      .ag-wrapper.sidebar-open { margin-left: 260px; }
    }

    /* Minimalist Dashboard Header */
    .ag-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 40px;
      gap: 20px;
      flex-wrap: wrap;
    }

    .ag-title h1 {
      font-size: 2.2rem;
      font-weight: 700;
      margin: 0;
      color: var(--ag-forest);
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .ag-title p { color: var(--ag-sage); margin: 4px 0 0 0; font-size: 1rem; }

    /* Control Panel */
    .ag-controls { display: flex; gap: 16px; align-items: center; }

    .ag-search-bar {
      background: var(--ag-white);
      border-radius: 50px;
      padding: 8px 20px;
      display: flex;
      align-items: center;
      gap: 12px;
      box-shadow: 0 4px 15px var(--ag-shadow);
      border: 1px solid transparent;
      transition: var(--transition);
      width: 300px;
    }

    .ag-search-bar:focus-within { border-color: var(--ag-leaf); width: 350px; }
    .ag-search-bar input { border: none; outline: none; width: 100%; font-family: inherit; font-size: 0.95rem; }
    .ag-search-bar svg { color: var(--ag-sage); }

    .btn-ag {
      background: var(--ag-forest);
      color: var(--ag-white);
      border: none;
      padding: 12px 24px;
      border-radius: 50px;
      font-weight: 600;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 8px;
      transition: var(--transition);
      box-shadow: 0 6px 15px rgba(27, 60, 53, 0.2);
    }

    .btn-ag:hover { background: var(--ag-leaf); transform: translateY(-2px); }
    .btn-ag.cancel { background: #E74C3C; }

    /* Stats Section */
    .ag-stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 20px;
      margin-bottom: 40px;
    }

    .ag-stat-card {
      background: var(--ag-white);
      padding: 20px;
      border-radius: var(--radius-organic);
      border: 1px solid rgba(139, 168, 136, 0.2);
      display: flex;
      align-items: center;
      gap: 16px;
      box-shadow: 0 4px 10px var(--ag-shadow);
    }

    .ag-stat-icon {
      width: 50px;
      height: 50px;
      border-radius: 16px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: var(--ag-sand);
      color: var(--ag-leaf);
    }

    .ag-stat-info h4 { margin: 0; font-size: 0.85rem; color: var(--ag-sage); text-transform: uppercase; }
    .ag-stat-info h2 { margin: 0; font-size: 1.6rem; font-weight: 700; }

    /* Professional Form */
    .ag-form-container {
      background: var(--ag-white);
      border-radius: var(--radius-organic);
      padding: 40px;
      margin-bottom: 40px;
      box-shadow: 0 20px 40px var(--ag-shadow);
      animation: agriSlideIn 0.5s ease-out;
      border: 1px solid rgba(139, 168, 136, 0.1);
    }

    @keyframes agriSlideIn {
      from { opacity: 0; transform: translateY(-20px); }
      to { opacity: 1; transform: translateY(0); }
    }

    .ag-form-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 24px;
    }

    .ag-input-group { display: flex; flex-direction: column; gap: 8px; }
    .ag-input-group label { font-size: 0.9rem; font-weight: 600; color: var(--ag-forest); opacity: 0.8; }
    .ag-input-group input, .ag-input-group select {
      padding: 12px 16px;
      border-radius: 12px;
      border: 1.5px solid #eee;
      background: #fafafa;
      transition: var(--transition);
      font-family: inherit;
    }

    .ag-input-group input:focus { border-color: var(--ag-leaf); background: white; box-shadow: 0 0 0 4px rgba(74, 124, 68, 0.1); outline: none; }

    /* User Grid */
    .ag-user-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 30px;
    }

    .ag-card {
      background: var(--ag-white);
      border-radius: var(--radius-organic);
      padding: 30px;
      position: relative;
      border: 1px solid rgba(139, 168, 136, 0.1);
      transition: var(--transition);
      overflow: hidden;
    }

    .ag-card:hover { transform: translateY(-10px); box-shadow: 0 15px 35px var(--ag-shadow); }

    .ag-card::before {
        content: "";
        position: absolute;
        top: -20px;
        right: -20px;
        width: 100px;
        height: 100px;
        background: var(--ag-sand);
        border-radius: 50%;
        opacity: 0.5;
        z-index: 0;
    }

    .ag-card-header { position: relative; z-index: 1; display: flex; gap: 15px; align-items: center; margin-bottom: 25px; }
    .ag-avatar {
      width: 60px;
      height: 60px;
      border-radius: 20px;
      background: var(--ag-forest);
      color: white;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 1.5rem;
      font-weight: 700;
      box-shadow: 0 8px 15px rgba(27, 60, 53, 0.15);
    }

    .ag-badge {
      font-size: 0.7rem;
      padding: 4px 12px;
      border-radius: 50px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .ag-card-body { position: relative; z-index: 1; display: flex; flex-direction: column; gap: 14px; }
    .ag-data-item { display: flex; align-items: center; gap: 10px; color: var(--ag-slate); font-size: 0.95rem; }
    .ag-data-item svg { color: var(--ag-sage); flex-shrink: 0; }

    .ag-card-actions {
      margin-top: 25px;
      padding-top: 20px;
      border-top: 1px solid #f0f0f0;
      display: flex;
      gap: 12px;
    }

    .btn-action {
      flex: 1;
      padding: 10px;
      border-radius: 12px;
      border: none;
      font-weight: 600;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      font-size: 0.85rem;
      transition: var(--transition);
    }

    .btn-edit { background: var(--ag-sand); color: var(--ag-forest); }
    .btn-edit:hover { background: var(--ag-clay); }
    .btn-delete { background: #FFF5F5; color: #E53E3E; }
    .btn-delete:hover { background: #FED7D7; }

    /* Modals */
    .ag-overlay {
      position: fixed;
      inset: 0;
      background: rgba(27, 60, 53, 0.4);
      backdrop-filter: blur(8px);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 9999;
      padding: 20px;
    }

    .ag-modal {
      background: white;
      padding: 40px;
      border-radius: var(--radius-organic);
      width: 100%;
      max-width: 450px;
      text-align: center;
      box-shadow: 0 30px 60px rgba(0,0,0,0.2);
    }

    /* Status Alerts */
    .ag-alert {
      padding: 16px;
      border-radius: 16px;
      margin-bottom: 24px;
      display: flex;
      align-items: center;
      gap: 12px;
      font-weight: 500;
    }
    .ag-alert.success { background: #EBFEEB; color: #2D5A27; border: 1px solid #D5F5D5; }
    .ag-alert.error { background: #FFF5F5; color: #C53030; border: 1px solid #FEB2B2; }

    /* Responsive */
    @media (max-width: 768px) {
      .ag-header { flex-direction: column; align-items: stretch; margin-top: 60px; }
      .ag-search-bar { width: 100%; }
      .ag-stats-grid { grid-template-columns: 1fr 1fr; }
    }
  `;

  return (
    <div className={`ag-wrapper ${isSidebarOpen ? "sidebar-open" : ""}`}>
      <style>{styles}</style>

      {/* Header & Controls */}
      <div className="ag-header">
        <div className="ag-title"></div>

        <div className="ag-controls">
          <div className="ag-search-bar">
            <Search size={18} />
            <input
              type="text"
              placeholder="Filter by name or email..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <button
            className={`btn-ag ${isFormVisible && !isEdit ? "cancel" : ""}`}
            onClick={handleAddNewUser}
          >
            {isFormVisible && !isEdit ? <X size={20} /> : <Plus size={20} />}
            {isFormVisible && !isEdit ? "Cancel" : "Add User"}
          </button>
        </div>
      </div>

      {/* Analytics Snapshot */}
      <div className="ag-stats-grid">
        <div className="ag-stat-card">
          <div className="ag-stat-icon">
            <Users size={22} />
          </div>
          <div className="ag-stat-info">
            <h4>Total Users</h4>
            <h2>{stats.total}</h2>
          </div>
        </div>
        <div className="ag-stat-card">
          <div className="ag-stat-icon" style={{ color: "#4CAF50" }}>
            <Leaf size={22} />
          </div>
          <div className="ag-stat-info">
            <h4>Farmers</h4>
            <h2>{stats.farmers}</h2>
          </div>
        </div>
        <div className="ag-stat-card">
          <div className="ag-stat-icon" style={{ color: "#2E7D32" }}>
            <Sprout size={22} />
          </div>
          <div className="ag-stat-info">
            <h4>Experts</h4>
            <h2>{stats.experts}</h2>
          </div>
        </div>
        <div className="ag-stat-card">
          <div className="ag-stat-icon" style={{ color: "#1B3C35" }}>
            <ShieldCheck size={22} />
          </div>
          <div className="ag-stat-info">
            <h4>Admins</h4>
            <h2>{stats.admins}</h2>
          </div>
        </div>
        <div className="ag-stat-card">
          <div className="ag-stat-icon" style={{ color: "#7B1FA2" }}>
            <ShoppingBag size={22} />
          </div>
          <div className="ag-stat-info">
            <h4>Retailers</h4>
            <h2>{stats.retailers}</h2>
          </div>
        </div>
        <div className="ag-stat-card">
          <div className="ag-stat-icon" style={{ color: "#FF9800" }}>
            <User size={22} />
          </div>
          <div className="ag-stat-info">
            <h4>Consumers</h4>
            <h2>{stats.consumers}</h2>
          </div>
        </div>
      </div>

      {/* Feedback Messages */}
      {statusMsg && (
        <div className="ag-alert success">
          <CheckCircle size={20} /> {statusMsg}
        </div>
      )}
      {errorMsg && (
        <div className="ag-alert error">
          <AlertCircle size={20} /> {errorMsg}
        </div>
      )}

      {/* Form Section */}
      {isFormVisible && (
        <div className="ag-overlay" onClick={handleOverlayClick}>
          <div className="ag-modal" ref={formOverlayRef}>
            <h2
              style={{ marginTop: 0, marginBottom: "30px", fontSize: "1.5rem" }}
            >
              {isEdit ? "Update User Profile" : "Add New User"}
            </h2>
            <form onSubmit={handleSubmit}>
              <div className="ag-form-grid">
                {/* All existing form fields stay exactly the same */}
                <div className="ag-input-group">
                  <label>Full Name</label>
                  <input
                    name="name"
                    value={form.name}
                    onChange={handleChange}
                    required
                    placeholder="Enter full name"
                  />
                </div>
                {/* ... include ALL other input groups exactly as-is ... */}
                <div className="ag-input-group">
                  <label>Email Address</label>
                  <input
                    name="email"
                    type="email"
                    value={form.email}
                    onChange={handleChange}
                    required
                    placeholder="email@example.com"
                  />
                </div>
                <div className="ag-input-group">
                  <label>Phone Number</label>
                  <input
                    name="phone_number"
                    value={form.phone_number}
                    onChange={handleChange}
                    required
                    placeholder="Contact number"
                  />
                </div>
                <div className="ag-input-group">
                  <label>Birth Date</label>
                  <input
                    name="dob"
                    type="date"
                    value={form.dob}
                    onChange={handleChange}
                    required
                  />
                </div>
                <div className="ag-input-group">
                  <label>User Category</label>
                  <select
                    name="category_id"
                    value={form.category_id}
                    onChange={handleChange}
                    required
                  >
                    <option value="">Select Category</option>
                    {categoryOptions.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.label}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="ag-input-group">
                  <label>Pincode</label>
                  <input
                    name="pincode"
                    value={form.pincode}
                    onChange={handleChange}
                    required
                    placeholder="6-digit code"
                  />
                </div>
                <div
                  className="ag-input-group"
                  style={{ gridColumn: "1 / -1" }}
                >
                  <label>User Address</label>
                  <input
                    name="address"
                    value={form.address}
                    onChange={handleChange}
                    required
                    placeholder="Full Home or Farm address"
                  />
                </div>

                <div className="ag-input-group">
                  <label>
                    Secure Password {isEdit && "(Leave blank to skip)"}
                  </label>
                  <input
                    name="password"
                    type="password"
                    value={form.password}
                    onChange={handleChange}
                    required={!isEdit}
                  />
                </div>
              </div>

              <div style={{ marginTop: "40px", display: "flex", gap: "15px" }}>
                <button
                  className="btn-ag"
                  type="submit"
                  style={{ padding: "14px 40px", flex: 1 }}
                >
                  {isEdit ? "Update" : "Submit"}
                </button>
                <button
                  className="btn-ag cancel"
                  type="button"
                  onClick={() => resetForm(false)}
                  style={{ padding: "14px 40px", flex: 1 }}
                >
                  <X size={20} /> Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* User Data Grid */}
      {loading ? (
        <div style={{ textAlign: "center", padding: "100px" }}>
          <Wind
            size={40}
            className="ag-spin"
            style={{ color: "var(--ag-sage)" }}
          />
          <p style={{ color: "var(--ag-sage)", marginTop: "10px" }}>
            Cultivating data...
          </p>
        </div>
      ) : (
        <div className="ag-user-grid">
          {filteredUsers.length > 0 ? (
            filteredUsers.map((u) => (
              <div className="ag-card" key={u.user_id}>
                <div className="ag-card-header">
                  <div className="ag-avatar">{u.name.charAt(0)}</div>
                  <div>
                    <h3 style={{ margin: 0, fontSize: "1.2rem" }}>{u.name}</h3>
                    <span
                      className="ag-badge"
                      style={{
                        background: u.categoryInfo.bg,
                        color: u.categoryInfo.color,
                      }}
                    >
                      {u.categoryInfo.label}
                    </span>
                  </div>
                </div>

                <div className="ag-card-body">
                  <div className="ag-data-item">
                    <Mail size={16} /> {u.email}
                  </div>
                  <div className="ag-data-item">
                    <Phone size={16} /> {u.phone_number}
                  </div>
                  <div className="ag-data-item">
                    <MapPin size={16} /> {u.address}
                  </div>
                  <div className="ag-data-item">
                    <Calendar size={16} /> {u.formatted_dob}
                  </div>
                </div>

                <div className="ag-card-actions">
                  <button
                    className="btn-action btn-edit"
                    onClick={() => handleEdit(u)}
                  >
                    <Edit size={16} /> Edit
                  </button>
                  <button
                    className="btn-action btn-delete"
                    onClick={() => {
                      setUserToDelete(u);
                      setIsConfirmOpen(true);
                    }}
                  >
                    <Trash2 size={16} /> Delete
                  </button>
                </div>
              </div>
            ))
          ) : (
            <div
              style={{
                gridColumn: "1 / -1",
                textAlign: "center",
                padding: "60px",
                background: "white",
                borderRadius: "24px",
              }}
            >
              <CloudSun size={48} color="#ddd" />
              <p style={{ color: "#999", marginTop: "15px" }}>
                No records found for "{searchTerm}"
              </p>
            </div>
          )}
        </div>
      )}

      {/* Minimal Confirmation Modal */}
      {isConfirmOpen && (
        <div className="ag-overlay">
          <div className="ag-modal">
            <div
              style={{
                background: "#FFF5F5",
                color: "#E53E3E",
                width: "60px",
                height: "60px",
                borderRadius: "50%",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                margin: "0 auto 20px",
              }}
            >
              <AlertCircle size={30} />
            </div>
            <h2 style={{ margin: "0 0 10px 0" }}>Remove Member?</h2>
            <p style={{ color: "#666", marginBottom: "30px" }}>
              Are you sure you want to delete{" "}
              <strong>{userToDelete?.name}</strong>? This will permanently
              remove them from the system.
            </p>
            <div style={{ display: "flex", gap: "12px" }}>
              <button
                className="btn-ag"
                style={{ flex: 1, background: "#E53E3E" }}
                onClick={async () => {
                  try {
                    await axiosInstance.delete(
                      `${apiBase}/deleteUser/${userToDelete.user_id}`,
                      {
                        headers: { Authorization: `Bearer ${access_token}` },
                      },
                    );
                    setUsers(
                      users.filter((u) => u.user_id !== userToDelete.user_id),
                    );
                    setIsConfirmOpen(false);
                  } catch (e) {
                    setErrorMsg("Failed to delete.");
                  }
                }}
              >
                Delete Permanently
              </button>
              <button
                className="btn-ag"
                style={{
                  flex: 1,
                  background: "#eee",
                  color: "#333",
                  boxShadow: "none",
                }}
                onClick={() => setIsConfirmOpen(false)}
              >
                Keep Profile
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default UserManage;
