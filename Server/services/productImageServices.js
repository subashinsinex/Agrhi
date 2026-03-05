// Product image services (retail + farm)
const fs = require("fs");
const path = require("path");
const { query } = require("../db/database");
const { compressImageInPlace } = require("../utils/imageCompressor");
const logger = require("../utils/logger");

// Shared UUID validator
const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

// Shared input validator for file and productId
function validateInput(file, productId, context) {
  if (!file) {
    logger.error(`${context} - No file provided`);
    throw new Error("No file provided");
  }
  if (!productId || typeof productId !== "string") {
    logger.error(`${context} - Invalid product_id`, { productId });
    throw new Error("Valid product_id string (UUID) is required");
  }
  if (!uuidRegex.test(productId)) {
    logger.error(`${context} - Invalid UUID format`, { productId });
    throw new Error("Invalid product_id: must be valid UUID format");
  }
  if (!file.filename || typeof file.filename !== "string") {
    logger.error(`${context} - Invalid file.filename`, {
      filename: file.filename,
    });
    throw new Error("Uploaded file is missing filename");
  }
}

// Save/replace image for retail product
exports.saveProductImage = async (file, productId) => {
  validateInput(file, productId, "saveProductImage");

  const newImageUrl = `/uploads/product_image/${String(file.filename)}`;
  logger.info("saveProductImage - Start", { productId, newImageUrl });

  try {
    // Fetch current product image info
    const productRes = await query(
      `SELECT 
         rp.image_id,
         i.image_url
       FROM retailer_products rp
       LEFT JOIN images i ON rp.image_id = i.image_id
       WHERE rp.product_id = $1::uuid`,
      [productId],
    );

    logger.info("saveProductImage - Product fetched", {
      productId,
      rows: productRes.rows,
    });

    if (productRes.rowCount === 0) {
      throw new Error("Product not found for given product_id");
    }

    const { image_id, image_url: oldImageUrl } = productRes.rows[0];

    if (!image_id) {
      throw new Error("Product does not have an associated image_id");
    }

    // Compress new image
    const fullPath = path.join(__dirname, "..", newImageUrl);
    logger.info("saveProductImage - Compressing image", { fullPath });
    await compressImageInPlace(fullPath);

    // Delete old image file if exists
    if (oldImageUrl && oldImageUrl !== "no-image") {
      const absolutePath = path.join(__dirname, "..", oldImageUrl);
      logger.info("saveProductImage - Deleting old image", { absolutePath });
      fs.unlink(absolutePath, (err) => {
        if (err) {
          logger.error("saveProductImage - Failed to delete old image", {
            absolutePath,
            err,
          });
        } else {
          logger.info("saveProductImage - Old image deleted", { absolutePath });
        }
      });
    }

    // Update image record with new URL
    const imageUpdateRes = await query(
      "UPDATE images SET image_url = $2::text WHERE image_id = $1::uuid RETURNING *",
      [image_id, newImageUrl],
    );

    if (imageUpdateRes.rowCount === 0) {
      throw new Error("Failed to update image record");
    }

    logger.info("saveProductImage - Done", {
      productId,
      image_id,
      image_url: imageUpdateRes.rows[0].image_url,
    });

    return {
      image_id,
      image_url: imageUpdateRes.rows[0].image_url,
      product: productRes.rows[0],
    };
  } catch (error) {
    logger.error("saveProductImage - Error:", error);
    throw error;
  }
};

// Save/replace image for farm product
exports.saveFarmProductImage = async (file, productId) => {
  validateInput(file, productId, "saveFarmProductImage");

  const newImageUrl = `/uploads/product_image/${String(file.filename)}`;
  logger.info("saveFarmProductImage - Start", { productId, newImageUrl });

  try {
    // Fetch current farm product image info
    const productRes = await query(
      `SELECT 
         fp.image_id,
         i.image_url
       FROM farmer_products fp
       LEFT JOIN images i ON fp.image_id = i.image_id
       WHERE fp.product_id = $1::uuid`,
      [productId],
    );

    logger.info("saveFarmProductImage - Farm product fetched", {
      productId,
      rows: productRes.rows,
    });

    if (productRes.rowCount === 0) {
      throw new Error("Farm product not found for given product_id");
    }

    const { image_id, image_url: oldImageUrl } = productRes.rows[0];

    if (!image_id) {
      throw new Error("Farm product does not have an associated image_id");
    }

    // Compress new image
    const fullPath = path.join(__dirname, "..", newImageUrl);
    logger.info("saveFarmProductImage - Compressing image", { fullPath });
    await compressImageInPlace(fullPath);

    // Delete old image file if exists
    if (oldImageUrl && oldImageUrl !== "no-image") {
      const absolutePath = path.join(__dirname, "..", oldImageUrl);
      logger.info("saveFarmProductImage - Deleting old image", {
        absolutePath,
      });
      fs.unlink(absolutePath, (err) => {
        if (err) {
          logger.error("saveFarmProductImage - Failed to delete old image", {
            absolutePath,
            err,
          });
        } else {
          logger.info("saveFarmProductImage - Old image deleted", {
            absolutePath,
          });
        }
      });
    }

    // Update image record with new URL
    const imageUpdateRes = await query(
      "UPDATE images SET image_url = $2::text WHERE image_id = $1::uuid RETURNING *",
      [image_id, newImageUrl],
    );

    if (imageUpdateRes.rowCount === 0) {
      throw new Error("Failed to update farm image record");
    }

    logger.info("saveFarmProductImage - Done", {
      productId,
      image_id,
      image_url: imageUpdateRes.rows[0].image_url,
    });

    return {
      image_id,
      image_url: imageUpdateRes.rows[0].image_url,
      product: productRes.rows[0],
    };
  } catch (error) {
    logger.error("saveFarmProductImage - Error:", error);
    throw error;
  }
};
