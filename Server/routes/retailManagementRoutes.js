const express = require("express");
const router = express.Router();

const retailService = require("../services/retailManagementServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");

// Retailer profile
router.post("/createretailers", jwtChecker, retailService.createRetailer);

// NEW: list all retailers (admin / authenticated)
router.get("/allretailers", jwtChecker, retailService.getAllRetailers);

router.get("/getretailers/:id", jwtChecker, retailService.getRetailerById);
router.get("/getretail/:id", jwtChecker, retailService.getRetailerByRetailId);
router.put("/updateretailers/:id", jwtChecker, retailService.updateRetailer);
router.get("/retailers/nearby", jwtChecker, retailService.getNearbyRetailers);

// NEW: all retailers with nested products
router.get(
  "/retailers-with-products",
  jwtChecker,
  retailService.getRetailersWithProducts
);

// Retailer products
router.post("/createproducts", jwtChecker, retailService.createProduct);

router.get(
  "/getproducts/retailer/:id",
  jwtChecker,
  retailService.getProductsByRetailer
);

router.put("/updateproducts/:id", jwtChecker, retailService.updateProduct);

router.post(
  "/products/:id/toggle-status",
  jwtChecker,
  retailService.toggleProductStatus,
);

router.delete(
  "/deleteproducts/:id",
  jwtChecker,
  adminChecker,
  retailService.deleteProduct
);

// NEW: Get store locations (retailer_id, shop_name, shop_address, business_type, latitude, longitude)
router.get("/store-locations", jwtChecker, retailService.getStoreLocations);

module.exports = router;
