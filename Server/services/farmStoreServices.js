// Farm management services (shop places + products)
const pool = require("../db/database");
const { v4: uuidv4 } = require("uuid");
const fs = require("fs");
const path = require("path");
const logger = require("../utils/logger");

// Generate unique UUID for any table
async function generateUniqueId(client, tableName, idColumn) {
  logger.info("Generating unique ID", { tableName, idColumn });
  let id, exists;
  do {
    id = uuidv4();
    const check = await client.query(
      `SELECT 1 FROM ${tableName} WHERE ${idColumn} = $1`,
      [id],
    );
    exists = check.rowCount > 0;
  } while (exists);
  logger.info("Generated unique ID", { id, tableName });
  return id;
}

// Add or update farmer shop location
exports.addFarmerShopPlace = async (req, res) => {
  const { latitude, longitude } = req.body;
  const farmer_id = req.user_id;
  logger.info("addFarmerShopPlace - Request", {
    farmer_id,
    latitude,
    longitude,
  });

  if (!latitude || !longitude) {
    logger.error("addFarmerShopPlace - Missing lat/lng");
    return res
      .status(400)
      .json({ message: "latitude and longitude are required" });
  }

  try {
    await pool.query("BEGIN");

    // Check if shop location already exists
    const existingPlace = await pool.query(
      "SELECT farmer_id FROM farmer_shop_place WHERE farmer_id = $1",
      [farmer_id],
    );

    let result;
    if (existingPlace.rowCount > 0) {
      result = await pool.query(
        `UPDATE farmer_shop_place
         SET latitude = $1, longitude = $2, updated_at = CURRENT_TIMESTAMP
         WHERE farmer_id = $3
         RETURNING *`,
        [latitude, longitude, farmer_id],
      );
      await pool.query("COMMIT");
      logger.info("addFarmerShopPlace - Location updated", { farmer_id });
      return res.json({
        message: "Shop location updated successfully",
        shopPlace: result.rows[0],
      });
    } else {
      result = await pool.query(
        `INSERT INTO farmer_shop_place (farmer_id, latitude, longitude)
         VALUES ($1, $2, $3)
         RETURNING *`,
        [farmer_id, latitude, longitude],
      );
      await pool.query("COMMIT");
      logger.info("addFarmerShopPlace - Location created", { farmer_id });
      return res.json({
        message: "Shop location created successfully",
        shopPlace: result.rows[0],
      });
    }
  } catch (error) {
    await pool.query("ROLLBACK");
    logger.error("addFarmerShopPlace - Error:", error);
    res
      .status(500)
      .json({ message: "Error saving shop location", error: error.message });
  }
};

// Get shop location for a farmer
exports.getFarmerShopPlaces = async (req, res) => {
  const { farmerId } = req.params;
  logger.info("getFarmerShopPlaces - Request", { farmerId });

  try {
    const sql = `
      SELECT 
        fsp.*,
        ud.name AS farmer_name
      FROM farmer_shop_place fsp
      LEFT JOIN user_details ud ON fsp.farmer_id = ud.user_id
      WHERE fsp.farmer_id = $1
    `;
    const result = await pool.query(sql, [farmerId]);
    logger.info("getFarmerShopPlaces - Success", {
      farmerId,
      count: result.rowCount,
    });
    res.json(result.rows);
  } catch (error) {
    logger.error("getFarmerShopPlaces - Error:", { farmerId, error });
    res
      .status(500)
      .json({ message: "Error fetching shop places", error: error.message });
  }
};

