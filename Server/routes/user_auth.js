const express = require("express");
const pool = require("../utils/db");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const router = express.Router();
const SECRET_KEY = process.env.SECRET_KEY;
const REFRESH_SECRET = process.env.REFRESH_SECRET;

// User Login (Checks is_active before login)
router.post("/login", async (req, res) => {
  const { phone_number, password, platform } = req.body;
  console.log("Login attempt:", phone_number, "from", platform);
  if (!phone_number || !password || !platform)
    return res
      .status(400)
      .json({ error: "Missing phone number, password or platform" });

  try {
    const result = await pool.query(
      `SELECT user_id, password, phone_number, email, is_admin 
       FROM user_auth where phone_number = $1`,
      [phone_number]
    );

    if (result.rows.length === 0)
      return res.status(401).json({ error: "Invalid phone_number" });

    const user = result.rows[0];

    if (String(password) !== String(user.password)) {
      return res.status(401).json({ error: "Invalid password" });
}

    // const isPasswordValid = await bcrypt.compare(password, user.password);
    // if (!isPasswordValid)
    //   return res.status(401).json({ error: "Invalid password" });

    // Restrict web login to admins only
    if (platform === "web" && user.is_admin !== true) {
      return res.status(403).json({ error: "Only admins can log in from web" });
    }

    // Generate JWT tokens
    const accessToken = jwt.sign({ userId: user.user_id }, SECRET_KEY, {
      expiresIn: "15m",
    });
    const refreshToken = jwt.sign({ userId: user.user_id }, REFRESH_SECRET, {
      expiresIn: "14d",
    });
    console.log("User logged in:", user.user_id);
    res.json({ accessToken, refreshToken });
  } catch (error) {
    console.error("Login error:", error);
    res.status(500).json({ error: "Database error", details: error.message });
  }
});

// Refresh Token
router.post("/refresh", async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken)
    return res.status(401).json({ error: "No token provided" });

  try {
    const decoded = jwt.verify(refreshToken, REFRESH_SECRET);
    const userId = decoded.userId;

    // Check if the refresh token is valid for the user
    const user = await pool.query(
      "SELECT user_id FROM user_auth WHERE user_id = $1",
      [userId]
    );

    if (user.rows.length === 0) {
      return res.status(403).json({ error: "Invalid refresh token" });
    }

    const accessToken = jwt.sign({ userId }, SECRET_KEY, {
      expiresIn: "15m",
    });

    res.json({ accessToken });
  } catch (err) {
    console.error("Token refresh error:", err);
    res.status(403).json({ error: "Invalid or expired refresh token" });
  }
});

// User Logout (Update logout time)
router.post("/logout", async (req, res) => {
  const token = req.header("Authorization")?.split(" ")[1];
  if (!token) return res.status(401).json({ error: "No token provided" });

  try {
    res.json({ success: true });
  } catch (error) {
    console.error("Logout error:", error);
    res.status(403).json({ error: "Invalid token" });
  }
});

module.exports = router;
