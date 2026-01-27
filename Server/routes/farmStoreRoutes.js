const express = require("express");
const router = express.Router();

const farmStoreService = require("../services/farmStoreServices");
const jwtChecker = require("../middleware/jwtChecker");

// ========== FARMER SHOP PLACES ==========

// Add or update farmer shop location
router.post(
  "/add-farmer-shop-places",
  jwtChecker,
  farmStoreService.addFarmerShopPlace,
);

// Get farmer shop location by farmer ID
router.get(
  "/farmer-shop-places/:farmerId",
  jwtChecker,
  farmStoreService.getFarmerShopPlaces,
);

// ========== FARM PRODUCTS ==========

// Create new farm product
router.post("/farm-products", jwtChecker, farmStoreService.createFarmProduct);

// Get nearby farm products (must be before /:id route)
router.get(
  "/farm-products/nearby",
  jwtChecker,
  farmStoreService.getNearbyFarmProducts,
);

// Get all farm products by farmer ID
router.get(
  "/farm-products/farmer/:farmerId",
  jwtChecker,
  farmStoreService.getFarmProductsByFarmer,
);

// Get single farm product by ID
router.get(
  "/farm-products/:id",
  jwtChecker,
  farmStoreService.getFarmProductById,
);

// Get all farm products with optional filters
router.get("/farm-products", jwtChecker, farmStoreService.getAllFarmProducts);

// Update farm product
router.put(
  "/farm-products/:id",
  jwtChecker,
  farmStoreService.updateFarmProduct,
);

// Toggle farm product availability status
router.put(
  "/farm-products/:id/toggle-status",
  jwtChecker,
  farmStoreService.toggleFarmProductStatus,
);

// Delete farm product
router.delete(
  "/farm-products/:id",
  jwtChecker,
  farmStoreService.deleteFarmProduct,
);

module.exports = router;
