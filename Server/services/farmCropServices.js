// Farm crop services (farms, crops, master tables)
const pool = require("../db/database");
const { v4: uuidv4 } = require("uuid");
const logger = require("../utils/logger");

// Shared helper to update reference_table_versions timestamp
async function touchRefVersion(tableName) {
  await pool.query(
    "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = $1",
    [tableName],
  );
}

// Generate unique UUID for any table
async function generateUniqueId(client, tableName, idColumn) {
  logger.info("Generating unique ID", { tableName, idColumn });
  let id, exists;
  do {
    id = uuidv4();
    const check = await client.query(
      `SELECT 1 FROM ${tableName} WHERE ${idColumn} = $1`,
      [id],
    );
    exists = check.rowCount > 0;
  } while (exists);
  logger.info("Generated unique ID", { id, tableName });
  return id;
}

// ── FARMS ──────────────────────────────────────────────

// Get all farms with aggregated soil/irrigation/water data
exports.getAllFarms = async (req, res) => {
  logger.info("getAllFarms - Request");
  try {
    const sql = `
      SELECT
        f.farm_id,
        f.farm_size,
        f.survey_number,
        f.is_delete,
        ud.name AS owner_name,
        array_agg(DISTINCT s.name) FILTER (WHERE s.name IS NOT NULL) AS soil_types,
        array_agg(DISTINCT i.method_name) FILTER (WHERE i.method_name IS NOT NULL) AS irrigation_methods,
        array_agg(DISTINCT w.source) FILTER (WHERE w.source IS NOT NULL) AS water_sources
      FROM farms f
      LEFT JOIN farms_soil_types fs ON f.farm_id = fs.farm_id
      LEFT JOIN soil_types s ON fs.soil_type_id = s.soil_type_id
      LEFT JOIN farm_irrigation fi ON f.farm_id = fi.farm_id
      LEFT JOIN irrigation_method i ON fi.irrigation_id = i.irrigation_id
      LEFT JOIN farms_water_src fw ON f.farm_id = fw.farm_id
      LEFT JOIN water_src w ON fw.water_src_id = w.water_src_id
      LEFT JOIN user_details ud ON f.user_id = ud.user_id
      GROUP BY f.farm_id, f.farm_size, f.survey_number, ud.name
      ORDER BY f.farm_id
    `;
    const result = await pool.query(sql);
    logger.info("getAllFarms - Success", { count: result.rowCount });
    res.json(result.rows);
  } catch (error) {
    logger.error("getAllFarms - Error:", error);
    res.status(500).json({ message: "Error fetching farms", error });
  }
};

// Get farms by user ID (blocks consumer category)
exports.getFarmById = async (req, res) => {
  const { id } = req.params;
  logger.info("getFarmById - Request", { id });

  try {
    // Block consumer category from accessing farm details
    const consumerCheck = await pool.query(
      `SELECT 1 FROM user_details WHERE user_id = $1 AND category_id = 'a3e9a9b4-4c2d-4b1f-9b3b-23f5c4a7d901'`,
      [id],
    );
    if (consumerCheck.rowCount > 0) {
      logger.warn("getFarmById - Consumer access blocked", { id });
      return res
        .status(200)
        .json({ message: "Consumer Not Allowed to Access Farm Details" });
    }

    const sql = `
      SELECT
        f.farm_id,
        f.farm_size,
        f.survey_number,
        f.is_delete,
        array_agg(DISTINCT s.name) FILTER (WHERE s.name IS NOT NULL) AS soil_types,
        array_agg(DISTINCT i.method_name) FILTER (WHERE i.method_name IS NOT NULL) AS irrigation_methods,
        array_agg(DISTINCT w.source) FILTER (WHERE w.source IS NOT NULL) AS water_sources
      FROM farms f
      LEFT JOIN farms_soil_types fs ON f.farm_id = fs.farm_id
      LEFT JOIN soil_types s ON fs.soil_type_id = s.soil_type_id
      LEFT JOIN farm_irrigation fi ON f.farm_id = fi.farm_id
      LEFT JOIN irrigation_method i ON fi.irrigation_id = i.irrigation_id
      LEFT JOIN farms_water_src fw ON f.farm_id = fw.farm_id
      LEFT JOIN water_src w ON fw.water_src_id = w.water_src_id
      LEFT JOIN user_details ud ON f.user_id = ud.user_id
      WHERE f.user_id = $1 AND COALESCE(f.is_delete, false) = false
      GROUP BY f.farm_id
    `;
    const result = await pool.query(sql, [id]);

    if (result.rows.length > 0) {
      logger.info("getFarmById - Success", { id, count: result.rowCount });
      return res.json(result.rows);
    } else {
      logger.info("getFarmById - No farms Available", { id });
      return res.json({ message: "No farms Available" });
    }

  } catch (error) {
    logger.error("getFarmById - Error:", { id, error });
    return res.status(500).json({ message: "Error fetching farm", error });
  }
};

