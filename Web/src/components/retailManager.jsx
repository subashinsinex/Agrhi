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
  Edit,
  Store,
  ShieldCheck,
  CheckCircle,
  AlertCircle,
  Leaf,
  Wind,
  CloudSun,
  CheckSquare,
  Package,
  IndianRupee,
  Image as ImageIcon,
  Trash2,
  ChevronDown,
  ChevronUp,
  RefreshCw,
  Database,
} from "lucide-react";
import { SERVER_IP, SERVER_PORT } from "../constant";

const apiBase = `http://${SERVER_IP}:${SERVER_PORT}/api/retail`;
const imageUploadBase = `http://${SERVER_IP}:${SERVER_PORT}/api`;

const businessTypeOptions = [
  { value: "fertilizer", label: "Fertilizer" },
  { value: "seeds", label: "Seeds" },
  { value: "tool", label: "Tools" },
  { value: "pesticide", label: "Pesticides" },
  { value: "all", label: "All Agri Inputs" },
];

const productCategoryOptions = [
  { value: "fertilizer", label: "Fertilizer" },
  { value: "seeds", label: "Seeds" },
  { value: "pesticides", label: "Pesticides" },
  { value: "tools", label: "Tool / Equipment" },
];

const unitOptions = [
  { value: "kg", label: "kg" },
  { value: "litre", label: "Litre" },
  { value: "piece", label: "Piece" },
  { value: "box", label: "Box" },
  { value: "bag", label: "Bag" },
];

