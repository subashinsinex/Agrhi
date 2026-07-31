// src/pages/marketPlaceManagement.jsx

import React, { useEffect, useState, useMemo, useCallback } from "react";
import {
  FaShoppingBasket,
  FaSearch,
  FaSync,
  FaFilter,
  FaEye,
  FaChevronLeft,
  FaChevronRight,
  FaSort,
  FaSortUp,
  FaSortDown,
  FaLeaf,
  FaStore,
  FaMapMarkerAlt,
  FaTimes,
  FaRulerHorizontal,
  FaCheck,
} from "react-icons/fa";
import { axiosInstance } from "../api/login";
import { SERVER_ADDR } from "../constant";

/**
 * ------------------------------------------------------------------
 * CONSTANTS & CONFIGURATION
 * ------------------------------------------------------------------
 */
const API_BASE = `${SERVER_ADDR}/api/marketplace`;

// Default coordinates (e.g., Chennai) to use if geolocation fails or is denied
const DEFAULT_LOCATION = {
  lat: 13.0827,
  lng: 80.2707,
};

const THEME = {
  primary: "#055219", // Deep Forest Green
  primaryLight: "#0a7d2a",
  primaryFaint: "rgba(5, 82, 25, 0.08)",
  secondary: "#130f40", // Dark Navy
  accent: "#2ecc71", // Bright Green
  danger: "#e74c3c",
  warning: "#f1c40f",
  success: "#27ae60",
  textMain: "#2c3e50",
  textMuted: "#7f8c8d",
  bgLight: "#f8fdf9",
  bgWhite: "#ffffff",
  border: "#e0e0e0",
  shadowSmall: "0 2px 8px rgba(0,0,0,0.06)",
  shadowMedium: "0 8px 24px rgba(0,0,0,0.08)",
  shadowLarge: "0 16px 48px rgba(0,0,0,0.12)",
  radiusMedium: "16px",
  radiusPill: "999px",
  fontFamily: "'Outfit', 'Inter', system-ui, sans-serif",
  transition: "all 0.25s cubic-bezier(0.4, 0, 0.2, 1)",
};

/**
 * ------------------------------------------------------------------
 * STYLES
 * ------------------------------------------------------------------
 */
