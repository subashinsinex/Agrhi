const express = require("express");
const router = express.Router();
const {
  getAppConfig,
  updateAppConfig,
} = require("../services/developerServices");
const logger = require("../utils/logger");

// Check if app update is needed based on build number
router.post("/config", async (req, res) => {
  
  try {
    const { build_number, platform, package_name } = req.body;
    const config = await getAppConfig();
    const currentBuild = parseInt(build_number) || 0;
    const latestBuild = parseInt(config.latest_build_number) || 0;
    const needsUpdate = currentBuild !== latestBuild;

    res.json({
      needs_update: needsUpdate,
      current_build_number: currentBuild,
      latest_build_number: latestBuild,
      latest_version: config.latest_version,
      update_message: config.update_message,
      store_url: config.url,
    });
  } catch (error) {
    logger.error("POST /config - Error:", error);
    res.status(500).json({ error: "Server error", needs_update: false });
  }
});

// Update app config (version, build number, store URL)
router.put("/updateConfig", async (req, res) => {
  
  try {
    const { latest_build_number, latest_version, update_message, url } =
      req.body;
    const updated = await updateAppConfig({
      latest_build_number,
      latest_version,
      update_message,
      url,
    });
    res.json(updated);
  } catch (error) {
    logger.error("PUT /updateConfig - Error:", error);
    res.status(500).json({ message: "Error updating app config" });
  }
});

module.exports = router;
