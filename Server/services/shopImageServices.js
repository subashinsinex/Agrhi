// Shop image services
const fs = require("fs");
const path = require("path");
const pool = require("../db/database");
const { compressImageInPlace } = require("../utils/imageCompressor");
const logger = require("../utils/logger");

// Save/replace shop image for retailer
exports.saveShopImageForRetailer = async (file, retailerId) => {
  logger.info("Saving shop image for retailer", {
    retailerId,
    filename: file.filename,
  });

  if (!file) {
    logger.error("No file provided to saveShopImageForRetailer");
    throw new Error("No file provided");
  }
  if (!retailerId) {
    logger.error("No retailerId provided to saveShopImageForRetailer");
    throw new Error("retailer_id is required");
  }

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // Get existing retailer image info
    const retailerRes = await client.query(
      `SELECT r.image_id, i.image_url
       FROM retailers r
       LEFT JOIN images i ON r.image_id = i.image_id
       WHERE r.retailer_id = $1`,
      [retailerId],
    );

    if (retailerRes.rowCount === 0) {
      logger.error("Retailer not found", { retailerId });
      throw new Error("Retailer not found for given retailer_id");
    }

    const { image_id, image_url: oldImageUrl } = retailerRes.rows[0];

    if (!image_id) {
      logger.error("No image_id found for retailer", { retailerId });
      throw new Error("No image_id found for this retailer");
    }

    const newImageUrl = `/uploads/shop_images/${file.filename}`;
    const fullPath = path.join(__dirname, "..", newImageUrl);

    logger.info("Compressing image", { fullPath });

    // Compress uploaded image
    await compressImageInPlace(fullPath);

    // Delete old image file if exists
    if (oldImageUrl && oldImageUrl !== "no-image") {
      const absolutePath = path.join(__dirname, "..", oldImageUrl);
      logger.info("Deleting old image", { oldImageUrl });

      fs.unlink(absolutePath, (err) => {
        if (err) {
          logger.error("Failed to delete old image", { absolutePath, err });
        } else {
          logger.info("Old image deleted successfully", oldImageUrl);
        }
      });
    }

    // Update image record with new URL
    const imageUpdateRes = await client.query(
      "UPDATE images SET image_url = $2 WHERE image_id = $1 RETURNING *",
      [image_id, newImageUrl],
    );

    await client.query("COMMIT");

    logger.info("Shop image saved successfully", {
      retailerId,
      image_id,
      newImageUrl,
      oldImageUrl,
    });

    return {
      image_id,
      image_url: newImageUrl,
      retailer: retailerRes.rows[0],
    };
  } catch (error) {
    logger.error("Error saving shop image", { retailerId, error });
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};