const styles = {
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
    margin: 0,
  },
  subTitle: {
    fontSize: "1rem",
    color: THEME.bgWhite, // Assumes dark background on parent
    opacity: 0.9,
    fontWeight: 400,
    maxWidth: "600px",
  },
  locationBadge: {
    display: "flex",
    alignItems: "center",
    gap: "8px",
    backgroundColor: "rgba(255,255,255,0.2)",
    padding: "8px 16px",
    borderRadius: THEME.radiusPill,
    color: "#fff",
    fontSize: "0.9rem",
    backdropFilter: "blur(4px)",
    marginTop: "12px",
    width: "fit-content",
  },

  // Stats
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
    fontWeight: 700,
    color: THEME.textMuted,
    marginBottom: "4px",
  },
  statValue: {
    fontSize: "2rem",
    fontWeight: 800,
    color: THEME.secondary,
  },

  // Toolbar
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
  },
  searchInput: {
    width: "100%",
    padding: "12px 12px 12px 48px",
    fontSize: "0.95rem",
    border: `2px solid ${THEME.bgLight}`,
    backgroundColor: THEME.bgLight,
    borderRadius: THEME.radiusPill,
    outline: "none",
    color: THEME.textMain,
    boxSizing: "border-box",
  },

  filterPanel: {
    paddingTop: "20px",
    borderTop: `1px solid ${THEME.border}`,
    display: "flex",
    flexWrap: "wrap",
    gap: "24px",
    alignItems: "center",
    animation: "fadeIn 0.3s ease",
  },
  filterGroup: {
    display: "flex",
    flexDirection: "column",
    gap: "8px",
  },
  label: {
    fontSize: "0.85rem",
    fontWeight: 600,
    color: THEME.secondary,
  },
  selectInput: {
    padding: "10px 16px",
    borderRadius: "8px",
    border: `1px solid ${THEME.border}`,
    fontSize: "0.9rem",
    outline: "none",
    cursor: "pointer",
  },
  rangeContainer: {
    display: "flex",
    alignItems: "center",
    gap: "12px",
  },
  rangeInput: {
    width: "150px",
    accentColor: THEME.primary,
  },

  // Table
  tableCard: {
    backgroundColor: THEME.bgWhite,
    borderRadius: THEME.radiusMedium,
    boxShadow: THEME.shadowMedium,
    border: `1px solid ${THEME.border}`,
    overflow: "hidden",
  },
  tableWrapper: {
    overflowX: "auto",
    width: "100%",
  },
  table: {
    width: "100%",
    borderCollapse: "collapse",
    minWidth: "1000px",
  },
  thead: {
    backgroundColor: THEME.bgLight,
    borderBottom: `1px solid ${THEME.border}`,
  },
  th: {
    padding: "16px 24px",
    textAlign: "left",
    fontSize: "0.8rem",
    fontWeight: 700,
    textTransform: "uppercase",
    color: THEME.textMuted,
    cursor: "pointer",
    userSelect: "none",
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

  // Components
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
  },
  btnPrimary: {
    backgroundColor: THEME.primary,
    color: "#fff",
  },
  btnSecondary: {
    backgroundColor: THEME.bgLight,
    color: THEME.textMain,
    border: `1px solid ${THEME.border}`,
  },
  btnGhost: {
    backgroundColor: "transparent",
    color: THEME.primary,
  },

  // Badges
  badge: {
    padding: "4px 10px",
    borderRadius: "6px",
    fontSize: "0.75rem",
    fontWeight: 700,
    textTransform: "uppercase",
  },
  badgeFarm: {
    backgroundColor: "#e8f5e9",
    color: "#2e7d32",
    border: "1px solid #c8e6c9",
  },
  badgeRetail: {
    backgroundColor: "#e3f2fd",
    color: "#1565c0",
    border: "1px solid #bbdefb",
  },

  // Modal
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
    borderRadius: THEME.radiusMedium,
    width: "100%",
    maxWidth: "700px",
    maxHeight: "90vh",
    overflowY: "auto",
    boxShadow: THEME.shadowLarge,
    animation: "slideUp 0.3s ease",
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
  modalBody: {
    padding: "32px",
    display: "grid",
    gridTemplateColumns: "1fr 1fr",
    gap: "24px",
  },
  detailRow: {
    marginBottom: "16px",
  },
  detailLabel: {
    fontSize: "0.8rem",
    color: THEME.textMuted,
    fontWeight: 600,
    marginBottom: "4px",
  },
  detailValue: {
    fontSize: "1rem",
    color: THEME.secondary,
    fontWeight: 500,
  },
  imageBox: {
    width: "100%",
    height: "200px",
    backgroundColor: "#f0f0f0",
    borderRadius: "12px",
    overflow: "hidden",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    gridColumn: "1 / -1",
    marginBottom: "10px",
  },
  productImg: {
    width: "100%",
    height: "100%",
    objectFit: "cover",
  },
  emptyState: {
    padding: "60px",
    textAlign: "center",
    color: THEME.textMuted,
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
  // Pagination
  paginationBar: {
    padding: "16px 24px",
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    borderTop: `1px solid ${THEME.border}`,
    backgroundColor: "#fafbfc",
  },
  pageControls: {
    display: "flex",
    gap: "8px",
    alignItems: "center",
  },
  pageBtn: {
    width: "32px",
    height: "32px",
    borderRadius: "6px",
    border: `1px solid ${THEME.border}`,
    backgroundColor: "#fff",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    cursor: "pointer",
  },
};

/**
 * ------------------------------------------------------------------
 * UTILITY FUNCTIONS
 * ------------------------------------------------------------------
 */
const formatCurrency = (amount) => {
  if (amount === null || amount === undefined) return "-";
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    minimumFractionDigits: 0,
  }).format(amount);
};

