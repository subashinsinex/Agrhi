const express = require("express");
const router = express.Router();
const {
  getAppConfig,
  updateAppConfig,
} = require("../services/developerServices");

// POST /developer/config - Check if update needed
router.post("/config", async (req, res) => {
  try {
    const { build_number, platform, package_name } = req.body;

    const config = await getAppConfig();

    const currentBuild = parseInt(build_number) || 0;
    const latestBuild = parseInt(config.latest_build_number) || 0;

    // ✅ Simple check: if builds don't match = update needed
    const needsUpdate = currentBuild !== latestBuild;

    console.log("📱 App Version Check:", {
      package: package_name,
      current_build: currentBuild,
      latest_build: latestBuild,
      needs_update: needsUpdate,
      platform,
    });

    res.json({
      needs_update: needsUpdate,
      current_build_number: currentBuild,
      latest_build_number: latestBuild,
      latest_version: config.latest_version,
      update_message: config.update_message,
      store_url: config.url,
    });
  } catch (error) {
    console.error("❌ Error checking app version:", error);
    res.status(500).json({
      error: "Server error",
      needs_update: false,
    });
  }
});

// PUT /developer/config - Update configuration
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
    console.error("Error updating app config:", error);
    res.status(500).json({ message: "Error updating app config" });
  }
});

module.exports = router;
