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
      SELECT f.farm_id, f.farm_size, f.survey_number,
       s.name AS soil_type, i.method_name AS irrigation, w.source AS water_source,
       f.pincode, ud.name AS owner_name
FROM farms f
LEFT JOIN farms_soil_types fs ON f.farm_id = fs.farm_id
LEFT JOIN soil_types s ON fs.soil_type_id = s.soil_type_id
LEFT JOIN farm_irrigation fi ON f.farm_id = fi.farm_id
LEFT JOIN irrigation_method i ON fi.irrigation_id = i.irrigation_id
LEFT JOIN farms_water_src fw ON f.farm_id = fw.farm_id
LEFT JOIN water_src w ON fw.water_src_id = w.water_src_id
LEFT JOIN user_details ud ON f.user_id = ud.user_id
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
      SELECT f.*, s.name AS soil_type, i.method_name AS irrigation, w.source AS water_source,
             ud.name AS owner_name, ud.dob, ud.address
      FROM farms f
      LEFT JOIN farms_soil_types fs ON f.farm_id = fs.farm_id
      LEFT JOIN soil_types s ON fs.soil_type_id = s.soil_type_id
      LEFT JOIN farm_irrigation fi ON f.farm_id = fi.farm_id
      LEFT JOIN irrigation_method i ON fi.irrigation_id = i.irrigation_id
      LEFT JOIN farms_water_src fw ON f.farm_id = fw.farm_id
      LEFT JOIN water_src w ON fw.water_src_id = w.water_src_id
      LEFT JOIN user_details ud ON f.user_id = ud.user_id
      WHERE f.farm_id = $1
    `;
    const result = await pool.query(sql, [id]);
    if (result.rows.length > 0) res.json(result.rows[0]);
    else res.status(404).json({ message: "Farm not found" });
  } catch (error) {
    console.error("getFarmById error:", error);
    res.status(500).json({ message: "Error fetching farm", error });
  }
};

exports.addFarm = async (req, res) => {
  const {
    phone_number, // <-- use phone_number in frontend
    farm_size,
    survey_number,
    pincode,
    soil_type_id,
    irrigation_id,
    water_src_id,
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

    // rest of your insert logic
    const farmResult = await client.query(
      `INSERT INTO farms (user_id, farm_id, farm_size, survey_number, pincode)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *;`,
      [user_id, farm_id, farm_size, survey_number, pincode]
    );
    const farm = farmResult.rows[0];

    // Insert associated soil type, if provided
    if (soil_type_id) {
      await client.query(
        `INSERT INTO farms_soil_types (farm_id, soil_type_id) VALUES ($1, $2)`,
        [farm_id, soil_type_id]
      );
    }

    // Insert associated irrigation, if provided
    if (irrigation_id) {
      await client.query(
        `INSERT INTO farm_irrigation (farm_id, irrigation_id) VALUES ($1, $2)`,
        [farm_id, irrigation_id]
      );
    }

    // Insert associated water source, if provided
    if (water_src_id) {
      await client.query(
        `INSERT INTO farms_water_src (farm_id, water_src_id) VALUES ($1, $2)`,
        [farm_id, water_src_id]
      );
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

exports.updateFarm = async (req, res) => {
  const farm_id = req.params.id;
  const {
    farm_size,
    survey_number,
    pincode,
    soil_type_id,
    irrigation_id,
    water_src_id,
  } = req.body;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // Update main farm record (do NOT touch user_id)
    await client.query(
      `UPDATE farms 
       SET farm_size = $2, survey_number = $3, pincode = $4
       WHERE farm_id = $1`,
      [farm_id, farm_size, survey_number, pincode]
    );

    // Update soil type
    if (soil_type_id) {
      await client.query("DELETE FROM farms_soil_types WHERE farm_id = $1", [
        farm_id,
      ]);
      await client.query(
        "INSERT INTO farms_soil_types (farm_id, soil_type_id) VALUES ($1, $2)",
        [farm_id, soil_type_id]
      );
    }

    // Update irrigation
    if (irrigation_id) {
      await client.query("DELETE FROM farm_irrigation WHERE farm_id = $1", [
        farm_id,
      ]);
      await client.query(
        "INSERT INTO farm_irrigation (farm_id, irrigation_id) VALUES ($1, $2)",
        [farm_id, irrigation_id]
      );
    }

    // Update water source
    if (water_src_id) {
      await client.query("DELETE FROM farms_water_src WHERE farm_id = $1", [
        farm_id,
      ]);
      await client.query(
        "INSERT INTO farms_water_src (farm_id, water_src_id) VALUES ($1, $2)",
        [farm_id, water_src_id]
      );
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
        st.name AS soil_type,
        pl.water_requirement
      FROM user_crops uc
      LEFT JOIN plants pl ON uc.plant_id = pl.plant_id
      LEFT JOIN crop_types ct ON pl.crop_type_id = ct.crop_type_id
      LEFT JOIN farms f ON uc.farm_id = f.farm_id
      LEFT JOIN user_details ud ON f.user_id = ud.user_id
      LEFT JOIN farms_soil_types fst ON f.farm_id = fst.farm_id
      LEFT JOIN soil_types st ON fst.soil_type_id = st.soil_type_id
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
        st.name AS soil_type,
        pl.water_requirement
      FROM user_crops uc
      LEFT JOIN plants pl ON uc.plant_id = pl.plant_id
      LEFT JOIN crop_types ct ON pl.crop_type_id = ct.crop_type_id
      LEFT JOIN farms f ON uc.farm_id = f.farm_id
      LEFT JOIN user_details ud ON f.user_id = ud.user_id
      LEFT JOIN farms_soil_types fst ON f.farm_id = fst.farm_id
      LEFT JOIN soil_types st ON fst.soil_type_id = st.soil_type_id
      WHERE uc.user_crop_id = $1 AND uc.isactive = true;
    `;
    const result = await pool.query(sql, [id]);
    res.json(result.rows[0]);
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
        st.name AS soil_type,
        pl.water_requirement
      FROM user_crops uc
      LEFT JOIN plants pl ON uc.plant_id = pl.plant_id
      LEFT JOIN crop_types ct ON pl.crop_type_id = ct.crop_type_id
      LEFT JOIN farms f ON uc.farm_id = f.farm_id
      LEFT JOIN user_details ud ON f.user_id = ud.user_id
      LEFT JOIN farms_soil_types fst ON f.farm_id = fst.farm_id
      LEFT JOIN soil_types st ON fst.soil_type_id = st.soil_type_id
      WHERE uc.user_crop_id = $1 AND uc.isactive = false;
    `;
    const result = await pool.query(sql, [id]);
    res.json(result.rows[0]);
  } catch (error) {
    console.error("getCropHistoryById error:", error);
    res.status(500).json({ message: "Error fetching crop", error });
  }
};

exports.addCrop = async (req, res) => {
  const {
    farm_id,
    plant_name,
    planting_date,
    harvest_date,
    field_size,
    status,
    isactive,
  } = req.body;

  const client = await pool.connect();
  try {
    // 1. Look up plant_id using plant_name
    const plantQuery = await client.query(
      "SELECT plant_id FROM plants WHERE plant_name = $1 LIMIT 1",
      [plant_name]
    );
    if (plantQuery.rowCount === 0) {
      throw new Error(`Invalid plant_name: '${plant_name}' not found`);
    }
    const plant_id = plantQuery.rows[0].plant_id;

    // 2. Calculate duration in days
    const start = new Date(planting_date);
    const end = new Date(harvest_date);
    const duration = Math.round((end - start) / (1000 * 60 * 60 * 24));

    // 3. Generate unique user_crop_id
    const user_crop_id = await generateUniqueId(
      client,
      "user_crops",
      "user_crop_id"
    );

    // 4. Fetch soil_type_id for the farm
    const soilIdSql = `
      SELECT soil_type_id 
      FROM farms_soil_types 
      WHERE farm_id = $1
      LIMIT 1
    `;
    const soilIdResult = await client.query(soilIdSql, [farm_id]);
    const soil_type_id = soilIdResult.rows[0]?.soil_type_id || null;

    // 5. Insert into user_crops table
    const insertSql = `
      INSERT INTO user_crops (
        user_crop_id, farm_id, plant_id, planting_date, harvest_date, duration,
        field_size, soil_type_id, status, is_active
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
      ) RETURNING *;
    `;
    const result = await client.query(insertSql, [
      user_crop_id,
      farm_id,
      plant_id,
      planting_date,
      harvest_date,
      duration,
      field_size,
      soil_type_id,
      status,
      isactive,
    ]);
    let userCrop = result.rows[0];

    // 6. Fetch soil type name for the farm
    const soilSql = `
      SELECT name
      FROM farms_soil_types fst
      JOIN soil_types st ON fst.soil_type_id = st.soil_type_id
      WHERE fst.farm_id = $1
      LIMIT 1
    `;
    const soilResult = await client.query(soilSql, [farm_id]);
    const soil_type_name = soilResult.rows[0]?.name || null;

    // 7. Send response with all crop fields and soil_type_name
    res.json({ message: "Crop added", crop: { ...userCrop, soil_type_name } });
  } catch (error) {
    console.error("addCrop error:", error.message || error);
    res
      .status(500)
      .json({ message: "Error adding crop", error: error.message || error });
  } finally {
    client.release();
  }
};

exports.updateCrop = async (req, res) => {
  const { id } = req.params; // user_crop_id
  const {
    farm_id,
    plant_name,
    planting_date,
    harvest_date,
    field_size,
    soil_type_name,
    status,
    isactive,
  } = req.body;

  try {
    // 1. Look up plant_id from plant_name
    const plantQuery = await pool.query(
      "SELECT plant_id FROM plants WHERE plant_name = $1 LIMIT 1",
      [plant_name]
    );
    if (plantQuery.rowCount === 0) {
      throw new Error(`Invalid plant_name: '${plant_name}' not found`);
    }
    const plant_id = plantQuery.rows[0].plant_id;

    // 2. Look up soil_type_id from soil_type_name
    const soilQuery = await pool.query(
      "SELECT soil_type_id FROM soil_types WHERE name = $1 LIMIT 1",
      [soil_type_name]
    );
    if (soilQuery.rowCount === 0) {
      throw new Error(`Invalid soil_type_name: '${soil_type_name}' not found`);
    }
    const soil_type_id = soilQuery.rows[0].soil_type_id;

    // 3. Calculate duration in days from dates
    const start = new Date(planting_date);
    const end = new Date(harvest_date);
    const duration = Math.round((end - start) / (1000 * 60 * 60 * 24));

    // 4. Update query for user_crops
    const sql = `
      UPDATE user_crops SET
        farm_id = $1,
        plant_id = $2,
        planting_date = $3,
        harvest_date = $4,
        duration = $5,
        field_size = $6,
        soil_type_id = $7,
        status = $8,
        is_active = $9
      WHERE user_crop_id = $10
      RETURNING *;
    `;
    const result = await pool.query(sql, [
      farm_id,
      plant_id,
      planting_date,
      harvest_date,
      duration,
      field_size,
      soil_type_id,
      status,
      isactive,
      id,
    ]);
    const userCrop = result.rows[0];

    // 5. Return updated data with soil_type_name
    res.json({
      message: "Crop updated",
      crop: { ...userCrop, soil_type_name },
    });
  } catch (error) {
    console.error("updateCrop error:", error.message || error);
    res
      .status(500)
      .json({ message: "Error updating crop", error: error.message || error });
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
