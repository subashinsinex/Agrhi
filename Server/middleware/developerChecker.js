const pool = require("../db/database");

const developerChecker = async (req, res, next) => {
  try {
    const user_id = req.user_id;
    const developerCheck = await pool.query(
      "SELECT category_id FROM user_details WHERE user_id = $1",
      [user_id]
    );
    if (developerCheck.rows.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }
    if (
      developerCheck.rows[0].category_id !==
      "4defeb52-8177-4fa4-afdd-1412e92d7a66"
    ) {
      return res
        .status(403)
        .json({ message: "Access denied, Developers only" });
    }
    next();
  } catch (error) {
    console.error("Error checking developer status:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

module.exports = developerChecker;
