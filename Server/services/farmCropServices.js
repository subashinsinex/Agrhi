const pool = require("../db/database");
const { v4: uuidv4 } = require("uuid");

async function generateUniqueId(client, tableName, idColumn) {
  let id, exists;
  do {
    id = uuidv4();
    const check = await client.query(
      `SELECT 1 FROM ${tableName} WHERE ${idColumn} = $1`,
      [id]
    );
    exists = check.rowCount > 0;
  } while (exists);
  return id;
}

exports.getAllFarms = async (req, res) => {
  try {
    const sql = `
      SELECT
        f.farm_id,
        f.farm_size,
        f.survey_number,
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
      ORDER BY f.farm_id;
    `;
    const result = await pool.query(sql);
    res.json(result.rows);
  } catch (error) {
    console.error("getAllFarms error:", error);
    res.status(500).json({ message: "Error fetching farms", error });
  }
};

exports.getFarmById = async (req, res) => {
  const { id } = req.params;
  try {
    const sql = `
      SELECT
        f.farm_id,
        f.farm_size,
        f.survey_number,
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
      WHERE f.user_id = $1
      GROUP BY f.farm_id, ud.name, ud.dob, ud.address;
    `;
    const result = await pool.query(sql, [id]);
    if (result.rows.length > 0) res.json(result.rows);
    else res.status(404).json({ message: "Farm not found" });
  } catch (error) {
    console.error("getFarmById error:", error);
    res.status(500).json({ message: "Error fetching farm", error });
  }
};

exports.addFarm = async (req, res) => {
  const {
    phone_number,
    farm_size,
    survey_number,
    soil_type_ids, // <-- array, not single value
    irrigation_ids, // <-- array
    water_src_ids, // <-- array
  } = req.body;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    // Lookup user_id by phone_number
    const userRes = await client.query(
      "SELECT user_id FROM users_auth WHERE phone_number = $1 LIMIT 1",
      [phone_number]
    );
    if (userRes.rowCount === 0) {
      throw new Error("Phone number not found. Invalid user.");
    }
    const user_id = userRes.rows[0].user_id;
    const farm_id = await generateUniqueId(client, "farms", "farm_id");

    // Insert farm row
    const farmResult = await client.query(
      `INSERT INTO farms (user_id, farm_id, farm_size, survey_number)
       VALUES ($1, $2, $3, $4)
       RETURNING *;`,
      [user_id, farm_id, farm_size, survey_number]
    );
    const farm = farmResult.rows[0];

    // Multi-insert soils
    if (soil_type_ids && Array.isArray(soil_type_ids)) {
      for (const soil_type_id of soil_type_ids) {
        await client.query(
          `INSERT INTO farms_soil_types (farm_id, soil_type_id) VALUES ($1, $2)`,
          [farm_id, soil_type_id]
        );
      }
    }

    // Multi-insert irrigations
    if (irrigation_ids && Array.isArray(irrigation_ids)) {
      for (const irrigation_id of irrigation_ids) {
        await client.query(
          `INSERT INTO farm_irrigation (farm_id, irrigation_id) VALUES ($1, $2)`,
          [farm_id, irrigation_id]
        );
      }
    }

    // Multi-insert water sources
    if (water_src_ids && Array.isArray(water_src_ids)) {
      for (const water_src_id of water_src_ids) {
        await client.query(
          `INSERT INTO farms_water_src (farm_id, water_src_id) VALUES ($1, $2)`,
          [farm_id, water_src_id]
        );
      }
    }

    await client.query("COMMIT");
    res.json({ message: "Farm added", farm });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("addFarm error:", error);
    res.status(500).json({ message: "Error adding farm", error });
  } finally {
    client.release();
  }
};

