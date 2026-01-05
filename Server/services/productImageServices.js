// services/productImageServices.js
const pool = require("../db/database");
const { v4: uuidv4 } = require("uuid");

/**
 * Save product image:
 *  - insert into images
 *  - update retailer_products.image_id
 * Input:
 *   file      -> multer file object
 *   productId -> product_id (UUID)
 */
exports.saveProductImage = async (file, productId) => {
  if (!file) {
    throw new Error("No file provided");
  }

  if (!productId) {
    throw new Error("product_id is required");
  }

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const image_id = uuidv4();
    const image_url = `/uploads/product_image/${file.filename}`;

    // 1) insert into images
    await client.query(
      "INSERT INTO images (image_id, image_url) VALUES ($1, $2)",
      [image_id, image_url]
    );

    // 2) update retailer_products.image_id
    const result = await client.query(
      `UPDATE retailer_products
       SET image_id = $2
       WHERE product_id = $1
       RETURNING *`,
      [productId, image_id]
    );

    if (result.rowCount === 0) {
      throw new Error("Product not found for given product_id");
    }

    await client.query("COMMIT");

    return {
      image_id,
      image_url,
      product: result.rows[0],
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};
