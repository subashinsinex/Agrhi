const pool = require("../db/database");

// Get current app config (single row with id = 1)
exports.getAppConfig = async () => {
  const sql = `
    SELECT
      latest_build_number,
      latest_version,
      update_message,
      url,
      updated_at
    FROM app_config
    WHERE id = 1
  `;
  const result = await pool.query(sql);
  return result.rows[0];
};

// Update app config
exports.updateAppConfig = async (config) => {
  const { latest_build_number, latest_version, update_message, url } = config;

  const sql = `
    UPDATE app_config
    SET
      latest_build_number = COALESCE($1, latest_build_number),
      latest_version = COALESCE($2, latest_version),
      update_message = COALESCE($3, update_message),
      url = COALESCE($4, url),
      updated_at = CURRENT_TIMESTAMP
    WHERE id = 1
    RETURNING
      latest_build_number,
      latest_version,
      update_message,
      url,
      updated_at
  `;

  const values = [latest_build_number, latest_version, update_message, url];

  const result = await pool.query(sql, values);
  return result.rows[0];
};
