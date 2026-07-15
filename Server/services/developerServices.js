// Developer app config services
const pool = require("../db/database");
const logger = require("../utils/logger");

// Get current app config (single row id = 1)
exports.getAppConfig = async () => {
  logger.info("getAppConfig - Request");
  try {
    const result = await pool.query(`
      SELECT latest_build_number, latest_version, update_message, url, updated_at
      FROM app_config WHERE id = 1
    `);
    logger.info("getAppConfig - Success", {
      latest_build_number: result.rows[0]?.latest_build_number,
    });
    return result.rows[0];
  } catch (error) {
    logger.error("getAppConfig - Error:", error);
    throw error;
  }
};

// Update app config fields (COALESCE preserves existing values)
exports.updateAppConfig = async (config) => {
  const { latest_build_number, latest_version, update_message, url } = config;
  logger.info("updateAppConfig - Request", {
    latest_build_number,
    latest_version,
  });

  try {
    const result = await pool.query(
      `UPDATE app_config
       SET
         latest_build_number = COALESCE($1, latest_build_number),
         latest_version = COALESCE($2, latest_version),
         update_message = COALESCE($3, update_message),
         url = COALESCE($4, url),
         updated_at = CURRENT_TIMESTAMP
       WHERE id = 1
       RETURNING latest_build_number, latest_version, update_message, url, updated_at`,
      [latest_build_number, latest_version, update_message, url],
    );
    logger.info("updateAppConfig - Success", {
      latest_build_number,
      latest_version,
    });
    return result.rows[0];
  } catch (error) {
    logger.error("updateAppConfig - Error:", error);
    throw error;
  }
};
