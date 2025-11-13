const pool = require("../db/database");
const { get } = require("../routes/feedbackRoutes");
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

// --- DISEASES ---
async function getDiseases() {
  const sql = `
    SELECT 
      d.disease_id,
      d.name,
      d.severity,
      ARRAY_AGG(p.plant_id) AS plant_ids,
      ARRAY_AGG(p.plant_name) AS plant_names
    FROM diseases d
    JOIN diseases_plants dp ON d.disease_id = dp.disease_id
    JOIN plants p ON dp.plant_id = p.plant_id
    GROUP BY d.disease_id, d.name, d.severity
    ORDER BY d.disease_id
  `;
  const result = await pool.query(sql);
  return result.rows;
}

async function createDisease(disease) {
  try {
    // Accept plant_id as array for flexibility, fallback to single value if not array
    const plantIds = Array.isArray(disease.plant_id)
      ? disease.plant_id
      : [disease.plant_id];

    // FK validation: Check all supplied plant_id(s) exist
    const plantCheckSql = `SELECT plant_id FROM plants WHERE plant_id = ANY($1::uuid[])`;
    const plantRes = await pool.query(plantCheckSql, [plantIds]);
    if (plantRes.rowCount !== plantIds.length) {
      throw new Error("Invalid plant_id(s)");
    }

    // Generate unique disease_id
    const disease_id = await generateUniqueId(pool, "diseases", "disease_id");

    // Insert into diseases table (no plant_id here)
    const insertSql =
      "INSERT INTO diseases (disease_id, name, severity) VALUES ($1, $2, $3) RETURNING *";
    const insertVals = [disease_id, disease.name, disease.severity];
    await pool.query(insertSql, insertVals);

    // Link disease to plant(s) using diseases_plants join table
    for (const pid of plantIds) {
      await pool.query(
        "INSERT INTO diseases_plants (disease_id, plant_id) VALUES ($1, $2)",
        [disease_id, pid]
      );
    }

    // Update reference_table_versions timestamp for diseases
    await pool.query(
      "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'diseases'"
    );

    await pool.query(
      "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'diseases_plants'"
    );

    // Return joined result: one row per plant, with plant_name
    const joinSql = `
      SELECT d.*, p.plant_id, p.plant_name
      FROM diseases d
      JOIN diseases_plants dp ON d.disease_id = dp.disease_id
      JOIN plants p ON dp.plant_id = p.plant_id
      WHERE d.disease_id = $1
    `;
    const joinRes = await pool.query(joinSql, [disease_id]);
    return joinRes.rows; // array of disease+plant combos
  } catch (error) {
    console.error("createDisease error:", error.message || error);
    throw error; // propagate if higher level wants to handle, otherwise respond with 500
  }
}

async function updateDisease(disease_id, updated) {
  try {
    // Validate: if plant_id is provided, ensure it exists (supports array for multi-plant relation)
    if (updated.plant_id) {
      const plantIds = Array.isArray(updated.plant_id)
        ? updated.plant_id
        : [updated.plant_id];
      const plantCheckSql = `SELECT plant_id FROM plants WHERE plant_id = ANY($1::uuid[])`;
      const plantRes = await pool.query(plantCheckSql, [plantIds]);
      if (plantRes.rowCount !== plantIds.length)
        throw new Error("Invalid plant_id(s)");
    }

    // Update disease main fields (name, severity)
    const sql =
      "UPDATE diseases SET name=$1, severity=$2 WHERE disease_id=$3 RETURNING *";
    const values = [updated.name, updated.severity, disease_id];
    const result = await pool.query(sql, values);
    await pool.query(
      "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'diseases'"
    );

    await pool.query(
      "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'diseases_plants'"
    );

    // If plant_id provided: replace links in diseasesplants join table
    if (updated.plant_id) {
      // Remove existing links for this disease
      await pool.query("DELETE FROM diseases_plants WHERE disease_id = $1", [
        disease_id,
      ]);
      // Re-insert new links
      const plantIds = Array.isArray(updated.plant_id)
        ? updated.plant_id
        : [updated.plant_id];
      for (const pid of plantIds) {
        await pool.query(
          "INSERT INTO diseases_plants (disease_id, plant_id) VALUES ($1, $2)",
          [disease_id, pid]
        );
      }
    }

    // Return joined result (one row per linked plant)
    const joinSql = `
      SELECT d.*, p.plant_id, p.plant_name
      FROM diseases d
      JOIN diseases_plants dp ON d.disease_id = dp.disease_id
      JOIN plants p ON dp.plant_id = p.plant_id
      WHERE d.disease_id = $1
    `;
    const joinRes = await pool.query(joinSql, [disease_id]);
    await pool.query(
      "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'diseases'"
    );

    await pool.query(
      "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'diseases_plants'"
    );
    return joinRes.rows; // array of disease-plant combos
  } catch (error) {
    console.error("updateDisease error:", error.message || error);
    throw error;
  }
}

