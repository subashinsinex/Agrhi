const express = require("express");
const router = express.Router();
const farmStoreService = require("../services/farmStoreServices");
const jwtChecker = require("../middleware/jwtChecker");
const logger = require("../utils/logger");

// Farmer shop location routes
router.post("/add-farmer-shop-places", jwtChecker, (req, res, next) => {
  
  farmStoreService.addFarmerShopPlace(req, res, next);
});

router.get("/farmer-shop-places/:farmerId", jwtChecker, (req, res, next) => {
  
  farmStoreService.getFarmerShopPlaces(req, res, next);
});

// Farm product routes (specific paths before :id)
router.post("/farm-products", jwtChecker, (req, res, next) => {
  
  farmStoreService.createFarmProduct(req, res, next);
});

router.get("/farm-products/nearby", jwtChecker, (req, res, next) => {
  
  farmStoreService.getNearbyFarmProducts(req, res, next);
});

router.get("/farm-products/farmer/:farmerId", jwtChecker, (req, res, next) => {
  
  farmStoreService.getFarmProductsByFarmer(req, res, next);
});

router.get("/farm-products", jwtChecker, (req, res, next) => {
  
  farmStoreService.getAllFarmProducts(req, res, next);
});

router.get("/farm-products/:id", jwtChecker, (req, res, next) => {
  
  farmStoreService.getFarmProductById(req, res, next);
});

router.put("/farm-products/:id", jwtChecker, (req, res, next) => {
  
  farmStoreService.updateFarmProduct(req, res, next);
});

router.put("/farm-products/:id/toggle-status", jwtChecker, (req, res, next) => {
  
  farmStoreService.toggleFarmProductStatus(req, res, next);
});

router.delete("/farm-products/:id", jwtChecker, (req, res, next) => {
  
  farmStoreService.deleteFarmProduct(req, res, next);
});

module.exports = router;
