const pool = require("../db/database");
const { v4: uuidv4 } = require("uuid");
const fs = require("fs");
const path = require("path");

async function generateUniqueId(client, tableName, idColumn) {
  let id, exists;
  do {
    id = uuidv4();
    const check = await client.query(
      `SELECT 1 FROM ${tableName} WHERE ${idColumn} = $1`,
      [id],
    );
    exists = check.rowCount > 0;
  } while (exists);
  return id;
}

// ========== FARMER SHOP PLACES ==========

exports.addFarmerShopPlace = async (req, res) => {
  const { latitude, longitude } = req.body;

  if (!latitude || !longitude) {
    return res.status(400).json({
      message: "latitude and longitude are required",
    });
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const farmer_id = req.user_id;

    // Check if farmer already has a shop place
    const existingPlace = await client.query(
      "SELECT farmer_id FROM farmer_shop_place WHERE farmer_id = $1",
      [farmer_id],
    );

    let result;

    if (existingPlace.rowCount > 0) {
      // Update existing location
      result = await client.query(
        `UPDATE farmer_shop_place
         SET latitude = $1, longitude = $2, updated_at = CURRENT_TIMESTAMP
         WHERE farmer_id = $3
         RETURNING *`,
        [latitude, longitude, farmer_id],
      );

      await client.query("COMMIT");
      res.json({
        message: "Shop location updated successfully",
        shopPlace: result.rows[0],
      });
    } else {
      result = await client.query(
        `INSERT INTO farmer_shop_place (farmer_id, latitude, longitude)
         VALUES ($1, $2, $3)
         RETURNING *`,
        [farmer_id, latitude, longitude],
      );

      await client.query("COMMIT");
      res.json({
        message: "Shop location created successfully",
        shopPlace: result.rows[0],
      });
    }
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("addFarmerShopPlace error:", error);
    res.status(500).json({
      message: "Error saving shop location",
      error: error.message,
    });
  } finally {
    client.release();
  }
};

exports.getFarmerShopPlaces = async (req, res) => {
  const { farmerId } = req.params;

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
    res.json(result.rows);
  } catch (error) {
    console.error("getFarmerShopPlaces error:", error);
    res.status(500).json({
      message: "Error fetching shop places",
      error: error.message,
    });
  }
};

// ========== FARM PRODUCTS ==========

exports.createFarmProduct = async (req, res) => {
  const {
    product_name,
    variety,
    description,
    price_per_unit,
    unit,
    quantity_available,
  } = req.body;

  if (!product_name || !price_per_unit || !unit || !quantity_available) {
    return res.status(400).json({
      message:
        "product_name, price_per_unit, unit, and quantity_available are required",
    });
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const farmer_id = req.user_id;

    // Generate product_id
    const product_id = await generateUniqueId(
      client,
      "farmer_products",
      "product_id",
    );

    const insertSql = `
      INSERT INTO farmer_products (
        product_id,
        farmer_id,
        product_name,
        variety,
        description,
        price_per_unit,
        unit,
        quantity_available,
        is_available
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true)
      RETURNING *
    `;

    const result = await client.query(insertSql, [
      product_id,
      farmer_id,
      product_name,
      variety || null,
      description || null,
      price_per_unit,
      unit,
      quantity_available,
    ]);

    await client.query("COMMIT");
    res.json({
      message: "Product created successfully",
      product: result.rows[0],
      product_id: product_id,
    });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("createFarmProduct error:", error);
    res.status(500).json({
      message: "Error creating product",
      error: error.message,
    });
  } finally {
    client.release();
  }
};

exports.getFarmProductsByFarmer = async (req, res) => {
  const { farmerId } = req.params;

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
    res.json({
      success: true,
      products: result.rows,
    });
  } catch (error) {
    console.error("getFarmProductsByFarmer error:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching products",
      error: error.message,
    });
  }
};

