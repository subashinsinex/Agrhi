// src/pages/marketPlaceManagement.jsx

import React, { useEffect, useState, useMemo, useCallback } from "react";
import {
  FaShoppingBasket,
  FaSearch,
  FaSync,
  FaToggleOn,
  FaToggleOff,
  FaTrash,
  FaFilter,
  FaEdit,
  FaPlus,
  FaTimes,
  FaCheck,
  FaChevronLeft,
  FaChevronRight,
  FaFileExport,
  FaSort,
  FaSortUp,
  FaSortDown,
  FaInfoCircle,
  FaLeaf,
  FaUser,
} from "react-icons/fa";
import { axiosInstance } from "../api/login";
import { SERVER_IP, SERVER_PORT } from "../constant";

/**
 * ------------------------------------------------------------------
 * CONSTANTS & CONFIGURATION
 * ------------------------------------------------------------------
 */
const API_BASE = `http://${SERVER_IP}:${SERVER_PORT}/api/marketplace`;

const THEME = {
  primary: "#055219", // Deep Forest Green
  primaryLight: "#0a7d2a",
  primaryFaint: "rgba(5, 82, 25, 0.08)",
  secondary: "#130f40", // Dark Navy
  accent: "#2ecc71", // Bright Green
  danger: "#e74c3c",
  dangerHover: "#c0392b",
  warning: "#f1c40f",
  success: "#27ae60",
  textMain: "#2c3e50",
  textMuted: "#7f8c8d",
  textLight: "#bdc3c7",
  bgLight: "#f8fdf9",
  bgWhite: "#ffffff",
  border: "#e0e0e0",
  shadowSmall: "0 2px 8px rgba(0,0,0,0.06)",
  shadowMedium: "0 8px 24px rgba(0,0,0,0.08)",
  shadowLarge: "0 16px 48px rgba(0,0,0,0.12)",
  radiusSmall: "8px",
  radiusMedium: "16px",
  radiusLarge: "24px",
  radiusPill: "999px",
  fontFamily: "'Outfit', 'Inter', system-ui, sans-serif",
  transition: "all 0.25s cubic-bezier(0.4, 0, 0.2, 1)",
};

const INITIAL_FORM_STATE = {
  phone_number: "",
  crop_type_id: "",
  plant_id: "",
  variety: "",
  price_per_unit: "",
  unit: "kg",
  available_qty: "",
  min_order_qty: "",
};

/**
 * ------------------------------------------------------------------
 * STYLES (CSS-IN-JS SYSTEM)
 * ------------------------------------------------------------------
 */
