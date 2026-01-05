// services/shopImageServices.js
const path = require("path");
const pool = require("../db/database");
const { v4: uuidv4 } = require("uuid");

/**
 * Save shop image: insert into images + update retailers.image_id
 * Input:
 *   file      -> multer file object
 *   retailerId -> retailer_id (UUID)
 */
exports.saveShopImageForRetailer = async (file, retailerId) => {
  if (!file) {
    throw new Error("No file provided");
  }
  if (!retailerId) {
    throw new Error("retailer_id is required");
  }

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const image_id = uuidv4();
    const image_url = `/uploads/shop_images/${file.filename}`;

    // 1) Insert into images table
    await client.query(
      "INSERT INTO images (image_id, image_url) VALUES ($1, $2)",
      [image_id, image_url]
    );

    // 2) Update retailers table with this image_id
    const updateRes = await client.query(
      "UPDATE retailers SET image_id = $2 WHERE retailer_id = $1 RETURNING *",
      [retailerId, image_id]
    );

    if (updateRes.rowCount === 0) {
      throw new Error("Retailer not found for given retailer_id");
    }

    await client.query("COMMIT");

    return {
      image_id,
      image_url,
      retailer: updateRes.rows[0],
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};
