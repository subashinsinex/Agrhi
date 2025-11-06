const express = require("express");
const router = express.Router();
const userManageServices = require("../services/userManageServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");

// router.use(jwtChecker, adminChecker);

// Get all users
router.get("/getUser", jwtChecker, adminChecker, async (req, res) => {
  try {
    const users = await userManageServices.getUsers();
    res.json(users);
  } catch (error) {
    res.status(500).json({ message: "Error fetching users" });
  }
});

// Create new user
router.post("/postUser", jwtChecker, async (req, res) => {
  try {
    const newUser = req.body;
    const result = await userManageServices.postUser(newUser);
    res.status(201).json(result);
  } catch (error) {
    console.error("Route postUser error:", error);
    res.status(500).json({ message: "Error creating user" });
  }
});

// Update user
router.put("/putUser/:userid", jwtChecker, async (req, res) => {
  try {
    const user_id = req.params.userid;
    const updatedUser = req.body;
    const result = await userManageServices.putUser(user_id, updatedUser);
    res.json(result);
  } catch (error) {
    console.error("Route putUser error:", error);
    res.status(500).json({ message: "Error updating user" });
  }
});

// Delete user
router.delete(
  "/deleteUser/:userid",
  jwtChecker,
  adminChecker,
  async (req, res) => {
    try {
      const user_id = req.params.userid;
      const result = await userManageServices.deleteUser(user_id);
      res.json(result);
    } catch (error) {
      console.error("Route deleteUser error:", error);
      res.status(500).json({ message: "Error deleting user" });
    }
  }
);

router.get("/rtv", jwtChecker, async (req, res) => {
  try {
    const versions = await userManageServices.getReferenceTableVersions();
    res.json(versions);
  } catch (error) {
    console.error("Error fetching reference_table_versions:", error);
    res
      .status(500)
      .json({ message: "Error fetching reference table versions" });
  }
});
module.exports = router;
