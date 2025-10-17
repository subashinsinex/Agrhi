import React, { useEffect, useState, useCallback, useMemo } from "react";
import axios from "axios";
// Using Menu, X, Mail, Phone, MapPin, Calendar, User, Search from lucide-react
import {
  Menu,
  X,
  Mail,
  Phone,
  MapPin,
  Calendar,
  User,
  Search,
} from "lucide-react";

import { SERVER_IP } from "../constant";

// IMPORTANT: Assume this component now receives props from a parent layout:
// props: { isSidebarOpen, toggleSidebar }

const categoryOptions = [
  { id: 1, label: "Farmer" },
  { id: 2, label: "Expert" },
  { id: 3, label: "Admin" },
];

// Helper to map category ID to a readable label
const getCategoryLabel = (id) => {
  const category = categoryOptions.find(
    (c) => c.id.toString() === id.toString()
  );
  return category ? category.label : "Unknown";
};

const apiBase = `http://${SERVER_IP}:5000/api/users`;

const UserManage = ({ isSidebarOpen, toggleSidebar }) => {
  // Accepts props
  const [users, setUsers] = useState([]);
  const [statusMsg, setStatusMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");
  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [userToDelete, setUserToDelete] = useState(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [isFormVisible, setIsFormVisible] = useState(false);

  // Add/Edit form state
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

  const token = localStorage.getItem("token");

  const fetchUsers = useCallback(async () => {
    setErrorMsg("");
    if (!token) {
      setErrorMsg("Authentication token missing. Cannot fetch data.");
      return;
    }
    try {
      const res = await axios.get(`${apiBase}/getUser`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      // Map user data to include the category label and ensure DOB is readable
      setUsers(
        res.data.map((u) => ({
          ...u,
          user_category: getCategoryLabel(u.category_id),
          // Format DOB to MM/DD/YYYY for card display
          formatted_dob: u.dob
            ? new Date(u.dob).toLocaleDateString("en-US")
            : "N/A",
        })) || []
      );
      setStatusMsg("");
    } catch (err) {
      setErrorMsg(
        "Unable to fetch users: " + (err.response?.data?.message || err.message)
      );
    }
  }, [token]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

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
    // Toggle form visibility
    if (isFormVisible && !isEdit) {
      setIsFormVisible(false);
    } else {
      resetForm(true); // Show form in add mode
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setStatusMsg("");
    setErrorMsg("");
    if (!token) {
      setErrorMsg("Authentication required for this action.");
      return;
    }
    try {
      if (isEdit) {
        await axios.put(`${apiBase}/putUser/${form.user_id}`, form, {
          headers: { Authorization: `Bearer ${token}` },
        });
        setStatusMsg("User updated successfully");
      } else {
        if (!form.password) {
          setErrorMsg("Password is required for adding a new user.");
          return;
        }
        await axios.post(`${apiBase}/postUser`, form, {
          headers: { Authorization: `Bearer ${token}` },
        });
        setStatusMsg("User added successfully");
      }
      fetchUsers();
      resetForm(false); // Hide form after successful submission
    } catch (err) {
      setErrorMsg(err?.response?.data?.message || "Error saving user details.");
    }
  };

  const handleEdit = (user) => {
    // Populate form data, converting DOB string to date input format
    setForm({
      user_id: user.user_id,
      name: user.name,
      dob: user.dob ? user.dob.split("T")[0] : "",
      address: user.address || "",
      pincode: user.pincode || "",
      phone_number: user.phone_number || "",
      email: user.email,
      password: "", // MUST NOT populate password!
      category_id: user.category_id,
    });
    setIsEdit(true);
    setIsFormVisible(true); // Show form when editing
    setStatusMsg("");
    setErrorMsg("");
  };

  const handleDeleteClick = (user) => {
    setUserToDelete(user);
    setIsConfirmOpen(true);
  };

  const confirmDelete = async () => {
    setIsConfirmOpen(false);
    setErrorMsg("");
    if (!userToDelete || !token) return;

    try {
      await axios.delete(`${apiBase}/deleteUser/${userToDelete.user_id}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      // Filter out deleted user and update status
      setUsers((prevUsers) =>
        prevUsers.filter((u) => u.user_id !== userToDelete.user_id)
      );
      setStatusMsg(`User ${userToDelete.name} deleted successfully.`);
    } catch (err) {
      setErrorMsg(
        "Could not delete user: " + (err.response?.data?.message || err.message)
      );
    } finally {
      setUserToDelete(null);
    }
  };

  const cancelDelete = () => {
    setIsConfirmOpen(false);
    setUserToDelete(null);
  };

  // Filter users based on search term (name or email)
  const filteredUsers = useMemo(() => {
    if (!searchTerm) return users;
    const lowerCaseSearch = searchTerm.toLowerCase();
    return users.filter(
      (user) =>
        user.name.toLowerCase().includes(lowerCaseSearch) ||
        user.email.toLowerCase().includes(lowerCaseSearch)
    );
  }, [users, searchTerm]);

  // Inline styles using modern CSS, mimicking Tailwind/the provided design
  // Updated margin-left to transition dynamically based on isSidebarOpen state on desktop
  const cardStyles = `
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
  
  /* Main content area transition and positioning */
  .user-mgmt-bg {
    
    min-height: 100vh;
    padding: 20px 30px;
    background: #f8f9fa;
    font-family: 'Inter', sans-serif;
    transition: margin-left 0.3s ease-out; /* Add transition for smooth movement */
  }

  /* Desktop View: Sidebar always open */
  @media (min-width: 1024px) {
    .user-mgmt-bg.sidebar-open {
        margin-left: 220px; /* Offset for sidebar width */
    }
    .user-mgmt-bg.sidebar-closed {
        margin-left: 0; /* Should not happen on desktop with fixed sidebar, but good for safety */
    }
    .menu-toggle-btn {
        display: none; /* Hide toggle button on desktop */
    }
  }

  /* Mobile/Tablet View: Full width, toggle button visible */
  @media (max-width: 1023px) {
    .user-mgmt-bg { 
        margin-left: 0 !important; /* Always full width */
        padding: 15px; 
    }
    .menu-toggle-btn {
        display: block;
        position: absolute;
        top: 25px;
        left: 20px;
        z-index: 60; /* Higher than sidebar */
        background: #4f46e5;
        color: white;
        border: none;
        border-radius: 50%;
        width: 40px;
        height: 40px;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
        transition: background 0.2s;
    }
    .menu-toggle-btn:hover {
        background: #4338ca;
    }
    .header-container { margin-top: 50px; } /* Push content down to clear the button */
    .mobile-overlay {
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.5);
        z-index: 49; /* Below sidebar, above content */
        transition: opacity 0.3s ease-out;
    }
  }

  /* Header & Search */
  .header-container {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 30px;
    padding-bottom: 10px;
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
  .search-box {
    position: relative;
  }
  .search-box input {
    width: 280px;
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
  .add-user-btn {
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
  .add-user-btn:hover {
    background: #4338ca;
    transform: translateY(-1px);
  }
  .add-user-btn svg {
      margin-right: 5px;
      width: 20px;
      height: 20px;
  }
  .toggle-active {
      background: #dc2626; /* Red when active/open */
      box-shadow: 0 4px 8px rgba(220, 38, 38, 0.3);
  }
  .toggle-active:hover {
      background: #b91c1c;
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
  .user-card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 30px;
  }

  /* Single Card */
  .user-card {
    background: #fff;
    border-radius: 16px;
    padding: 25px;
    box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
    border: 1px solid #f0f4f8;
    transition: transform 0.2s ease, box-shadow 0.2s ease;
  }
  .user-card:hover {
      transform: translateY(-3px);
      box-shadow: 0 15px 20px -5px rgba(0, 0, 0, 0.1), 0 6px 10px -3px rgba(0, 0, 0, 0.05);
  }
  
  .card-header {
    display: flex;
    align-items: center;
    margin-bottom: 15px;
    padding-bottom: 15px;
    border-bottom: 1px solid #eee;
  }
  .avatar {
    width: 50px;
    height: 50px;
    border-radius: 50%;
    background: #4f46e5; /* Primary color background for avatar */
    color: white;
    font-size: 1.5rem;
    font-weight: 700;
    display: flex;
    justify-content: center;
    align-items: center;
    margin-right: 15px;
    box-shadow: 0 2px 5px rgba(0,0,0,0.2);
  }
  .info-block {
    line-height: 1.2;
  }
  .info-block strong {
    display: block;
    font-size: 1.25rem;
    font-weight: 600;
    color: #1a202c;
  }
  .info-block span {
    font-size: 0.9rem;
    color: #6b7280;
    font-weight: 400;
  }

  .card-details {
    display: grid;
    grid-template-columns: 1fr;
    gap: 12px;
    margin-bottom: 20px;
  }
  .detail-item {
    display: flex;
    align-items: center;
    font-size: 0.95rem;
    color: #4a5568;
    font-weight: 500;
  }
  .detail-item svg {
    margin-right: 10px;
    width: 18px;
    height: 18px;
    color: #4f46e5;
  }
  
  .card-actions {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    border-top: 1px solid #eee;
    padding-top: 15px;
  }
  .action-btn, .delete-btn {
    padding: 8px 15px;
    border-radius: 8px;
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }
  .action-btn {
    background: #e0e7ff;
    color: #4f46e5;
    border: 1px solid #c7d2fe;
  }
  .action-btn:hover {
    background: #c7d2fe;
  }
  .delete-btn {
    background: #fee2e2;
    color: #ef4444;
    border: 1px solid #fecaca;
  }
  .delete-btn:hover {
    background: #fecaca;
  }

  /* Form Section (Hidden by default) */
  .form-section {
    background: #fff;
    padding: 30px;
    border-radius: 16px;
    box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
    max-width: 800px;
    margin: 30px auto;
    transition: all 0.3s ease-out;
    opacity: 0;
    height: 0;
    overflow: hidden;
    transform: translateY(-10px);
  }
  .form-section.visible {
    opacity: 1;
    height: auto;
    padding: 30px;
    transform: translateY(0);
  }
  .form-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: #1a202c;
    margin-bottom: 20px;
    border-bottom: 2px solid #e0e7ff;
    padding-bottom: 10px;
  }
  .form-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
  }
  .form-group label {
    display: block;
    font-size: 0.9rem;
    font-weight: 500;
    color: #4a5568;
    margin-bottom: 5px;
  }
  input, select {
    width: 100%;
    padding: 10px 12px;
    border: 1px solid #cbd5e1;
    border-radius: 8px;
    font-size: 1rem;
    box-sizing: border-box;
  }
  .full-width {
    grid-column: 1 / -1;
  }
  .save-btn {
    background: #4f46e5;
    color: #fff;
    border: none;
    padding: 12px 25px;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    margin-top: 20px;
    transition: background 0.2s;
  }
  .cancel-btn {
      background: #e2e8f0;
      color: #1a202c;
      margin-left: 10px;
      padding: 12px 25px;
      border-radius: 8px;
      font-size: 1rem;
      font-weight: 600;
      cursor: pointer;
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
  }
  .modal {
    background: #fff;
    padding: 30px;
    border-radius: 12px;
    box-shadow: 0 5px 15px rgba(0,0,0,0.3);
    max-width: 400px;
    width: 90%;
    animation: fadeIn 0.3s;
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
  
  /* Media Queries for Responsiveness */
  @media (max-width: 768px) {
      .header-container { flex-direction: column; align-items: flex-start; gap: 15px; margin-top: 70px; }
      .header-right { width: 100%; justify-content: space-between; gap: 10px; }
      .search-box input { width: 100%; max-width: none; }
      .header-left { font-size: 1.8rem; }
      .user-card-grid { grid-template-columns: 1fr; }
      .form-grid { grid-template-columns: 1fr; }
      .form-section.visible { padding: 20px; }
      .add-user-btn { flex: 1; justify-content: center; }
  }
  `;

  // Determine the main content class based on sidebar state (Desktop only)
  const mainContentClass = isSidebarOpen ? "sidebar-open" : "sidebar-closed";

  return (
    <div className={`user-mgmt-bg ${mainContentClass}`}>
      <style>{cardStyles}</style>

      {/* Sandwich Button for Mobile/Tablet */}
      {toggleSidebar && (
        <button
          className="menu-toggle-btn"
          onClick={toggleSidebar}
          title="Toggle Sidebar"
        >
          {isSidebarOpen ? <X size={24} /> : <Menu size={24} />}
        </button>
      )}

      {/* Overlay to close sidebar when clicking outside on mobile */}
      {isSidebarOpen && window.innerWidth < 1024 && (
        <div className="mobile-overlay" onClick={toggleSidebar}></div>
      )}

      {/* Header with Search and Add Button */}
      <div className="header-container">
        <div className="header-left">
          User Management <User size={28} />
        </div>
        <div className="header-right">
          <div className="search-box">
            <Search />
            <input
              type="text"
              placeholder="Search by name or email..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <button
            className={`add-user-btn ${
              isFormVisible && !isEdit ? "toggle-active" : ""
            }`}
            onClick={handleAddNewUser}
            title={
              isFormVisible && !isEdit ? "Cancel Add User" : "Add New User"
            }
          >
            <User /> {isFormVisible && !isEdit ? "Cancel" : "Add User"}
          </button>
        </div>
      </div>

      {/* ... (rest of the component logic for form and cards remains the same) ... */}

      {/* Form Section (Toggled) */}
      <div className={`form-section ${isFormVisible ? "visible" : ""}`}>
        <div className="form-title">
          {isEdit ? "Edit User Details" : "Add New User"}
        </div>
        {statusMsg && !isFormVisible && (
          <div className="status-msg">{statusMsg}</div>
        )}
        {errorMsg && <div className="error-msg">{errorMsg}</div>}

        <form onSubmit={handleSubmit} autoComplete="off">
          <div className="form-grid">
            <div className="form-group">
              <label>Name</label>
              <input
                name="name"
                value={form.name}
                onChange={handleChange}
                required
              />
            </div>
            <div className="form-group">
              <label>Email</label>
              <input
                name="email"
                type="email"
                value={form.email}
                onChange={handleChange}
                required
              />
            </div>
            <div className="form-group">
              <label>Phone</label>
              <input
                name="phone_number"
                value={form.phone_number}
                onChange={handleChange}
                required
              />
            </div>
            <div className="form-group">
              <label>Date of Birth</label>
              <input
                name="dob"
                type="date"
                value={form.dob}
                onChange={handleChange}
                required
              />
            </div>
            <div className="form-group">
              <label>Category</label>
              <select
                name="category_id"
                value={form.category_id}
                onChange={handleChange}
                required
              >
                <option value="">Select</option>
                {categoryOptions.map((c) => (
                  <option value={c.id} key={c.id}>
                    {c.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="form-group full-width">
              <label>Address</label>
              <input
                name="address"
                value={form.address}
                onChange={handleChange}
                required
              />
            </div>
            <div className="form-group">
              <label>Pincode</label>
              <input
                name="pincode"
                value={form.pincode}
                onChange={handleChange}
                required
              />
            </div>
            <div className="form-group">
              <label>
                Password {isEdit ? "(Leave blank to keep current)" : ""}
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
          <button className="save-btn" type="submit">
            {isEdit ? "Update User" : "Add User"}
          </button>
          <button
            className="cancel-btn"
            type="button"
            onClick={() => resetForm(false)}
          >
            Cancel
          </button>
        </form>
      </div>

      {statusMsg && !isFormVisible && (
        <div className="status-msg">{statusMsg}</div>
      )}
      {errorMsg && !isFormVisible && (
        <div className="error-msg">{errorMsg}</div>
      )}

      {/* User Card Grid */}
      <div className="user-card-grid">
        {filteredUsers.length > 0 ? (
          filteredUsers.map((u) => (
            <div className="user-card" key={u.user_id}>
              {/* Card Header */}
              <div className="card-header">
                <div className="avatar">{u.name.charAt(0).toUpperCase()}</div>
                <div className="info-block">
                  <strong>{u.name}</strong>
                  <span>@{u.user_id}</span>
                </div>
              </div>

              {/* Card Details */}
              <div className="card-details">
                <div className="detail-item">
                  <Mail size={18} /> {u.email}
                </div>
                <div className="detail-item">
                  <Phone size={18} /> {u.phone_number}
                </div>
                <div className="detail-item">
                  <MapPin size={18} /> {u.address}
                </div>
                <div className="detail-item">
                  <Calendar size={18} /> {u.formatted_dob}
                </div>
                <div className="detail-item">
                  <User size={18} /> Category: {u.user_category}
                </div>
              </div>

              {/* Card Actions */}
              <div className="card-actions">
                <button
                  className="action-btn"
                  onClick={() => handleEdit(u)}
                  title="Edit User"
                >
                  Edit
                </button>
                <button
                  className="delete-btn"
                  onClick={() => handleDeleteClick(u)}
                  title="Delete User"
                >
                  Delete
                </button>
              </div>
            </div>
          ))
        ) : (
          <div
            className="full-width"
            style={{
              textAlign: "center",
              color: "#6b7280",
              padding: "50px 0",
              gridColumn: "1 / -1",
            }}
          >
            No users found matching "{searchTerm}" or the user list is empty.
          </div>
        )}
      </div>

      {/* Delete Confirmation Modal */}
      {isConfirmOpen && userToDelete && (
        <div className="modal-overlay">
          <div className="modal">
            <h3>Warning: Delete User</h3>
            <p>
              Are you sure you want to delete user **{userToDelete.name}** (
              {userToDelete.email})? This action is irreversible.
            </p>
            <div className="modal-actions">
              <button className="cancel-btn" onClick={cancelDelete}>
                Cancel
              </button>
              <button className="confirm-delete-btn" onClick={confirmDelete}>
                Confirm Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

// Exporting the main component
export default UserManage;