exports.getFarmProductById = async (req, res) => {
  const { id } = req.params;

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
      return res.status(404).json({ message: "Product not found" });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error("getFarmProductById error:", error);
    res.status(500).json({
      message: "Error fetching product",
      error: error.message,
    });
  }
};

exports.getAllFarmProducts = async (req, res) => {
  const { is_available, farmer_id } = req.query;

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
    res.json(result.rows);
  } catch (error) {
    console.error("getAllFarmProducts error:", error);
    res.status(500).json({
      message: "Error fetching all products",
      error: error.message,
    });
  }
};

exports.updateFarmProduct = async (req, res) => {
  const { id } = req.params;
  const {
    product_name,
    variety,
    description,
    price_per_unit,
    unit,
    quantity_available,
    is_available,
  } = req.body;

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
      product_name,
      variety,
      description,
      price_per_unit,
      unit,
      quantity_available,
      is_available,
      req.user_id,
    ]);

    if (result.rowCount === 0) {
      return res.status(404).json({
        message: "Product not found or access denied",
      });
    }

    res.json({
      message: "Product updated successfully",
      product: result.rows[0],
    });
  } catch (error) {
    console.error("updateFarmProduct error:", error);
    res.status(500).json({
      message: "Error updating product",
      error: error.message,
    });
  }
};

exports.toggleFarmProductStatus = async (req, res) => {
  const { id } = req.params;

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
      return res.status(404).json({
        message: "Product not found or access denied",
      });
    }

    const newStatus = result.rows[0].is_available;
    res.json({
      success: true,
      message: `Product ${newStatus ? "activated" : "deactivated"} successfully`,
      is_available: newStatus,
      product: result.rows[0],
    });
  } catch (error) {
    console.error("toggleFarmProductStatus error:", error);
    res.status(500).json({
      success: false,
      message: "Error updating product status",
      error: error.message,
    });
  }
};

exports.deleteFarmProduct = async (req, res) => {
  const { id } = req.params;

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // Get the image_id first
    const productResult = await client.query(
      "SELECT image_id FROM farmer_products WHERE product_id = $1 AND farmer_id = $2",
      [id, req.user_id],
    );

    if (productResult.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({
        message: "Product not found or access denied",
      });
    }

    const imageId = productResult.rows[0].image_id;

    // Delete the product
    await client.query("DELETE FROM farmer_products WHERE product_id = $1", [
      id,
    ]);

    // Delete associated image if exists
    if (imageId) {
      const imageResult = await client.query(
        "SELECT image_url FROM images WHERE image_id = $1",
        [imageId],
      );

      if (imageResult.rowCount > 0) {
        const imageUrl = imageResult.rows[0].image_url;

        // Delete physical file if exists
        if (imageUrl && imageUrl !== "no-image") {
          const imagePath = path.join(__dirname, "..", imageUrl);
          if (fs.existsSync(imagePath)) {
            fs.unlinkSync(imagePath);
            console.log("🗑️ Deleted image file:", imagePath);
          }
        }
      }

      await client.query("DELETE FROM images WHERE image_id = $1", [imageId]);
    }

    await client.query("COMMIT");
    res.json({ message: "Product deleted successfully" });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("deleteFarmProduct error:", error);
    res.status(500).json({
      message: "Error deleting product",
      error: error.message,
    });
  } finally {
    client.release();
  }
};

// Get nearby farm products (within 5km of user location)
exports.getNearbyFarmProducts = async (req, res) => {
  const { lat, lng } = req.query;

  if (!lat || !lng) {
    return res.status(400).json({
      message: "lat and lng query params are required",
    });
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
      SELECT *
      FROM nearby
      WHERE distance_km <= 5
      ORDER BY distance_km
    `;

    const result = await pool.query(sql, [parseFloat(lat), parseFloat(lng)]);

    res.json(result.rows);
  } catch (error) {
    console.error("getNearbyFarmProducts error:", error);
    res.status(500).json({
      message: "Error fetching nearby products",
      error: error.message,
    });
  }
};
