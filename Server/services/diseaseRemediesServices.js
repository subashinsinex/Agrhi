// Disease, remedy, and analysis services
const pool = require("../db/database");
const { v4: uuidv4 } = require("uuid");
const logger = require("../utils/logger");

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

// Shared helper to update reference_table_versions timestamp
async function touchRefVersion(tableName) {
  await pool.query(
    "UPDATE reference_table_versions SET updated_at = CURRENT_TIMESTAMP WHERE ref_table_name = $1",
    [tableName],
  );
}

// ── DISEASES ──────────────────────────────────────────

// Get all diseases with linked plant names
async function getDiseases() {
  logger.info("getDiseases - Request");
  const sql = `
    SELECT 
      d.disease_id, d.name, d.severity,
      ARRAY_AGG(p.plant_id) AS plant_ids,
      ARRAY_AGG(p.plant_name) AS plant_names
    FROM diseases d
    JOIN diseases_plants dp ON d.disease_id = dp.disease_id
    JOIN plants p ON dp.plant_id = p.plant_id
    GROUP BY d.disease_id, d.name, d.severity
    ORDER BY d.disease_id
  `;
  const result = await pool.query(sql);
  logger.info("getDiseases - Success", { count: result.rowCount });
  return result.rows;
}

// Create disease and link to one or more plants
async function createDisease(disease) {
  logger.info("createDisease - Request", { name: disease.name });
  try {
    const plantIds = Array.isArray(disease.plant_id)
      ? disease.plant_id
      : [disease.plant_id];

    // Validate all plant IDs exist
    const plantRes = await pool.query(
      `SELECT plant_id FROM plants WHERE plant_id = ANY($1::uuid[])`,
      [plantIds],
    );
    if (plantRes.rowCount !== plantIds.length) {
      throw new Error("Invalid plant_id(s)");
    }

    const disease_id = await generateUniqueId(pool, "diseases", "disease_id");

    await pool.query(
      "INSERT INTO diseases (disease_id, name, severity) VALUES ($1, $2, $3)",
      [disease_id, disease.name, disease.severity],
    );

    // Link disease to all supplied plants
    for (const pid of plantIds) {
      await pool.query(
        "INSERT INTO diseases_plants (disease_id, plant_id) VALUES ($1, $2)",
        [disease_id, pid],
      );
    }

    await touchRefVersion("diseases");
    await touchRefVersion("diseases_plants");

    // Return full joined result
    const joinRes = await pool.query(
      `SELECT d.*, p.plant_id, p.plant_name
      FROM diseases d
      JOIN diseases_plants dp ON d.disease_id = dp.disease_id
      JOIN plants p ON dp.plant_id = p.plant_id
      WHERE d.disease_id = $1`,
      [disease_id],
    );

    logger.info("createDisease - Success", { disease_id });
    return joinRes.rows;
  } catch (error) {
    logger.error("createDisease - Error:", error);
    throw error;
  }
}

// Update disease fields and replace plant links if provided
async function updateDisease(disease_id, updated) {
  logger.info("updateDisease - Request", { disease_id });
  try {
    // Validate new plant IDs if provided
    if (updated.plant_id) {
      const plantIds = Array.isArray(updated.plant_id)
        ? updated.plant_id
        : [updated.plant_id];
      const plantRes = await pool.query(
        `SELECT plant_id FROM plants WHERE plant_id = ANY($1::uuid[])`,
        [plantIds],
      );
      if (plantRes.rowCount !== plantIds.length) {
        throw new Error("Invalid plant_id(s)");
      }
    }

    await pool.query(
      "UPDATE diseases SET name=$1, severity=$2 WHERE disease_id=$3",
      [updated.name, updated.severity, disease_id],
    );

    // Replace plant links if new ones are provided
    if (updated.plant_id) {
      await pool.query("DELETE FROM diseases_plants WHERE disease_id = $1", [
        disease_id,
      ]);
      const plantIds = Array.isArray(updated.plant_id)
        ? updated.plant_id
        : [updated.plant_id];
      for (const pid of plantIds) {
        await pool.query(
          "INSERT INTO diseases_plants (disease_id, plant_id) VALUES ($1, $2)",
          [disease_id, pid],
        );
      }
    }

    await touchRefVersion("diseases");
    await touchRefVersion("diseases_plants");

    const joinRes = await pool.query(
      `SELECT d.*, p.plant_id, p.plant_name
      FROM diseases d
      JOIN diseases_plants dp ON d.disease_id = dp.disease_id
      JOIN plants p ON dp.plant_id = p.plant_id
      WHERE d.disease_id = $1`,
      [disease_id],
    );

    logger.info("updateDisease - Success", { disease_id });
    return joinRes.rows;
  } catch (error) {
    logger.error("updateDisease - Error:", error);
    throw error;
  }
}