const styles = {
  // --- Layout Wrappers ---
  pageWrapper: {
    minHeight: "100vh",
    background: "transparent",
    padding: "40px",
    fontFamily: THEME.fontFamily,
    color: THEME.textMain,
    boxSizing: "border-box",
  },
  container: {
    maxWidth: "1600px",
    margin: "0 auto",
  },

  // --- Header Section ---
  headerRow: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "flex-start",
    flexWrap: "wrap",
    gap: "24px",
    marginBottom: "32px",
  },
  titleGroup: {
    display: "flex",
    flexDirection: "column",
    gap: "8px",
  },
  mainTitle: {
    fontSize: "2.5rem",
    fontWeight: 800,
    color: THEME.secondary,
    display: "flex",
    alignItems: "center",
    gap: "16px",
    letterSpacing: "-0.5px",
    margin: 0,
  },
  subTitle: {
    fontSize: "1rem",
    color: THEME.bgWhite,
    fontWeight: 400,
    maxWidth: "600px",
    lineHeight: 1.5,
  },
  headerActions: {
    display: "flex",
    alignItems: "center",
    gap: "12px",
    flexWrap: "wrap",
  },

  // --- Stats Dashboard ---
  statsGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
    gap: "24px",
    marginBottom: "32px",
  },
  statCard: {
    backgroundColor: THEME.bgWhite,
    borderRadius: THEME.radiusMedium,
    padding: "24px",
    display: "flex",
    alignItems: "center",
    gap: "20px",
    boxShadow: THEME.shadowSmall,
    border: `1px solid ${THEME.border}`,
    transition: THEME.transition,
    cursor: "default",
    position: "relative",
    overflow: "hidden",
  },
  statIconBox: {
    width: "64px",
    height: "64px",
    borderRadius: THEME.radiusMedium,
    backgroundColor: THEME.bgLight,
    color: THEME.primary,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    fontSize: "1.75rem",
    flexShrink: 0,
  },
  statContent: {
    display: "flex",
    flexDirection: "column",
  },
  statLabel: {
    fontSize: "0.85rem",
    textTransform: "uppercase",
    letterSpacing: "0.5px",
    fontWeight: 700,
    color: THEME.textMuted,
    marginBottom: "4px",
  },
  statValue: {
    fontSize: "2rem",
    fontWeight: 800,
    color: THEME.secondary,
    lineHeight: 1,
  },

  // --- Toolbar (Filter & Search) ---
  toolbar: {
    backgroundColor: THEME.bgWhite,
    borderRadius: THEME.radiusMedium,
    padding: "20px",
    boxShadow: THEME.shadowSmall,
    border: `1px solid ${THEME.border}`,
    marginBottom: "24px",
    display: "flex",
    flexDirection: "column",
    gap: "20px",
  },
  toolbarTop: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    flexWrap: "wrap",
    gap: "16px",
  },
  searchContainer: {
    position: "relative",
    flex: "1 1 300px",
    maxWidth: "500px",
  },
  searchIcon: {
    position: "absolute",
    left: "16px",
    top: "50%",
    transform: "translateY(-50%)",
    color: THEME.textMuted,
    pointerEvents: "none",
  },
  searchInput: {
    width: "100%",
    padding: "14px 14px 14px 48px",
    fontSize: "0.95rem",
    border: `2px solid ${THEME.bgLight}`,
    backgroundColor: THEME.bgLight,
    borderRadius: THEME.radiusPill,
    outline: "none",
    transition: THEME.transition,
    color: THEME.textMain,
    boxSizing: "border-box",
  },
  searchInputFocus: {
    borderColor: THEME.primary,
    backgroundColor: THEME.bgWhite,
    boxShadow: `0 0 0 4px ${THEME.primaryFaint}`,
  },

  filterToggleRow: {
    display: "flex",
    gap: "12px",
  },

  filterPanel: {
    paddingTop: "20px",
    borderTop: `1px solid ${THEME.border}`,
    display: "flex",
    flexWrap: "wrap",
    gap: "20px",
    alignItems: "flex-end",
    animation: "fadeIn 0.3s ease",
  },
  filterGroup: {
    display: "flex",
    flexDirection: "column",
    gap: "8px",
    flex: "1 1 200px",
  },
  label: {
    fontSize: "0.85rem",
    fontWeight: 600,
    color: THEME.secondary,
    marginLeft: "4px",
  },
  selectInput: {
    padding: "12px 16px",
    borderRadius: THEME.radiusSmall,
    border: `1px solid ${THEME.border}`,
    backgroundColor: THEME.bgWhite,
    fontSize: "0.9rem",
    outline: "none",
    width: "100%",
    cursor: "pointer",
    transition: THEME.transition,
  },

  // --- Buttons ---
  btn: {
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    gap: "8px",
    padding: "10px 20px",
    borderRadius: THEME.radiusPill,
    border: "none",
    fontSize: "0.9rem",
    fontWeight: 600,
    cursor: "pointer",
    transition: THEME.transition,
    textDecoration: "none",
    outline: "none",
    whiteSpace: "nowrap",
  },
  btnPrimary: {
    backgroundColor: THEME.primary,
    color: "#fff",
    boxShadow: `0 4px 14px ${THEME.primaryFaint}`,
  },
  btnSecondary: {
    backgroundColor: THEME.bgLight,
    color: THEME.textMain,
    border: `1px solid ${THEME.border}`,
  },
  btnDanger: {
    backgroundColor: "#fff",
    color: THEME.danger,
    border: `1px solid ${THEME.danger}`,
  },
  btnGhost: {
    backgroundColor: "transparent",
    color: THEME.primary,
  },
  btnIconOnly: {
    padding: "10px",
    borderRadius: "50%",
    width: "40px",
    height: "40px",
  },

  // --- Table Area ---
  tableCard: {
    backgroundColor: THEME.bgWhite,
    borderRadius: THEME.radiusMedium,
    boxShadow: THEME.shadowMedium,
    border: `1px solid ${THEME.border}`,
    overflow: "hidden",
    display: "flex",
    flexDirection: "column",
  },
  tableWrapper: {
    overflowX: "auto",
    width: "100%",
  },
  table: {
    width: "100%",
    borderCollapse: "collapse",
    minWidth: "1200px",
  },
  thead: {
    backgroundColor: THEME.bgLight,
    borderBottom: `1px solid ${THEME.border}`,
  },
  th: {
    padding: "18px 24px",
    textAlign: "left",
    fontSize: "0.8rem",
    fontWeight: 700,
    textTransform: "uppercase",
    color: THEME.textMuted,
    letterSpacing: "0.5px",
    cursor: "pointer",
    userSelect: "none",
    whiteSpace: "nowrap",
  },
  thContent: {
    display: "flex",
    alignItems: "center",
    gap: "6px",
  },
  tr: {
    borderBottom: `1px solid ${THEME.border}`,
    transition: "background-color 0.15s ease",
  },
  td: {
    padding: "16px 24px",
    verticalAlign: "middle",
    fontSize: "0.9rem",
    color: THEME.textMain,
  },
  actionCell: {
    display: "flex",
    gap: "8px",
    justifyContent: "flex-end",
  },

  // --- Badges & Indicators ---
  badge: {
    display: "inline-flex",
    alignItems: "center",
    gap: "6px",
    padding: "6px 12px",
    borderRadius: THEME.radiusPill,
    fontSize: "0.75rem",
    fontWeight: 700,
    textTransform: "uppercase",
  },
  badgeActive: {
    backgroundColor: "#e8f5e9",
    color: "#27ae60",
    border: "1px solid #c8e6c9",
  },
  badgeInactive: {
    backgroundColor: "#ffebee",
    color: "#c0392b",
    border: "1px solid #ffcdd2",
  },
  unitBadge: {
    backgroundColor: "#f0f4f8",
    color: THEME.textMuted,
    padding: "2px 8px",
    borderRadius: "4px",
    fontSize: "0.8em",
    fontWeight: 600,
    marginLeft: "4px",
  },

  // --- Pagination ---
  paginationBar: {
    padding: "16px 24px",
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    borderTop: `1px solid ${THEME.border}`,
    backgroundColor: "#fafbfc",
  },
  pageInfo: {
    fontSize: "0.9rem",
    color: THEME.textMuted,
  },
  pageControls: {
    display: "flex",
    gap: "8px",
    alignItems: "center",
  },
  pageBtn: {
    width: "36px",
    height: "36px",
    borderRadius: "8px",
    border: `1px solid ${THEME.border}`,
    backgroundColor: "#fff",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    cursor: "pointer",
    fontSize: "0.9rem",
    color: THEME.textMain,
    transition: THEME.transition,
  },
  pageBtnActive: {
    backgroundColor: THEME.primary,
    color: "#fff",
    borderColor: THEME.primary,
  },
  pageBtnDisabled: {
    opacity: 0.5,
    cursor: "not-allowed",
    backgroundColor: "#f5f5f5",
  },

  // --- Modals ---
  modalOverlay: {
    position: "fixed",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: "rgba(19, 15, 64, 0.6)",
    backdropFilter: "blur(4px)",
    zIndex: 1000,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    padding: "20px",
  },
  modalContent: {
    backgroundColor: "#fff",
    borderRadius: THEME.radiusLarge,
    width: "100%",
    maxWidth: "600px",
    maxHeight: "90vh",
    overflowY: "auto",
    boxShadow: THEME.shadowLarge,
    animation: "slideUp 0.3s cubic-bezier(0.16, 1, 0.3, 1)",
    display: "flex",
    flexDirection: "column",
  },
  modalHeader: {
    padding: "24px 32px",
    borderBottom: `1px solid ${THEME.border}`,
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    backgroundColor: "#fafbfc",
  },
  modalTitle: {
    fontSize: "1.25rem",
    fontWeight: 800,
    color: THEME.secondary,
    margin: 0,
  },
  modalCloseBtn: {
    background: "none",
    border: "none",
    cursor: "pointer",
    color: THEME.textMuted,
    fontSize: "1.2rem",
    padding: "8px",
    borderRadius: "50%",
    transition: "background 0.2s",
  },
  modalBody: {
    padding: "32px",
    display: "flex",
    flexDirection: "column",
    gap: "24px",
  },
  modalFooter: {
    padding: "20px 32px",
    borderTop: `1px solid ${THEME.border}`,
    backgroundColor: "#fafbfc",
    display: "flex",
    justifyContent: "flex-end",
    gap: "12px",
  },
  formGrid: {
    display: "grid",
    gridTemplateColumns: "1fr 1fr",
    gap: "20px",
  },
  formGroup: {
    display: "flex",
    flexDirection: "column",
    gap: "8px",
  },
  fullWidth: {
    gridColumn: "1 / -1",
  },
  inputError: {
    fontSize: "0.8rem",
    color: THEME.danger,
    marginTop: "4px",
    fontWeight: 500,
  },
  reqMark: {
    color: THEME.danger,
    marginLeft: "4px",
  },

  // --- Toasts ---
  toastContainer: {
    position: "fixed",
    bottom: "32px",
    right: "32px",
    zIndex: 2000,
    display: "flex",
    flexDirection: "column",
    gap: "12px",
  },
  toast: {
    minWidth: "300px",
    padding: "16px 20px",
    borderRadius: THEME.radiusMedium,
    backgroundColor: "#fff",
    boxShadow: "0 8px 30px rgba(0,0,0,0.15)",
    display: "flex",
    alignItems: "center",
    gap: "12px",
    borderLeft: "6px solid",
    animation: "slideInRight 0.3s ease",
  },
  toastContent: {
    flex: 1,
  },
  toastTitle: {
    fontSize: "0.95rem",
    fontWeight: 700,
    marginBottom: "2px",
  },
  toastMessage: {
    fontSize: "0.85rem",
    color: THEME.textMuted,
  },

  // --- Empty States & Loaders ---
  emptyState: {
    padding: "60px",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    color: THEME.textMuted,
    textAlign: "center",
  },
  spinner: {
    width: "40px",
    height: "40px",
    border: `4px solid ${THEME.bgLight}`,
    borderTop: `4px solid ${THEME.primary}`,
    borderRadius: "50%",
    animation: "spin 1s linear infinite",
    margin: "0 auto",
  },
};