// Global Styles Injection
const GlobalStyles = () => (
  <style>
    {`
      @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
      @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
      @keyframes slideUp { from { opacity: 0; transform: translateY(30px); } to { opacity: 1; transform: translateY(0); } }
      
      ::-webkit-scrollbar { width: 8px; height: 8px; }
      ::-webkit-scrollbar-track { background: #f1f1f1; }
      ::-webkit-scrollbar-thumb { background: #c1c1c1; border-radius: 4px; }
    `}
  </style>
);

/**
 * ------------------------------------------------------------------
 * SUB-COMPONENTS
 * ------------------------------------------------------------------
 */
const Button = ({
  children,
  onClick,
  variant = "primary",
  icon: Icon,
  disabled,
}) => {
  let btnStyle = { ...styles.btn };
  if (variant === "primary") btnStyle = { ...btnStyle, ...styles.btnPrimary };
  if (variant === "secondary")
    btnStyle = { ...btnStyle, ...styles.btnSecondary };
  if (variant === "ghost") btnStyle = { ...btnStyle, ...styles.btnGhost };

  if (disabled) btnStyle = { ...btnStyle, opacity: 0.5, cursor: "not-allowed" };

  return (
    <button
      style={btnStyle}
      onClick={disabled ? undefined : onClick}
      disabled={disabled}
    >
      {Icon && <Icon size={14} />}
      {children}
    </button>
  );
};

const getImageUrl = (imagePath) => {
  if (!imagePath) return "https://via.placeholder.com/150"; // Fallback
  if (imagePath.startsWith("http")) return imagePath; // Already a full URL
  return `${SERVER_ADDR}${imagePath}`;
};

