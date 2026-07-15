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
      return res
        .status(401)
        .json({
          message: "Access denied, Invalid token or expired",
          success: false,
        });
    }

    req.user_id = decoded.user_id || decoded.id;
    console.log("✅ jwtChecker userId:", req.user_id);

    asyncLocalStorage.run({ userId: req.user_id }, () => {
      // Verify the store is accessible immediately inside run()
      const store = asyncLocalStorage.getStore();
      console.log("✅ ALS store inside run():", store);
      next();
    });
  });

};

module.exports = jwtChecker;
