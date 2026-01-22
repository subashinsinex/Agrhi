const pool = require("../db/database");
const { v4: uuidv4 } = require("uuid");

// Generate UUID that is unique within a table
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

// ---- Listings (farmer → consumers) ----

exports.createListing = async (req, res) => {
  const {
    phone_number,
    crop_type_id,
    plant_id,
    variety,
    price_per_unit,
    unit,
    available_qty,
    min_order_qty,
  } = req.body;

  if (!phone_number || !/^\d{10}$/.test(phone_number)) {
    return res.status(400).json({ message: "Valid 10-digit phone required" });
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // Lookup farmer user_id from users_auth by phone_number
    const userResult = await client.query(
      "SELECT user_id FROM users_auth WHERE phone_number = $1",
      [phone_number],
    );

    if (userResult.rowCount === 0) {
      throw new Error("Farmer phone not found");
    }

    const farmer_id = userResult.rows[0].user_id;

    // Generate listing_id
    const listing_id = await generateUniqueId(
      client,
      "farmer_market_listings",
      "listing_id",
    );

    const insertSql = `
      INSERT INTO farmer_market_listings (
        listing_id,
        farmer_id,
        crop_type_id,
        plant_id,
        variety,
        price_per_unit,
        unit,
        available_qty,
        min_order_qty,
        is_active
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true)
      RETURNING *
    `;

    const result = await client.query(insertSql, [
      listing_id,
      farmer_id,
      crop_type_id,
      plant_id,
      variety,
      price_per_unit,
      unit,
      available_qty,
      min_order_qty,
    ]);

    await client.query("COMMIT");
    res.json({ message: "Listing created", listing: result.rows[0] });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("createListing error:", error);
    res
      .status(500)
      .json({ message: "Error creating listing", error: error.message });
  } finally {
    client.release();
  }
};

