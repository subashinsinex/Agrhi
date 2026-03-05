const express = require("express");
const router = express.Router();
const retailService = require("../services/retailManagementServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");
const logger = require("../utils/logger");

// Retailer CRUD routes
router.post("/createretailers", jwtChecker, (req, res, next) => {
  
  retailService.createRetailer(req, res, next);
});

router.get("/allretailers", jwtChecker, (req, res, next) => {
  
  retailService.getAllRetailers(req, res, next);
});

router.get("/getretailers/:id", jwtChecker, (req, res, next) => {
  
  retailService.getRetailerById(req, res, next);
});

router.get("/getretail/:id", jwtChecker, (req, res, next) => {
  
  retailService.getRetailerByRetailId(req, res, next);
});

router.put("/updateretailers/:id", jwtChecker, (req, res, next) => {
  
  retailService.updateRetailer(req, res, next);
});

router.get("/retailers/nearby", jwtChecker, (req, res, next) => {
  
  retailService.getNearbyRetailers(req, res, next);
});

router.get("/retailers-with-products", jwtChecker, (req, res, next) => {
  
  retailService.getRetailersWithProducts(req, res, next);
});

// Product CRUD routes
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

router.delete(
  "/deleteproducts/:id",
  jwtChecker,
  adminChecker,
  (req, res, next) => {
    
    retailService.deleteProduct(req, res, next);
  },
);

// Store location route
router.get("/store-locations", jwtChecker, (req, res, next) => {
  
  retailService.getStoreLocations(req, res, next);
});

module.exports = router;