// Create new farm product with image placeholder
exports.createFarmProduct = async (req, res) => {
  const {
    product_name,
    variety,
    description,
    price_per_unit,
    unit,
    quantity_available,
  } = req.body;
  const farmer_id = req.user_id;
  logger.info("createFarmProduct - Request", { farmer_id, product_name });

  if (!product_name || !price_per_unit || !unit || !quantity_available) {
    logger.error("createFarmProduct - Missing required fields");
    return res.status(400).json({
      message:
        "product_name, price_per_unit, unit, and quantity_available are required",
    });
  }

  try {
    await pool.query("BEGIN");

    const product_id = await generateUniqueId(
      pool,
      "farmer_products",
      "product_id",
    );
    const image_id = uuidv4();

    // Insert image placeholder
    await pool.query(
      "INSERT INTO images (image_id, image_url) VALUES ($1, $2)",
      [image_id, "no-image"],
    );

    const result = await pool.query(
      `INSERT INTO farmer_products (
        product_id, farmer_id, product_name, variety, description,
        price_per_unit, unit, quantity_available, is_available, image_id
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, $9)
      RETURNING *`,
      [
        product_id,
        farmer_id,
        product_name,
        variety || null,
        description || null,
        price_per_unit,
        unit,
        quantity_available,
        image_id,
      ],
    );

    await pool.query("COMMIT");
    logger.info("createFarmProduct - Success", { product_id, farmer_id });

    res.json({
      message: "Product created successfully",
      product: result.rows[0],
      product_id,
      image_id,
    });
  } catch (error) {
    await pool.query("ROLLBACK");
    logger.error("createFarmProduct - Error:", error);
    res
      .status(500)
      .json({ message: "Error creating product", error: error.message });
  }
};

// Get all products for a specific farmer
exports.getFarmProductsByFarmer = async (req, res) => {
  const { farmerId } = req.params;
  logger.info("getFarmProductsByFarmer - Request", { farmerId });

  try {
    const sql = `
      SELECT
        fp.*,
        ud.name AS farmer_name,
        i.image_url
      FROM farmer_products fp
      LEFT JOIN user_details ud ON fp.farmer_id = ud.user_id
      LEFT JOIN images i ON fp.image_id = i.image_id
      WHERE fp.farmer_id = $1
      ORDER BY fp.created_at DESC
    `;
    const result = await pool.query(sql, [farmerId]);
    logger.info("getFarmProductsByFarmer - Success", {
      farmerId,
      count: result.rowCount,
    });
    res.json({ success: true, products: result.rows });
  } catch (error) {
    logger.error("getFarmProductsByFarmer - Error:", { farmerId, error });
    res
      .status(500)
      .json({
        success: false,
        message: "Error fetching products",
        error: error.message,
      });
  }
};

// Get single farm product by product_id
exports.getFarmProductById = async (req, res) => {
  const { id } = req.params;
  logger.info("getFarmProductById - Request", { id });

  try {
    const sql = `
      SELECT
        fp.*,
        ud.name AS farmer_name,
        ua.phone_number AS farmer_phone,
        i.image_url,
        fsp.latitude AS shop_latitude,
        fsp.longitude AS shop_longitude
      FROM farmer_products fp
      LEFT JOIN user_details ud ON fp.farmer_id = ud.user_id
      LEFT JOIN users_auth ua ON fp.farmer_id = ua.user_id
      LEFT JOIN images i ON fp.image_id = i.image_id
      LEFT JOIN farmer_shop_place fsp ON fp.farmer_id = fsp.farmer_id
      WHERE fp.product_id = $1
    `;
    const result = await pool.query(sql, [id]);

    if (result.rowCount === 0) {
      logger.warn("getFarmProductById - Not found", { id });
      return res.status(404).json({ message: "Product not found" });
    }

    logger.info("getFarmProductById - Success", { id });
    res.json(result.rows[0]);
  } catch (error) {
    logger.error("getFarmProductById - Error:", { id, error });
    res
      .status(500)
      .json({ message: "Error fetching product", error: error.message });
  }
};