exports.getListingById = async (req, res) => {
  const { id } = req.params; // listing_id

  try {
    const sql = `
      SELECT
        fml.*,
        p.plant_name,
        ct.name AS crop_type,
        ud.name AS farmer_name
      FROM farmer_market_listings fml
      LEFT JOIN plants p ON fml.plant_id = p.plant_id
      LEFT JOIN crop_types ct ON fml.crop_type_id = ct.crop_type_id
      LEFT JOIN user_details ud ON fml.farmer_id = ud.user_id
      WHERE fml.listing_id = $1
    `;

    const result = await pool.query(sql, [id]);

    if (result.rowCount === 0) {
      return res.status(404).json({ message: "Listing not found" });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error("getListingById error:", error);
    res
      .status(500)
      .json({ message: "Error fetching listing", error: error.message });
  }
};

exports.getFarmerListings = async (req, res) => {
  const { id } = req.params; // farmer_id (users_auth.user_id)

  try {
    const sql = `
      SELECT
        fml.*,
        p.plant_name,
        ct.name AS crop_type
      FROM farmer_market_listings fml
      LEFT JOIN plants p ON fml.plant_id = p.plant_id
      LEFT JOIN crop_types ct ON fml.crop_type_id = ct.crop_type_id
      WHERE fml.farmer_id = $1
      ORDER BY fml.created_at DESC
    `;

    const result = await pool.query(sql, [id]);
    res.json(result.rows);
  } catch (error) {
    console.error("getFarmerListings error:", error);
    res
      .status(500)
      .json({ message: "Error fetching listings", error: error.message });
  }
};

// Admin: all listings with optional filters
exports.getAllListings = async (req, res) => {
  // query params: ?is_active=true&crop_type_id=uuid&farmer_id=uuid
  const { is_active, crop_type_id, farmer_id } = req.query;

  const conditions = [];
  const values = [];
  let idx = 1;

  if (typeof is_active !== "undefined") {
    conditions.push(`fml.is_active = $${idx++}`);
    values.push(is_active === "true");
  }

  if (crop_type_id) {
    conditions.push(`fml.crop_type_id = $${idx++}`);
    values.push(crop_type_id);
  }

  if (farmer_id) {
    conditions.push(`fml.farmer_id = $${idx++}`);
    values.push(farmer_id);
  }

  const whereClause = conditions.length
    ? `WHERE ${conditions.join(" AND ")}`
    : "";

  try {
    const sql = `
      SELECT
        fml.*,
        p.plant_name,
        ct.name AS crop_type,
        ud.name AS farmer_name,
        ua.phone_number AS farmer_phone
      FROM farmer_market_listings fml
      LEFT JOIN plants p ON fml.plant_id = p.plant_id
      LEFT JOIN crop_types ct ON fml.crop_type_id = ct.crop_type_id
      LEFT JOIN user_details ud ON fml.farmer_id = ud.user_id
      LEFT JOIN users_auth ua ON fml.farmer_id = ua.user_id
      ${whereClause}
      ORDER BY fml.created_at DESC
    `;

    const result = await pool.query(sql, values);
    res.json(result.rows);
  } catch (error) {
    console.error("getAllListings error:", error);
    res
      .status(500)
      .json({ message: "Error fetching all listings", error: error.message });
  }
};

exports.updateListing = async (req, res) => {
  const { id } = req.params; // listing_id
  const {
    crop_type_id,
    plant_id,
    variety,
    price_per_unit,
    unit,
    available_qty,
    min_order_qty,
    is_active,
  } = req.body;

  try {
    const sql = `
      UPDATE farmer_market_listings
      SET
        crop_type_id = COALESCE($2, crop_type_id),
        plant_id = COALESCE($3, plant_id),
        variety = COALESCE($4, variety),
        price_per_unit = COALESCE($5, price_per_unit),
        unit = COALESCE($6, unit),
        available_qty = COALESCE($7, available_qty),
        min_order_qty = COALESCE($8, min_order_qty),
        is_active = COALESCE($9, is_active)
      WHERE listing_id = $1
      RETURNING *
    `;

    const result = await pool.query(sql, [
      id,
      crop_type_id,
      plant_id,
      variety,
      price_per_unit,
      unit,
      available_qty,
      min_order_qty,
      is_active,
    ]);

    if (result.rowCount === 0) {
      return res.status(404).json({ message: "Listing not found" });
    }

    res.json({ message: "Listing updated", listing: result.rows[0] });
  } catch (error) {
    console.error("updateListing error:", error);
    res
      .status(500)
      .json({ message: "Error updating listing", error: error.message });
  }
};

exports.toggleListing = async (req, res) => {
  const { id } = req.params; // listing_id
  const { is_active } = req.body;

  try {
    const sql = `
      UPDATE farmer_market_listings
      SET is_active = $2
      WHERE listing_id = $1
      RETURNING *
    `;

    const result = await pool.query(sql, [id, !!is_active]);

    if (result.rowCount === 0) {
      return res.status(404).json({ message: "Listing not found" });
    }

    res.json({ message: "Listing status updated", listing: result.rows[0] });
  } catch (error) {
    console.error("toggleListing error:", error);
    res
      .status(500)
      .json({ message: "Error updating status", error: error.message });
  }
};

exports.deleteListing = async (req, res) => {
  const { id } = req.params; // listing_id

  try {
    await pool.query(
      "DELETE FROM farmer_market_listings WHERE listing_id = $1",
      [id],
    );
    res.json({ message: "Listing deleted" });
  } catch (error) {
    console.error("deleteListing error:", error);
    res
      .status(500)
      .json({ message: "Error deleting listing", error: error.message });
  }
};

// ---- Nearby listings (5 km) ----
exports.getNearbyListings = async (req, res) => {
  const { lat, lng, crop_type_id } = req.query;

  if (!lat || !lng) {
    return res
      .status(400)
      .json({ message: "lat and lng query params are required" });
  }

  try {
    const sql = `
      WITH nearby AS (
        SELECT
          fml.listing_id,
          fml.farmer_id,
          fml.price_per_unit,
          fml.unit,
          fml.available_qty,
          fml.min_order_qty,
          fml.is_active,
          p.plant_name,
          ct.name AS crop_type,
          ud.latitude,
          ud.longitude,
          ud.name AS farmer_name,
          (
            6371 * acos(
              cos(radians($1)) * cos(radians(ud.latitude)) *
              cos(radians(ud.longitude) - radians($2)) +
              sin(radians($1)) * sin(radians(ud.latitude))
            )
          ) AS distance_km
        FROM farmer_market_listings fml
        JOIN user_details ud ON fml.farmer_id = ud.user_id
        LEFT JOIN plants p ON fml.plant_id = p.plant_id
        LEFT JOIN crop_types ct ON fml.crop_type_id = ct.crop_type_id
        WHERE fml.is_active = true
          AND ud.latitude BETWEEN $1 - 0.05 AND $1 + 0.05
          AND ud.longitude BETWEEN $2 - 0.05 AND $2 + 0.05
          AND ($3::uuid IS NULL OR fml.crop_type_id = $3)
      )
      SELECT *
      FROM nearby
      WHERE distance_km <= 5
      ORDER BY distance_km
    `;

    const result = await pool.query(sql, [
      parseFloat(lat),
      parseFloat(lng),
      crop_type_id || null,
    ]);

    res.json(result.rows);
  } catch (error) {
    console.error("getNearbyListings error:", error);
    res.status(500).json({
      message: "Error fetching nearby listings",
      error: error.message,
    });
  }
};

// Create farmer shop place (farmer only)
exports.createFarmerShopPlace = async (req, res) => {
  const { latitude, longitude } = req.body;
  if (!latitude || !longitude) {
    return res.status(400).json({ message: "latitude and longitude required" });
  }
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const farmerId = req.user_id;
    const result = await client.query(
      `INSERT INTO farmer_shop_place (farmer_id, latitude, longitude) 
       VALUES ($1, $2, $3) RETURNING *`,
      [farmerId, latitude, longitude],
    );
    await client.query("COMMIT");
    res.json({ message: "Shop place created", shopPlace: result.rows[0] });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("createFarmerShopPlace error:", error);
    res
      .status(500)
      .json({ message: "Error creating shop place", error: error.message });
  } finally {
    client.release();
  }
};

