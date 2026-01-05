const express = require("express");
const router = express.Router();

const retailService = require("../services/retailManagementServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");

// Retailer profile
router.post("/retailers", jwtChecker, retailService.createRetailer);
router.get("/retailers/:id", jwtChecker, retailService.getRetailerById);
router.put("/retailers/:id", jwtChecker, retailService.updateRetailer);
router.get("/retailers/nearby", jwtChecker, retailService.getNearbyRetailers);

// Retailer products
router.post("/products", jwtChecker, retailService.createProduct);
router.get(
  "/products/retailer/:id",
  jwtChecker,
  retailService.getProductsByRetailer
);
router.put("/products/:id", jwtChecker, retailService.updateProduct);
router.put("/products/:id/isactive", jwtChecker, retailService.toggleProduct);
router.delete(
  "/products/:id",
  jwtChecker,
  adminChecker,
  retailService.deleteProduct
);

module.exports = router;
