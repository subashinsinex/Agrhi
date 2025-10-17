const express = require("express");
const router = express.Router();
const subsidiesServices = require("../services/subsidiesServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");

// Get all subsidies
router.get("/getSubsidy", async (req, res) => {
  try {
    const subsidies = await subsidiesServices.getSubsidies();
    res.json(subsidies);
  } catch (error) {
    console.error("Route getSubsidy error:", error);
    res.status(500).json({ message: "Error fetching subsidies" });
  }
});

// Create new subsidy
router.post("/postSubsidy", jwtChecker, adminChecker, async (req, res) => {
  try {
    const newSubsidy = req.body;
    const result = await subsidiesServices.postSubsidy(newSubsidy);
    res.status(201).json(result);
  } catch (error) {
    console.error("Route postSubsidy error:", error);
    res.status(500).json({ message: "Error creating subsidy" });
  }
});

// Update subsidy
router.put(
  "/putSubsidy/:subsidyid",
  jwtChecker,
  adminChecker,
  async (req, res) => {
    try {
      const subsidy_id = req.params.subsidyid;
      const updatedSubsidy = req.body;
      const result = await subsidiesServices.putSubsidy(
        subsidy_id,
        updatedSubsidy
      );
      res.json(result);
    } catch (error) {
      console.error("Route putSubsidy error:", error);
      res.status(500).json({ message: "Error updating subsidy" });
    }
  }
);

// Delete subsidy
router.delete("/deleteSubsidy/:subsidyid", async (req, res) => {
  try {
    const subsidy_id = req.params.subsidyid;
    const result = await subsidiesServices.deleteSubsidy(subsidy_id);
    res.json(result);
  } catch (error) {
    console.error("Route deleteSubsidy error:", error);
    res.status(500).json({ message: "Error deleting subsidy" });
  }
});

module.exports = router;
