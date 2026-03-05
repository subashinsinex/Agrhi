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
  logger.info("Generated unique ID", id);
  return id;
}

// Batch upload disease analyses from mobile app
async function batchUploadAnalyses(userId, analyses) {
  const uploadedIds = [];
  logger.info("Starting batch upload analyses", {
    userId,
    analysesCount: analyses.length,
  });

  try {
    const client = await pool.connect();
    await client.query("BEGIN");

    try {
      for (const analysis of analyses) {
        // Validate required fields
        if (
          !analysis.id ||
          !analysis.user_id ||
          !analysis.plant_id ||
          !analysis.disease_id ||
          analysis.confidence === undefined
        ) {
          logger.error("Invalid analysis data", analysis);
          throw new Error(`Invalid analysis data: ${JSON.stringify(analysis)}`);
        }

        // Create image placeholder if image_id is provided
        if (analysis.image_id) {
          logger.info("Creating image placeholder", analysis.image_id);
          const existingImage = await client.query(
            "SELECT image_id FROM images WHERE image_id = $1",
            [analysis.image_id],
          );

          if (existingImage.rows.length === 0) {
            await client.query(
              `INSERT INTO images (image_id, image_url) 
               VALUES ($1, $2)`,
              [analysis.image_id, "/uploads/images/pending"],
            );
            logger.info("Image placeholder created", analysis.image_id);
          } else {
            logger.info("Image already exists", analysis.image_id);
          }
        }

        // Insert/update analysis (upsert)
        await client.query(
          `INSERT INTO disease_analysis_results 
          (id, user_id, plant_id, image_id, disease_id, confidence, created_at)
          VALUES ($1, $2, $3, $4, $5, $6, $7)
          ON CONFLICT (id) DO UPDATE SET
            confidence = EXCLUDED.confidence,
            disease_id = EXCLUDED.disease_id`,
          [
            analysis.id,
            analysis.user_id,
            analysis.plant_id,
            analysis.image_id,
            analysis.disease_id,
            analysis.confidence,
            analysis.created_at || new Date().toISOString(),
          ],
        );

        uploadedIds.push(analysis.id);
      }

      await client.query("COMMIT");
      logger.info("Batch upload completed", {
        userId,
        uploadedCount: uploadedIds.length,
        uploadedIds,
      });

      return {
        success: true,
        uploaded_ids: uploadedIds,
        count: uploadedIds.length,
      };
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error("Batch upload transaction error", { userId, error });
    if (client) await client.query("ROLLBACK");
    throw error;
  }
}

// Get analysis changes since timestamp
async function getAnalysisChanges(userId, since = null) {
  logger.info("Fetching analysis changes", { userId, since });

  let query;
  let params;

  if (since) {
    query = `
      SELECT 
        dar.id,
        dar.user_id,
        dar.plant_id,
        dar.image_id,
        dar.disease_id,
        dar.confidence,
        dar.created_at,
        i.image_url as server_image_url
      FROM disease_analysis_results dar
      LEFT JOIN images i ON dar.image_id = i.image_id
      WHERE dar.user_id = $1 AND dar.created_at > $2
      ORDER BY dar.created_at DESC
    `;
    params = [userId, since];
  } else {
    query = `
      SELECT 
        dar.id,
        dar.user_id,
        dar.plant_id,
        dar.image_id,
        dar.disease_id,
        dar.confidence,
        dar.created_at,
        i.image_url as server_image_url
      FROM disease_analysis_results dar
      LEFT JOIN images i ON dar.image_id = i.image_id
      WHERE dar.user_id = $1
      ORDER BY dar.created_at DESC
    `;
    params = [userId];
  }

  const result = await pool.query(query, params);
  logger.info("Fetched analysis changes", {
    userId,
    count: result.rows.length,
  });

  return {
    analyses: result.rows,
    server_timestamp: new Date().toISOString(),
  };
}

// Save uploaded image metadata
async function saveImageMetadata(imageId, imageUrl) {
  logger.info("Saving image metadata", { imageId, imageUrl });

  await pool.query(
    `INSERT INTO images (image_id, image_url)
     VALUES ($1, $2)
     ON CONFLICT (image_id) DO UPDATE SET
       image_url = EXCLUDED.image_url`,
    [imageId, imageUrl],
  );

  logger.info("Image metadata saved", { imageId });
}

module.exports = {
  generateUniqueId,
  batchUploadAnalyses,
  getAnalysisChanges,
  saveImageMetadata,
};
