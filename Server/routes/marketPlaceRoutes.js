const express = require("express");
const router = express.Router();

const marketService = require("../services/marketPlaceServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");

// Farmer listings (B2C)
router.post("/listings", jwtChecker, marketService.createListing);
router.get("/listings/:id", jwtChecker, marketService.getListingById);
router.get("/listings/farmer/:id", jwtChecker, marketService.getFarmerListings);
router.get("/listings/nearby", jwtChecker, marketService.getNearbyListings);
router.put("/listings/:id", jwtChecker, marketService.updateListing);
router.put("/listings/:id/isactive", jwtChecker, marketService.toggleListing);
router.delete(
  "/listings/:id",
  jwtChecker,
  adminChecker,
  marketService.deleteListing
);

module.exports = router;