/**
 * ------------------------------------------------------------------
 * UTILITY FUNCTIONS
 * ------------------------------------------------------------------
 */

const formatCurrency = (amount) => {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    minimumFractionDigits: 0,
  }).format(amount);
};

const formatDate = (dateString) => {
  if (!dateString) return "-";
  return new Date(dateString).toLocaleDateString("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
};

// Simple global keyframes injection for animations
const GlobalStyles = () => (
  <style>
    {`
      @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
      @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
      @keyframes slideUp { from { opacity: 0; transform: translateY(40px); } to { opacity: 1; transform: translateY(0); } }
      @keyframes slideInRight { from { opacity: 0; transform: translateX(100%); } to { opacity: 1; transform: translateX(0); } }
      
      ::-webkit-scrollbar { width: 8px; height: 8px; }
      ::-webkit-scrollbar-track { background: #f1f1f1; }
      ::-webkit-scrollbar-thumb { background: #c1c1c1; border-radius: 4px; }
      ::-webkit-scrollbar-thumb:hover { background: #a8a8a8; }
    `}
  </style>
);

/**
 * ------------------------------------------------------------------
 * SUB-COMPONENTS
 * ------------------------------------------------------------------
 */

// 1. Toast Notification Component
const ToastNotification = ({ toasts, removeToast }) => {
  return (
    <div style={styles.toastContainer}>
      {toasts.map((toast) => {
        const borderColor =
          toast.type === "success"
            ? THEME.success
            : toast.type === "error"
            ? THEME.danger
            : THEME.primary;
        const Icon =
          toast.type === "success"
            ? FaCheck
            : toast.type === "error"
            ? FaTimes
            : FaInfoCircle;

        return (
          <div
            key={toast.id}
            style={{ ...styles.toast, borderLeftColor: borderColor }}
            onClick={() => removeToast(toast.id)}
          >
            <div
              style={{
                color: borderColor,
                fontSize: "1.2rem",
                display: "flex",
              }}
            >
              <Icon />
            </div>
            <div style={styles.toastContent}>
              <div style={{ ...styles.toastTitle, color: borderColor }}>
                {toast.type === "success"
                  ? "Success"
                  : toast.type === "error"
                  ? "Error"
                  : "Info"}
              </div>
              <div style={styles.toastMessage}>{toast.message}</div>
            </div>
          </div>
        );
      })}
    </div>
  );
};

// 2. Custom Button
const Button = ({
  children,
  onClick,
  variant = "primary",
  icon: Icon,
  disabled,
  style = {},
  type = "button",
}) => {
  const [hover, setHover] = useState(false);

  let baseStyle = { ...styles.btn };
  if (variant === "primary") baseStyle = { ...baseStyle, ...styles.btnPrimary };
  if (variant === "secondary")
    baseStyle = { ...baseStyle, ...styles.btnSecondary };
  if (variant === "danger") baseStyle = { ...baseStyle, ...styles.btnDanger };
  if (variant === "ghost") baseStyle = { ...baseStyle, ...styles.btnGhost };

  if (disabled) {
    baseStyle = { ...baseStyle, opacity: 0.6, cursor: "not-allowed" };
  } else if (hover) {
    baseStyle = { ...baseStyle, transform: "translateY(-1px)", opacity: 0.9 };
  }

  return (
    <button
      type={type}
      style={{ ...baseStyle, ...style }}
      onClick={disabled ? undefined : onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      disabled={disabled}
    >
      {Icon && <Icon size={14} />}
      {children}
    </button>
  );
};

// 3. Form Input Field
const FormInput = ({
  label,
  name,
  value,
  onChange,
  type = "text",
  placeholder,
  required,
  error,
  options = null,
  helperText,
}) => {
  const [focused, setFocused] = useState(false);

  return (
    <div style={styles.formGroup}>
      <label style={styles.label}>
        {label}
        {required && <span style={styles.reqMark}>*</span>}
      </label>

      {options ? (
        <select
          name={name}
          value={value}
          onChange={onChange}
          style={{
            ...styles.selectInput,
            borderColor: error
              ? THEME.danger
              : focused
              ? THEME.primary
              : THEME.border,
            boxShadow: focused ? `0 0 0 4px ${THEME.primaryFaint}` : "none",
          }}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
        >
          <option value="" disabled>
            Select {label}
          </option>
          {options.map((opt) => (
            <option key={opt.value} value={opt.value}>
              {opt.label}
            </option>
          ))}
        </select>
      ) : (
        <input
          type={type}
          name={name}
          value={value}
          onChange={onChange}
          placeholder={placeholder}
          style={{
            ...styles.searchInput,
            padding: "12px 16px",
            borderColor: error
              ? THEME.danger
              : focused
              ? THEME.primary
              : THEME.border,
            backgroundColor: focused ? "#fff" : THEME.bgLight,
            boxShadow: focused ? `0 0 0 4px ${THEME.primaryFaint}` : "none",
          }}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
        />
      )}

      {error && <span style={styles.inputError}>{error}</span>}
      {!error && helperText && (
        <span style={{ fontSize: "0.75rem", color: THEME.textMuted }}>
          {helperText}
        </span>
      )}
    </div>
  );
};

// 4. Listing Form Modal
const ListingModal = ({
  isOpen,
  onClose,
  onSubmit,
  initialData,
  isEdit,
  cropTypes,
  plants,
  fetchDropdownData,
}) => {
  const [formData, setFormData] = useState(INITIAL_FORM_STATE);
  const [errors, setErrors] = useState({});

  useEffect(() => {
    if (isOpen) {
      if (initialData) {
        setFormData({
          phone_number: "", // not editable in edit mode (backend identifies farmer by listing)
          crop_type_id: initialData.crop_type_id || "",
          plant_id: initialData.plant_id || "",
          variety: initialData.variety || "",
          price_per_unit: initialData.price_per_unit || "",
          unit: initialData.unit || "kg",
          available_qty: initialData.available_qty || "",
          min_order_qty: initialData.min_order_qty || "",
        });
      } else {
        setFormData(INITIAL_FORM_STATE);
      }
      setErrors({});
    }
  }, [isOpen, initialData]);

  const validate = () => {
    const newErrors = {};
    if (!isEdit && !formData.phone_number) {
      newErrors.phone_number = "Farmer phone number is required";
    }
    if (
      !isEdit &&
      formData.phone_number &&
      !/^\d{10}$/.test(formData.phone_number)
    ) {
      newErrors.phone_number = "Enter a valid 10-digit phone";
    }

    if (!formData.crop_type_id)
      newErrors.crop_type_id = "Crop Type is required";
    if (!formData.plant_id) newErrors.plant_id = "Plant is required";
    if (!formData.price_per_unit) newErrors.price_per_unit = "Price required";
    if (isNaN(formData.price_per_unit) || Number(formData.price_per_unit) <= 0)
      newErrors.price_per_unit = "Must be a positive number";
    if (!formData.available_qty) newErrors.available_qty = "Quantity required";
    if (isNaN(formData.available_qty) || Number(formData.available_qty) < 0)
      newErrors.available_qty = "Must be zero or more";
    if (
      formData.min_order_qty &&
      (isNaN(formData.min_order_qty) || Number(formData.min_order_qty) < 0)
    )
      newErrors.min_order_qty = "Must be zero or more";

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    if (errors[name]) {
      setErrors((prev) => ({ ...prev, [name]: null }));
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (validate()) {
      const payload = { ...formData };
      if (isEdit) {
        // backend updateListing ignores phone_number; remove to avoid confusion
        delete payload.phone_number;
      }
      onSubmit(payload);
    }
  };

  useEffect(() => {
    if (isOpen) fetchDropdownData();
  }, [isOpen, fetchDropdownData]);

  if (!isOpen) return null;

  return (
    <div style={styles.modalOverlay} onClick={onClose}>
      <div style={styles.modalContent} onClick={(e) => e.stopPropagation()}>
        <div style={styles.modalHeader}>
          <h3 style={styles.modalTitle}>
            {isEdit ? "Edit Listing" : "Create New Listing"}
          </h3>
          <button style={styles.modalCloseBtn} onClick={onClose}>
            <FaTimes />
          </button>
        </div>
        <form onSubmit={handleSubmit}>
          <div style={styles.modalBody}>
            <div style={styles.formGrid}>
              {!isEdit && (
                <FormInput
                  label="Farmer Phone Number"
                  name="phone_number"
                  type="tel"
                  placeholder="e.g., 9876543210"
                  value={formData.phone_number}
                  onChange={handleChange}
                  required
                  error={errors.phone_number}
                  helperText="Linked to users_auth.phone_number"
                />
              )}

              <FormInput
                label="Crop Type"
                name="crop_type_id"
                value={formData.crop_type_id}
                onChange={handleChange}
                options={cropTypes.map((ct) => ({
                  value: ct.crop_type_id,
                  label: ct.name,
                }))}
                required
                error={errors.crop_type_id}
              />

              <FormInput
                label="Plant"
                name="plant_id"
                value={formData.plant_id}
                onChange={handleChange}
                options={plants.map((p) => ({
                  value: p.plant_id,
                  label: p.plant_name,
                }))}
                required
                error={errors.plant_id}
              />

              <FormInput
                label="Variety"
                name="variety"
                value={formData.variety}
                onChange={handleChange}
                placeholder="e.g. Red Delicious"
              />

              <FormInput
                label="Price Per Unit"
                name="price_per_unit"
                type="number"
                value={formData.price_per_unit}
                onChange={handleChange}
                placeholder="0.00"
                required
                error={errors.price_per_unit}
              />

              <FormInput
                label="Unit"
                name="unit"
                value={formData.unit}
                onChange={handleChange}
                options={[
                  { value: "kg", label: "Kilogram (kg)" },
                  { value: "g", label: "Gram (g)" },
                  { value: "piece", label: "Piece" },
                  { value: "litre", label: "Litre" },
                  { value: "dozen", label: "Dozen" },
                ]}
                required
              />

              <FormInput
                label="Available Qty"
                name="available_qty"
                type="number"
                value={formData.available_qty}
                onChange={handleChange}
                placeholder="0"
                required
                error={errors.available_qty}
              />

              <FormInput
                label="Min Order Qty"
                name="min_order_qty"
                type="number"
                value={formData.min_order_qty}
                onChange={handleChange}
                placeholder="1"
                error={errors.min_order_qty}
              />
            </div>
          </div>
          <div style={styles.modalFooter}>
            <Button variant="secondary" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" variant="primary">
              {isEdit ? "Update Listing" : "Create Listing"}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};

/**
 * ------------------------------------------------------------------
 * MAIN COMPONENT: MarketPlaceManagement
 * ------------------------------------------------------------------
 */
const MarketPlaceManagement = () => {
  // --- STATE ---
  const [listings, setListings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [toasts, setToasts] = useState([]);

  // Filters & Search
  const [searchTerm, setSearchTerm] = useState("");
  const [isFilterOpen, setIsFilterOpen] = useState(false);
  const [filterActive, setFilterActive] = useState(""); // "all", "true", "false"
  const [filterCropType, setFilterCropType] = useState("");
  const [filterFarmerId, setFilterFarmerId] = useState("");
  const [filterPlantId, setFilterPlantId] = useState("");
  const [farmers, setFarmers] = useState([]);
  const [cropTypes, setCropTypes] = useState([]);
  const [plants, setPlants] = useState([]);

  // Pagination & Sorting
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage] = useState(10);
  const [sortConfig, setSortConfig] = useState({
    key: "created_at",
    direction: "desc",
  });

  // Modals
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingListing, setEditingListing] = useState(null);

  // --- TOAST SYSTEM ---
  const addToast = useCallback((message, type = "info") => {
    const id = Date.now();
    setToasts((prev) => [...prev, { id, message, type }]);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 4000);
  }, []);

  const removeToast = (id) =>
    setToasts((prev) => prev.filter((t) => t.id !== id));

  // --- DATA FETCHING ---
  const fetchListings = useCallback(async () => {
    setLoading(true);
    const accessToken = localStorage.getItem("access_token");

    if (!accessToken) {
      addToast("Authentication missing. Please login.", "error");
      setLoading(false);
      return;
    }

    const params = {};
    if (filterActive === "true") params.is_active = true;
    if (filterActive === "false") params.is_active = false;
    if (filterCropType) params.crop_type_id = filterCropType;
    if (filterFarmerId) params.farmer_id = filterFarmerId;
    if (filterPlantId) params.crop_type_id = filterCropType;

    try {
      const response = await axiosInstance.get(`${API_BASE}/alllistings`, {
        headers: { Authorization: `Bearer ${accessToken}` },
        params,
      });
      setListings(response.data || []);
      setCurrentPage(1);
    } catch (error) {
      const msg = error.response?.data?.message || "Failed to fetch listings.";
      addToast(msg, "error");
    } finally {
      setLoading(false);
    }
  }, [filterActive, filterCropType, filterFarmerId, filterPlantId, addToast]);

  const fetchDropdownData = useCallback(async () => {
    const accessToken = localStorage.getItem("access_token");
    if (!accessToken) {
      addToast("Authentication missing. Please login.", "error");
      return;
    }
    try {
      const [farmersRes, cropRes, plantsRes] = await Promise.all([
        axiosInstance.get(`${API_BASE}/farmers`, {
          headers: { Authorization: `Bearer ${accessToken}` },
        }),
        axiosInstance.get(`${API_BASE}/croptypes`, {
          headers: { Authorization: `Bearer ${accessToken}` },
        }),
        axiosInstance.get(`${API_BASE}/plants`, {
          headers: { Authorization: `Bearer ${accessToken}` },
        }),
      ]);
      setFarmers(farmersRes.data);
      setCropTypes(cropRes.data);
      setPlants(plantsRes.data);
    } catch {
      addToast("Error loading dropdown options", "error");
    }
  }, [addToast]);

  useEffect(() => {
    fetchListings();
  }, [fetchListings]);

  const handleApplyFilters = () => {
    fetchListings();
  };

  const handleResetFilters = () => {
    setFilterActive("");
    setFilterCropType("");
    setFilterFarmerId("");
    setFilterPlantId("");
    setSearchTerm("");
    fetchListings();
  };

  // --- CRUD HANDLERS ---
  const handleCreate = async (formData) => {
    const accessToken = localStorage.getItem("access_token");
    try {
      await axiosInstance.post(`${API_BASE}/createlistings`, formData, {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      addToast("Listing created successfully", "success");
      setIsModalOpen(false);
      fetchListings();
    } catch (error) {
      addToast(
        error.response?.data?.message || "Error creating listing",
        "error"
      );
    }
  };

  const handleUpdate = async (formData) => {
    if (!editingListing) return;
    const accessToken = localStorage.getItem("access_token");
    try {
      await axiosInstance.put(
        `${API_BASE}/updatelistings/${editingListing.listing_id}`,
        formData,
        { headers: { Authorization: `Bearer ${accessToken}` } }
      );
      addToast("Listing updated successfully", "success");
      setIsModalOpen(false);
      setEditingListing(null);
      fetchListings();
    } catch (error) {
      addToast(
        error.response?.data?.message || "Error updating listing",
        "error"
      );
    }
  };

  const handleToggleStatus = async (listing) => {
    if (
      !window.confirm(
        `Are you sure you want to ${
          listing.is_active ? "deactivate" : "activate"
        } this listing?`
      )
    )
      return;

    const accessToken = localStorage.getItem("access_token");
    try {
      await axiosInstance.put(
        `${API_BASE}/togglelistings/${listing.listing_id}/isactive`,
        { is_active: !listing.is_active },
        { headers: { Authorization: `Bearer ${accessToken}` } }
      );
      addToast(
        `Listing is now ${!listing.is_active ? "Active" : "Inactive"}`,
        "success"
      );
      fetchListings();
    } catch {
      addToast("Failed to change status", "error");
    }
  };

  const handleDelete = async (id) => {
    if (
      !window.confirm(
        "Are you sure you want to permanently delete this listing?"
      )
    )
      return;

    const accessToken = localStorage.getItem("access_token");
    try {
      await axiosInstance.delete(`${API_BASE}/deletelistings/${id}`, {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      addToast("Listing deleted successfully", "success");
      setListings((prev) => prev.filter((l) => l.listing_id !== id));
    } catch (error) {
      addToast(
        error.response?.data?.message || "Failed to delete listing",
        "error"
      );
    }
  };

  const openCreateModal = () => {
    setEditingListing(null);
    setIsModalOpen(true);
  };

  const openEditModal = (listing) => {
    setEditingListing(listing);
    setIsModalOpen(true);
  };

  // --- DATA PROCESSING ---
  const processedListings = useMemo(() => {
    let result = [...listings];

    if (searchTerm) {
      const lower = searchTerm.toLowerCase();
      result = result.filter(
        (l) =>
          (l.variety && l.variety.toLowerCase().includes(lower)) ||
          (l.plant_name && l.plant_name.toLowerCase().includes(lower)) ||
          (l.farmer_name && l.farmer_name.toLowerCase().includes(lower)) ||
          (l.listing_id && l.listing_id.toLowerCase().includes(lower)) ||
          (l.crop_type && l.crop_type.toLowerCase().includes(lower))
      );
    }

    if (sortConfig.key) {
      result.sort((a, b) => {
        let aVal = a[sortConfig.key];
        let bVal = b[sortConfig.key];

        if (aVal === null) aVal = "";
        if (bVal === null) bVal = "";

        if (typeof aVal === "string") {
          aVal = aVal.toLowerCase();
          bVal = bVal.toLowerCase();
        }

        if (aVal < bVal) return sortConfig.direction === "asc" ? -1 : 1;
        if (aVal > bVal) return sortConfig.direction === "asc" ? 1 : -1;
        return 0;
      });
    }

    return result;
  }, [listings, searchTerm, sortConfig]);

  const totalPages = Math.ceil(processedListings.length / itemsPerPage);
  const paginatedListings = useMemo(() => {
    const start = (currentPage - 1) * itemsPerPage;
    return processedListings.slice(start, start + itemsPerPage);
  }, [processedListings, currentPage, itemsPerPage]);

  const handleSort = (key) => {
    let direction = "asc";
    if (sortConfig.key === key && sortConfig.direction === "asc") {
      direction = "desc";
    }
    setSortConfig({ key, direction });
  };

  const getSortIcon = (key) => {
    if (sortConfig.key !== key) return <FaSort size={12} color="#ccc" />;
    return sortConfig.direction === "asc" ? (
      <FaSortUp size={12} color={THEME.primary} />
    ) : (
      <FaSortDown size={12} color={THEME.primary} />
    );
  };

  // --- EXPORT CSV ---
  const handleExportCSV = () => {
    if (listings.length === 0) {
      addToast("No data to export", "error");
      return;
    }
    const headers = [
      "Listing ID",
      "Farmer Name",
      "Crop Type",
      "Plant",
      "Variety",
      "Price",
      "Unit",
      "Available",
      "Status",
      "Created At",
    ];
    const rows = listings.map((l) => [
      l.listing_id,
      l.farmer_name || "Unknown",
      l.crop_type || "-",
      l.plant_name || "-",
      l.variety || "-",
      l.price_per_unit,
      l.unit,
      l.available_qty,
      l.is_active ? "Active" : "Inactive",
      l.created_at,
    ]);

    const csvContent =
      "data:text/csv;charset=utf-8," +
      [headers.join(","), ...rows.map((r) => r.join(","))].join("\n");

    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", "marketplace_listings.csv");
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // --- STATS ---
  const stats = useMemo(() => {
    const total = listings.length;
    const active = listings.filter((l) => l.is_active).length;
    const totalStock = listings.reduce(
      (acc, curr) => acc + Number(curr.available_qty || 0),
      0
    );
    const uniqueFarmers = new Set(listings.map((l) => l.farmer_id)).size;
    return { total, active, totalStock, uniqueFarmers };
  }, [listings]);

  const renderRow = (l) => (
    <tr key={l.listing_id} style={styles.tr}>
      <td style={styles.td}>{l.listing_id}</td>
      <td style={styles.td}>
        <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
          <FaUser size={14} color={THEME.textMuted} />
          <span>{l.farmer_name || "Unknown"}</span>
        </div>
        <div
          style={{
            fontSize: "0.75rem",
            color: THEME.textMuted,
            marginTop: "2px",
          }}
        >
          {l.farmer_phone ? `📞 ${l.farmer_phone}` : ""}
        </div>
      </td>
      <td style={styles.td}>{l.crop_type || "-"}</td>
      <td style={styles.td}>
        <div>{l.plant_name || "-"}</div>
        {l.variety && (
          <div
            style={{
              fontSize: "0.8rem",
              color: THEME.textMuted,
              marginTop: "2px",
            }}
          >
            Variety: {l.variety}
          </div>
        )}
      </td>
      <td style={styles.td}>
        <div>{formatCurrency(l.price_per_unit)}</div>
        <span style={styles.unitBadge}>{l.unit}</span>
      </td>
      <td style={styles.td}>{l.available_qty}</td>
      <td style={styles.td}>
        <span
          style={{
            ...styles.badge,
            ...(l.is_active ? styles.badgeActive : styles.badgeInactive),
          }}
        >
          {l.is_active ? (
            <>
              <FaToggleOn /> Active
            </>
          ) : (
            <>
              <FaToggleOff /> Inactive
            </>
          )}
        </span>
      </td>
      <td style={styles.td}>{formatDate(l.created_at)}</td>
      <td style={{ ...styles.td, ...styles.actionCell }}>
        <Button variant="ghost" icon={FaEdit} onClick={() => openEditModal(l)}>
          Edit
        </Button>
        <Button
          variant="ghost"
          icon={l.is_active ? FaToggleOff : FaToggleOn}
          onClick={() => handleToggleStatus(l)}
        >
          {l.is_active ? "Deactivate" : "Activate"}
        </Button>
        <Button
          variant="danger"
          icon={FaTrash}
          onClick={() => handleDelete(l.listing_id)}
        >
          Delete
        </Button>
      </td>
    </tr>
  );

  return (
    <>
      <GlobalStyles />

      <div style={styles.pageWrapper}>
        <div style={styles.container}>
          {/* HEADER */}
          <div style={styles.headerRow}>
            <div style={styles.titleGroup}>
              <h1 style={styles.mainTitle}>
                <FaShoppingBasket color={THEME.primary} />
                Marketplace Listings
              </h1>
              <p style={styles.subTitle}>
                Manage farmer-to-consumer listings, update pricing and
                availability, and monitor marketplace activity.
              </p>
            </div>

            <div style={styles.headerActions}>
              <Button
                variant="secondary"
                icon={FaFileExport}
                onClick={handleExportCSV}
              >
                Export CSV
              </Button>
              <Button variant="primary" icon={FaPlus} onClick={openCreateModal}>
                New Listing
              </Button>
            </div>
          </div>

          {/* STATS */}
          <div style={styles.statsGrid}>
            <div style={styles.statCard}>
              <div style={styles.statIconBox}>
                <FaShoppingBasket />
              </div>
              <div style={styles.statContent}>
                <div style={styles.statLabel}>Total Listings</div>
                <div style={styles.statValue}>{stats.total}</div>
              </div>
            </div>

            <div style={styles.statCard}>
              <div style={styles.statIconBox}>
                <FaLeaf />
              </div>
              <div style={styles.statContent}>
                <div style={styles.statLabel}>Active Listings</div>
                <div style={styles.statValue}>{stats.active}</div>
              </div>
            </div>

            <div style={styles.statCard}>
              <div style={styles.statIconBox}>
                <FaUser />
              </div>
              <div style={styles.statContent}>
                <div style={styles.statLabel}>Unique Farmers</div>
                <div style={styles.statValue}>{stats.uniqueFarmers}</div>
              </div>
            </div>

            <div style={styles.statCard}>
              <div style={styles.statIconBox}>
                <FaShoppingBasket />
              </div>
              <div style={styles.statContent}>
                <div style={styles.statLabel}>Total Stock</div>
                <div style={styles.statValue}>{stats.totalStock}</div>
              </div>
            </div>
          </div>

          {/* TOOLBAR */}
          <div style={styles.toolbar}>
            <div style={styles.toolbarTop}>
              <div style={styles.searchContainer}>
                <FaSearch style={styles.searchIcon} />
                <input
                  type="text"
                  placeholder="Search by farmer, crop, plant, variety, or listing ID..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  style={styles.searchInput}
                />
              </div>

              <div style={styles.filterToggleRow}>
                <Button
                  variant={isFilterOpen ? "primary" : "secondary"}
                  icon={FaFilter}
                  onClick={() => setIsFilterOpen((prev) => !prev)}
                >
                  Filters
                </Button>
                <Button variant="ghost" icon={FaSync} onClick={fetchListings}>
                  Refresh
                </Button>
              </div>
            </div>

            {isFilterOpen && (
              <div style={styles.filterPanel}>
                <div style={styles.filterGroup}>
                  <label style={styles.label}>Status</label>
                  <select
                    value={filterActive}
                    onChange={(e) => setFilterActive(e.target.value)}
                    style={styles.selectInput}
                  >
                    <option value="">All</option>
                    <option value="true">Active only</option>
                    <option value="false">Inactive only</option>
                  </select>
                </div>

                <div style={styles.filterGroup}>
                  <label style={styles.label}>Crop Type</label>
                  <select
                    value={filterCropType}
                    onChange={(e) => setFilterCropType(e.target.value)}
                    style={styles.selectInput}
                  >
                    <option value="">All</option>
                    {cropTypes.map((ct) => (
                      <option key={ct.crop_type_id} value={ct.crop_type_id}>
                        {ct.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div style={styles.filterGroup}>
                  <label style={styles.label}>Farmer</label>
                  <select
                    value={filterFarmerId}
                    onChange={(e) => setFilterFarmerId(e.target.value)}
                    style={styles.selectInput}
                  >
                    <option value="">All</option>
                    {farmers.map((f) => (
                      <option key={f.user_id} value={f.user_id}>
                        {f.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div style={styles.filterGroup}>
                  <label style={styles.label}>Plant</label>
                  <select
                    value={filterPlantId}
                    onChange={(e) => setFilterPlantId(e.target.value)}
                    style={styles.selectInput}
                  >
                    <option value="">All</option>
                    {plants.map((p) => (
                      <option key={p.plant_id} value={p.plant_id}>
                        {p.plant_name}
                      </option>
                    ))}
                  </select>
                </div>

                <div
                  style={{
                    ...styles.filterGroup,
                    alignItems: "flex-end",
                    flex: "0 0 auto",
                  }}
                >
                  <div style={{ display: "flex", gap: "8px" }}>
                    <Button
                      variant="primary"
                      icon={FaCheck}
                      onClick={handleApplyFilters}
                    >
                      Apply
                    </Button>
                    <Button
                      variant="secondary"
                      icon={FaTimes}
                      onClick={handleResetFilters}
                    >
                      Reset
                    </Button>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* TABLE */}
          <div style={styles.tableCard}>
            <div style={styles.tableWrapper}>
              <table style={styles.table}>
                <thead style={styles.thead}>
                  <tr>
                    <th
                      style={styles.th}
                      onClick={() => handleSort("listing_id")}
                    >
                      <div style={styles.thContent}>
                        ID {getSortIcon("listing_id")}
                      </div>
                    </th>
                    <th
                      style={styles.th}
                      onClick={() => handleSort("farmer_name")}
                    >
                      <div style={styles.thContent}>
                        Farmer {getSortIcon("farmer_name")}
                      </div>
                    </th>
                    <th
                      style={styles.th}
                      onClick={() => handleSort("crop_type")}
                    >
                      <div style={styles.thContent}>
                        Crop {getSortIcon("crop_type")}
                      </div>
                    </th>
                    <th
                      style={styles.th}
                      onClick={() => handleSort("plant_name")}
                    >
                      <div style={styles.thContent}>
                        Plant/Variety {getSortIcon("plant_name")}
                      </div>
                    </th>
                    <th
                      style={styles.th}
                      onClick={() => handleSort("price_per_unit")}
                    >
                      <div style={styles.thContent}>
                        Price {getSortIcon("price_per_unit")}
                      </div>
                    </th>
                    <th
                      style={styles.th}
                      onClick={() => handleSort("available_qty")}
                    >
                      <div style={styles.thContent}>
                        Qty {getSortIcon("available_qty")}
                      </div>
                    </th>
                    <th
                      style={styles.th}
                      onClick={() => handleSort("is_active")}
                    >
                      <div style={styles.thContent}>
                        Status {getSortIcon("is_active")}
                      </div>
                    </th>
                    <th
                      style={styles.th}
                      onClick={() => handleSort("created_at")}
                    >
                      <div style={styles.thContent}>
                        Created {getSortIcon("created_at")}
                      </div>
                    </th>
                    <th
                      style={{
                        ...styles.th,
                        textAlign: "right",
                      }}
                    >
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {loading ? (
                    <tr>
                      <td
                        colSpan="9"
                        style={{ padding: "60px", textAlign: "center" }}
                      >
                        <div style={styles.spinner}></div>
                        <p
                          style={{
                            marginTop: "16px",
                            color: THEME.textMuted,
                          }}
                        >
                          Loading Listings...
                        </p>
                      </td>
                    </tr>
                  ) : paginatedListings.length === 0 ? (
                    <tr>
                      <td colSpan="9">
                        <div style={styles.emptyState}>
                          <FaShoppingBasket size={48} color={THEME.border} />
                          <h3>No Listings Found</h3>
                          <p>Try adjusting your search terms or filters.</p>
                        </div>
                      </td>
                    </tr>
                  ) : (
                    paginatedListings.map(renderRow)
                  )}
                </tbody>
              </table>
            </div>

            {!loading && paginatedListings.length > 0 && (
              <div style={styles.paginationBar}>
                <div style={styles.pageInfo}>
                  Showing <b>{(currentPage - 1) * itemsPerPage + 1}</b> to{" "}
                  <b>
                    {Math.min(
                      currentPage * itemsPerPage,
                      processedListings.length
                    )}
                  </b>{" "}
                  of <b>{processedListings.length}</b> entries
                </div>
                <div style={styles.pageControls}>
                  <button
                    style={{
                      ...styles.pageBtn,
                      ...(currentPage === 1 ? styles.pageBtnDisabled : {}),
                    }}
                    onClick={() => setCurrentPage((p) => (p > 1 ? p - 1 : p))}
                    disabled={currentPage === 1}
                  >
                    <FaChevronLeft />
                  </button>

                  {Array.from({ length: totalPages }, (_, i) => i + 1)
                    .filter(
                      (p) =>
                        p === 1 ||
                        p === totalPages ||
                        Math.abs(p - currentPage) <= 1
                    )
                    .map((p, index, array) => (
                      <React.Fragment key={p}>
                        {index > 0 && array[index - 1] !== p - 1 && (
                          <span style={{ color: THEME.textMuted }}>...</span>
                        )}
                        <button
                          style={{
                            ...styles.pageBtn,
                            ...(p === currentPage ? styles.pageBtnActive : {}),
                          }}
                          onClick={() => setCurrentPage(p)}
                        >
                          {p}
                        </button>
                      </React.Fragment>
                    ))}

                  <button
                    style={{
                      ...styles.pageBtn,
                      ...(currentPage === totalPages
                        ? styles.pageBtnDisabled
                        : {}),
                    }}
                    onClick={() =>
                      setCurrentPage((p) => (p < totalPages ? p + 1 : p))
                    }
                    disabled={currentPage === totalPages}
                  >
                    <FaChevronRight />
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      <ListingModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onSubmit={editingListing ? handleUpdate : handleCreate}
        initialData={editingListing}
        isEdit={!!editingListing}
        cropTypes={cropTypes}
        plants={plants}
        fetchDropdownData={fetchDropdownData}
      />

      <ToastNotification toasts={toasts} removeToast={removeToast} />
    </>
  );
};

export default MarketPlaceManagement;
