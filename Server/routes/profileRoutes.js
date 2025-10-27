const express = require("express");
const router = express.Router();
const profileServices = require("../services/profileServices");
const jwtChecker = require("../middleware/jwtChecker");

router.get("/getUserDetails/:user_id", jwtChecker, async (req, res) => {
  try {
    const { user_id } = req.params; // ✅ Get user_id from URL
    const user = await profileServices.getUserById(user_id);

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(user);
  } catch (error) {
    console.error("Error fetching user details:", error);
    res.status(500).json({ message: "Error fetching user details" });
  }
});

router.post("/createUser", jwtChecker, async (req, res) => {
  try {
    const newUser = req.body; // ✅ user registration data
    const result = await profileServices.createUser(newUser); // ✅ call createUser

    res.status(201).json({
      message: "User registered successfully",
      user: result,
    });
  } catch (error) {
    console.error("Route createUser error:", error);
    res.status(500).json({ message: "Error creating user" });
  }
});

router.put("/updateUser/:userid", jwtChecker, async (req, res) => {
  try {
    const user_id = req.params.userid;
    const updatedUser = req.body;
    const result = await profileServices.updateUser(user_id, updatedUser);
    res.json(result);
  } catch (error) {
    console.error("Route putUser error:", error);
    res.status(500).json({ message: "Error updating user" });
  }
});

module.exports = router;
