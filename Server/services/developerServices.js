const pool = require("../db/database");

// Get current app config (single row with id = 1)
exports.getAppConfig = async () => {
  const sql = `
    SELECT
      maintenance_mode,
      maintenance_message,
      minimum_build_number,
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

// Update app config (force_update / update_available are handled in API layer)
exports.updateAppConfig = async (config) => {
  const {
    maintenance_mode,
    maintenance_message,
    minimum_build_number,
    latest_build_number,
    latest_version,
    update_message,
    url,
  } = config;

  const sql = `
    UPDATE app_config
    SET
      maintenance_mode = COALESCE($1, maintenance_mode),
      maintenance_message = COALESCE($2, maintenance_message),
      minimum_build_number = COALESCE($3, minimum_build_number),
      latest_build_number = COALESCE($4, latest_build_number),
      latest_version = COALESCE($5, latest_version),
      update_message = COALESCE($6, update_message),
      url = COALESCE($7, url),
      updated_at = CURRENT_TIMESTAMP
    WHERE id = 1
    RETURNING
      maintenance_mode,
      maintenance_message,
      minimum_build_number,
      latest_build_number,
      latest_version,
      update_message,
      url,
      updated_at
  `;

  const values = [
    maintenance_mode,
    maintenance_message,
    minimum_build_number,
    latest_build_number,
    latest_version,
    update_message,
    url,
  ];

  const result = await pool.query(sql, values);
  return result.rows[0];
};
