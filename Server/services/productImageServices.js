// Server/services/productImageServices.js
const fs = require("fs");
const path = require("path");
const { query } = require("../db/database");
const { v4: uuidv4 } = require("uuid");
const { compressImageInPlace } = require("../utils/imageCompressor");

// ---------- Retailer product image ----------

exports.saveProductImage = async (file, productId) => {
  // Basic validations
  if (!file) {
    throw new Error("No file provided");
  }
  if (!productId || typeof productId !== "string") {
    throw new Error("Valid product_id string (UUID) is required");
  }

  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(productId)) {
    throw new Error("Invalid product_id: must be valid UUID format");
  }

  if (!file.filename || typeof file.filename !== "string") {
    console.error("saveProductImage: invalid file.filename =", file.filename);
    throw new Error("Uploaded file is missing filename");
  }

  const newImageUrl = `/uploads/product_image/${String(file.filename)}`;
  console.log("saveProductImage: START");
  console.log("  productId =", productId);
  console.log("  file.filename =", file.filename);
  console.log("  newImageUrl =", newImageUrl);

  try {
    // 1) Get current image_id and image_url for this product
    const productRes = await query(
      `SELECT 
         rp.image_id,
         i.image_url
       FROM retailer_products rp
       LEFT JOIN images i ON rp.image_id = i.image_id
       WHERE rp.product_id = $1::uuid`,
      [productId],
    );

    console.log("saveProductImage: productRes.rows =", productRes.rows);

    if (productRes.rowCount === 0) {
      throw new Error("Product not found for given product_id");
    }

    const { image_id, image_url: oldImageUrl } = productRes.rows[0];

    if (!image_id) {
      throw new Error("Product does not have an associated image_id");
    }

    // 2) Compress uploaded file
    const fullPath = path.join(__dirname, "..", newImageUrl);
    console.log("saveProductImage: fullPath to compress =", fullPath);
    await compressImageInPlace(fullPath);

    // 3) Delete old image file if it exists (and is not NULL/placeholder)
    if (oldImageUrl && oldImageUrl !== "no-image") {
      const absolutePath = path.join(__dirname, "..", oldImageUrl);
      console.log("saveProductImage: deleting old image at =", absolutePath);
      fs.unlink(absolutePath, (err) => {
        if (err) {
          console.error("Error deleting old product image:", err);
        } else {
          console.log("Old image deleted successfully");
        }
      });
    }

    // 4) Update the existing image record with new URL
    const imageUpdateRes = await query(
      "UPDATE images SET image_url = $2::text WHERE image_id = $1::uuid RETURNING *",
      [image_id, newImageUrl],
    );
    console.log("saveProductImage: imageUpdateRes.rows =", imageUpdateRes.rows);

    if (imageUpdateRes.rowCount === 0) {
      throw new Error("Failed to update image record");
    }

    console.log("saveProductImage: DONE");
    return {
      image_id,
      image_url: imageUpdateRes.rows[0].image_url,
      product: productRes.rows[0],
    };
  } catch (error) {
    console.error("saveProductImage ERROR:", error);
    throw error;
  }
};

// ---------- Farmer product image ----------

exports.saveFarmProductImage = async (file, productId) => {
  if (!file) {
    throw new Error("No file provided");
  }
  if (!productId || typeof productId !== "string") {
    throw new Error("Valid product_id string (UUID) is required");
  }

  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(productId)) {
    throw new Error("Invalid product_id: must be valid UUID format");
  }

  if (!file.filename || typeof file.filename !== "string") {
    console.error(
      "saveFarmProductImage: invalid file.filename =",
      file.filename,
    );
    throw new Error("Uploaded file is missing filename");
  }

  console.log("🔍 saveFarmProductImage: productId type =", typeof productId);
  console.log("🔍 saveFarmProductImage: productId value =", productId);
  console.log("🔍 saveFarmProductImage: productId length =", productId.length);
  console.log(
    "🔍 saveFarmProductImage: uuidRegex.test =",
    uuidRegex.test(productId),
  );
  console.log("🔍 saveFarmProductImage: file.filename =", file.filename);

  const newImageUrl = `/uploads/product_image/${String(file.filename)}`;

  try {
    // 1) Load existing farmer_product row
    const productRes = await query(
      `SELECT 
         fp.image_id,
         i.image_url
       FROM farmer_products fp
       LEFT JOIN images i ON fp.image_id = i.image_id
       WHERE fp.product_id = $1::uuid`,
      [productId],
    );

    console.log("🔍 saveFarmProductImage: productRes.rows =", productRes.rows);

    if (productRes.rowCount === 0) {
      throw new Error("Farm product not found for given product_id");
    }

    const { image_id, image_url: oldImageUrl } = productRes.rows[0];

    if (!image_id) {
      throw new Error("Farm product does not have an associated image_id");
    }

    // 2) Compress uploaded file
    const fullPath = path.join(__dirname, "..", newImageUrl);
    console.log("🔍 saveFarmProductImage: fullPath to compress =", fullPath);
    await compressImageInPlace(fullPath);

    // 3) Delete old image file if exists
    if (oldImageUrl && oldImageUrl !== "no-image") {
      const absolutePath = path.join(__dirname, "..", oldImageUrl);
      console.log(
        "🔍 saveFarmProductImage: deleting old image at =",
        absolutePath,
      );
      fs.unlink(absolutePath, (err) => {
        if (err) {
          console.error("Error deleting old farm product image:", err);
        } else {
          console.log("Old farm image deleted successfully");
        }
      });
    }

    // 4) Update the existing image record
    const imageUpdateRes = await query(
      "UPDATE images SET image_url = $2::text WHERE image_id = $1::uuid RETURNING *",
      [image_id, newImageUrl],
    );
    console.log(
      "🔍 saveFarmProductImage: imageUpdateRes.rows =",
      imageUpdateRes.rows,
    );

    if (imageUpdateRes.rowCount === 0) {
      throw new Error("Failed to update farm image record");
    }

    return {
      image_id,
      image_url: imageUpdateRes.rows[0].image_url,
      product: productRes.rows[0],
    };
  } catch (error) {
    console.error("saveFarmProductImage ERROR:", error);
    throw error;
  }
};
