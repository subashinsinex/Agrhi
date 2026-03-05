const express = require("express");
const router = express.Router();
const userManageServices = require("../services/userManageServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");
const logger = require("../utils/logger");

// Get all users (admin only)
router.get("/getUser", jwtChecker, adminChecker, async (req, res) => {
  
  try {
    const users = await userManageServices.getUsers();
    res.json(users);
  } catch (error) {
    logger.error("GET /getUser - Error:", error);
    res.status(500).json({ message: "Error fetching users" });
  }
});

// Create new user
router.post("/postUser", jwtChecker, async (req, res) => {
  
  try {
    const result = await userManageServices.postUser(req.body);
    res.status(201).json(result);
  } catch (error) {
    logger.error("POST /postUser - Error:", error);
    res.status(500).json({ message: "Error creating user" });
  }
});

// Update user
router.put("/putUser/:userid", jwtChecker, async (req, res) => {
  
  try {
    const result = await userManageServices.putUser(
      req.params.userid,
      req.body,
    );
    res.json(result);
  } catch (error) {
    logger.error("PUT /putUser - Error:", {
      user_id: req.params.userid,
      error,
    });
    res.status(500).json({ message: "Error updating user" });
  }
});

// Delete user (admin only)
router.delete(
  "/deleteUser/:userid",
  jwtChecker,
  adminChecker,
  async (req, res) => {
    
    try {
      const result = await userManageServices.deleteUser(req.params.userid);
      res.json(result);
    } catch (error) {
      logger.error("DELETE /deleteUser - Error:", {
        user_id: req.params.userid,
        error,
      });
      res.status(500).json({ message: "Error deleting user" });
    }
  },
);

// Get reference table versions
router.get("/rtv", jwtChecker, async (req, res) => {
  
  try {
    const versions = await userManageServices.getReferenceTableVersions();
    res.json(versions);
  } catch (error) {
    logger.error("GET /rtv - Error:", error);
    res
      .status(500)
      .json({ message: "Error fetching reference table versions" });
  }
});

module.exports = router;