// Add farm by phone number lookup
exports.addFarm = async (req, res) => {
  const {
    phone_number,
    farm_size,
    survey_number,
    is_delete,
    soil_type_ids,
    irrigation_ids,
    water_src_ids,
  } = req.body;
  logger.info("addFarm - Request", { phone_number });

  try {
    await pool.query("BEGIN");

    // Resolve user_id from phone number
    const userRes = await pool.query(
      "SELECT user_id FROM users_auth WHERE phone_number = $1 LIMIT 1",
      [phone_number],
    );
    if (userRes.rowCount === 0) {
      throw new Error("Phone number not found. Invalid user.");
    }

    const user_id = userRes.rows[0].user_id;
    const farm_id = await generateUniqueId(pool, "farms", "farm_id");

    const farmResult = await pool.query(
      `INSERT INTO farms (user_id, farm_id, farm_size, survey_number, is_delete)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [user_id, farm_id, farm_size, survey_number, is_delete],
    );

    // Insert soil types
    if (Array.isArray(soil_type_ids)) {
      for (const soil_type_id of soil_type_ids) {
        await pool.query(
          `INSERT INTO farms_soil_types (farm_id, soil_type_id) VALUES ($1, $2)`,
          [farm_id, soil_type_id],
        );
      }
    }

    // Insert irrigations
    if (Array.isArray(irrigation_ids)) {
      for (const irrigation_id of irrigation_ids) {
        await pool.query(
          `INSERT INTO farm_irrigation (farm_id, irrigation_id) VALUES ($1, $2)`,
          [farm_id, irrigation_id],
        );
      }
    }

    // Insert water sources
    if (Array.isArray(water_src_ids)) {
      for (const water_src_id of water_src_ids) {
        await pool.query(
          `INSERT INTO farms_water_src (farm_id, water_src_id) VALUES ($1, $2)`,
          [farm_id, water_src_id],
        );
      }
    }

    await pool.query("COMMIT");
    logger.info("addFarm - Success", { farm_id, user_id });
    res.json({ message: "Farm added", farm: farmResult.rows[0] });
  } catch (error) {
    await pool.query("ROLLBACK");
    logger.error("addFarm - Error:", error);
    res.status(500).json({ message: "Error adding farm", error });
  }
};

// Add farm directly by user_id
exports.addFarmByUserId = async (req, res) => {
  const {
    user_id,
    farm_id,
    farm_size,
    survey_number,
    is_delete,
    soil_type_ids,
    irrigation_ids,
    water_src_ids,
  } = req.body;
  logger.info("addFarmByUserId - Request", { user_id });

  try {
    await pool.query("BEGIN");

    // Validate user exists
    const userRes = await pool.query(
      "SELECT user_id FROM users_auth WHERE user_id = $1 LIMIT 1",
      [user_id],
    );
    if (userRes.rowCount === 0) {
      throw new Error("Invalid user_id. User not found.");
    }

    const farmResult = await pool.query(
      `INSERT INTO farms (user_id, farm_id, farm_size, survey_number, is_delete)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [user_id, farm_id, farm_size, survey_number, is_delete],
    );

    // Insert soil types
    if (Array.isArray(soil_type_ids)) {
      for (const soil_type_id of soil_type_ids) {
        await pool.query(
          `INSERT INTO farms_soil_types (farm_id, soil_type_id) VALUES ($1, $2)`,
          [farm_id, soil_type_id],
        );
      }
    }

    // Insert irrigations
    if (Array.isArray(irrigation_ids)) {
      for (const irrigation_id of irrigation_ids) {
        await pool.query(
          `INSERT INTO farm_irrigation (farm_id, irrigation_id) VALUES ($1, $2)`,
          [farm_id, irrigation_id],
        );
      }
    }

    // Insert water sources
    if (Array.isArray(water_src_ids)) {
      for (const water_src_id of water_src_ids) {
        await pool.query(
          `INSERT INTO farms_water_src (farm_id, water_src_id) VALUES ($1, $2)`,
          [farm_id, water_src_id],
        );
      }
    }

    await pool.query("COMMIT");
    logger.info("addFarmByUserId - Success", { farm_id, user_id });
    res.json({ message: "Farm added", farm: farmResult.rows[0] });
  } catch (error) {
    await pool.query("ROLLBACK");
    logger.error("addFarmByUserId - Error:", error);
    res.status(500).json({ message: "Error adding farm", error });
  }
};