// Product Details Modal
const ProductDetailsModal = ({ isOpen, onClose, product, loading }) => {
  if (!isOpen) return null;

  return (
    <div style={styles.modalOverlay} onClick={onClose}>
      <div style={styles.modalContent} onClick={(e) => e.stopPropagation()}>
        <div style={styles.modalHeader}>
          <h3 style={styles.modalTitle}>Product Details</h3>
          <button
            style={{
              border: "none",
              background: "none",
              cursor: "pointer",
              fontSize: "1.2rem",
            }}
            onClick={onClose}
          >
            <FaTimes />
          </button>
        </div>

        {loading ? (
          <div style={{ padding: "60px", textAlign: "center" }}>
            <div style={styles.spinner}></div>
            <p style={{ marginTop: "16px", color: THEME.textMuted }}>
              Loading details...
            </p>
          </div>
        ) : product ? (
          <div style={styles.modalBody}>
            <div style={styles.imageBox}>
              {product.image_url ? (
                <img
                  src={getImageUrl(product.image_url)}
                  alt={product.product_name}
                  onError={(e) => {
                    e.target.src = "https://via.placeholder.com/150";
                  }} // Auto-fallback if fails
                  style={{ width: "100%", height: "150px", objectFit: "cover" }}
                />
              ) : (
                <FaShoppingBasket size={48} color={THEME.textMuted} />
              )}
            </div>

            <div style={{ ...styles.detailRow, gridColumn: "1 / -1" }}>
              <h2 style={{ margin: "0 0 8px 0", color: THEME.secondary }}>
                {product.product_name}
              </h2>
              <span
                style={
                  product.product_type === "farm"
                    ? styles.badgeFarm
                    : styles.badgeRetail
                }
              >
                {product.product_type === "farm"
                  ? "Farm Product"
                  : "Retail Product"}
              </span>
            </div>

            <div style={styles.detailRow}>
              <div style={styles.detailLabel}>Variety/Brand</div>
              <div style={styles.detailValue}>
                {product.variety || product.brand || "-"}
              </div>
            </div>

            <div style={styles.detailRow}>
              <div style={styles.detailLabel}>Price</div>
              <div style={styles.detailValue}>
                {formatCurrency(product.price_per_unit)} / {product.unit}
              </div>
            </div>

            <div style={styles.detailRow}>
              <div style={styles.detailLabel}>Available Quantity</div>
              <div style={styles.detailValue}>
                {product.quantity_available} {product.unit}
              </div>
            </div>

            <div style={styles.detailRow}>
              <div style={styles.detailLabel}>Seller</div>
              <div style={styles.detailValue}>{product.seller_name}</div>
            </div>

            <div style={styles.detailRow}>
              <div style={styles.detailLabel}>Phone</div>
              <div style={styles.detailValue}>
                {product.seller_phone || "N/A"}
              </div>
            </div>

            <div style={{ ...styles.detailRow, gridColumn: "1 / -1" }}>
              <div style={styles.detailLabel}>Description</div>
              <div
                style={{
                  ...styles.detailValue,
                  fontSize: "0.9rem",
                  lineHeight: 1.5,
                }}
              >
                {product.description || "No description provided."}
              </div>
            </div>

            <div style={{ ...styles.detailRow, gridColumn: "1 / -1" }}>
              <div style={styles.detailLabel}>Location</div>
              <div
                style={{
                  ...styles.detailValue,
                  fontSize: "0.9rem",
                  display: "flex",
                  alignItems: "center",
                  gap: "6px",
                }}
              >
                <FaMapMarkerAlt color={THEME.danger} />
                {product.seller_address ||
                  product.shop_address ||
                  "Address not available"}
              </div>
            </div>
          </div>
        ) : (
          <div
            style={{
              padding: "40px",
              textAlign: "center",
              color: THEME.danger,
            }}
          >
            Failed to load details.
          </div>
        )}
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
  const [products, setProducts] = useState([]);
  const [stats, setStats] = useState({
    total_products: 0,
    total_farm_products: 0,
    total_retail_products: 0,
    nearby_sellers: 0,
  });

  const [loading, setLoading] = useState(true);
  const [userLocation, setUserLocation] = useState(null); // { lat, lng }

  // Filters
  const [searchTerm, setSearchTerm] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [maxDistance, setMaxDistance] = useState(50); // Default 50km
  const [filterType, setFilterType] = useState("all"); // 'all', 'farm', 'retail'
  const [isFilterOpen, setIsFilterOpen] = useState(false);

  // Pagination (Frontend)
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage] = useState(10);
  const [sortConfig, setSortConfig] = useState({
    key: "distance_km",
    direction: "asc",
  });

  // Product Details Modal
  const [selectedProductId, setSelectedProductId] = useState(null);
  const [selectedProductData, setSelectedProductData] = useState(null);
  const [detailsLoading, setDetailsLoading] = useState(false);

  // --- INITIALIZATION ---

  // 1. Get User Location
  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setUserLocation({
            lat: position.coords.latitude,
            lng: position.coords.longitude,
          });
        },
        (error) => {
          console.error("Location denied, using default", error);
          setUserLocation(DEFAULT_LOCATION);
        },
      );
    } else {
      setUserLocation(DEFAULT_LOCATION);
    }
  }, []);

  // 2. Debounce Search
  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedSearch(searchTerm);
    }, 500);
    return () => clearTimeout(handler);
  }, [searchTerm]);

  // --- API CALLS ---

  const fetchMarketplaceData = useCallback(async () => {
    if (!userLocation) return;

    setLoading(true);
    const accessToken = localStorage.getItem("access_token");
    if (!accessToken) {
      console.error("No access token found");
      setLoading(false);
      return;
    }

    const params = {
      lat: userLocation.lat,
      lng: userLocation.lng,
      max_distance: maxDistance,
      product_type: filterType,
      search: debouncedSearch || undefined,
    };

    try {
      // 1. Fetch Products
      const prodRes = await axiosInstance.get(`${API_BASE}/products`, {
        headers: { Authorization: `Bearer ${accessToken}` },
        params,
      });

      // 2. Fetch Stats
      const statsRes = await axiosInstance.get(`${API_BASE}/stats`, {
        headers: { Authorization: `Bearer ${accessToken}` },
        params: {
          lat: userLocation.lat,
          lng: userLocation.lng,
          max_distance: maxDistance,
        },
      });

      setProducts(prodRes.data.products || []);
      setStats(statsRes.data.stats || {});
      setCurrentPage(1); // Reset to page 1 on new fetch
    } catch (error) {
      console.error("Error fetching marketplace data:", error);
    } finally {
      setLoading(false);
    }
  }, [userLocation, maxDistance, filterType, debouncedSearch]);

  // Trigger fetch when dependencies change
  useEffect(() => {
    fetchMarketplaceData();
  }, [fetchMarketplaceData]);

  // Fetch Single Product Details
  const fetchProductDetails = async (id, type) => {
    setDetailsLoading(true);
    const accessToken = localStorage.getItem("access_token");
    try {
      const response = await axiosInstance.get(`${API_BASE}/products/${id}`, {
        headers: { Authorization: `Bearer ${accessToken}` },
        params: { product_type: type },
      });
      setSelectedProductData(response.data.product);
    } catch (error) {
      console.error("Error fetching details:", error);
      setSelectedProductData(null);
    } finally {
      setDetailsLoading(false);
    }
  };

  const handleOpenDetails = (product) => {
    setSelectedProductId(product.product_id);
    fetchProductDetails(product.product_id, product.product_type);
  };

  const handleCloseDetails = () => {
    setSelectedProductId(null);
    setSelectedProductData(null);
  };

  // --- SORTING & PAGINATION (Frontend Side) ---

  const sortedProducts = useMemo(() => {
    let sortableItems = [...products];
    if (sortConfig.key) {
      sortableItems.sort((a, b) => {
        let aVal = a[sortConfig.key];
        let bVal = b[sortConfig.key];

        // Handle nulls
        if (aVal === null) aVal = "";
        if (bVal === null) bVal = "";

        // String comparison
        if (typeof aVal === "string") {
          aVal = aVal.toLowerCase();
          bVal = bVal.toLowerCase();
        }

        if (aVal < bVal) return sortConfig.direction === "asc" ? -1 : 1;
        if (aVal > bVal) return sortConfig.direction === "asc" ? 1 : -1;
        return 0;
      });
    }
    return sortableItems;
  }, [products, sortConfig]);

  const totalPages = Math.ceil(sortedProducts.length / itemsPerPage);
  const paginatedProducts = useMemo(() => {
    const start = (currentPage - 1) * itemsPerPage;
    return sortedProducts.slice(start, start + itemsPerPage);
  }, [sortedProducts, currentPage, itemsPerPage]);

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

  // --- RENDER HELPERS ---
  const renderRow = (product) => (
    <tr key={`${product.product_type}_${product.product_id}`} style={styles.tr}>
      <td style={styles.td}>
        <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
          <div
            style={{
              width: "40px",
              height: "40px",
              borderRadius: "8px",
              background: "#f0f0f0",
              overflow: "hidden",
            }}
          >
            {product.image_url ? (
              <img
                src={product.image_url}
                alt=""
                style={{ width: "100%", height: "100%", objectFit: "cover" }}
              />
            ) : (
              <div
                style={{
                  width: "100%",
                  height: "100%",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <FaShoppingBasket color="#ccc" />
              </div>
            )}
          </div>
          <div>
            <div style={{ fontWeight: 600 }}>{product.product_name}</div>
            <div style={{ fontSize: "0.8rem", color: THEME.textMuted }}>
              {product.variety || product.product_type_label}
            </div>
          </div>
        </div>
      </td>
      <td style={styles.td}>
        <span
          style={
            product.product_type === "farm"
              ? styles.badgeFarm
              : styles.badgeRetail
          }
        >
          {product.product_type === "farm" ? "Farm" : "Retail"}
        </span>
      </td>
      <td style={styles.td}>{product.seller_name}</td>
      <td style={styles.td}>
        {formatCurrency(product.price_per_unit)} / {product.unit}
      </td>
      <td style={styles.td}>{parseFloat(product.distance_km).toFixed(1)} km</td>
      <td style={styles.td}>
        {product.quantity_available > 0 ? (
          <span style={{ color: THEME.success, fontWeight: 600 }}>
            In Stock ({product.quantity_available})
          </span>
        ) : (
          <span style={{ color: THEME.danger, fontWeight: 600 }}>
            Out of Stock
          </span>
        )}
      </td>
      <td style={styles.td}>
        <Button
          variant="ghost"
          icon={FaEye}
          onClick={() => handleOpenDetails(product)}
        >
          View
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
                Marketplace Explorer
              </h1>
              <p style={styles.subTitle}>
                Monitor nearby products, check availability, and analyze
                marketplace activity in real-time.
              </p>

              {userLocation && (
                <div style={styles.locationBadge}>
                  <FaMapMarkerAlt />
                  Loc: {userLocation.lat.toFixed(4)},{" "}
                  {userLocation.lng.toFixed(4)}
                </div>
              )}
            </div>
          </div>

          {/* STATS */}
          <div style={styles.statsGrid}>
            <div style={styles.statCard}>
              <div style={styles.statIconBox}>
                <FaShoppingBasket />
              </div>
              <div style={styles.statContent}>
                <div style={styles.statLabel}>Total Products</div>
                <div style={styles.statValue}>{stats.total_products || 0}</div>
              </div>
            </div>

            <div style={styles.statCard}>
              <div style={styles.statIconBox}>
                <FaLeaf />
              </div>
              <div style={styles.statContent}>
                <div style={styles.statLabel}>Farm Products</div>
                <div style={styles.statValue}>
                  {stats.total_farm_products || 0}
                </div>
              </div>
            </div>

            <div style={styles.statCard}>
              <div style={styles.statIconBox}>
                <FaStore />
              </div>
              <div style={styles.statContent}>
                <div style={styles.statLabel}>Retail Products</div>
                <div style={styles.statValue}>
                  {stats.total_retail_products || 0}
                </div>
              </div>
            </div>

            <div style={styles.statCard}>
              <div style={styles.statIconBox}>
                <FaMapMarkerAlt />
              </div>
              <div style={styles.statContent}>
                <div style={styles.statLabel}>Nearby Sellers</div>
                <div style={styles.statValue}>{stats.nearby_sellers || 0}</div>
              </div>
            </div>
          </div>

          {/* TOOLBAR & FILTERS */}
          <div style={styles.toolbar}>
            <div style={styles.toolbarTop}>
              <div style={styles.searchContainer}>
                <FaSearch style={styles.searchIcon} />
                <input
                  type="text"
                  placeholder="Search products or descriptions..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  style={styles.searchInput}
                />
              </div>

              <div style={{ display: "flex", gap: "12px" }}>
                <Button
                  variant={isFilterOpen ? "primary" : "secondary"}
                  icon={FaFilter}
                  onClick={() => setIsFilterOpen(!isFilterOpen)}
                >
                  Filters
                </Button>
                <Button
                  variant="ghost"
                  icon={FaSync}
                  onClick={fetchMarketplaceData}
                >
                  Refresh
                </Button>
              </div>
            </div>

            {isFilterOpen && (
              <div style={styles.filterPanel}>
                <div style={styles.filterGroup}>
                  <label style={styles.label}>Product Type</label>
                  <select
                    style={styles.selectInput}
                    value={filterType}
                    onChange={(e) => setFilterType(e.target.value)}
                  >
                    <option value="all">All Products</option>
                    <option value="farm">Farm Only</option>
                    <option value="retail">Retail Only</option>
                  </select>
                </div>

                <div style={styles.filterGroup}>
                  <label style={styles.label}>
                    <div
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: "8px",
                      }}
                    >
                      <FaRulerHorizontal />
                      Max Distance: <b>{maxDistance} km</b>
                    </div>
                  </label>
                  <div style={styles.rangeContainer}>
                    <span style={{ fontSize: "0.8rem" }}>1km</span>
                    <input
                      type="range"
                      min="1"
                      max="100"
                      value={maxDistance}
                      onChange={(e) => setMaxDistance(parseInt(e.target.value))}
                      style={styles.rangeInput}
                    />
                    <span style={{ fontSize: "0.8rem" }}>100km</span>
                  </div>
                </div>

                <div style={{ marginLeft: "auto" }}>
                  <Button
                    variant="primary"
                    icon={FaCheck}
                    onClick={fetchMarketplaceData}
                  >
                    Apply Filters
                  </Button>
                </div>
              </div>
            )}
          </div>

          {/* DATA TABLE */}
          <div style={styles.tableCard}>
            <div style={styles.tableWrapper}>
              <table style={styles.table}>
                <thead style={styles.thead}>
                  <tr>
                    <th
                      style={styles.th}
                      onClick={() => handleSort("product_name")}
                    >
                      <div style={styles.thContent}>
                        Product {getSortIcon("product_name")}
                      </div>
                    </th>
                    <th
                      style={styles.th}
                      onClick={() => handleSort("product_type")}
                    >
                      <div style={styles.thContent}>
                        Type {getSortIcon("product_type")}
                      </div>
                    </th>
                    <th
                      style={styles.th}
                      onClick={() => handleSort("seller_name")}
                    >
                      <div style={styles.thContent}>
                        Seller {getSortIcon("seller_name")}
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
                      onClick={() => handleSort("distance_km")}
                    >
                      <div style={styles.thContent}>
                        Distance {getSortIcon("distance_km")}
                      </div>
                    </th>
                    <th
                      style={styles.th}
                      onClick={() => handleSort("quantity_available")}
                    >
                      <div style={styles.thContent}>
                        Status {getSortIcon("quantity_available")}
                      </div>
                    </th>
                    <th style={styles.th}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {loading ? (
                    <tr>
                      <td
                        colSpan="7"
                        style={{ padding: "60px", textAlign: "center" }}
                      >
                        <div style={styles.spinner}></div>
                      </td>
                    </tr>
                  ) : sortedProducts.length === 0 ? (
                    <tr>
                      <td colSpan="7">
                        <div style={styles.emptyState}>
                          <FaShoppingBasket
                            size={48}
                            style={{ marginBottom: "16px", opacity: 0.5 }}
                          />
                          <h3>No Products Found</h3>
                          <p>Try adjusting your distance or search filters.</p>
                        </div>
                      </td>
                    </tr>
                  ) : (
                    paginatedProducts.map(renderRow)
                  )}
                </tbody>
              </table>
            </div>

            {/* Pagination */}
            {!loading && sortedProducts.length > 0 && (
              <div style={styles.paginationBar}>
                <div style={{ fontSize: "0.9rem", color: THEME.textMuted }}>
                  Showing <b>{(currentPage - 1) * itemsPerPage + 1}</b> to{" "}
                  <b>
                    {Math.min(
                      currentPage * itemsPerPage,
                      sortedProducts.length,
                    )}
                  </b>{" "}
                  of <b>{sortedProducts.length}</b> results
                </div>
                <div style={styles.pageControls}>
                  <button
                    style={{
                      ...styles.pageBtn,
                      opacity: currentPage === 1 ? 0.5 : 1,
                    }}
                    onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                    disabled={currentPage === 1}
                  >
                    <FaChevronLeft size={12} />
                  </button>
                  <span style={{ fontSize: "0.9rem", fontWeight: 600 }}>
                    {currentPage} / {totalPages}
                  </span>
                  <button
                    style={{
                      ...styles.pageBtn,
                      opacity: currentPage === totalPages ? 0.5 : 1,
                    }}
                    onClick={() =>
                      setCurrentPage((p) => Math.min(totalPages, p + 1))
                    }
                    disabled={currentPage === totalPages}
                  >
                    <FaChevronRight size={12} />
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Detail Modal */}
      <ProductDetailsModal
        isOpen={!!selectedProductId}
        onClose={handleCloseDetails}
        product={selectedProductData}
        loading={detailsLoading}
      />
    </>
  );
};

export default MarketPlaceManagement;
