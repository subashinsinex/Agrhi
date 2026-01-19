// services/shopImageServices.js
const fs = require("fs");
const path = require("path");
const pool = require("../db/database");
const { v4: uuidv4 } = require("uuid");

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

    // Get the existing image_id and old image_url
    const retailerRes = await client.query(
      `SELECT r.image_id, i.image_url
       FROM retailers r
       LEFT JOIN images i ON r.image_id = i.image_id
       WHERE r.retailer_id = $1`,
      [retailerId]
    );

    if (retailerRes.rowCount === 0) {
      throw new Error("Retailer not found for given retailer_id");
    }

    const { image_id, image_url: oldImageUrl } = retailerRes.rows[0];

    if (!image_id) {
      throw new Error("No image_id found for this retailer");
    }

    const newImageUrl = `/uploads/shop_images/${file.filename}`;

    // Delete old file from disk if it exists
    if (oldImageUrl && oldImageUrl !== "no-image") {
      const absolutePath = path.join(__dirname, "..", oldImageUrl);
      fs.unlink(absolutePath, (err) => {
        if (err) {
          console.error("Error deleting old shop image:", err);
        }
      });
    }

    // Update the existing image row with the new image_url
    const imageUpdateRes = await client.query(
      "UPDATE images SET image_url = $2 WHERE image_id = $1 RETURNING *",
      [image_id, newImageUrl]
    );

    await client.query("COMMIT");

    return {
      image_id,
      image_url: newImageUrl,
      retailer: retailerRes.rows[0],
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};