// Update farm fields and replace all relations
exports.updateFarm = async (req, res) => {
  const farm_id = req.params.id;
  const {
    farm_size,
    survey_number,
    is_delete,
    soil_type_ids,
    irrigation_ids,
    water_src_ids,
  } = req.body;
  logger.info("updateFarm - Request", { farm_id });

  try {
    await pool.query("BEGIN");

    await pool.query(
      `UPDATE farms SET farm_size = $2, survey_number = $3, is_delete = $4 WHERE farm_id = $1`,
      [farm_id, farm_size, survey_number, is_delete],
    );

    // Replace soil types
    await pool.query("DELETE FROM farms_soil_types WHERE farm_id = $1", [
      farm_id,
    ]);
    if (Array.isArray(soil_type_ids)) {
      for (const soil_type_id of soil_type_ids) {
        await pool.query(
          "INSERT INTO farms_soil_types (farm_id, soil_type_id) VALUES ($1, $2)",
          [farm_id, soil_type_id],
        );
      }
    }

    // Replace irrigations
    await pool.query("DELETE FROM farm_irrigation WHERE farm_id = $1", [
      farm_id,
    ]);
    if (Array.isArray(irrigation_ids)) {
      for (const irrigation_id of irrigation_ids) {
        await pool.query(
          "INSERT INTO farm_irrigation (farm_id, irrigation_id) VALUES ($1, $2)",
          [farm_id, irrigation_id],
        );
      }
    }

    // Replace water sources
    await pool.query("DELETE FROM farms_water_src WHERE farm_id = $1", [
      farm_id,
    ]);
    if (Array.isArray(water_src_ids)) {
      for (const water_src_id of water_src_ids) {
        await pool.query(
          "INSERT INTO farms_water_src (farm_id, water_src_id) VALUES ($1, $2)",
          [farm_id, water_src_id],
        );
      }
    }

    await pool.query("COMMIT");
    logger.info("updateFarm - Success", { farm_id });
    res.json({ message: "Farm updated successfully" });
  } catch (error) {
    await pool.query("ROLLBACK");
    logger.error("updateFarm - Error:", { farm_id, error });
    res.status(500).json({ message: "Error updating farm", error });
  }
};

// Soft delete farm by setting is_delete = true
exports.isdeleteFarm = async (req, res) => {
  const { id } = req.params;
  logger.info("isdeleteFarm - Request", { id });

  try {
    const result = await pool.query(
      `UPDATE farms SET is_delete = true WHERE farm_id = $1 RETURNING *`,
      [id],
    );
    if (result.rowCount === 0) {
      logger.warn("isdeleteFarm - Not found", { id });
      return res.status(404).json({ message: "Farm not found" });
    }
    logger.info("isdeleteFarm - Success", { id });
    res.json({ message: "Farm marked as deleted", farm: result.rows[0] });
  } catch (error) {
    logger.error("isdeleteFarm - Error:", { id, error });
    res.status(500).json({ message: "Error marking farm as deleted", error });
  }
};