async function deleteDisease(disease_id) {
  try {
    // Delete links from diseaseremedy table first
    await pool.query("DELETE FROM disease_remedy WHERE disease_id = $1", [
      disease_id,
    ]);
    // Delete links from diseasesplants join table
    await pool.query("DELETE FROM diseases_plants WHERE disease_id = $1", [
      disease_id,
    ]);
    // Delete from diseases table
    const sql = "DELETE FROM diseases WHERE disease_id = $1 RETURNING *";
    const result = await pool.query(sql, [disease_id]);
    await pool.query(
      "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'diseases'"
    );

    await pool.query(
      "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'diseases_plants'"
    );
    return result.rows[0];
  } catch (error) {
    console.error("deleteDisease error:", error.message || error);
    throw error;
  }
}

// --- REMEDIES ---
// Get all remedies, optionally return mapped diseases too (if needed, add a JOIN)
async function getRemedies() {
  const sql = `
    SELECT r.*, array_agg(dr.disease_id) AS mapped_diseases
    FROM remedies r
    LEFT JOIN disease_remedy dr ON r.remedy_id = dr.remedy_id
    GROUP BY r.remedy_id
    ORDER BY r.remedy_id
  `;
  const result = await pool.query(sql);
  return result.rows;
}

async function createRemedy(remedy, diseaseIds) {
  try {
    // Validate all supplied disease_id(s)
    if (diseaseIds && diseaseIds.length) {
      const checkSql = `SELECT disease_id FROM diseases WHERE disease_id = ANY($1::uuid[])`;
      const res = await pool.query(checkSql, [diseaseIds]);
      if (res.rowCount !== diseaseIds.length)
        throw new Error("Invalid disease_id(s)");
    }

    // Generate unique remedy_id
    const remedy_id = await generateUniqueId(pool, "remedies", "remedy_id");

    // Insert into remedies table
    const insertSql = `
      INSERT INTO remedies (remedy_id, remedy, prevention)
      VALUES ($1, $2, $3) RETURNING *
    `;
    const insertVals = [remedy_id, remedy.remedy, remedy.prevention];
    const remedyRes = await pool.query(insertSql, insertVals);

    // Link to disease(s) in disease_remedy table
    if (diseaseIds && diseaseIds.length) {
      for (const did of diseaseIds) {
        await pool.query(
          "INSERT INTO disease_remedy (disease_id, remedy_id) VALUES ($1, $2)",
          [did, remedy_id]
        );
      }
    }

    // Update reference_table_versions timestamp for remedies
    await pool.query(
      "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'remedies'"
    );

    // Return the inserted remedy and disease links
    return {
      remedy: remedyRes.rows[0],
      linkedDiseases: diseaseIds,
    };
  } catch (error) {
    console.error("createRemedy error:", error.message || error);
    throw error;
  }
}

// Update an existing remedy
async function updateRemedy(remedy_id, updated) {
  const sql =
    "UPDATE remedies SET remedy=$1, prevention=$2 WHERE remedy_id=$3 RETURNING *";
  const values = [updated.remedy, updated.prevention, remedy_id];
  const result = await pool.query(sql, values);
  return result.rows[0];
}

// Delete a remedy (will fail if remedy is still mapped in disease_remedy)
async function deleteRemedy(remedy_id) {
  // Optionally, check and delete from mapping first if you want cascade
  const sql = "DELETE FROM remedies WHERE remedy_id=$1 RETURNING *";
  const result = await pool.query(sql, [remedy_id]);
  await pool.query(
    "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'remedies'"
  );
  return result.rows[0];
}

// --- Disease-Remedy Mapping ---
async function getRemediesByDisease(diseaseid) {
  const sql = `
    SELECT r.*
    FROM remedies r
    JOIN disease_remedy dr ON r.remedy_id = dr.remedy_id
    WHERE dr.disease_id = $1
    ORDER BY r.remedy_id
  `;
  const result = await pool.query(sql, [diseaseid]);
  return result.rows;
}

async function getAllDiseasesWithRemedies() {
  const sql = `
    SELECT 
      d.disease_id,
      d.name AS disease_name,
      r.remedy_id,
      r.remedy,
      r.prevention
    FROM diseases d
    LEFT JOIN disease_remedy dr ON d.disease_id = dr.disease_id
    LEFT JOIN remedies r ON dr.remedy_id = r.remedy_id
    ORDER BY d.disease_id, r.remedy_id;
  `;
  const result = await pool.query(sql);
  return result.rows;
}

