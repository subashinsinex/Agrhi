const pool = require("../db/database");

// Utility: Unique random 5-digit ID
async function generateUniqueId(tableName, idField) {
  let newId, exists, sql;
  do {
    newId = Math.floor(10000 + Math.random() * 90000);
    sql = `SELECT 1 FROM ${tableName} WHERE ${idField} = $1`;
    const check = await pool.query(sql, [newId]);
    exists = check.rowCount > 0;
  } while (exists);
  return newId;
}

// --- DISEASES ---
async function getDiseases() {
  const sql = `
    SELECT d.*, p.plant_name
    FROM diseases d
    JOIN plants p ON d.plant_id = p.plant_id
    ORDER BY d.disease_id
  `;
  const result = await pool.query(sql);
  return result.rows;
}

async function createDisease(disease) {
  // FK validation: Check plant exists
  const checkPlantSql = "SELECT * FROM plants WHERE plant_id = $1";
  const plantRes = await pool.query(checkPlantSql, [disease.plant_id]);
  if (plantRes.rowCount === 0) throw new Error("Invalid plantid");
  // Generate unique diseaseid
  const disease_id = await generateUniqueId("diseases", "disease_id");
  // Insert
  const insertSql =
    "INSERT INTO diseases (disease_id, name, severity, plant_id) VALUES ($1, $2, $3, $4) RETURNING *";
  const insertVals = [
    disease_id,
    disease.name,
    disease.severity,
    disease.plant_id,
  ];
  await pool.query(insertSql, insertVals);
  // Return joined row
  const joinSql = `
    SELECT d.*, p.plant_name
    FROM diseases d
    JOIN plants p ON d.plant_id = p.plant_id
    WHERE d.disease_id = $1
  `;
  const joinRes = await pool.query(joinSql, [disease_id]);
  return joinRes.rows[0];
}

async function updateDisease(disease_id, updated) {
  // FK validation: Check plant exists (if updating plantid)
  if (updated.plant_id) {
    const checkPlantSql = "SELECT * FROM plants WHERE plant_id = $1";
    const plantRes = await pool.query(checkPlantSql, [updated.plant_id]);
    if (plantRes.rowCount === 0) throw new Error("Invalid plantid");
  }
  // Update
  const sql =
    "UPDATE diseases SET name=$1, severity=$2, plant_id=$3 WHERE disease_id=$4 RETURNING *";
  const values = [updated.name, updated.severity, updated.plant_id, disease_id];
  await pool.query(sql, values);
  // Return joined row
  const joinSql = `
    SELECT d.*, p.plant_name
    FROM diseases d
    JOIN plants p ON d.plant_id = p.plant_id
    WHERE d.disease_id = $1
  `;
  const joinRes = await pool.query(joinSql, [disease_id]);
  return joinRes.rows[0];
}

async function deleteDisease(disease_id) {
  const sql = "DELETE FROM diseases WHERE disease_id=$1 RETURNING *";
  const result = await pool.query(sql, [disease_id]);
  return result.rows[0];
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

// Create a new remedy (with unique 5-digit random remedyid)
async function createRemedy(remedy) {
  const remedy_id = await generateUniqueId("remedies", "remedy_id");
  const sql =
    "INSERT INTO remedies (remedy_id, remedy, prevention) VALUES ($1, $2, $3) RETURNING *";
  const values = [remedy_id, remedy.remedy, remedy.prevention];
  const result = await pool.query(sql, values);
  return result.rows[0];
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

async function mapRemedyToDisease(disease_id, remedy_id) {
  // FK integrity checks are recommended but not required here
  const sql =
    "INSERT INTO disease_remedy (disease_id, remedy_id) VALUES ($1, $2) RETURNING *";
  const result = await pool.query(sql, [disease_id, remedy_id]);
  return result.rows[0];
}

async function unmapRemedyFromDisease(disease_id, remedy_id) {
  const sql =
    "DELETE FROM disease_remedy WHERE disease_id=$1 AND remedy_id=$2 RETURNING *";
  const result = await pool.query(sql, [disease_id, remedy_id]);
  return result.rows[0];
}

// --- IMAGES (Read Only) ---
async function getImages() {
  const sql =
    "SELECT image_id, crop_id, image_url FROM images ORDER BY image_id";
  const result = await pool.query(sql);
  return result.rows;
}

// Add a new image (with unique 5-digit imageid)
async function addImage(image) {
  // Validate cropid exists (FK from images to crops)
  const cropCheck = await pool.query(
    "SELECT user_crop_id FROM user_crops WHERE user_crop_id = $1",
    [image.crop_id]
  );
  if (cropCheck.rowCount === 0) throw new Error("Invalid cropid");
  // Generate unique imageid
  const image_id = await generateUniqueId("images", "image_id");
  // Insert image
  const sql =
    "INSERT INTO images (image_id, crop_id, image_url) VALUES ($1, $2, $3) RETURNING *";
  const values = [image_id, image.crop_id, image.image_url];
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
    JOIN user_crops uc ON dar.crop_id = uc.user_crop_id
    JOIN plants p ON uc.plant_id = p.plant_id
    JOIN images i ON dar.image_id = i.image_id
    JOIN diseases d ON dar.disease_id = d.disease_id
    JOIN disease_remedy dr ON dar.disease_id = dr.disease_id AND dar.remedy_id = dr.remedy_id
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
      (id, user_id, crop_id, image_id, disease_id, remedy_id, confidence, created_at)
    VALUES
      ($1, $2, $3, $4, $5, $6, $7, NOW())
    RETURNING *
  `;
  const values = [
    id,
    entry.user_id, // maps to userdetails/userauth
    entry.crop_id, // links to user_crops
    entry.image_id, // links to images
    entry.disease_id, // links to diseases
    entry.remedy_id, // links to remedies (and validated by disease_remedy mapping)
    entry.confidence, // detection confidence value
  ];
  const result = await pool.query(sql, values);
  return result.rows[0];
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
  mapRemedyToDisease,
  unmapRemedyFromDisease,
  getDiseaseAnalysisResults,
  createDiseaseAnalysisResult,
};
