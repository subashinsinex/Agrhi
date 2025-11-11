const db = require("../db/database");
const { v4: uuidv4 } = require("uuid");

/**
 * Generate a unique UUID for a table
 */
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

/**
 * Batch upload disease analyses from mobile app
 * Creates image placeholders if they don't exist
 */
async function batchUploadAnalyses(userId, analyses) {
  const uploadedIds = [];
  const client = await db.connect();

  try {
    await client.query("BEGIN");

    for (const analysis of analyses) {
      // Validate required fields
      if (
        !analysis.id ||
        !analysis.user_id ||
        !analysis.plant_id ||
        !analysis.disease_id ||
        analysis.confidence === undefined
      ) {
        throw new Error(`Invalid analysis data: ${JSON.stringify(analysis)}`);
      }

      // Create image placeholder if image_id is provided
      if (analysis.image_id) {
        console.log(`🖼️ Creating placeholder for image: ${analysis.image_id}`);
        try {
          // Check if image already exists
          const existingImage = await client.query(
            "SELECT image_id FROM images WHERE image_id = $1",
            [analysis.image_id]
          );

          if (existingImage.rows.length === 0) {
            // Insert placeholder - actual image will be uploaded separately
            await client.query(
              `INSERT INTO images (image_id, image_url) 
               VALUES ($1, $2)`,
              [analysis.image_id, "/uploads/images/pending"]
            );
            console.log(`✅ Image placeholder created: ${analysis.image_id}`);
          } else {
            console.log(`ℹ️ Image already exists: ${analysis.image_id}`);
          }
        } catch (imgError) {
          console.error(`❌ Image placeholder creation failed:`, imgError);
          throw imgError;
        }
      }

      // Insert the analysis
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
        ]
      );

      uploadedIds.push(analysis.id);
    }

    await client.query("COMMIT");
    console.log(
      `✅ Uploaded ${uploadedIds.length} analyses for user ${userId}`
    );

    return {
      success: true,
      uploaded_ids: uploadedIds,
      count: uploadedIds.length,
    };
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("❌ Batch upload transaction error:", error);
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Get analysis changes for a user since a timestamp
 */
async function getAnalysisChanges(userId, since = null) {
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

  const result = await db.query(query, params);

  // Get deleted IDs (optional - for tracking deletions)
  let deletedIds = [];
  try {
    const deletedResult = await db.query(
      `SELECT id FROM deleted_analyses 
       WHERE user_id = $1 AND deleted_at > $2`,
      [userId, since || "1970-01-01"]
    );
    deletedIds = deletedResult.rows.map((r) => r.id);
  } catch (err) {
    console.log("No deleted_analyses table found (optional)");
  }

  console.log(`📦 Retrieved ${result.rows.length} analyses for user ${userId}`);

  return {
    analyses: result.rows,
    deleted_ids: deletedIds,
    server_timestamp: new Date().toISOString(),
  };
}

/**
 * Save uploaded image file and update database with server URL
 */
async function saveImageMetadata(imageId, imageUrl) {
  console.log(`💾 Saving image: ${imageId} -> ${imageUrl}`);

  await db.query(
    `INSERT INTO images (image_id, image_url)
     VALUES ($1, $2)
     ON CONFLICT (image_id) DO UPDATE SET
       image_url = EXCLUDED.image_url`,
    [imageId, imageUrl]
  );

  console.log(`✅ Image saved: ${imageId}`);
}

module.exports = {
  generateUniqueId,
  batchUploadAnalyses,
  getAnalysisChanges,
  saveImageMetadata,
};
