const express = require("express");
const router = express.Router();

const marketplaceService = require("../services/marketPlaceServices");
const jwtChecker = require("../middleware/jwtChecker");

// Get unified marketplace products (farm + retail)
router.get("/products", jwtChecker, marketplaceService.getMarketplaceProducts);

// Get single product details
router.get(
  "/products/:productId",
  jwtChecker,
  marketplaceService.getProductDetails,
);

// Get marketplace statistics
router.get("/stats", jwtChecker, marketplaceService.getMarketplaceStats);

// Search sellers (farmers and retailers)
router.get("/sellers", jwtChecker, marketplaceService.searchSellers);

module.exports = router;
