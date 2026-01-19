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

    // Get current image_id and image_url (if any)
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

    const { image_id: existingImageId, image_url: oldImageUrl } =
      retailerRes.rows[0];
    const newImageUrl = `/uploads/shop_images/${file.filename}`;

    let image_id;

    if (!existingImageId) {
      // No image yet: create image row and set retailers.image_id
      image_id = uuidv4();

      await client.query(
        "INSERT INTO images (image_id, image_url) VALUES ($1, $2)",
        [image_id, newImageUrl]
      );

      const updateRes = await client.query(
        "UPDATE retailers SET image_id = $2 WHERE retailer_id = $1 RETURNING *",
        [retailerId, image_id]
      );

      await client.query("COMMIT");
      return {
        image_id,
        image_url: newImageUrl,
        retailer: updateRes.rows[0],
      };
    }

    // Retailer already has image: delete old file and update same image_id
    image_id = existingImageId;

    if (oldImageUrl && oldImageUrl !== "no-image") {
      const absolutePath = path.join(__dirname, "..", oldImageUrl);
      fs.unlink(absolutePath, (err) => {
        if (err) {
          console.error("Error deleting old shop image:", err);
        }
      });
    }

    const imageUpdateRes = await client.query(
      "UPDATE images SET image_url = $2 WHERE image_id = $1 RETURNING *",
      [image_id, newImageUrl]
    );

    await client.query("COMMIT");
    return {
      image_id,
      image_url: imageUpdateRes.rows[0].image_url,
      retailer: retailerRes.rows[0],
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};
