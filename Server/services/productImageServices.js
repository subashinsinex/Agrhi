const fs = require("fs");
const path = require("path");
const pool = require("../db/database");
const { v4: uuidv4 } = require("uuid");

// Save or update product image for a retail product
// - file: multer file object
// - productId: retailer_products.product_id (UUID)
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

    // Get current image_id and image_url for this product
    const productRes = await client.query(
      `SELECT rp.image_id, i.image_url
       FROM retailer_products rp
       LEFT JOIN images i ON rp.image_id = i.image_id
       WHERE rp.product_id = $1`,
      [productId],
    );

    if (productRes.rowCount === 0) {
      throw new Error("Product not found for given product_id");
    }

    const { image_id: existingImageId, image_url: oldImageUrl } =
      productRes.rows[0];
    const newImageUrl = `/uploads/product_image/${file.filename}`;

    let image_id;

    if (!existingImageId) {
      // No image yet: create new image row and set retailer_products.image_id
      image_id = uuidv4();

      await client.query(
        "INSERT INTO images (image_id, image_url) VALUES ($1, $2)",
        [image_id, newImageUrl],
      );

      const result = await client.query(
        "UPDATE retailer_products SET image_id = $2 WHERE product_id = $1 RETURNING *",
        [productId, image_id],
      );

      await client.query("COMMIT");
      return {
        image_id,
        image_url: newImageUrl,
        product: result.rows[0],
      };
    }

    // Product already has image: delete old file and update same image_id
    image_id = existingImageId;

    if (oldImageUrl && oldImageUrl !== "no-image") {
      const absolutePath = path.join(__dirname, "..", oldImageUrl);
      fs.unlink(absolutePath, (err) => {
        if (err) {
          console.error("Error deleting old product image:", err);
        }
      });
    }

    const imageUpdateRes = await client.query(
      "UPDATE images SET image_url = $2 WHERE image_id = $1 RETURNING *",
      [image_id, newImageUrl],
    );

    await client.query("COMMIT");
    return {
      image_id,
      image_url: imageUpdateRes.rows[0].image_url,
      product: productRes.rows[0],
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};

// Save or update product image for a farm product
// - file: multer file object
// - productId: farmer_products.product_id (UUID)
exports.saveFarmProductImage = async (file, productId) => {
  if (!file) {
    throw new Error("No file provided");
  }
  if (!productId) {
    throw new Error("product_id is required");
  }

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // Get current image_id and image_url for this farm product
    const productRes = await client.query(
      `SELECT fp.image_id, i.image_url
       FROM farmer_products fp
       LEFT JOIN images i ON fp.image_id = i.image_id
       WHERE fp.product_id = $1`,
      [productId],
    );

    if (productRes.rowCount === 0) {
      throw new Error("Farm product not found for given product_id");
    }

    const { image_id: existingImageId, image_url: oldImageUrl } =
      productRes.rows[0];
    const newImageUrl = `/uploads/product_image/${file.filename}`;

    let image_id;

    if (!existingImageId) {
      // No image yet: create new image row and set farmer_products.image_id
      image_id = uuidv4();

      await client.query(
        "INSERT INTO images (image_id, image_url) VALUES ($1, $2)",
        [image_id, newImageUrl],
      );

      const result = await client.query(
        "UPDATE farmer_products SET image_id = $2 WHERE product_id = $1 RETURNING *",
        [productId, image_id],
      );

      await client.query("COMMIT");
      return {
        image_id,
        image_url: newImageUrl,
        product: result.rows[0],
      };
    }

    // Product already has image: delete old file and update same image_id
    image_id = existingImageId;

    if (oldImageUrl && oldImageUrl !== "no-image") {
      const absolutePath = path.join(__dirname, "..", oldImageUrl);
      fs.unlink(absolutePath, (err) => {
        if (err) {
          console.error("Error deleting old farm product image:", err);
        }
      });
    }

    const imageUpdateRes = await client.query(
      "UPDATE images SET image_url = $2 WHERE image_id = $1 RETURNING *",
      [image_id, newImageUrl],
    );

    await client.query("COMMIT");
    return {
      image_id,
      image_url: imageUpdateRes.rows[0].image_url,
      product: productRes.rows[0],
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};
