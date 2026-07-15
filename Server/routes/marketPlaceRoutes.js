const express = require("express");
const router = express.Router();
const marketplaceService = require("../services/marketPlaceServices");
const jwtChecker = require("../middleware/jwtChecker");
const logger = require("../utils/logger");

// Get all marketplace products (farm + retail) by location
router.get("/products", jwtChecker, (req, res, next) => {
  
  marketplaceService.getMarketplaceProducts(req, res, next);
});

// Get single product details by ID
router.get("/products/:productId", jwtChecker, (req, res, next) => {
  
  marketplaceService.getProductDetails(req, res, next);
});

// Get marketplace stats by location
router.get("/stats", jwtChecker, (req, res, next) => {
  
  marketplaceService.getMarketplaceStats(req, res, next);
});

// Search nearby sellers (farmers and retailers)
router.get("/sellers", jwtChecker, (req, res, next) => {
  
  marketplaceService.searchSellers(req, res, next);
});

module.exports = router;