exports.addFarmByUserId = async (req, res) => {
  const {
    user_id, // Farmer's user_id after login
    farm_size,
    survey_number,
    soil_type_ids, // array
    irrigation_ids, // array
    water_src_ids, // array
  } = req.body;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // Optional: Validate that user_id exists in users_auth table
    const userRes = await client.query(
      "SELECT user_id FROM users_auth WHERE user_id = $1 LIMIT 1",
      [user_id]
    );
    if (userRes.rowCount === 0) {
      throw new Error("Invalid user_id. User not found.");
    }

    // Generate unique farm_id
    const farm_id = await generateUniqueId(client, "farms", "farm_id");

    // Insert farm row
    const farmResult = await client.query(
      `INSERT INTO farms (user_id, farm_id, farm_size, survey_number)
       VALUES ($1, $2, $3, $4)
       RETURNING *;`,
      [user_id, farm_id, farm_size, survey_number]
    );
    const farm = farmResult.rows[0];

    // Multi-insert soil types
    if (soil_type_ids && Array.isArray(soil_type_ids)) {
      for (const soil_type_id of soil_type_ids) {
        await client.query(
          `INSERT INTO farms_soil_types (farm_id, soil_type_id) VALUES ($1, $2)`,
          [farm_id, soil_type_id]
        );
      }
    }

    // Multi-insert irrigations
    if (irrigation_ids && Array.isArray(irrigation_ids)) {
      for (const irrigation_id of irrigation_ids) {
        await client.query(
          `INSERT INTO farm_irrigation (farm_id, irrigation_id) VALUES ($1, $2)`,
          [farm_id, irrigation_id]
        );
      }
    }

    // Multi-insert water sources
    if (water_src_ids && Array.isArray(water_src_ids)) {
      for (const water_src_id of water_src_ids) {
        await client.query(
          `INSERT INTO farms_water_src (farm_id, water_src_id) VALUES ($1, $2)`,
          [farm_id, water_src_id]
        );
      }
    }

    await client.query("COMMIT");
    res.json({ message: "Farm added", farm });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("addFarmByUserId error:", error);
    res.status(500).json({ message: "Error adding farm", error });
  } finally {
    client.release();
  }
};

exports.updateFarm = async (req, res) => {
  const farm_id = req.params.id;
  const {
    farm_size,
    survey_number,
    soil_type_ids, // <-- array
    irrigation_ids, // <-- array
    water_src_ids, // <-- array
  } = req.body;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // Update main farm record (do NOT touch user_id)
    await client.query(
      `UPDATE farms 
       SET farm_size = $2, survey_number = $3
       WHERE farm_id = $1`,
      [farm_id, farm_size, survey_number]
    );

    // DELETE + multi-insert soils
    await client.query("DELETE FROM farms_soil_types WHERE farm_id = $1", [
      farm_id,
    ]);
    if (soil_type_ids && Array.isArray(soil_type_ids)) {
      for (const soil_type_id of soil_type_ids) {
        await client.query(
          "INSERT INTO farms_soil_types (farm_id, soil_type_id) VALUES ($1, $2)",
          [farm_id, soil_type_id]
        );
      }
    }

    // DELETE + multi-insert irrigations
    await client.query("DELETE FROM farm_irrigation WHERE farm_id = $1", [
      farm_id,
    ]);
    if (irrigation_ids && Array.isArray(irrigation_ids)) {
      for (const irrigation_id of irrigation_ids) {
        await client.query(
          "INSERT INTO farm_irrigation (farm_id, irrigation_id) VALUES ($1, $2)",
          [farm_id, irrigation_id]
        );
      }
    }

    // DELETE + multi-insert water sources
    await client.query("DELETE FROM farms_water_src WHERE farm_id = $1", [
      farm_id,
    ]);
    if (water_src_ids && Array.isArray(water_src_ids)) {
      for (const water_src_id of water_src_ids) {
        await client.query(
          "INSERT INTO farms_water_src (farm_id, water_src_id) VALUES ($1, $2)",
          [farm_id, water_src_id]
        );
      }
    }

    await client.query("COMMIT");
    res.json({ message: "Farm updated successfully" });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("updateFarm error:", error);
    res.status(500).json({ message: "Error updating farm", error });
  } finally {
    client.release();
  }
};

exports.deleteFarm = async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query("DELETE FROM farms WHERE farm_id=$1", [id]);
    res.json({ message: "Farm deleted" });
  } catch (error) {
    console.error("deleteFarm error:", error);
    res.status(500).json({ message: "Error deleting farm", error });
  }
};

// ----------- CROP OPERATIONS ----------