// Delete disease and all related links
async function deleteDisease(disease_id) {
  logger.info("deleteDisease - Request", { disease_id });
  try {
    await pool.query("DELETE FROM disease_remedy WHERE disease_id = $1", [
      disease_id,
    ]);
    await pool.query("DELETE FROM diseases_plants WHERE disease_id = $1", [
      disease_id,
    ]);
    const result = await pool.query(
      "DELETE FROM diseases WHERE disease_id = $1 RETURNING *",
      [disease_id],
    );
    await touchRefVersion("diseases");
    await touchRefVersion("diseases_plants");
    logger.info("deleteDisease - Success", { disease_id });
    return result.rows[0];
  } catch (error) {
    logger.error("deleteDisease - Error:", error);
    throw error;
  }
}

// ── REMEDIES ──────────────────────────────────────────

// Get all remedies with mapped disease IDs
async function getRemedies() {
  logger.info("getRemedies - Request");
  const sql = `
    SELECT r.*, array_agg(dr.disease_id) AS mapped_diseases
    FROM remedies r
    LEFT JOIN disease_remedy dr ON r.remedy_id = dr.remedy_id
    GROUP BY r.remedy_id
    ORDER BY r.remedy_id
  `;
  const result = await pool.query(sql);
  logger.info("getRemedies - Success", { count: result.rowCount });
  return result.rows;
}

// Create remedy and link to one or more diseases
async function createRemedy(remedy, diseaseIds) {
  logger.info("createRemedy - Request", { remedy: remedy.remedy });
  try {
    // Validate all disease IDs exist
    if (diseaseIds && diseaseIds.length) {
      const res = await pool.query(
        `SELECT disease_id FROM diseases WHERE disease_id = ANY($1::uuid[])`,
        [diseaseIds],
      );
      if (res.rowCount !== diseaseIds.length) {
        throw new Error("Invalid disease_id(s)");
      }
    }

    const remedy_id = await generateUniqueId(pool, "remedies", "remedy_id");

    const remedyRes = await pool.query(
      `INSERT INTO remedies (remedy_id, remedy, prevention) VALUES ($1, $2, $3) RETURNING *`,
      [remedy_id, remedy.remedy, remedy.prevention],
    );

    // Link remedy to all supplied diseases
    if (diseaseIds && diseaseIds.length) {
      for (const did of diseaseIds) {
        await pool.query(
          "INSERT INTO disease_remedy (disease_id, remedy_id) VALUES ($1, $2)",
          [did, remedy_id],
        );
      }
    }

    await touchRefVersion("remedies");
    logger.info("createRemedy - Success", { remedy_id });
    return { remedy: remedyRes.rows[0], linkedDiseases: diseaseIds };
  } catch (error) {
    logger.error("createRemedy - Error:", error);
    throw error;
  }
}

// Update remedy fields
async function updateRemedy(remedy_id, updated) {
  logger.info("updateRemedy - Request", { remedy_id });
  try {
    const result = await pool.query(
      "UPDATE remedies SET remedy=$1, prevention=$2 WHERE remedy_id=$3 RETURNING *",
      [updated.remedy, updated.prevention, remedy_id],
    );
    logger.info("updateRemedy - Success", { remedy_id });
    return result.rows[0];
  } catch (error) {
    logger.error("updateRemedy - Error:", error);
    throw error;
  }
}

// Delete remedy by ID
async function deleteRemedy(remedy_id) {
  logger.info("deleteRemedy - Request", { remedy_id });
  try {
    const result = await pool.query(
      "DELETE FROM remedies WHERE remedy_id=$1 RETURNING *",
      [remedy_id],
    );
    await touchRefVersion("remedies");
    logger.info("deleteRemedy - Success", { remedy_id });
    return result.rows[0];
  } catch (error) {
    logger.error("deleteRemedy - Error:", error);
    throw error;
  }
}

// ── DISEASE-REMEDY MAPPING ─────────────────────────────

// Get all remedies for a specific disease
async function getRemediesByDisease(diseaseid) {
  logger.info("getRemediesByDisease - Request", { diseaseid });
  const result = await pool.query(
    `SELECT r.* FROM remedies r
    JOIN disease_remedy dr ON r.remedy_id = dr.remedy_id
    WHERE dr.disease_id = $1
    ORDER BY r.remedy_id`,
    [diseaseid],
  );
  logger.info("getRemediesByDisease - Success", {
    diseaseid,
    count: result.rowCount,
  });
  return result.rows;
}

