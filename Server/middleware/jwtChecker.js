// Server/middleware/jwtChecker.js
const jwt = require("jsonwebtoken");
const { asyncLocalStorage } = require("../db/database");
const SECRET_KEY = process.env.SECRET_KEY;

const jwtChecker = (req, res, next) => {
  const authorizationHeader = req.headers["authorization"];

  if (!authorizationHeader) {
    return res.status(401).json({
      message: "Access denied, token missing",
      success: false,
    });
  }

  const token = authorizationHeader.split(" ")[1];

  if (!token) {
    return res.status(401).json({
      message: "Access denied, Invalid token format",
      success: false,
    });
  }

  jwt.verify(token, SECRET_KEY, (err, decoded) => {
    if (err) {
      return res.status(401).json({
        message: "Access denied, Invalid token or expired",
        success: false,
      });
    }

    // Set req.user_id (for backward compatibility)
    req.user_id = decoded.user_id || decoded.id;

    // ✅ Run the rest of the request in AsyncLocalStorage context
    // The database pool will automatically fetch the user's role from user_category
    asyncLocalStorage.run({ userId: req.user_id }, () => {
      next();
    });
  });
};

module.exports = jwtChecker;
