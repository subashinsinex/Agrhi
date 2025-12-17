const express = require("express");
const router = express.Router();
const {
  getAppConfig,
  updateAppConfig,
} = require("../services/developerServices");
// const developerChecker = require("../middleware/developerChecker"); // if needed

// GET /developer/config
router.get("/config", async (req, res) => {
  try {
    const config = await getAppConfig();

    // Add derived flags required by app
    const response = {
      maintenance_mode: config.maintenance_mode,
      maintenance_message: config.maintenance_message,
      force_update:
        config.minimum_build_number !== null &&
        config.minimum_build_number > (req.body?.build_number || 0),
      update_available:
        config.latest_build_number !== null &&
        config.latest_build_number > (req.body?.build_number || 0),
      latest_version: config.latest_version,
      latest_build_number: config.latest_build_number,
      update_message: config.update_message,
      url: config.url,
    };

    res.json(response);
  } catch (error) {
    console.error("Error fetching app config:", error);
    res.status(500).json({ message: "Error fetching app config" });
  }
});

// PUT /developer/config
router.put(
  "/config",
  /* developerChecker, */ async (req, res) => {
    try {
      const {
        maintenance_mode,
        maintenance_message,
        minimum_build_number,
        latest_build_number,
        latest_version,
        update_message,
        url,
      } = req.body;

      const updated = await updateAppConfig({
        maintenance_mode,
        maintenance_message,
        minimum_build_number,
        latest_build_number,
        latest_version,
        update_message,
        url,
      });

      res.json(updated);
    } catch (error) {
      console.error("Error updating app config:", error);
      res.status(500).json({ message: "Error updating app config" });
    }
  }
);

module.exports = router;