// Hard delete farm (admin only)
exports.deleteFarm = async (req, res) => {
  const { id } = req.params;
  logger.info("deleteFarm - Request", { id });

  try {
    await pool.query("DELETE FROM farms WHERE farm_id=$1", [id]);
    logger.info("deleteFarm - Success", { id });
    res.json({ message: "Farm deleted" });
  } catch (error) {
    logger.error("deleteFarm - Error:", { id, error });
    res.status(500).json({ message: "Error deleting farm", error });
  }
};

// ── CROPS ──────────────────────────────────────────────

// Get all crops with full join data (admin)
exports.getAllCrops = async (req, res) => {
  logger.info("getAllCrops - Request");
  try {
    const sql = `
      SELECT 
        uc.farm_id, uc.user_crop_id, uc.is_delete,
        pl.plant_name, ct.name AS crop_type,
        uc.planting_date, uc.harvest_date,
        uc.field_size, uc.status, uc.is_active,
        f.survey_number, f.farm_size,
        ud.name AS farmer, pl.water_requirement
      FROM user_crops uc
      LEFT JOIN plants pl ON uc.plant_id = pl.plant_id
      LEFT JOIN crop_types ct ON pl.crop_type_id = ct.crop_type_id
      LEFT JOIN farms f ON uc.farm_id = f.farm_id
      LEFT JOIN user_details ud ON f.user_id = ud.user_id
      ORDER BY uc.user_crop_id
    `;
    const result = await pool.query(sql);
    logger.info("getAllCrops - Success", { count: result.rowCount });
    res.json(result.rows);
  } catch (error) {
    logger.error("getAllCrops - Error:", error);
    res.status(500).json({ message: "Error fetching crops", error });
  }
};

// Get active crops by farm ID
exports.getCropById = async (req, res) => {
  const { id } = req.params;
  logger.info("getCropById - Request", { id });

  try {
    const sql = `
      SELECT
        uc.user_crop_id, uc.is_delete,
        pl.plant_name, ct.name AS crop_type,
        uc.planting_date, uc.harvest_date,
        uc.field_size, uc.status, uc.is_active,
        f.survey_number, f.farm_size,
        ud.name AS farmer, pl.water_requirement
      FROM user_crops uc
      LEFT JOIN plants pl ON uc.plant_id = pl.plant_id
      LEFT JOIN crop_types ct ON pl.crop_type_id = ct.crop_type_id
      LEFT JOIN farms f ON uc.farm_id = f.farm_id
      LEFT JOIN user_details ud ON f.user_id = ud.user_id
      WHERE f.farm_id = $1 AND uc.is_delete = false AND uc.is_active = true
    `;
    const result = await pool.query(sql, [id]);
    logger.info("getCropById - Success", { id, count: result.rowCount });
    res.json(result.rows);
  } catch (error) {
    logger.error("getCropById - Error:", { id, error });
    res.status(500).json({ message: "Error fetching crop", error });
  }
};

// Get inactive crop history by farm ID
exports.getCropHistoryById = async (req, res) => {
  const { id } = req.params;
  logger.info("getCropHistoryById - Request", { id });

  try {
    const sql = `
      SELECT
        uc.user_crop_id, uc.is_delete,
        pl.plant_name, ct.name AS crop_type,
        uc.planting_date, uc.harvest_date,
        uc.field_size, uc.status, uc.is_active,
        f.survey_number, f.farm_size,
        ud.name AS farmer, pl.water_requirement
      FROM user_crops uc
      LEFT JOIN plants pl ON uc.plant_id = pl.plant_id
      LEFT JOIN crop_types ct ON pl.crop_type_id = ct.crop_type_id
      LEFT JOIN farms f ON uc.farm_id = f.farm_id
      LEFT JOIN user_details ud ON f.user_id = ud.user_id
      WHERE f.farm_id = $1 AND uc.is_delete = false AND uc.is_active = false
    `;
    const result = await pool.query(sql, [id]);
    logger.info("getCropHistoryById - Success", { id, count: result.rowCount });
    res.json(result.rows);
  } catch (error) {
    logger.error("getCropHistoryById - Error:", { id, error });
    res.status(500).json({ message: "Error fetching crop history", error });
  }
};

