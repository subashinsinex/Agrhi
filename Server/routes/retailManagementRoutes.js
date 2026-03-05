const express = require("express");
const router = express.Router();
const retailService = require("../services/retailManagementServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");
const logger = require("../utils/logger");

// ─── Retailer Routes ───────────────────────────────────────────────

// Farmer/user creates their own retailer profile
router.post("/createretailers", jwtChecker, (req, res, next) => {
  retailService.createRetailer(req, res, next);
});

// Admin creates retailer using phone number
router.post(
  "/createretailersadmin",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    retailService.createRetailerAdmin(req, res, next);
  },
);

router.get("/allretailers", jwtChecker, (req, res, next) => {
  retailService.getAllRetailers(req, res, next);
});

router.get("/getretailers/:id", jwtChecker, (req, res, next) => {
  retailService.getRetailerById(req, res, next);
});

// Get retailer by retail_id (separate from user id)
router.get("/getretail/:id", jwtChecker, (req, res, next) => {
  retailService.getRetailerByRetailId(req, res, next);
});

router.put("/updateretailers/:id", jwtChecker, (req, res, next) => {
  retailService.updateRetailer(req, res, next);
});

// Get nearby retailers based on location
router.get("/retailers/nearby", jwtChecker, (req, res, next) => {
  retailService.getNearbyRetailers(req, res, next);
});

// Get all retailers with their nested products
router.get("/retailers-with-products", jwtChecker, (req, res, next) => {
  retailService.getRetailersWithProducts(req, res, next);
});

// ─── Product Routes ────────────────────────────────────────────────

router.post("/createproducts", jwtChecker, (req, res, next) => {
  retailService.createProduct(req, res, next);
});

router.get("/getproducts/retailer/:id", jwtChecker, (req, res, next) => {
  retailService.getProductsByRetailer(req, res, next);
});

router.put("/updateproducts/:id", jwtChecker, (req, res, next) => {
  retailService.updateProduct(req, res, next);
});

router.post("/products/:id/toggle-status", jwtChecker, (req, res, next) => {
  retailService.toggleProductStatus(req, res, next);
});

// Only admin can delete products
router.delete(
  "/deleteproducts/:id",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    retailService.deleteProduct(req, res, next);
  },
);

// ─── Store Location Route ──────────────────────────────────────────

router.get("/store-locations", jwtChecker, (req, res, next) => {
  retailService.getStoreLocations(req, res, next);
});

module.exports = router;