exports.getAllCrops = async (req, res) => {
  try {
    const sql = `
      SELECT 
        uc.farm_id,
        uc.user_crop_id, 
        uc.farm_id,
        pl.plant_name, 
        ct.name AS crop_type,
        uc.planting_date, 
        uc.harvest_date,
        uc.duration,
        uc.field_size, 
        uc.status, 
        uc.is_active, 
        f.survey_number, 
        f.farm_size, 
        ud.name AS farmer,
        pl.water_requirement
      FROM user_crops uc
      LEFT JOIN plants pl ON uc.plant_id = pl.plant_id
      LEFT JOIN crop_types ct ON pl.crop_type_id = ct.crop_type_id
      LEFT JOIN farms f ON uc.farm_id = f.farm_id
      LEFT JOIN user_details ud ON f.user_id = ud.user_id
      ORDER BY uc.user_crop_id;
    `;
    const result = await pool.query(sql);
    res.json(result.rows);
  } catch (error) {
    console.error("getAllCrops error:", error);
    res.status(500).json({ message: "Error fetching crops", error });
  }
};

exports.getCropById = async (req, res) => {
  const { id } = req.params;
  try {
    const sql = `
      SELECT
        uc.farm_id,
        pl.plant_name,
        ct.name AS crop_type,
        uc.planting_date,
        uc.harvest_date,
        uc.duration,
        uc.field_size,
        uc.status,
        uc.is_active,
        f.survey_number,
        f.farm_size,
        ud.name AS farmer,
        pl.water_requirement
      FROM user_crops uc
      LEFT JOIN plants pl ON uc.plant_id = pl.plant_id
      LEFT JOIN crop_types ct ON pl.crop_type_id = ct.crop_type_id
      LEFT JOIN farms f ON uc.farm_id = f.farm_id
      LEFT JOIN user_details ud ON f.user_id = ud.user_id
      WHERE f.farm_id = $1
      AND uc.is_active = true;
    `;
    const result = await pool.query(sql, [id]);
    res.json(result.rows);
  } catch (error) {
    console.error("getCropById error:", error);
    res.status(500).json({ message: "Error fetching crop", error });
  }
};

exports.getCropHistoryById = async (req, res) => {
  const { id } = req.params;
  try {
    const sql = `
      SELECT
        pl.plant_name,
        ct.name AS crop_type,
        uc.planting_date,
        uc.harvest_date,
        uc.duration,
        uc.field_size,
        uc.status,
        uc.is_active,
        f.survey_number,
        f.farm_size,
        ud.name AS farmer,
        pl.water_requirement
      FROM user_crops uc
      LEFT JOIN plants pl ON uc.plant_id = pl.plant_id
      LEFT JOIN crop_types ct ON pl.crop_type_id = ct.crop_type_id
      LEFT JOIN farms f ON uc.farm_id = f.farm_id
      LEFT JOIN user_details ud ON f.user_id = ud.user_id
      WHERE f.farm_id = $1
      AND uc.is_active = false;
    `;
    const result = await pool.query(sql, [id]);
    res.json(result.rows);
  } catch (error) {
    console.error("getCropHistoryById error:", error);
    res.status(500).json({ message: "Error fetching crop", error });
  }
};

exports.getFarmCropOptions = async (req, res) => {
  const { id } = req.params; // Must match your router param key
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
    // Return empty arrays if not found.
    res.json(
      result.rows[0] || {
        soil_type_ids: [],
        soil_type_names: [],
        irrigation_ids: [],
        irrigation_names: [],
        water_src_ids: [],
        water_src_names: [],
      }
    );
  } catch (error) {
    res.status(500).json({ message: "Error fetching farm options", error });
  }
};