// Get all diseases with their linked remedies
async function getAllDiseasesWithRemedies() {
  logger.info("getAllDiseasesWithRemedies - Request");
  const result = await pool.query(`
    SELECT 
      d.disease_id, d.name AS disease_name,
      r.remedy_id, r.remedy, r.prevention
    FROM diseases d
    LEFT JOIN disease_remedy dr ON d.disease_id = dr.disease_id
    LEFT JOIN remedies r ON dr.remedy_id = r.remedy_id
    ORDER BY d.disease_id, r.remedy_id
  `);
  logger.info("getAllDiseasesWithRemedies - Success", {
    count: result.rowCount,
  });
  return result.rows;
}

// Map a remedy to a disease
async function mapRemedyToDisease(disease_id, remedy_id) {
  logger.info("mapRemedyToDisease - Request", { disease_id, remedy_id });
  const result = await pool.query(
    "INSERT INTO disease_remedy (disease_id, remedy_id) VALUES ($1, $2) RETURNING *",
    [disease_id, remedy_id],
  );
  await touchRefVersion("disease_remedy");
  logger.info("mapRemedyToDisease - Success", { disease_id, remedy_id });
  return result.rows[0];
}

// Remove remedy mapping from a disease
async function unmapRemedyFromDisease(disease_id, remedy_id) {
  logger.info("unmapRemedyFromDisease - Request", { disease_id, remedy_id });
  const result = await pool.query(
    "DELETE FROM disease_remedy WHERE disease_id=$1 AND remedy_id=$2 RETURNING *",
    [disease_id, remedy_id],
  );
  await touchRefVersion("disease_remedy");
  logger.info("unmapRemedyFromDisease - Success", { disease_id, remedy_id });
  return result.rows[0];
}

// ── IMAGES ────────────────────────────────────────────

// Get all images
async function getImages() {
  logger.info("getImages - Request");
  const result = await pool.query(
    "SELECT image_id, image_url FROM images ORDER BY image_id",
  );
  logger.info("getImages - Success", { count: result.rowCount });
  return result.rows;
}

// Add new image record
async function addImage(image) {
  logger.info("addImage - Request");
  const image_id = await generateUniqueId(pool, "images", "image_id");
  const result = await pool.query(
    "INSERT INTO images (image_id, image_url) VALUES ($1, $2) RETURNING *",
    [image_id, image.image_url],
  );
  logger.info("addImage - Success", { image_id });
  return result.rows[0];
}

// ── DISEASE ANALYSIS RESULTS ──────────────────────────

// Get disease analysis results with optional filters
async function getDiseaseAnalysisResults(filters) {
  logger.info("getDiseaseAnalysisResults - Request", { filters });

  let sql = `
    SELECT dar.id,
           ud.name AS user_name, ud.user_id,
           p.plant_name, i.image_url,
           d.name AS disease_name,
           r.remedy, dar.confidence
    FROM disease_analysis_results dar
    JOIN user_details ud ON dar.user_id = ud.user_id
    JOIN plants p ON dar.plant_id = p.plant_id
    JOIN images i ON dar.image_id = i.image_id
    JOIN diseases d ON dar.disease_id = d.disease_id
    JOIN disease_remedy dr ON dar.disease_id = dr.disease_id
    JOIN remedies r ON dr.remedy_id = r.remedy_id
  `;

  const clauses = [];
  const values = [];
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
  logger.info("getDiseaseAnalysisResults - Success", {
    count: result.rowCount,
  });
  return result.rows;
}

// Save a new disease analysis result entry
async function createDiseaseAnalysisResult(entry) {
  logger.info("createDiseaseAnalysisResult - Request", {
    user_id: entry.user_id,
    disease_id: entry.disease_id,
  });
  const id = await generateUniqueId(pool, "disease_analysis_results", "id");
  const result = await pool.query(
    `INSERT INTO disease_analysis_results
      (id, user_id, plant_id, image_id, disease_id, confidence, created_at)
     VALUES ($1, $2, $3, $4, $5, $6, NOW())
     RETURNING *`,
    [
      id,
      entry.user_id,
      entry.image_id,
      entry.disease_id,
      entry.remedy_id,
      entry.confidence,
    ],
  );
  logger.info("createDiseaseAnalysisResult - Success", { id });
  return result.rows[0];
}

// Get all disease-remedy mappings
async function diseaseRemedy() {
  logger.info("diseaseRemedy - Request");
  const result = await pool.query(
    "SELECT * FROM disease_remedy ORDER BY disease_id, remedy_id",
  );
  logger.info("diseaseRemedy - Success", { count: result.rowCount });
  return result.rows;
}

// Get all disease-plant mappings
async function diseasePlants() {
  logger.info("diseasePlants - Request");
  const result = await pool.query(
    "SELECT * FROM diseases_plants ORDER BY disease_id, plant_id",
  );
  logger.info("diseasePlants - Success", { count: result.rowCount });
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