async function mapRemedyToDisease(disease_id, remedy_id) {
  // FK integrity checks are recommended but not required here
  const sql =
    "INSERT INTO disease_remedy (disease_id, remedy_id) VALUES ($1, $2) RETURNING *";
  const result = await pool.query(sql, [disease_id, remedy_id]);

  // Update reference_table_versions timestamp for disease_remedy
  await pool.query(
    "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'disease_remedy'"
  );
  return result.rows[0];
}

async function unmapRemedyFromDisease(disease_id, remedy_id) {
  const sql =
    "DELETE FROM disease_remedy WHERE disease_id=$1 AND remedy_id=$2 RETURNING *";
  const result = await pool.query(sql, [disease_id, remedy_id]);
  await pool.query(
    "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = 'disease_remedy'"
  );
  return result.rows[0];
}

// --- IMAGES (Read Only) ---
async function getImages() {
  const sql = "SELECT image_id, image_url FROM images ORDER BY image_id";
  const result = await pool.query(sql);
  return result.rows;
}

async function addImage(image) {
  // Generate unique imageid
  const image_id = await generateUniqueId("images", "image_id");
  // Insert image (without crop_id)
  const sql =
    "INSERT INTO images (image_id, image_url) VALUES ($1, $2) RETURNING *";
  const values = [image_id, image.image_url];
  const result = await pool.query(sql, values);
  return result.rows[0];
}

// --- Disease Analysis Results (Read, and Insert with Random ID) ---
async function getDiseaseAnalysisResults(filters) {
  let sql = `
    SELECT dar.id,
           ud.name AS user_name,
           ud.user_id AS user_id,
           p.plant_name,
           i.image_url,
           d.name AS disease_name,
           r.remedy,
           dar.confidence
    FROM disease_analysis_results dar
    JOIN user_details ud ON dar.user_id = ud.user_id
    JOIN plants p ON dar.plant_id = p.plant_id
    JOIN images i ON dar.image_id = i.image_id
    JOIN diseases d ON dar.disease_id = d.disease_id
    JOIN disease_remedy dr ON dar.disease_id = dr.disease_id
    JOIN remedies r ON dr.remedy_id = r.remedy_id
  `;

  let clauses = [];
  let values = [];
  let idx = 1;
  if (filters.user_id) {
    clauses.push(`ud.user_id = $${idx++}`);
    values.push(filters.user_id);
  }
  if (filters.plant_id) {
    clauses.push(`p.plant_id = $${idx++}`);
    values.push(filters.plant_id);
  }
  if (filters.image_id) {
    clauses.push(`i.image_id = $${idx++}`);
    values.push(filters.image_id);
  }
  if (filters.disease_id) {
    clauses.push(`d.disease_id = $${idx++}`);
    values.push(filters.disease_id);
  }
  if (filters.remedy_id) {
    clauses.push(`r.remedy_id = $${idx++}`);
    values.push(filters.remedy_id);
  }
  if (clauses.length) sql += ` WHERE ` + clauses.join(" AND ");
  sql += " ORDER BY dar.created_at DESC";

  const result = await pool.query(sql, values);
  return result.rows;
}

async function createDiseaseAnalysisResult(entry) {
  // Validate required FKs if you want stricter control (optional)
  const id = await generateUniqueId("disease_analysis_results", "id");
  const sql = `
    INSERT INTO disease_analysis_results
      (id, user_id, plant_id, image_id, disease_id, confidence, created_at)
    VALUES
      ($1, $2, $3, $4, $5, $6, NOW())
    RETURNING *
  `;
  const values = [
    id,
    entry.user_id, // maps to userdetails/userauth
    entry.image_id, // links to images
    entry.disease_id, // links to diseases
    entry.remedy_id, // links to remedies (and validated by disease_remedy mapping)
    entry.confidence, // detection confidence value
  ];
  const result = await pool.query(sql, values);
  return result.rows[0];
}

async function diseaseRemedy() {
  const sql = `
    SELECT * FROM disease_remedy ORDER BY disease_id, remedy_id
  `;
  const result = await pool.query(sql);
  return result.rows;
}

async function diseasePlants() {
<<<<<<< HEAD
  const sql = `
    SELECT * FROM diseases_plants ORDER BY disease_id, plant_id
  `;
  const result = await pool.query(sql);
=======
  const result = await pool.query(
    'SELECT * FROM diseases_plants ORDER BY disease_id, plant_id'
  );
>>>>>>> 840374f89285353e34bd926f9c85896dc03ac009
  return result.rows;
}

module.exports = {
  getDiseases,
  createDisease,
  updateDisease,
  deleteDisease,
  getRemedies,
  createRemedy,
  updateRemedy,
  deleteRemedy,
  getImages,
  addImage,
  getRemediesByDisease,
  getAllDiseasesWithRemedies,
  mapRemedyToDisease,
  unmapRemedyFromDisease,
  getDiseaseAnalysisResults,
  createDiseaseAnalysisResult,
  diseaseRemedy,
  diseasePlants,
};