// Get all farm products with optional filters
exports.getAllFarmProducts = async (req, res) => {
  const { is_available, farmer_id } = req.query;
  logger.info("getAllFarmProducts - Request", { is_available, farmer_id });

  const conditions = [];
  const values = [];
  let idx = 1;

  if (typeof is_available !== "undefined") {
    conditions.push(`fp.is_available = $${idx++}`);
    values.push(is_available === "true");
  }
  if (farmer_id) {
    conditions.push(`fp.farmer_id = $${idx++}`);
    values.push(farmer_id);
  }

  const whereClause = conditions.length
    ? `WHERE ${conditions.join(" AND ")}`
    : "";

  try {
    const sql = `
      SELECT
        fp.*,
        ud.name AS farmer_name,
        ua.phone_number AS farmer_phone,
        i.image_url,
        fsp.latitude AS shop_latitude,
        fsp.longitude AS shop_longitude
      FROM farmer_products fp
      LEFT JOIN user_details ud ON fp.farmer_id = ud.user_id
      LEFT JOIN users_auth ua ON fp.farmer_id = ua.user_id
      LEFT JOIN images i ON fp.image_id = i.image_id
      LEFT JOIN farmer_shop_place fsp ON fp.farmer_id = fsp.farmer_id
      ${whereClause}
      ORDER BY fp.created_at DESC
    `;
    const result = await pool.query(sql, values);
    logger.info("getAllFarmProducts - Success", { count: result.rowCount });
    res.json(result.rows);
  } catch (error) {
    logger.error("getAllFarmProducts - Error:", error);
    res
      .status(500)
      .json({ message: "Error fetching all products", error: error.message });
  }
};

// Update farm product fields
exports.updateFarmProduct = async (req, res) => {
  const { id } = req.params;
  const updates = req.body;
  logger.info("updateFarmProduct - Request", { id, farmer_id: req.user_id });

  try {
    const sql = `
      UPDATE farmer_products
      SET
        product_name = COALESCE($2, product_name),
        variety = COALESCE($3, variety),
        description = COALESCE($4, description),
        price_per_unit = COALESCE($5, price_per_unit),
        unit = COALESCE($6, unit),
        quantity_available = COALESCE($7, quantity_available),
        is_available = COALESCE($8, is_available),
        updated_at = CURRENT_TIMESTAMP
      WHERE product_id = $1 AND farmer_id = $9
      RETURNING *
    `;
    const result = await pool.query(sql, [
      id,
      updates.product_name,
      updates.variety,
      updates.description,
      updates.price_per_unit,
      updates.unit,
      updates.quantity_available,
      updates.is_available,
      req.user_id,
    ]);

    if (result.rowCount === 0) {
      logger.warn("updateFarmProduct - Not found or access denied", { id });
      return res
        .status(404)
        .json({ message: "Product not found or access denied" });
    }

    logger.info("updateFarmProduct - Success", { id });
    res.json({
      message: "Product updated successfully",
      product: result.rows[0],
    });
  } catch (error) {
    logger.error("updateFarmProduct - Error:", { id, error });
    res
      .status(500)
      .json({ message: "Error updating product", error: error.message });
  }
};

// Toggle product availability on/off
exports.toggleFarmProductStatus = async (req, res) => {
  const { id } = req.params;
  logger.info("toggleFarmProductStatus - Request", {
    id,
    farmer_id: req.user_id,
  });

  try {
    const sql = `
      UPDATE farmer_products
      SET is_available = NOT is_available,
          updated_at = CURRENT_TIMESTAMP
      WHERE product_id = $1 AND farmer_id = $2
      RETURNING *
    `;
    const result = await pool.query(sql, [id, req.user_id]);

    if (result.rowCount === 0) {
      logger.warn("toggleFarmProductStatus - Not found or access denied", {
        id,
      });
      return res
        .status(404)
        .json({ message: "Product not found or access denied" });
    }

    const newStatus = result.rows[0].is_available;
    logger.info("toggleFarmProductStatus - Success", {
      id,
      is_available: newStatus,
    });

    res.json({
      success: true,
      message: `Product ${newStatus ? "activated" : "deactivated"} successfully`,
      is_available: newStatus,
      product: result.rows[0],
    });
  } catch (error) {
    logger.error("toggleFarmProductStatus - Error:", { id, error });
    res
      .status(500)
      .json({
        success: false,
        message: "Error updating product status",
        error: error.message,
      });
  }
};