// Get all (admin dashboard)
exports.getAllFarmerShopPlaces = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT fsp.*, ud.name AS farmer_name, ua.phone_number 
      FROM farmer_shop_place fsp 
      JOIN user_details ud ON fsp.farmer_id = ud.user_id 
      JOIN users_auth ua ON fsp.farmer_id = ua.user_id 
    `);
    res.json(result.rows);
  } catch (error) {
    console.error("getAllFarmerShopPlaces error:", error);
    res.status(500).json({
      message: "Error fetching all shop places",
      error: error.message,
    });
  }
};

// Get by farmer ID
exports.getFarmerShopPlaces = async (req, res) => {
  const { farmerid } = req.params;
  try {
    const result = await pool.query(
      `
      SELECT fsp.*, ud.name AS farmer_name 
      FROM farmer_shop_place fsp 
      JOIN user_details ud ON fsp.farmer_id = ud.user_id 
      WHERE fsp.farmer_id = $1 
    `,
      [farmerid],
    );
    res.json(result.rows);
  } catch (error) {
    console.error("getFarmerShopPlaces error:", error);
    res
      .status(500)
      .json({ message: "Error fetching shop places", error: error.message });
  }
};

// Get single by ID (with ownership check via RLS)
exports.getFarmerShopPlaceById = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `
      SELECT fsp.*, ud.name AS farmer_name 
      FROM farmer_shop_place fsp 
      JOIN user_details ud ON fsp.farmer_id = ud.user_id 
      WHERE fsp.id = $1
    `,
      [id],
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ message: "Shop place not found" });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error("getFarmerShopPlaceById error:", error);
    res
      .status(500)
      .json({ message: "Error fetching shop place", error: error.message });
  }
};

// Delete own
exports.deleteFarmerShopPlace = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `DELETE FROM farmer_shop_place 
       WHERE farmer_id = $1 RETURNING *`,
      [req.user_id],
    );
    if (result.rowCount === 0) {
      return res
        .status(404)
        .json({ message: "Shop place not found or access denied" });
    }
    res.json({ message: "Shop place deleted" });
  } catch (error) {
    console.error("deleteFarmerShopPlace error:", error);
    res
      .status(500)
      .json({ message: "Error deleting shop place", error: error.message });
  }
};

// ---- Reference data helpers ----

exports.getFarmers = async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT ud.user_id, ud.name
      FROM user_details ud
      JOIN user_category uc ON ud.category_id = uc.category_id
      WHERE uc.category = 'Farmer'
      ORDER BY ud.name
    `);
    res.json(result.rows);
  } catch (error) {
    console.error("getFarmers error:", error);
    res
      .status(500)
      .json({ message: "Error fetching farmers", error: error.message });
  }
};

exports.getCropTypes = async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT crop_type_id, name FROM crop_types ORDER BY name",
    );
    res.json(result.rows);
  } catch (error) {
    console.error("getCropTypes error:", error);
    res
      .status(500)
      .json({ message: "Error fetching crop types", error: error.message });
  }
};

exports.getPlants = async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT plant_id, plant_name FROM plants ORDER BY plant_name",
    );
    res.json(result.rows);
  } catch (error) {
    console.error("getPlants error:", error);
    res
      .status(500)
      .json({ message: "Error fetching plants", error: error.message });
  }
};
