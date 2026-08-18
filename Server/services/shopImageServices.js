// Shop image services
const fs = require("fs");
const path = require("path");

const { query } = require("../db/database");
const { compressImageInPlace } = require("../utils/imageCompressor");
const logger = require("../utils/logger");

// Save/replace shop image for retailer
exports.saveShopImageForRetailer = async (file, retailerId) => {
  if (!file) {
    logger.error("No file provided to saveShopImageForRetailer");
    throw new Error("No file provided");
  }

  if (!retailerId) {
    logger.error("No retailerId provided to saveShopImageForRetailer");
    throw new Error("retailer_id is required");
  }

  logger.info("Saving shop image for retailer", {
    retailerId,
    filename: file.filename,
  });

  const newImageUrl = `/uploads/shop_images/${file.filename}`;

  const fullPath = path.join(
    __dirname,
    "..",
    "uploads",
    "shop_images",
    file.filename,
  );

  try {
    // ---------------------------------------------------------
    // 1. Get existing retailer image
    // ---------------------------------------------------------

    const retailerRes = await query(
      `
      SELECT
        r.image_id,
        i.image_url
      FROM retailers r
      LEFT JOIN images i
        ON r.image_id = i.image_id
      WHERE r.retailer_id = $1
      `,
      [retailerId],
    );

    if (retailerRes.rowCount === 0) {
      logger.error("Retailer not found", {
        retailerId,
      });

      throw new Error("Retailer not found for given retailer_id");
    }

    const { image_id, image_url: oldImageUrl } = retailerRes.rows[0];

    if (!image_id) {
      logger.error("No image_id found for retailer", {
        retailerId,
      });

      throw new Error("No image_id found for this retailer");
    }

    // ---------------------------------------------------------
    // 2. Make sure uploaded file exists
    // ---------------------------------------------------------

    if (!fs.existsSync(fullPath)) {
      logger.error("Uploaded shop image file not found", {
        fullPath,
      });

      throw new Error("Uploaded image file not found");
    }

    // ---------------------------------------------------------
    // 3. Compress new image
    // ---------------------------------------------------------

    logger.info("Compressing shop image", {
      fullPath,
    });

    await compressImageInPlace(fullPath);

    logger.info("Shop image compressed successfully", {
      retailerId,
      filename: file.filename,
    });

    // ---------------------------------------------------------
    // 4. Update DB
    // ---------------------------------------------------------

    const imageUpdateRes = await query(
      `
      UPDATE images
      SET image_url = $2
      WHERE image_id = $1
      RETURNING image_id, image_url
      `,
      [image_id, newImageUrl],
    );

    if (imageUpdateRes.rowCount === 0) {
      throw new Error("Failed to update shop image record");
    }

    // ---------------------------------------------------------
    // 5. Delete OLD image only after DB update succeeds
    // ---------------------------------------------------------

    if (
      oldImageUrl &&
      oldImageUrl !== "no-image" &&
      oldImageUrl !== newImageUrl
    ) {
      const oldImagePath = path.join(
        __dirname,
        "..",
        oldImageUrl.replace(/^\/+/, ""),
      );

      try {
        if (fs.existsSync(oldImagePath)) {
          await fs.promises.unlink(oldImagePath);

          logger.info("Old shop image deleted successfully", {
            retailerId,
            oldImageUrl,
          });
        }
      } catch (deleteError) {
        // Do not fail upload just because old file could not be deleted.
        logger.warn("Failed to delete old shop image", {
          retailerId,
          oldImageUrl,
          error: deleteError.message,
        });
      }
    }

    // ---------------------------------------------------------
    // SUCCESS
    // ---------------------------------------------------------

    logger.info("Shop image saved successfully", {
      retailerId,
      image_id,
      newImageUrl,
      oldImageUrl,
    });

    return {
      image_id,
      image_url: newImageUrl,
      retailer: {
        retailer_id: retailerId,
        image_id,
        image_url: newImageUrl,
      },
    };
  } catch (error) {
    logger.error("Error saving shop image", {
      retailerId,
      message: error.message,
      stack: error.stack,
    });

    // Remove newly uploaded file if operation failed.
    try {
      if (fs.existsSync(fullPath)) {
        await fs.promises.unlink(fullPath);
      }
    } catch (cleanupError) {
      logger.warn("Failed to clean up unsuccessful shop image upload", {
        fullPath,
        error: cleanupError.message,
      });
    }

    throw error;
  }
};