const RetailManager = ({ isSidebarOpen }) => {
  // ---------------- RETAILERS ----------------
  const [retailers, setRetailers] = useState([]);
  const [loadingRetailers, setLoadingRetailers] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedRetailer, setSelectedRetailer] = useState(null);

  // --------------- RETAILER FORM -------------
  const [isFormVisible, setIsFormVisible] = useState(false);
  const [isEdit, setIsEdit] = useState(false);
  const [form, setForm] = useState({
    retailer_id: "",
    user_id: "",
    shop_name: "",
    shop_address: "",
    gst_number: "",
    business_type: "",
    license_number: "",
    latitude: "",
    longitude: "",
    is_verified: false,
  });

  const [shopImageFile, setShopImageFile] = useState(null);
  const [shopImagePreview, setShopImagePreview] = useState(null);
  const [shopImageUploading, setShopImageUploading] = useState(false);

  // ---------------- PRODUCTS -----------------
  const [products, setProducts] = useState([]);
  const [loadingProducts, setLoadingProducts] = useState(false);
  const [isProductPanelOpen, setIsProductPanelOpen] = useState(true);
  const [productForm, setProductForm] = useState({
    product_id: "",
    category: "",
    product_name: "",
    brand: "",
    price: "",
    unit: "",
    stock_qty: "",
    description: "",
    is_active: true,
  });
  const [isProductEdit, setIsProductEdit] = useState(false);
  const [productImageFile, setProductImageFile] = useState(null);
  const [productImagePreview, setProductImagePreview] = useState(null);
  const [productImageUploading, setProductImageUploading] = useState(false);

  // --------------- GLOBAL STATE --------------
  const [statusMsg, setStatusMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");
  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [confirmMode, setConfirmMode] = useState(null);
  const [productToDelete, setProductToDelete] = useState(null);
  const [loadingAggregate, setLoadingAggregate] = useState(false);

  const formSectionRef = useRef(null);
  const access_token = localStorage.getItem("access_token");

  // --------------- STATS ---------------------
  const stats = useMemo(
    () => ({
      total: retailers.length,
      verified: retailers.filter((r) => r.is_verified).length,
      unverified: retailers.filter((r) => !r.is_verified).length,
    }),
    [retailers]
  );

  const authHeader = useMemo(
    () => ({
      headers: {
        Authorization: `Bearer ${access_token}`,
      },
    }),
    [access_token]
  );

  // ========== API OPERATIONS ==========

  const fetchRetailers = useCallback(async () => {
    setLoadingRetailers(true);
    setErrorMsg("");
    if (!access_token) {
      setErrorMsg("Unauthorized: Please log in again.");
      setLoadingRetailers(false);
      return;
    }

    try {
      const res = await axiosInstance.get(
        `${apiBase}/allretailers`,
        authHeader
      );
      const data = res.data || [];
      const processed = data.map((r) => {
        let created = "Not Set";
        if (r.created_at) {
          const d = new Date(r.created_at);
          created = d.toLocaleDateString("en-GB", {
            day: "2-digit",
            month: "short",
            year: "numeric",
          });
        }
        return {
          ...r,
          formatted_created_at: created,
        };
      });
      setRetailers(processed);
    } catch (err) {
      setErrorMsg(
        "Failed to fetch retailers: " +
          (err.response?.data?.message || err.message)
      );
    } finally {
      setLoadingRetailers(false);
    }
  }, [access_token, authHeader]);

  const fetchSingleRetailer = useCallback(
    async (retailer_id) => {
      if (!retailer_id) return;
      setErrorMsg("");
      try {
        const res = await axiosInstance.get(
          `${apiBase}/getretail/${retailer_id}`,
          authHeader
        );
        const r = res.data;
        let created = "Not Set";
        if (r.created_at) {
          const d = new Date(r.created_at);
          created = d.toLocaleDateString("en-GB", {
            day: "2-digit",
            month: "short",
            year: "numeric",
          });
        }
        setSelectedRetailer({
          ...r,
          formatted_created_at: created,
        });
      } catch (err) {
        setErrorMsg(
          "Failed to fetch retailer details: " +
            (err.response?.data?.message || err.message)
        );
      }
    },
    [authHeader]
  );

  const fetchProductsForRetailer = useCallback(
    async (retailer_id) => {
      if (!retailer_id) return;
      setLoadingProducts(true);
      setErrorMsg("");
      try {
        const res = await axiosInstance.get(
          `${apiBase}/getproducts/retailer/${retailer_id}`,
          authHeader
        );
        setProducts(res.data || []);
      } catch (err) {
        setErrorMsg(
          "Failed to fetch products: " +
            (err.response?.data?.message || err.message)
        );
      } finally {
        setLoadingProducts(false);
      }
    },
    [authHeader]
  );

  // Optional single-call aggregate: retailers with embedded products
  const fetchRetailersWithProducts = useCallback(async () => {
    setLoadingAggregate(true);
    setErrorMsg("");
    try {
      const res = await axiosInstance.get(
        `${apiBase}/retailers-with-products`,
        authHeader
      );
      const list = res.data || [];
      const processed = list.map((r) => {
        let created = "Not Set";
        if (r.created_at) {
          const d = new Date(r.created_at);
          created = d.toLocaleDateString("en-GB", {
            day: "2-digit",
            month: "short",
            year: "numeric",
          });
        }
        return {
          ...r,
          formatted_created_at: created,
        };
      });
      setRetailers(processed);
      if (processed.length > 0) {
        setSelectedRetailer(processed[0]);
        setProducts(processed[0].products || []);
      }
      setStatusMsg("Loaded retailers with products in a single call.");
    } catch (err) {
      setErrorMsg(
        "Failed to fetch aggregate retailers: " +
          (err.response?.data?.message || err.message)
      );
    } finally {
      setLoadingAggregate(false);
    }
  }, [authHeader]);

  const uploadShopImage = useCallback(
    async (retailer_id) => {
      if (!shopImageFile || !retailer_id) return null;
      setShopImageUploading(true);
      setErrorMsg("");

      try {
        const fd = new FormData();
        fd.append("retailer_id", retailer_id);
        fd.append("image", shopImageFile);
        const res = await axiosInstance.post(
          `${imageUploadBase}/shop-images/upload`,
          fd,
          {
            headers: {
              Authorization: `Bearer ${access_token}`,
              "Content-Type": "multipart/form-data",
            },
          }
        );
        return res.data?.image_id || null;
      } catch (err) {
        setErrorMsg(
          "Shop image upload failed: " +
            (err.response?.data?.message || err.message)
        );
        return null;
      } finally {
        setShopImageUploading(false);
      }
    },
    [shopImageFile, access_token]
  );

  const uploadProductImage = useCallback(
    async (product_id) => {
      if (!productImageFile || !product_id) return null;
      setProductImageUploading(true);
      setErrorMsg("");

      try {
        const fd = new FormData();
        fd.append("product_id", product_id);
        fd.append("image", productImageFile);
        const res = await axiosInstance.post(
          `${imageUploadBase}/product-images/upload`,
          fd,
          {
            headers: {
              Authorization: `Bearer ${access_token}`,
              "Content-Type": "multipart/form-data",
            },
          }
        );
        return res.data?.image_id || null;
      } catch (err) {
        setErrorMsg(
          "Product image upload failed: " +
            (err.response?.data?.message || err.message)
        );
        return null;
      } finally {
        setProductImageUploading(false);
      }
    },
    [productImageFile, access_token]
  );

  // ========== EFFECTS ==========

  useEffect(() => {
    fetchRetailers();
  }, [fetchRetailers]);

  useEffect(() => {
    if (selectedRetailer?.retailer_id) {
      fetchSingleRetailer(selectedRetailer.retailer_id);
      fetchProductsForRetailer(selectedRetailer.retailer_id);
    }
  }, [
    selectedRetailer?.retailer_id,
    fetchSingleRetailer,
    fetchProductsForRetailer,
  ]);

  // ========== HANDLERS: RETAILER FORM ==========

  const handleChange = (e) =>
    setForm({
      ...form,
      [e.target.name]: e.target.value,
    });

  const handleCheckboxChange = (e) =>
    setForm({
      ...form,
      [e.target.name]: e.target.checked,
    });

  const resetForm = (showForm = true) => {
    setForm({
      retailer_id: "",
      user_id: "",
      shop_name: "",
      shop_address: "",
      gst_number: "",
      business_type: "",
      license_number: "",
      latitude: "",
      longitude: "",
      is_verified: false,
    });
    setIsEdit(false);
    setErrorMsg("");
    setStatusMsg("");
    setIsFormVisible(showForm);
    setShopImageFile(null);
    setShopImagePreview(null);
  };

  const handleAddNewRetailer = () => {
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

  const handleShopImageChange = (e) => {
    const file = e.target.files?.[0];
    setShopImageFile(file || null);
    if (file) {
      const reader = new FileReader();
      reader.onload = () => setShopImagePreview(reader.result);
      reader.readAsDataURL(file);
    } else {
      setShopImagePreview(null);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setStatusMsg("");
    setErrorMsg("");

    try {
      if (!form.user_id) {
        setErrorMsg("User ID is required (retailer must be a user).");
        return;
      }

      if (isEdit) {
        await axiosInstance.put(
          `${apiBase}/updateretailers/${form.retailer_id}`,
          {
            shop_name: form.shop_name,
            shop_address: form.shop_address,
            gst_number: form.gst_number,
            business_type: form.business_type,
            license_number: form.license_number,
            latitude: form.latitude || null,
            longitude: form.longitude || null,
            is_verified: form.is_verified,
          },
          authHeader
        );

        if (shopImageFile) {
          const image_id = await uploadShopImage(form.retailer_id);
          if (image_id) {
            await axiosInstance.put(
              `${apiBase}/retailers/${form.retailer_id}`,
              { image_id },
              authHeader
            );
          }
        }

        setStatusMsg("Retailer updated successfully.");
      } else {
        const res = await axiosInstance.post(
          `${apiBase}/retailers`,
          {
            user_id: form.user_id,
            shop_name: form.shop_name,
            shop_address: form.shop_address,
            gst_number: form.gst_number,
            business_type: form.business_type,
            license_number: form.license_number,
            latitude: form.latitude || null,
            longitude: form.longitude || null,
          },
          authHeader
        );
        const created = res.data?.retailer;
        const createdId = created?.retailer_id;

        if (createdId && shopImageFile) {
          const image_id = await uploadShopImage(createdId);
          if (image_id) {
            await axiosInstance.put(
              `${apiBase}/retailers/${createdId}`,
              { image_id },
              authHeader
            );
          }
        }

        setStatusMsg("Retailer created successfully.");
      }

      fetchRetailers();
      setIsFormVisible(false);
    } catch (err) {
      setErrorMsg(
        err?.response?.data?.message || "Operation failed. Please check inputs."
      );
    }
  };

  const handleEdit = (r) => {
    setForm({
      retailer_id: r.retailer_id,
      user_id: r.user_id,
      shop_name: r.shop_name || "",
      shop_address: r.shop_address || "",
      gst_number: r.gst_number || "",
      business_type: r.business_type || "",
      license_number: r.license_number || "",
      latitude: r.latitude || "",
      longitude: r.longitude || "",
      is_verified: !!r.is_verified,
    });
    setIsEdit(true);
    setIsFormVisible(true);
    if (r.shop_image_url) {
      setShopImagePreview(
        `http://${SERVER_IP}:${SERVER_PORT}${r.shop_image_url}`
      );
    }
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handleRetailerCardClick = (r) => {
    setSelectedRetailer(r);
    setIsProductPanelOpen(true);
  };

  // ========== HANDLERS: PRODUCTS ==========

  const resetProductForm = () => {
    setProductForm({
      product_id: "",
      category: "",
      product_name: "",
      brand: "",
      price: "",
      unit: "",
      stock_qty: "",
      description: "",
      is_active: true,
    });
    setIsProductEdit(false);
    setProductImageFile(null);
    setProductImagePreview(null);
    setErrorMsg("");
    setStatusMsg("");
  };

  const handleProductChange = (e) => {
    const { name, value } = e.target;
    setProductForm((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleProductCheckboxChange = (e) => {
    const { name, checked } = e.target;
    setProductForm((prev) => ({
      ...prev,
      [name]: checked,
    }));
  };

  const handleProductImageChange = (e) => {
    const file = e.target.files?.[0];
    setProductImageFile(file || null);
    if (file) {
      const reader = new FileReader();
      reader.onload = () => setProductImagePreview(reader.result);
      reader.readAsDataURL(file);
    } else {
      setProductImagePreview(null);
    }
  };

  const handleEditProduct = (p) => {
    setProductForm({
      product_id: p.product_id,
      category: p.category || "",
      product_name: p.product_name || "",
      brand: p.brand || "",
      price: p.price || "",
      unit: p.unit || "",
      stock_qty: p.stock_qty || "",
      description: p.description || "",
      is_active: !!p.is_active,
    });
    setIsProductEdit(true);
    if (p.product_image_url) {
      setProductImagePreview(
        `http://${SERVER_IP}:${SERVER_PORT}${p.product_image_url}`
      );
    }
  };

  const handleProductSubmit = async (e) => {
    e.preventDefault();
    setStatusMsg("");
    setErrorMsg("");

    if (!selectedRetailer?.retailer_id) {
      setErrorMsg("Select a retailer before adding products.");
      return;
    }

    try {
      if (isProductEdit) {
        await axiosInstance.put(
          `${apiBase}/updateproducts/${productForm.product_id}`,
          {
            category: productForm.category || null,
            product_name: productForm.product_name || null,
            brand: productForm.brand || null,
            price:
              productForm.price !== "" ? parseFloat(productForm.price) : null,
            unit: productForm.unit || null,
            stock_qty:
              productForm.stock_qty !== ""
                ? parseFloat(productForm.stock_qty)
                : null,
            description: productForm.description || null,
            is_active: productForm.is_active,
          },
          authHeader
        );

        if (productImageFile) {
          const image_id = await uploadProductImage(productForm.product_id);
          if (image_id) {
            await axiosInstance.put(
              `${imageUploadBase}/product-images/upload`,
              { image_id },
              authHeader
            );
          }
        }

        setStatusMsg("Product updated successfully.");
      } else {
        const res = await axiosInstance.post(
          `${apiBase}/createproducts`,
          {
            retailer_id: selectedRetailer.retailer_id,
            category: productForm.category,
            product_name: productForm.product_name,
            brand: productForm.brand,
            price:
              productForm.price !== "" ? parseFloat(productForm.price) : null,
            unit: productForm.unit,
            stock_qty:
              productForm.stock_qty !== ""
                ? parseFloat(productForm.stock_qty)
                : 0,
            description: productForm.description,
          },
          authHeader
        );
        const created = res.data?.product;
        const createdProductId = created?.product_id;

        if (createdProductId && productImageFile) {
          const image_id = await uploadProductImage(createdProductId);
          if (image_id) {
            await axiosInstance.put(
              `${imageUploadBase}/product-images/upload`,
              { image_id },
              authHeader
            );
          }
        }

        setStatusMsg("Product added successfully.");
      }

      await fetchProductsForRetailer(selectedRetailer.retailer_id);
      resetProductForm();
    } catch (err) {
      setErrorMsg(err?.response?.data?.message || "Product operation failed.");
    }
  };

  const handleToggleProductStatus = async (p) => {
    setErrorMsg("");
    try {
      await axiosInstance.put(
        `${apiBase}/products/${p.product_id}/isactive`,
        {
          is_active: !p.is_active,
        },
        authHeader
      );
      await fetchProductsForRetailer(selectedRetailer.retailer_id);
    } catch (err) {
      setErrorMsg(
        err?.response?.data?.message || "Failed to update product status."
      );
    }
  };

  const confirmDeleteProduct = (p) => {
    setProductToDelete(p);
    setConfirmMode("product");
    setIsConfirmOpen(true);
  };

  const handleDeleteProduct = async () => {
    if (!productToDelete) return;
    setErrorMsg("");
    try {
      await axiosInstance.delete(
        `${apiBase}/deleteproducts/${productToDelete.product_id}`,
        authHeader
      );
      await fetchProductsForRetailer(selectedRetailer.retailer_id);
      setStatusMsg("Product deleted.");
    } catch (err) {
      setErrorMsg(err?.response?.data?.message || "Failed to delete product.");
    } finally {
      setIsConfirmOpen(false);
      setProductToDelete(null);
      setConfirmMode(null);
    }
  };

  // ========== FILTERING ==========

  const filteredRetailers = useMemo(() => {
    return retailers.filter((r) => {
      const term = searchTerm.toLowerCase();
      return (
        (r.shop_name || "").toLowerCase().includes(term) ||
        (r.name || "").toLowerCase().includes(term) ||
        (r.gst_number || "").toLowerCase().includes(term)
      );
    });
  }, [retailers, searchTerm]);

  // ========== STYLES ==========

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
  background: transparent;
  font-family: 'Outfit', sans-serif;
  padding: 50px;
  transition: margin-left 0.4s ease;
  color: var(--ag-forest);
}

@media (min-width: 1024px) {
  .ag-wrapper.sidebar-open {
    margin-left: 260px;
  }
}

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

.ag-title p {
  color: var(--ag-sage);
  margin: 4px 0 0 0;
  font-size: 1rem;
}

.ag-controls {
  display: flex;
  gap: 16px;
  align-items: center;
}

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

.ag-search-bar:focus-within {
  border-color: var(--ag-leaf);
  width: 350px;
}

.ag-search-bar input {
  border: none;
  outline: none;
  width: 100%;
  font-family: inherit;
  font-size: 0.95rem;
}

.ag-search-bar svg {
  color: var(--ag-sage);
}

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

.btn-ag:hover {
  background: var(--ag-leaf);
  transform: translateY(-2px);
}

.btn-ag.secondary {
  background: #F1F5F9;
  color: var(--ag-forest);
  box-shadow: 0 2px 6px rgba(15, 23, 42, 0.06);
}

.btn-ag.cancel {
  background: #E74C3C;
}

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

.ag-stat-info h4 {
  margin: 0;
  font-size: 0.85rem;
  color: var(--ag-sage);
  text-transform: uppercase;
}

.ag-stat-info h2 {
  margin: 0;
  font-size: 1.6rem;
  font-weight: 700;
}

.ag-form-container {
  background: var(--ag-white);
  border-radius: var(--radius-organic);
  padding: 40px;
  margin-bottom: 40px;
  box-shadow: 0 20px 40px var(--ag-shadow);
  border: 1px solid rgba(139, 168, 136, 0.1);
}

.ag-form-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  gap: 12px;
}

.ag-form-header h2 {
  margin: 0;
  font-size: 1.4rem;
  display: flex;
  align-items: center;
  gap: 8px;
}

.ag-form-header small {
  color: var(--ag-sage);
}

.ag-form-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 24px;
}

.ag-input-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.ag-input-group label {
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--ag-forest);
  opacity: 0.8;
}

.ag-input-group input,
.ag-input-group select,
.ag-input-group textarea {
  padding: 12px 16px;
  border-radius: 12px;
  border: 1.5px solid #eee;
  background: #fafafa;
  transition: var(--transition);
  font-family: inherit;
  resize: vertical;
}

.ag-input-group input:focus,
.ag-input-group select:focus,
.ag-input-group textarea:focus {
  border-color: var(--ag-leaf);
  background: white;
  box-shadow: 0 0 0 4px rgba(74, 124, 68, 0.1);
  outline: none;
}

.ag-checkbox-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 8px;
}

.ag-checkbox-row input[type="checkbox"] {
  width: 16px;
  height: 16px;
}

.ag-form-actions {
  margin-top: 30px;
  display: flex;
  gap: 16px;
}

.btn-outlined {
  padding: 10px 18px;
  border-radius: 50px;
  border: 1px solid var(--ag-leaf);
  background: transparent;
  color: var(--ag-leaf);
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 6px;
  font-weight: 500;
  transition: var(--transition);
}

.btn-outlined:hover {
  background: rgba(74, 124, 68, 0.05);
}

.ag-main-layout {
  display: grid;
  grid-template-columns: 2.2fr 1.3fr;
  gap: 30px;
  align-items: flex-start;
}

@media (max-width: 1024px) {
  .ag-main-layout {
    grid-template-columns: 1fr;
  }
}

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
  cursor: pointer;
}

.ag-card:hover {
  transform: translateY(-8px);
  box-shadow: 0 15px 35px var(--ag-shadow);
}

.ag-card.selected {
  border-color: var(--ag-leaf);
  box-shadow: 0 0 0 2px rgba(74, 124, 68, 0.2);
}

.ag-card-header {
  position: relative;
  z-index: 1;
  display: flex;
  gap: 15px;
  align-items: center;
  margin-bottom: 20px;
}

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

.badge-verified {
  background: #E6FFFA;
  color: #2C7A7B;
}

.badge-pending {
  background: #FFF5F5;
  color: #C53030;
}

.ag-card-body {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.ag-data-item {
  display: flex;
  align-items: center;
  gap: 10px;
  color: var(--ag-slate);
  font-size: 0.95rem;
}

.ag-data-item svg {
  color: var(--ag-sage);
  flex-shrink: 0;
}

.ag-card-footer {
  margin-top: 18px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
}

.ag-card-footer small {
  color: var(--ag-sage);
}

.ag-card-actions {
  display: flex;
  gap: 8px;
}

.btn-action {
  padding: 8px 12px;
  border-radius: 12px;
  border: none;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  font-size: 0.8rem;
  transition: var(--transition);
}

.btn-edit {
  background: var(--ag-sand);
  color: var(--ag-forest);
}

.btn-edit:hover {
  background: var(--ag-clay);
}

.btn-delete {
  background: #FFF5F5;
  color: #E53E3E;
}

.btn-delete:hover {
  background: #FED7D7;
}

.ag-alert {
  padding: 16px;
  border-radius: 16px;
  margin-bottom: 24px;
  display: flex;
  align-items: center;
  gap: 12px;
  font-weight: 500;
}

.ag-alert.success {
  background: #EBFEEB;
  color: #2D5A27;
  border: 1px solid #D5F5D5;
}

.ag-alert.error {
  background: #FFF5F5;
  color: #C53030;
  border: 1px solid #FEB2B2;
}

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

.ag-side-panel {
  background: var(--ag-white);
  border-radius: var(--radius-organic);
  padding: 24px;
  box-shadow: 0 20px 40px var(--ag-shadow);
  border: 1px solid rgba(139, 168, 136, 0.1);
}

.ag-side-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  gap: 12px;
}

.ag-side-header h3 {
  margin: 0;
  font-size: 1.2rem;
  display: flex;
  align-items: center;
  gap: 6px;
}

.ag-product-list {
  margin-top: 16px;
  max-height: 320px;
  overflow-y: auto;
  padding-right: 6px;
}

.ag-product-item {
  border-radius: 16px;
  border: 1px solid #eee;
  padding: 12px 14px;
  display: grid;
  grid-template-columns: minmax(0, 1.3fr) minmax(0, 0.8fr);
  gap: 10px;
  margin-bottom: 10px;
  font-size: 0.88rem;
}

.ag-product-main {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.ag-product-main strong {
  font-size: 0.95rem;
}

.ag-product-meta {
  color: var(--ag-sage);
}

.ag-product-actions {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 6px;
}

.ag-chip {
  border-radius: 999px;
  padding: 4px 10px;
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
}

.chip-active {
  background: #E6FFFA;
  color: #2C7A7B;
}

.chip-inactive {
  background: #EDF2F7;
  color: #718096;
}

.ag-product-form {
  margin-top: 20px;
  border-top: 1px dashed #e0e0e0;
  padding-top: 16px;
}

.ag-image-preview {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 6px;
}

.ag-image-preview img {
  width: 60px;
  height: 60px;
  border-radius: 15px;
  object-fit: cover;
  border: 1px solid #e0e0e0;
}

.ag-loading {
  text-align: center;
  padding: 40px 0;
  color: var(--ag-sage);
}

@media (max-width: 768px) {
  .ag-wrapper {
    padding: 18px;
  }
  .ag-header {
    flex-direction: column;
    align-items: stretch;
    margin-top: 60px;
  }
  .ag-search-bar {
    width: 100%;
  }
  .ag-stats-grid {
    grid-template-columns: 1fr 1fr;
  }
  .ag-side-panel {
    margin-top: 20px;
  }
}
`;

  const firstLetter = (text) =>
    (text || "").trim().charAt(0).toUpperCase() || "R";

  return (
    <>
      <style dangerouslySetInnerHTML={{ __html: styles }} />
      <div className={`ag-wrapper ${isSidebarOpen ? "sidebar-open" : ""}`}>
        <header className="ag-header">
          <div className="ag-title"></div>
          <div className="ag-controls">
            <div className="ag-search-bar">
              <Search size={18} />
              <input
                type="text"
                placeholder="Search by shop, owner, GST..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
            <button
              className="btn-ag secondary"
              type="button"
              onClick={fetchRetailers}
            >
              <RefreshCw size={16} />
              Refresh
            </button>
            <button
              className="btn-ag secondary"
              type="button"
              onClick={fetchRetailersWithProducts}
              disabled={loadingAggregate}
            >
              <Database size={16} />
              {loadingAggregate ? "Loading..." : "Load with products"}
            </button>
            <button
              className="btn-ag"
              type="button"
              onClick={handleAddNewRetailer}
            >
              <Plus size={18} />
              {isFormVisible && !isEdit
                ? "Close form"
                : isEdit
                ? "Editing retailer"
                : "Add retailer"}
            </button>
          </div>
        </header>

        <section className="ag-stats-grid">
          <div className="ag-stat-card">
            <div className="ag-stat-icon">
              <Leaf size={24} />
            </div>
            <div className="ag-stat-info">
              <h4>Total retailers</h4>
              <h2>{stats.total}</h2>
            </div>
          </div>
          <div className="ag-stat-card">
            <div className="ag-stat-icon">
              <ShieldCheck size={24} />
            </div>
            <div className="ag-stat-info">
              <h4>Verified</h4>
              <h2>{stats.verified}</h2>
            </div>
          </div>
          <div className="ag-stat-card">
            <div className="ag-stat-icon">
              <AlertCircle size={24} />
            </div>
            <div className="ag-stat-info">
              <h4>Pending verification</h4>
              <h2>{stats.unverified}</h2>
            </div>
          </div>
        </section>

        {statusMsg && (
          <div className="ag-alert success">
            <CheckCircle size={18} />
            <span>{statusMsg}</span>
          </div>
        )}
        {errorMsg && (
          <div className="ag-alert error">
            <AlertCircle size={18} />
            <span>{errorMsg}</span>
          </div>
        )}

        {isFormVisible && (
          <section ref={formSectionRef} className="ag-form-container">
            <div className="ag-form-header">
              <div>
                <h2>
                  <Store size={20} />
                  {isEdit ? "Edit retailer profile" : "Create new retailer"}
                </h2>
                <small>
                  Capture key shop information, link to user, and define
                  business type.
                </small>
              </div>
              <button
                type="button"
                className="btn-ag cancel"
                onClick={() => setIsFormVisible(false)}
              >
                <X size={16} />
                Close
              </button>
            </div>

            <form onSubmit={handleSubmit}>
              <div className="ag-form-grid">
                <div className="ag-input-group">
                  <label>User ID (UUID)</label>
                  <input
                    type="text"
                    name="user_id"
                    placeholder="User ID of retailer (from users_auth)"
                    value={form.user_id}
                    onChange={handleChange}
                    disabled={isEdit}
                  />
                </div>

                <div className="ag-input-group">
                  <label>Shop name</label>
                  <input
                    type="text"
                    name="shop_name"
                    placeholder="Sri Amman Agro Centre"
                    value={form.shop_name}
                    onChange={handleChange}
                  />
                </div>

                <div className="ag-input-group">
                  <label>Shop address</label>
                  <input
                    type="text"
                    name="shop_address"
                    placeholder="Main road, village, district"
                    value={form.shop_address}
                    onChange={handleChange}
                  />
                </div>

                <div className="ag-input-group">
                  <label>GST number</label>
                  <input
                    type="text"
                    name="gst_number"
                    placeholder="33ABCDE1234F1Z5"
                    value={form.gst_number}
                    onChange={handleChange}
                  />
                </div>

                <div className="ag-input-group">
                  <label>License number</label>
                  <input
                    type="text"
                    name="license_number"
                    placeholder="TN-AGRO-12345"
                    value={form.license_number}
                    onChange={handleChange}
                  />
                </div>

                <div className="ag-input-group">
                  <label>Business type</label>
                  <select
                    name="business_type"
                    value={form.business_type}
                    onChange={handleChange}
                  >
                    <option value="">Select...</option>
                    {businessTypeOptions.map((opt) => (
                      <option key={opt.value} value={opt.value}>
                        {opt.label}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="ag-input-group">
                  <label>Latitude</label>
                  <input
                    type="number"
                    step="0.000001"
                    name="latitude"
                    placeholder="13.035650"
                    value={form.latitude}
                    onChange={handleChange}
                  />
                </div>

                <div className="ag-input-group">
                  <label>Longitude</label>
                  <input
                    type="number"
                    step="0.000001"
                    name="longitude"
                    placeholder="80.158210"
                    value={form.longitude}
                    onChange={handleChange}
                  />
                </div>

                <div className="ag-input-group">
                  <label>Verification</label>
                  <div className="ag-checkbox-row">
                    <input
                      type="checkbox"
                      name="is_verified"
                      checked={form.is_verified}
                      onChange={handleCheckboxChange}
                    />
                    <span>Mark as verified retailer</span>
                  </div>
                </div>

                <div className="ag-input-group">
                  <label>Shop image</label>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleShopImageChange}
                  />
                  {shopImagePreview && (
                    <div className="ag-image-preview">
                      <img src={shopImagePreview} alt="Shop preview" />
                      <span>Preview</span>
                    </div>
                  )}
                  {shopImageUploading && (
                    <small style={{ color: "#888" }}>
                      Uploading shop image...
                    </small>
                  )}
                </div>
              </div>

              <div className="ag-form-actions">
                <button type="submit" className="btn-ag">
                  <CheckSquare size={18} />
                  {isEdit ? "Save changes" : "Create retailer"}
                </button>
                <button
                  type="button"
                  className="btn-outlined"
                  onClick={() => resetForm(true)}
                >
                  <Wind size={16} />
                  Reset form
                </button>
              </div>
            </form>
          </section>
        )}

        <section className="ag-main-layout">
          <div>
            {loadingRetailers ? (
              <div className="ag-loading">
                <CloudSun size={22} />
                <p>Cultivating retailer data...</p>
              </div>
            ) : filteredRetailers.length === 0 ? (
              <div className="ag-loading">
                <AlertCircle size={22} />
                <p>
                  No retailers found for "{searchTerm}". Try adjusting your
                  filters.
                </p>
              </div>
            ) : (
              <div className="ag-user-grid">
                {filteredRetailers.map((r) => (
                  <article
                    key={r.retailer_id}
                    className={`ag-card ${
                      selectedRetailer?.retailer_id === r.retailer_id
                        ? "selected"
                        : ""
                    }`}
                    onClick={() => handleRetailerCardClick(r)}
                  >
                    <div className="ag-card-header">
                      <div className="ag-avatar">
                        {firstLetter(r.shop_name)}
                      </div>
                      <div>
                        <h3 style={{ margin: 0 }}>{r.shop_name}</h3>
                        <div
                          style={{
                            display: "flex",
                            gap: 8,
                            marginTop: 4,
                            flexWrap: "wrap",
                          }}
                        >
                          <span
                            className={`ag-badge ${
                              r.is_verified ? "badge-verified" : "badge-pending"
                            }`}
                          >
                            {r.is_verified ? "Verified" : "Pending"}
                          </span>
                          {r.business_type && (
                            <span
                              className="ag-badge"
                              style={{
                                background: "#EDF2F7",
                                color: "#4A5568",
                              }}
                            >
                              {r.business_type}
                            </span>
                          )}
                        </div>
                      </div>
                    </div>

                    <div className="ag-card-body">
                      <div className="ag-data-item">
                        <MapPin size={16} />
                        <span>{r.shop_address || "Address not set"}</span>
                      </div>
                      {r.gst_number && (
                        <div className="ag-data-item">
                          <Mail size={16} />
                          <span>GST: {r.gst_number}</span>
                        </div>
                      )}
                      {r.license_number && (
                        <div className="ag-data-item">
                          <ShieldCheck size={16} />
                          <span>License: {r.license_number}</span>
                        </div>
                      )}
                      {r.name && (
                        <div className="ag-data-item">
                          <Phone size={16} />
                          <span>Owner: {r.name}</span>
                        </div>
                      )}
                      {r.pincode && (
                        <div className="ag-data-item">
                          <MapPin size={16} />
                          <span>PIN: {r.pincode}</span>
                        </div>
                      )}
                    </div>

                    <div className="ag-card-footer">
                      <small>
                        <Calendar size={14} style={{ marginRight: 4 }} />
                        Onboarded: {r.formatted_created_at || "Not set"}
                      </small>
                      <div className="ag-card-actions">
                        <button
                          type="button"
                          className="btn-action btn-edit"
                          onClick={(e) => {
                            e.stopPropagation();
                            handleEdit(r);
                          }}
                        >
                          <Edit size={14} />
                          Edit
                        </button>
                        <button
                          type="button"
                          className="btn-action btn-delete"
                          onClick={(e) => {
                            e.stopPropagation();
                            // future: add retailer delete route
                          }}
                        >
                          <Trash2 size={14} />
                          Remove
                        </button>
                      </div>
                    </div>
                  </article>
                ))}
              </div>
            )}
          </div>

          <aside className="ag-side-panel">
            <div className="ag-side-header">
              <div>
                <h3>
                  <Package size={18} />
                  Retailer products
                </h3>
                <small>
                  Manage SKU catalog for the selected retailer in the
                  marketplace.
                </small>
              </div>
              <button
                type="button"
                className="btn-outlined"
                onClick={() => setIsProductPanelOpen((prev) => !prev)}
              >
                {isProductPanelOpen ? (
                  <>
                    <ChevronUp size={16} /> Collapse
                  </>
                ) : (
                  <>
                    <ChevronDown size={16} /> Expand
                  </>
                )}
              </button>
            </div>

            {selectedRetailer ? (
              <>
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 10,
                    marginBottom: 12,
                  }}
                >
                  <div className="ag-avatar" style={{ width: 46, height: 46 }}>
                    {firstLetter(selectedRetailer.shop_name)}
                  </div>
                  <div>
                    <div style={{ fontWeight: 600 }}>
                      {selectedRetailer.shop_name}
                    </div>
                    <small style={{ color: "#718096" }}>
                      {selectedRetailer.shop_address || "Address not set"}
                    </small>
                  </div>
                </div>

                {isProductPanelOpen && (
                  <>
                    {loadingProducts ? (
                      <div className="ag-loading">
                        <CloudSun size={18} />
                        <p>Loading product catalog...</p>
                      </div>
                    ) : products.length === 0 ? (
                      <div className="ag-loading" style={{ padding: "12px 0" }}>
                        <AlertCircle size={18} />
                        <p>No products configured yet.</p>
                      </div>
                    ) : (
                      <div className="ag-product-list">
                        {products.map((p) => (
                          <div key={p.product_id} className="ag-product-item">
                            <div className="ag-product-main">
                              <strong>{p.product_name}</strong>
                              <div className="ag-product-meta">
                                {p.brand && <span>{p.brand}</span>}
                                {p.category && (
                                  <span> • {p.category.toUpperCase()}</span>
                                )}
                              </div>
                              <div className="ag-product-meta">
                                {p.price && (
                                  <>
                                    <IndianRupee size={12} /> {p.price}/{p.unit}
                                  </>
                                )}
                                {p.stock_qty && (
                                  <span> • Stock: {p.stock_qty}</span>
                                )}
                              </div>
                            </div>
                            <div className="ag-product-actions">
                              <span
                                className={`ag-chip ${
                                  p.is_active ? "chip-active" : "chip-inactive"
                                }`}
                              >
                                {p.is_active ? "Active" : "Inactive"}
                              </span>
                              <div style={{ display: "flex", gap: 6 }}>
                                <button
                                  type="button"
                                  className="btn-action btn-edit"
                                  onClick={() => handleEditProduct(p)}
                                >
                                  <Edit size={14} />
                                </button>
                                <button
                                  type="button"
                                  className="btn-action btn-edit"
                                  onClick={() => handleToggleProductStatus(p)}
                                >
                                  {p.is_active ? "Disable" : "Enable"}
                                </button>
                                <button
                                  type="button"
                                  className="btn-action btn-delete"
                                  onClick={() => confirmDeleteProduct(p)}
                                >
                                  <Trash2 size={14} />
                                </button>
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}

                    <div className="ag-product-form">
                      <h4
                        style={{
                          marginBottom: 8,
                          display: "flex",
                          alignItems: "center",
                          gap: 6,
                        }}
                      >
                        <Package size={16} />
                        {isProductEdit
                          ? "Edit product details"
                          : "Add new product"}
                      </h4>
                      <form onSubmit={handleProductSubmit}>
                        <div className="ag-form-grid">
                          <div className="ag-input-group">
                            <label>Category</label>
                            <select
                              name="category"
                              value={productForm.category}
                              onChange={handleProductChange}
                            >
                              <option value="">Select...</option>
                              {productCategoryOptions.map((opt) => (
                                <option key={opt.value} value={opt.value}>
                                  {opt.label}
                                </option>
                              ))}
                            </select>
                          </div>
                          <div className="ag-input-group">
                            <label>Product name</label>
                            <input
                              type="text"
                              name="product_name"
                              placeholder="DAP 18-46-0"
                              value={productForm.product_name}
                              onChange={handleProductChange}
                            />
                          </div>
                          <div className="ag-input-group">
                            <label>Brand</label>
                            <input
                              type="text"
                              name="brand"
                              placeholder="IFFCO"
                              value={productForm.brand}
                              onChange={handleProductChange}
                            />
                          </div>
                          <div className="ag-input-group">
                            <label>Price</label>
                            <input
                              type="number"
                              step="0.01"
                              name="price"
                              placeholder="65.00"
                              value={productForm.price}
                              onChange={handleProductChange}
                            />
                          </div>
                          <div className="ag-input-group">
                            <label>Unit</label>
                            <select
                              name="unit"
                              value={productForm.unit}
                              onChange={handleProductChange}
                            >
                              <option value="">Select...</option>
                              {unitOptions.map((u) => (
                                <option key={u.value} value={u.value}>
                                  {u.label}
                                </option>
                              ))}
                            </select>
                          </div>
                          <div className="ag-input-group">
                            <label>Stock quantity</label>
                            <input
                              type="number"
                              step="0.01"
                              name="stock_qty"
                              placeholder="200"
                              value={productForm.stock_qty}
                              onChange={handleProductChange}
                            />
                          </div>
                          <div className="ag-input-group">
                            <label>Description</label>
                            <textarea
                              name="description"
                              rows={3}
                              placeholder="High quality DAP fertilizer"
                              value={productForm.description}
                              onChange={handleProductChange}
                            />
                          </div>
                          <div className="ag-input-group">
                            <label>Active status</label>
                            <div className="ag-checkbox-row">
                              <input
                                type="checkbox"
                                name="is_active"
                                checked={productForm.is_active}
                                onChange={handleProductCheckboxChange}
                              />
                              <span>Available in marketplace</span>
                            </div>
                          </div>
                          <div className="ag-input-group">
                            <label>Product image</label>
                            <input
                              type="file"
                              accept="image/*"
                              onChange={handleProductImageChange}
                            />
                            {productImagePreview && (
                              <div className="ag-image-preview">
                                <img
                                  src={productImagePreview}
                                  alt="Product preview"
                                />
                                <span>Preview</span>
                              </div>
                            )}
                            {productImageUploading && (
                              <small style={{ color: "#888" }}>
                                Uploading product image...
                              </small>
                            )}
                          </div>
                        </div>

                        <div className="ag-form-actions">
                          <button type="submit" className="btn-ag">
                            <ImageIcon size={16} />
                            {isProductEdit ? "Update product" : "Add product"}
                          </button>
                          <button
                            type="button"
                            className="btn-outlined"
                            onClick={resetProductForm}
                          >
                            <Wind size={16} />
                            Clear
                          </button>
                        </div>
                      </form>
                    </div>
                  </>
                )}
              </>
            ) : (
              <div className="ag-loading">
                <Package size={20} />
                <p>Select a retailer card to manage its products.</p>
              </div>
            )}
          </aside>
        </section>

        {isConfirmOpen && (
          <div className="ag-overlay">
            <div className="ag-modal">
              <AlertCircle size={32} style={{ color: "#C53030" }} />
              <h3 style={{ marginTop: 16, marginBottom: 10 }}>
                Confirm removal
              </h3>
              {confirmMode === "product" && productToDelete && (
                <p>
                  Are you sure you want to remove{" "}
                  <strong>{productToDelete.product_name}</strong> from this
                  retailer's catalog?
                </p>
              )}
              <div
                style={{
                  display: "flex",
                  marginTop: 24,
                  justifyContent: "center",
                  gap: 12,
                }}
              >
                <button
                  className="btn-ag cancel"
                  type="button"
                  onClick={() => {
                    setIsConfirmOpen(false);
                    setConfirmMode(null);
                    setProductToDelete(null);
                  }}
                >
                  <X size={16} />
                  Cancel
                </button>
                <button
                  className="btn-ag"
                  type="button"
                  onClick={() => {
                    if (confirmMode === "product") {
                      handleDeleteProduct();
                    }
                  }}
                >
                  <Trash2 size={16} />
                  Yes, remove
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  );
};

export default RetailManager;