// Delete farm product and its image file
exports.deleteFarmProduct = async (req, res) => {
  const { id } = req.params;
  logger.info("deleteFarmProduct - Request", { id, farmer_id: req.user_id });

  try {
    await pool.query("BEGIN");

    // Fetch image_id before deletion
    const productResult = await pool.query(
      "SELECT image_id FROM farmer_products WHERE product_id = $1 AND farmer_id = $2",
      [id, req.user_id],
    );

    if (productResult.rowCount === 0) {
      await pool.query("ROLLBACK");
      logger.warn("deleteFarmProduct - Not found or access denied", { id });
      return res
        .status(404)
        .json({ message: "Product not found or access denied" });
    }

    const imageId = productResult.rows[0].image_id;

    await pool.query("DELETE FROM farmer_products WHERE product_id = $1", [id]);

    // Delete image file and record if exists
    if (imageId) {
      const imageResult = await pool.query(
        "SELECT image_url FROM images WHERE image_id = $1",
        [imageId],
      );

      if (imageResult.rowCount > 0) {
        const imageUrl = imageResult.rows[0].image_url;

        if (imageUrl && imageUrl !== "no-image") {
          const imagePath = path.join(__dirname, "..", imageUrl);
          if (fs.existsSync(imagePath)) {
            fs.unlinkSync(imagePath);
            logger.info("deleteFarmProduct - Image file deleted", {
              imagePath,
            });
          }
        }
      }

      await pool.query("DELETE FROM images WHERE image_id = $1", [imageId]);
      logger.info("deleteFarmProduct - Image record deleted", { imageId });
    }

    await pool.query("COMMIT");
    logger.info("deleteFarmProduct - Success", { id });
    res.json({ message: "Product deleted successfully" });
  } catch (error) {
    await pool.query("ROLLBACK");
    logger.error("deleteFarmProduct - Error:", { id, error });
    res
      .status(500)
      .json({ message: "Error deleting product", error: error.message });
  }
};

// Get nearby farm products within 5km
exports.getNearbyFarmProducts = async (req, res) => {
  const { lat, lng } = req.query;
  logger.info("getNearbyFarmProducts - Request", { lat, lng });

  if (!lat || !lng) {
    logger.error("getNearbyFarmProducts - Missing lat/lng");
    return res
      .status(400)
      .json({ message: "lat and lng query params are required" });
  }

  try {
    const sql = `
      WITH nearby AS (
        SELECT
          fp.*,
          ud.name AS farmer_name,
          ua.phone_number AS farmer_phone,
          i.image_url,
          fsp.latitude AS shop_latitude,
          fsp.longitude AS shop_longitude,
          (
            6371 * acos(
              cos(radians($1)) * cos(radians(fsp.latitude)) *
              cos(radians(fsp.longitude) - radians($2)) +
              sin(radians($1)) * sin(radians(fsp.latitude))
            )
          ) AS distance_km
        FROM farmer_products fp
        JOIN farmer_shop_place fsp ON fp.farmer_id = fsp.farmer_id
        LEFT JOIN user_details ud ON fp.farmer_id = ud.user_id
        LEFT JOIN users_auth ua ON fp.farmer_id = ua.user_id
        LEFT JOIN images i ON fp.image_id = i.image_id
        WHERE fp.is_available = true
          AND fsp.latitude BETWEEN $1 - 0.05 AND $1 + 0.05
          AND fsp.longitude BETWEEN $2 - 0.05 AND $2 + 0.05
      )
      SELECT * FROM nearby
      WHERE distance_km <= 5
      ORDER BY distance_km
    `;
    const result = await pool.query(sql, [parseFloat(lat), parseFloat(lng)]);
    logger.info("getNearbyFarmProducts - Success", {
      lat,
      lng,
      count: result.rowCount,
    });
    res.json(result.rows);
  } catch (error) {
    logger.error("getNearbyFarmProducts - Error:", error);
    res
      .status(500)
      .json({
        message: "Error fetching nearby products",
        error: error.message,
      });
  }
};