// Get aggregated soil/irrigation/water options for a farm
exports.getFarmCropOptions = async (req, res) => {
  const { id } = req.params;
  logger.info("getFarmCropOptions - Request", { id });

  try {
    const sql = `
      SELECT
        array_agg(DISTINCT st.soil_type_id) FILTER (WHERE st.soil_type_id IS NOT NULL) AS soil_type_ids,
        array_agg(DISTINCT st.name) FILTER (WHERE st.name IS NOT NULL) AS soil_type_names,
        array_agg(DISTINCT im.irrigation_id) FILTER (WHERE im.irrigation_id IS NOT NULL) AS irrigation_ids,
        array_agg(DISTINCT im.method_name) FILTER (WHERE im.method_name IS NOT NULL) AS irrigation_names,
        array_agg(DISTINCT ws.water_src_id) FILTER (WHERE ws.water_src_id IS NOT NULL) AS water_src_ids,
        array_agg(DISTINCT ws.source) FILTER (WHERE ws.source IS NOT NULL) AS water_src_names
      FROM farms f
      LEFT JOIN farms_soil_types fst ON f.farm_id = fst.farm_id
      LEFT JOIN soil_types st ON fst.soil_type_id = st.soil_type_id
      LEFT JOIN farm_irrigation fi ON f.farm_id = fi.farm_id
      LEFT JOIN irrigation_method im ON fi.irrigation_id = im.irrigation_id
      LEFT JOIN farms_water_src fws ON f.farm_id = fws.farm_id
      LEFT JOIN water_src ws ON fws.water_src_id = ws.water_src_id
      WHERE f.farm_id = $1
      GROUP BY f.farm_id
    `;
    const result = await pool.query(sql, [id]);
    logger.info("getFarmCropOptions - Success", { id });
    res.json(
      result.rows[0] || {
        soil_type_ids: [],
        soil_type_names: [],
        irrigation_ids: [],
        irrigation_names: [],
        water_src_ids: [],
        water_src_names: [],
      },
    );
  } catch (error) {
    logger.error("getFarmCropOptions - Error:", { id, error });
    res.status(500).json({ message: "Error fetching farm options", error });
  }
};

// Add or upsert crop record
exports.addCrop = async (req, res) => {
  const {
    user_crop_id,
    farm_id,
    plant_id,
    planting_date,
    harvest_date,
    field_size,
    status,
    is_active,
    is_delete,
  } = req.body;
  logger.info("addCrop - Request", { farm_id, plant_id });

  try {
    await pool.query("BEGIN");

    const cropId =
      user_crop_id ||
      (await generateUniqueId(pool, "user_crops", "user_crop_id"));

    const result = await pool.query(
      `INSERT INTO user_crops (
        user_crop_id, farm_id, plant_id, planting_date, harvest_date,
        field_size, status, is_active, is_delete
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
      ON CONFLICT (user_crop_id) DO UPDATE SET
        farm_id = EXCLUDED.farm_id,
        plant_id = EXCLUDED.plant_id,
        planting_date = EXCLUDED.planting_date,
        harvest_date = EXCLUDED.harvest_date,
        field_size = EXCLUDED.field_size,
        status = EXCLUDED.status,
        is_active = EXCLUDED.is_active,
        is_delete = EXCLUDED.is_delete
      RETURNING *`,
      [
        cropId,
        farm_id,
        plant_id,
        planting_date,
        harvest_date,
        field_size,
        status,
        is_active,
        is_delete,
      ],
    );

    await pool.query("COMMIT");
    logger.info("addCrop - Success", { cropId, farm_id });
    res.json({
      message: "Crop added",
      crop: result.rows[0],
      user_crop_id: cropId,
    });
  } catch (error) {
    await pool.query("ROLLBACK");
    logger.error("addCrop - Error:", error);
    res
      .status(500)
      .json({ message: "Error adding crop", error: error.message || error });
  }
};

