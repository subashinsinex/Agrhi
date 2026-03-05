const logger = require("../utils/logger");

module.exports = (req, res, next) => {
  const startTime = Date.now();

  res.on("finish", () => {
    const duration = Date.now() - startTime;

    logger.http({
      method: req.method,
      endpoint: req.originalUrl,
      user_id: req.user_id,
      ip: req.clientIp || req.ip || "unknown",
      user_agent: req.headers["user-agent"] || "unknown",
      status_code: res.statusCode,
      duration_ms: duration,
    });
  });

  next();
};
