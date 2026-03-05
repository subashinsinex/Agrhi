const pool = require("../db/database");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const logger = require("../utils/logger");

const SECRET_KEY = process.env.SECRET_KEY;
const REFRESH_KEY = process.env.REFRESH_KEY;

// Authenticate user and return JWT tokens
async function login(phone_number, password, platform) {
  logger.info("Login attempt", { phone_number, platform });

  try {
    // Fetch user by phone number
    const userAuthQuery = await pool.query(
      "SELECT u.user_id, u.password FROM users_auth u WHERE u.phone_number = $1",
      [phone_number],
    );

    if (userAuthQuery.rows.length === 0) {
      logger.error("Login failed - User not found", { phone_number });
      return { success: false, message: "User not found" };
    }

    const userAuth = userAuthQuery.rows[0];

    // Validate password
    if (!(await bcrypt.compare(password, userAuth.password))) {
      logger.error("Login failed - Invalid password", { phone_number });
      return { success: false, message: "Invalid password" };
    }

    // Fetch user category for role check
    const userDetailsQuery = await pool.query(
      "SELECT category_id FROM user_details WHERE user_id = $1",
      [userAuth.user_id],
    );

    if (userDetailsQuery.rows.length === 0) {
      logger.error("Login failed - User details not found", {
        user_id: userAuth.user_id,
      });
      return { success: false, message: "User details not found" };
    }

    const category_id = userDetailsQuery.rows[0].category_id;

    // Restrict web login to admin category only
    if (
      platform === "web" &&
      category_id !== "4bf987aa-5067-4f07-a827-9c685e1fd1c1"
    ) {
      logger.error("Login failed - Non-admin web login attempt", {
        phone_number,
        category_id,
        platform,
      });
      return {
        success: false,
        message: "Access denied: Admins can only login through web",
      };
    }

    // Generate access and refresh tokens
    const access_token = jwt.sign({ user_id: userAuth.user_id }, SECRET_KEY, {
      expiresIn: "60m",
    });

    const refresh_token = jwt.sign({ user_id: userAuth.user_id }, REFRESH_KEY, {
      expiresIn: "7d",
    });

    logger.info("Login successful", {
      user_id: userAuth.user_id,
      platform,
    });

    return { success: true, access_token, refresh_token };
  } catch (error) {
    logger.error("Login error:", error);
    return { success: false, message: "Error during login process" };
  }
}

// Issue new access token using valid refresh token
async function refreshToken(req, res) {
  const { refresh_token } = req.body;
  logger.info("Token refresh attempt");

  if (!refresh_token) {
    logger.error("Token refresh - No token provided");
    return res.status(401).json({ error: "No token provided" });
  }

  try {
    // Verify refresh token signature
    const decoded = jwt.verify(refresh_token, REFRESH_KEY);
    const user_id = decoded.user_id;

    logger.info("Token refresh - Decoded user", { user_id });

    // Validate user still exists
    const user = await pool.query(
      "SELECT user_id FROM users_auth WHERE user_id = $1",
      [user_id],
    );

    if (user.rows.length === 0) {
      logger.error("Token refresh - User not found", { user_id });
      return res.status(403).json({ error: "Invalid refresh token" });
    }

    // Issue new access token
    const access_token = jwt.sign({ user_id }, SECRET_KEY, {
      expiresIn: "60m",
    });

    logger.info("Token refresh - New access token issued", { user_id });
    return res.status(200).json({ access_token });
  } catch (error) {
    logger.error("Token refresh error:", error);
    return res.status(500).json({ error: "Internal server error" });
  }
}

module.exports = { login, refreshToken };
