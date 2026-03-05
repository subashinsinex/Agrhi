const express = require("express");
const router = express.Router();
const subsidiesServices = require("../services/subsidiesServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");
const logger = require("../utils/logger");

// Get all subsidies
router.get("/getSubsidy", jwtChecker, async (req, res) => {
  
  try {
    const subsidies = await subsidiesServices.getSubsidies();
    res.json(subsidies);
  } catch (error) {
    logger.error("GET /getSubsidy - Error:", error);
    res.status(500).json({ message: "Error fetching subsidies" });
  }
});

// Create new subsidy (admin only)
router.post("/postSubsidy", jwtChecker, adminChecker, async (req, res) => {
  
  try {
    const result = await subsidiesServices.postSubsidy(req.body);
    res.status(201).json(result);
  } catch (error) {
    logger.error("POST /postSubsidy - Error:", error);
    res.status(500).json({ message: "Error creating subsidy" });
  }
});

// Update existing subsidy (admin only)
router.put(
  "/putSubsidy/:subsidyid",
  jwtChecker,
  adminChecker,
  async (req, res) => {
    
    try {
      const result = await subsidiesServices.putSubsidy(
        req.params.subsidyid,
        req.body,
      );
      res.json(result);
    } catch (error) {
      logger.error("PUT /putSubsidy - Error:", {
        subsidy_id: req.params.subsidyid,
        error,
      });
      res.status(500).json({ message: "Error updating subsidy" });
    }
  },
);

// Delete subsidy (admin only)
router.delete(
  "/deleteSubsidy/:subsidyid",
  jwtChecker,
  adminChecker,
  async (req, res) => {
    
    try {
      const result = await subsidiesServices.deleteSubsidy(
        req.params.subsidyid,
      );
      res.json(result);
    } catch (error) {
      logger.error("DELETE /deleteSubsidy - Error:", {
        subsidy_id: req.params.subsidyid,
        error,
      });
      res.status(500).json({ message: "Error deleting subsidy" });
    }
  },
);

// Get state names for dropdowns (public)
router.get("/states", async (req, res) => {
  
  try {
    const states = await subsidiesServices.getStateNames();
    res.json(states);
  } catch (error) {
    logger.error("GET /states - Error:", error);
    res.status(500).json({ message: "Error fetching states" });
  }
});

module.exports = router;