// Update crop fields by user_crop_id
exports.updateCrop = async (req, res) => {
  const { id } = req.params;
  const {
    farm_id,
    plant_id,
    planting_date,
    harvest_date,
    field_size,
    status,
    is_active,
    is_delete,
  } = req.body;
  logger.info("updateCrop - Request", { id });

  try {
    await pool.query("BEGIN");

    const result = await pool.query(
      `UPDATE user_crops
       SET farm_id=$1, plant_id=$2, planting_date=$3, harvest_date=$4,
           field_size=$5, status=$6, is_active=$7, is_delete=$8
       WHERE user_crop_id=$9
       RETURNING *`,
      [
        farm_id,
        plant_id,
        planting_date,
        harvest_date,
        field_size,
        status,
        is_active,
        is_delete,
        id,
      ],
    );

    if (result.rowCount === 0) {
      throw new Error(`Crop with ID ${id} not found`);
    }

    await pool.query("COMMIT");
    logger.info("updateCrop - Success", { id });
    res.json({ message: "Crop updated", crop: result.rows[0] });
  } catch (error) {
    await pool.query("ROLLBACK");
    logger.error("updateCrop - Error:", { id, error });
    res
      .status(500)
      .json({ message: "Error updating crop", error: error.message || error });
  }
};

// Soft delete crop by setting is_delete = true
exports.isdeleteCrop = async (req, res) => {
  const { id } = req.params;
  logger.info("isdeleteCrop - Request", { id });

  try {
    const result = await pool.query(
      `UPDATE user_crops SET is_delete = true WHERE user_crop_id = $1 RETURNING *`,
      [id],
    );
    if (result.rowCount === 0) {
      logger.warn("isdeleteCrop - Not found", { id });
      return res.status(404).json({ message: "Crop not found" });
    }
    logger.info("isdeleteCrop - Success", { id });
    res.json({ message: "Crop marked as deleted", crop: result.rows[0] });
  } catch (error) {
    logger.error("isdeleteCrop - Error:", { id, error });
    res.status(500).json({ message: "Error marking crop as deleted", error });
  }
};

// Hard delete crop (admin only)
exports.deleteCrop = async (req, res) => {
  const { id } = req.params;
  logger.info("deleteCrop - Request", { id });

  try {
    await pool.query("DELETE FROM user_crops WHERE user_crop_id=$1", [id]);
    logger.info("deleteCrop - Success", { id });
    res.json({ message: "Crop deleted" });
  } catch (error) {
    logger.error("deleteCrop - Error:", { id, error });
    res.status(500).json({ message: "Error deleting crop", error });
  }
};

// ── MASTER TABLES ──────────────────────────────────────

exports.getSoilTypes = async (req, res) => {
  logger.info("getSoilTypes - Request");
  try {
    const result = await pool.query("SELECT * FROM soil_types ORDER BY name");
    logger.info("getSoilTypes - Success", { count: result.rowCount });
    res.json(result.rows);
  } catch (error) {
    logger.error("getSoilTypes - Error:", error);
    res.status(500).json({ message: "Error fetching soil types", error });
  }
};

exports.addSoilType = async (req, res) => {
  const { name } = req.body;
  logger.info("addSoilType - Request", { name });
  try {
    const soil_type_id = await generateUniqueId(
      pool,
      "soil_types",
      "soil_type_id",
    );
    const result = await pool.query(
      "INSERT INTO soil_types (soil_type_id, name) VALUES ($1, $2) RETURNING *",
      [soil_type_id, name],
    );
    if (result.rows.length > 0) await touchRefVersion("soil_types");
    logger.info("addSoilType - Success", { soil_type_id });
    res.json(result.rows[0]);
  } catch (error) {
    logger.error("addSoilType - Error:", error);
    res.status(500).json({ message: "Error adding soil type", error });
  }
};