exports.addCrop = async (req, res) => {
  const {
    farm_id,
    plant_id,
    planting_date,
    harvest_date,
    field_size,
    status,
    is_active,
  } = req.body;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const start = new Date(planting_date);
    const end = new Date(harvest_date);
    const duration = Math.round((end - start) / (1000 * 60 * 60 * 24));

    const user_crop_id = await generateUniqueId(
      client,
      "user_crops",
      "user_crop_id"
    );

    const insertSql = `
      INSERT INTO user_crops (
        user_crop_id, farm_id, plant_id, planting_date, harvest_date, duration,
        field_size, status, is_active
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
      RETURNING *;
    `;

    const result = await client.query(insertSql, [
      user_crop_id,
      farm_id,
      plant_id,
      planting_date,
      harvest_date,
      duration,
      field_size,
      status,
      is_active,
    ]);

    await client.query("COMMIT");
    res.json({ message: "Crop added", crop: result.rows[0] });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("addCrop error:", error.message || error);
    res
      .status(500)
      .json({ message: "Error adding crop", error: error.message || error });
  } finally {
    client.release();
  }
};

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
  } = req.body;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // 1. Calculate duration
    const start = new Date(planting_date);
    const end = new Date(harvest_date);
    const duration = Math.round((end - start) / (1000 * 60 * 60 * 24));

    // 2. Update query for user_crops
    const sql = `
      UPDATE user_crops
      SET farm_id = $1,
          plant_id = $2,
          planting_date = $3,
          harvest_date = $4,
          duration = $5,
          field_size = $6,
          status = $7,
          is_active = $8
      WHERE user_crop_id = $9
      RETURNING *
    `;

    const result = await client.query(sql, [
      farm_id,
      plant_id,
      planting_date,
      harvest_date,
      duration,
      field_size,
      status,
      is_active,
      id,
    ]);

    // 3. Check if update was successful
    if (result.rowCount === 0) {
      throw new Error(`Crop with ID ${id} not found`);
    }

    const user_crop = result.rows[0];

    await client.query("COMMIT");
    res.json({ message: "Crop updated", crop: user_crop });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("updateCrop error:", error.message || error);
    res
      .status(500)
      .json({ message: "Error updating crop", error: error.message || error });
  } finally {
    client.release();
  }
};

exports.deleteCrop = async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query("DELETE FROM user_crops WHERE user_crop_id=$1", [id]);
    res.json({ message: "Crop deleted" });
  } catch (error) {
    console.error("deleteCrop error:", error);
    res.status(500).json({ message: "Error deleting crop", error });
  }
};

// ----------- MASTER TABLES -----------

exports.getSoilTypes = async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM soil_types ORDER BY name");
    res.json(result.rows);
  } catch (error) {
    console.error("getSoilTypes error:", error);
    res.status(500).json({ message: "Error fetching soil types", error });
  }
};

exports.addSoilType = async (req, res) => {
  const client = await pool.connect();
  try {
    const { name } = req.body;
    const soil_type_id = await generateUniqueId(
      client,
      "soil_types",
      "soil_type_id"
    );

    const result = await pool.query(
      "INSERT INTO soil_types (soil_type_id, name) VALUES ($1, $2) RETURNING *",
      [soil_type_id, name]
    );
    if (result.rows.length !== 0) {
      await client.query(
        "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'soil_types'"
      );
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error("addSoilType error:", error);
    res.status(500).json({ message: "Error adding soil type", error });
  }
};

exports.deleteSoilType = async (req, res) => {
  try {
    const result = await pool.query(
      "DELETE FROM soil_types WHERE soil_type_id=$1",
      [req.params.id]
    );
    if (result.rowCount !== 0) {
      await pool.query(
        "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'soil_types'"
      );
    }
    res.json({ message: "Soil type deleted" });
  } catch (error) {
    console.error("deleteSoilType error:", error);
    res.status(500).json({ message: "Error deleting soil type", error });
  }
};

exports.getIrrigations = async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM irrigation_method ORDER BY method_name"
    );
    res.json(result.rows);
  } catch (error) {
    console.error("getIrrigations error:", error);
    res
      .status(500)
      .json({ message: "Error fetching irrigation methods", error });
  }
};

exports.addIrrigation = async (req, res) => {
  const client = await pool.connect();
  try {
    const { method_name } = req.body;
    const irrigation_method_id = await generateUniqueId(
      client,
      "irrigation_method",
      "irrigation_id"
    );

    const result = await pool.query(
      "INSERT INTO irrigation_method (irrigation_id, method_name) VALUES ($1, $2) RETURNING *",
      [irrigation_method_id, method_name]
    );
    if (result.rows.length !== 0) {
      await client.query(
        "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'irrigation_method'"
      );
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error("addIrrigation error:", error);
    res.status(500).json({ message: "Error adding irrigation method", error });
  }
};

exports.deleteIrrigation = async (req, res) => {
  try {
    const result = await pool.query(
      "DELETE FROM irrigation_method WHERE irrigation_id=$1",
      [req.params.id]
    );
    if (result.rowCount !== 0) {
      await pool.query(
        "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'irrigation_method'"
      );
    }
    res.json({ message: "Irrigation method deleted" });
  } catch (error) {
    console.error("deleteIrrigation error:", error);
    res.status(500).json({ message: "Error deleting irrigation", error });
  }
};

exports.getWaterSources = async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM water_src ORDER BY source");
    res.json(result.rows);
  } catch (error) {
    console.error("getWaterSources error:", error);
    res.status(500).json({ message: "Error fetching water sources", error });
  }
};

