const express = require("express");
const router = express.Router();

const marketService = require("../services/marketPlaceServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");

// Farmer listings (B2C)
router.post("/createlistings", jwtChecker, marketService.createListing);

router.get("/getlistings/:id", jwtChecker, marketService.getListingById);

router.get(
  "/getlistings/farmer/:id",
  jwtChecker,
  marketService.getFarmerListings
);

router.get("/alllistings", jwtChecker, marketService.getAllListings);

router.get("/listings/nearby", jwtChecker, marketService.getNearbyListings);

router.put("/updatelistings/:id", jwtChecker, marketService.updateListing);

router.put(
  "/togglelistings/:id/isactive",
  jwtChecker,
  marketService.toggleListing
);

router.delete(
  "/deletelistings/:id",
  jwtChecker,
  adminChecker,
  marketService.deleteListing
);

// Reference data
router.get("/farmers", jwtChecker, marketService.getFarmers);
router.get("/croptypes", jwtChecker, marketService.getCropTypes);
router.get("/plants", jwtChecker, marketService.getPlants);

module.exports = router;