exports.deleteSoilType = async (req, res) => {
  const { id } = req.params;
  logger.info("deleteSoilType - Request", { id });
  try {
    const result = await pool.query(
      "DELETE FROM soil_types WHERE soil_type_id=$1",
      [id],
    );
    if (result.rowCount > 0) await touchRefVersion("soil_types");
    logger.info("deleteSoilType - Success", { id });
    res.json({ message: "Soil type deleted" });
  } catch (error) {
    logger.error("deleteSoilType - Error:", { id, error });
    res.status(500).json({ message: "Error deleting soil type", error });
  }
};

exports.getIrrigations = async (req, res) => {
  logger.info("getIrrigations - Request");
  try {
    const result = await pool.query(
      "SELECT * FROM irrigation_method ORDER BY method_name",
    );
    logger.info("getIrrigations - Success", { count: result.rowCount });
    res.json(result.rows);
  } catch (error) {
    logger.error("getIrrigations - Error:", error);
    res
      .status(500)
      .json({ message: "Error fetching irrigation methods", error });
  }
};

exports.addIrrigation = async (req, res) => {
  const { method_name } = req.body;
  logger.info("addIrrigation - Request", { method_name });
  try {
    const irrigation_id = await generateUniqueId(
      pool,
      "irrigation_method",
      "irrigation_id",
    );
    const result = await pool.query(
      "INSERT INTO irrigation_method (irrigation_id, method_name) VALUES ($1, $2) RETURNING *",
      [irrigation_id, method_name],
    );
    if (result.rows.length > 0) await touchRefVersion("irrigation_method");
    logger.info("addIrrigation - Success", { irrigation_id });
    res.json(result.rows[0]);
  } catch (error) {
    logger.error("addIrrigation - Error:", error);
    res.status(500).json({ message: "Error adding irrigation method", error });
  }
};

exports.deleteIrrigation = async (req, res) => {
  const { id } = req.params;
  logger.info("deleteIrrigation - Request", { id });
  try {
    const result = await pool.query(
      "DELETE FROM irrigation_method WHERE irrigation_id=$1",
      [id],
    );
    if (result.rowCount > 0) await touchRefVersion("irrigation_method");
    logger.info("deleteIrrigation - Success", { id });
    res.json({ message: "Irrigation method deleted" });
  } catch (error) {
    logger.error("deleteIrrigation - Error:", { id, error });
    res.status(500).json({ message: "Error deleting irrigation", error });
  }
};

exports.getWaterSources = async (req, res) => {
  logger.info("getWaterSources - Request");
  try {
    const result = await pool.query("SELECT * FROM water_src ORDER BY source");
    logger.info("getWaterSources - Success", { count: result.rowCount });
    res.json(result.rows);
  } catch (error) {
    logger.error("getWaterSources - Error:", error);
    res.status(500).json({ message: "Error fetching water sources", error });
  }
};

exports.addWaterSource = async (req, res) => {
  const { source } = req.body;
  logger.info("addWaterSource - Request", { source });
  try {
    const water_src_id = await generateUniqueId(
      pool,
      "water_src",
      "water_src_id",
    );
    const result = await pool.query(
      "INSERT INTO water_src (water_src_id, source) VALUES ($1, $2) RETURNING *",
      [water_src_id, source],
    );
    if (result.rows.length > 0) await touchRefVersion("water_src");
    logger.info("addWaterSource - Success", { water_src_id });
    res.json(result.rows[0]);
  } catch (error) {
    logger.error("addWaterSource - Error:", error);
    res.status(500).json({ message: "Error adding water source", error });
  }
};