exports.addWaterSource = async (req, res) => {
  const client = await pool.connect();
  try {
    const { source } = req.body;
    const water_src_id = await generateUniqueId(
      client,
      "water_src",
      "water_src_id"
    );

    const result = await pool.query(
      "INSERT INTO water_src (water_src_id, source) VALUES ($1, $2) RETURNING *",
      [water_src_id, source]
    );
    if (result.rows.length !== 0) {
      await client.query(
        "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'water_src'"
      );
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error("addWaterSource error:", error);
    res.status(500).json({ message: "Error adding water source", error });
  }
};

exports.deleteWaterSource = async (req, res) => {
  try {
    const result = await pool.query(
      "DELETE FROM water_src WHERE water_src_id=$1",
      [req.params.id]
    );
    if (result.rowCount !== 0) {
      await pool.query(
        "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'water_src'"
      );
    }
    res.json({ message: "Water source deleted" });
  } catch (error) {
    console.error("deleteWaterSource error:", error);
    res.status(500).json({ message: "Error deleting water source", error });
  }
};

exports.getCropTypes = async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM crop_types ORDER BY name");
    res.json(result.rows);
  } catch (error) {
    console.error("getCropTypes error:", error);
    res.status(500).json({ message: "Error fetching crop types", error });
  }
};

exports.addCropType = async (req, res) => {
  const client = await pool.connect();
  try {
    const { name } = req.body;
    const crop_type_id = await generateUniqueId(
      client,
      "crop_types",
      "crop_type_id"
    );

    const result = await pool.query(
      "INSERT INTO crop_types (crop_type_id, name) VALUES ($1, $2) RETURNING *",
      [crop_type_id, name]
    );
    if (result.rows.length !== 0) {
      await client.query(
        "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'crop_types'"
      );
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error("addCropType error:", error);
    res.status(500).json({ message: "Error adding crop type", error });
  }
};

exports.deleteCropType = async (req, res) => {
  try {
    const result = await pool.query(
      "DELETE FROM crop_types WHERE crop_type_id=$1",
      [req.params.id]
    );
    if (result.rowCount !== 0) {
      await pool.query(
        "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'crop_types'"
      );
    }
    res.json({ message: "Crop type deleted" });
  } catch (error) {
    console.error("deleteCropType error:", error);
    res.status(500).json({ message: "Error deleting crop type", error });
  }
};

exports.getPlants = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT pl.*, ct.name as crop_type
      FROM plants pl
      LEFT JOIN crop_types ct ON pl.crop_type_id = ct.crop_type_id
      ORDER BY plant_name
    `);
    res.json(result.rows);
  } catch (error) {
    console.error("getPlants error:", error);
    res.status(500).json({ message: "Error fetching plants", error });
  }
};

exports.addPlant = async (req, res) => {
  const client = await pool.connect();
  try {
    const { plant_name, crop_type_id, water_requirement } = req.body;
    const plant_id = await generateUniqueId(client, "plants", "plant_id");

    const result = await pool.query(
      "INSERT INTO plants (plant_id, plant_name, crop_type_id, water_requirement) VALUES ($1, $2, $3, $4) RETURNING *",
      [plant_id, plant_name, crop_type_id, water_requirement]
    );
    if (result.rows.length !== 0) {
      await client.query(
        "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'plants'"
      );
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error("addPlant error:", error);
    res.status(500).json({ message: "Error adding plant", error });
  }
};

exports.deletePlant = async (req, res) => {
  try {
    const result = await pool.query("DELETE FROM plants WHERE plant_id=$1", [
      req.params.id,
    ]);
    if (result.rowCount !== 0) {
      await pool.query(
        "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'plants'"
      );
    }
    res.json({ message: "Plant deleted" });
  } catch (error) {
    console.error("deletePlant error:", error);
    res.status(500).json({ message: "Error deleting plant", error });
  }
};
