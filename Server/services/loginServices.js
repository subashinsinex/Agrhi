const pool = require("../db/database");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const SECRET_KEY = process.env.SECRET_KEY;
const REFRESH_KEY = process.env.REFRESH_KEY;

async function login(phone_number, password, platform) {
  try {
    // Fetch user auth info using phone_number
    const userAuthQuery = await pool.query(
      "SELECT u.user_id, u.password FROM users_auth u WHERE u.phone_number = $1",
      [phone_number]
    );

    if (userAuthQuery.rows.length === 0) {
      return { success: false, message: "User not found" };
    }
    const userAuth = userAuthQuery.rows[0];
    console.log("Fetched User Auth:", userAuth);

    if (!(await bcrypt.compare(password, userAuth.password))) {
      return { success: false, message: "Invalid credentials" };
    }

    // Fetch category_id from user_details to verify admin role
    const userDetailsQuery = await pool.query(
      "SELECT category_id FROM user_details WHERE user_id = $1",
      [userAuth.user_id]
    );
    console.log(userDetailsQuery.rows);
    if (userDetailsQuery.rows.length === 0) {
      return { success: false, message: "User details not found" };
    }

    const category_id = userDetailsQuery.rows[0].category_id;

    // Only category_id = 3 is admin
    // if (category_id !== 3) {
    //   return { success: false, message: 'Access denied, admins only' };
    // }

    if (platform === "web" && category_id !== 3) {
      return {
        success: false,
        message: "Access denied: Admins can only login through web",
      };
    }

    // Generate JWT token with user_id as payload
    const access_token = jwt.sign({ user_id: userAuth.user_id }, SECRET_KEY, {
      expiresIn: "15m",
    });

    const refresh_token = jwt.sign({ user_id: userAuth.user_id }, REFRESH_KEY, {
      expiresIn: "7d",
    });

    return { success: true, access_token, refresh_token };
  } catch (error) {
    console.error("Login error:", error);
    return { success: false, message: "Error during login process" };
  }
}

async function refreshToken(req, res) {
  const { refresh_token } = req.body;
  if (!refresh_token)
    return res.status(401).json({ error: "No token provided" });

  try {
    // Verify the refresh token
    const decoded = jwt.verify(refresh_token, REFRESH_KEY);
    const user_id = decoded.user_id;

    // Check if the refresh token is valid for the user
    const user = await pool.query(
      "SELECT user_id FROM users_auth WHERE user_id = $1",
      [user_id]
    );

    if (user.rows.length === 0) {
      return res.status(403).json({ error: "Invalid refresh token" });
    }

    const access_token = jwt.sign({ user_id }, SECRET_KEY, {
      expiresIn: "15m",
    });
    res.status(200).json({ access_token: access_token });
    return { success: True };
  } catch (error) {
    console.error("Refresh token error:", error);
    return res.status(500).json({ error: "Internal server error" });
  }
}

module.exports = { login, refreshToken };
