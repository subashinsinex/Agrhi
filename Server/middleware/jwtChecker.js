const jwt = require("jsonwebtoken");
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

    // Set req.user_id
    req.user_id = decoded.user_id || decoded.id;

    next();
  });
};

module.exports = jwtChecker;