exports.deleteWaterSource = async (req, res) => {
  const { id } = req.params;
  logger.info("deleteWaterSource - Request", { id });
  try {
    const result = await pool.query(
      "DELETE FROM water_src WHERE water_src_id=$1",
      [id],
    );
    if (result.rowCount > 0) await touchRefVersion("water_src");
    logger.info("deleteWaterSource - Success", { id });
    res.json({ message: "Water source deleted" });
  } catch (error) {
    logger.error("deleteWaterSource - Error:", { id, error });
    res.status(500).json({ message: "Error deleting water source", error });
  }
};

exports.getCropTypes = async (req, res) => {
  logger.info("getCropTypes - Request");
  try {
    const result = await pool.query("SELECT * FROM crop_types ORDER BY name");
    logger.info("getCropTypes - Success", { count: result.rowCount });
    res.json(result.rows);
  } catch (error) {
    logger.error("getCropTypes - Error:", error);
    res.status(500).json({ message: "Error fetching crop types", error });
  }
};

exports.addCropType = async (req, res) => {
  const { name } = req.body;
  logger.info("addCropType - Request", { name });
  try {
    const crop_type_id = await generateUniqueId(
      pool,
      "crop_types",
      "crop_type_id",
    );
    const result = await pool.query(
      "INSERT INTO crop_types (crop_type_id, name) VALUES ($1, $2) RETURNING *",
      [crop_type_id, name],
    );
    if (result.rows.length > 0) await touchRefVersion("crop_types");
    logger.info("addCropType - Success", { crop_type_id });
    res.json(result.rows[0]);
  } catch (error) {
    logger.error("addCropType - Error:", error);
    res.status(500).json({ message: "Error adding crop type", error });
  }
};

exports.deleteCropType = async (req, res) => {
  const { id } = req.params;
  logger.info("deleteCropType - Request", { id });
  try {
    const result = await pool.query(
      "DELETE FROM crop_types WHERE crop_type_id=$1",
      [id],
    );
    if (result.rowCount > 0) await touchRefVersion("crop_types");
    logger.info("deleteCropType - Success", { id });
    res.json({ message: "Crop type deleted" });
  } catch (error) {
    logger.error("deleteCropType - Error:", { id, error });
    res.status(500).json({ message: "Error deleting crop type", error });
  }
};

exports.getPlants = async (req, res) => {
  logger.info("getPlants - Request");
  try {
    const result = await pool.query(`
      SELECT pl.*, ct.name as crop_type
      FROM plants pl
      LEFT JOIN crop_types ct ON pl.crop_type_id = ct.crop_type_id
      ORDER BY plant_name
    `);
    logger.info("getPlants - Success", { count: result.rowCount });
    res.json(result.rows);
  } catch (error) {
    logger.error("getPlants - Error:", error);
    res.status(500).json({ message: "Error fetching plants", error });
  }
};

exports.addPlant = async (req, res) => {
  const { plant_name, crop_type_id, water_requirement } = req.body;
  logger.info("addPlant - Request", { plant_name });
  try {
    const plant_id = await generateUniqueId(pool, "plants", "plant_id");
    const result = await pool.query(
      "INSERT INTO plants (plant_id, plant_name, crop_type_id, water_requirement) VALUES ($1, $2, $3, $4) RETURNING *",
      [plant_id, plant_name, crop_type_id, water_requirement],
    );
    if (result.rows.length > 0) await touchRefVersion("plants");
    logger.info("addPlant - Success", { plant_id });
    res.json(result.rows[0]);
  } catch (error) {
    logger.error("addPlant - Error:", error);
    res.status(500).json({ message: "Error adding plant", error });
  }
};

exports.deletePlant = async (req, res) => {
  const { id } = req.params;
  logger.info("deletePlant - Request", { id });
  try {
    const result = await pool.query("DELETE FROM plants WHERE plant_id=$1", [
      id,
    ]);
    if (result.rowCount > 0) await touchRefVersion("plants");
    logger.info("deletePlant - Success", { id });
    res.json({ message: "Plant deleted" });
  } catch (error) {
    logger.error("deletePlant - Error:", { id, error });
    res.status(500).json({ message: "Error deleting plant", error });
  }
};
