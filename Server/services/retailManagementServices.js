const pool = require("../db/database");
const { v4: uuidv4 } = require("uuid");

async function generateUniqueId(client, tableName, idColumn) {
  let id, exists;
  do {
    id = uuidv4();
    const check = await client.query(
      `SELECT 1 FROM ${tableName} WHERE ${idColumn} = $1`,
      [id]
    );
    exists = check.rowCount > 0;
  } while (exists);
  return id;
}

// ---- Retailer profile ----

// ---- Retailer profile ----

exports.createRetailer = async (req, res) => {
  const {
    user_id,
    shop_name,
    shop_address,
    gst_number,
    business_type,
    license_number,
    latitude,
    longitude,
    image_id, // <--- NEW: from images table
  } = req.body;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const userRes = await client.query(
      "SELECT user_id FROM users_auth WHERE user_id = $1 LIMIT 1",
      [user_id]
    );
    if (userRes.rowCount === 0) {
      throw new Error("Invalid user_id. User not found.");
    }

    const retailer_id = await generateUniqueId(
      client,
      "retailers",
      "retailer_id"
    );

    const result = await client.query(
      `INSERT INTO retailers 
        (retailer_id, user_id, shop_name, shop_address, gst_number, business_type, license_number, latitude, longitude, image_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [
        retailer_id,
        user_id,
        shop_name,
        shop_address,
        gst_number,
        business_type,
        license_number,
        latitude,
        longitude,
        image_id || null,
      ]
    );

    await client.query("COMMIT");
    res.json({ message: "Retailer created", retailer: result.rows[0] });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("createRetailer error:", error);
    res.status(500).json({ message: "Error creating retailer", error });
  } finally {
    client.release();
  }
};

exports.getRetailerById = async (req, res) => {
  const { id } = req.params; // retailer_id
  try {
    const sql = `
      SELECT 
        r.*,
        ud.name,
        ud.address,
        ud.pincode,
        img.image_url AS shop_image_url
      FROM retailers r
      LEFT JOIN user_details ud ON r.user_id = ud.user_id
      LEFT JOIN images img ON r.image_id = img.image_id
      WHERE r.retailer_id = $1
    `;
    const result = await pool.query(sql, [id]);
    if (result.rowCount === 0) {
      return res.status(404).json({ message: "Retailer not found" });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error("getRetailerById error:", error);
    res.status(500).json({ message: "Error fetching retailer", error });
  }
};

exports.updateRetailer = async (req, res) => {
  const { id } = req.params; // retailer_id
  const {
    shop_name,
    shop_address,
    gst_number,
    business_type,
    license_number,
    is_verified,
    image_id, // <--- NEW
  } = req.body;

  try {
    const sql = `
      UPDATE retailers
      SET shop_name = COALESCE($2, shop_name),
          shop_address = COALESCE($3, shop_address),
          gst_number = COALESCE($4, gst_number),
          business_type = COALESCE($5, business_type),
          license_number = COALESCE($6, license_number),
          is_verified = COALESCE($7, is_verified),
          image_id = COALESCE($8, image_id)
      WHERE retailer_id = $1
      RETURNING *
    `;
    const result = await pool.query(sql, [
      id,
      shop_name,
      shop_address,
      gst_number,
      business_type,
      license_number,
      is_verified,
      image_id,
    ]);

    if (result.rowCount === 0) {
      return res.status(404).json({ message: "Retailer not found" });
    }

    res.json({ message: "Retailer updated", retailer: result.rows[0] });
  } catch (error) {
    console.error("updateRetailer error:", error);
    res.status(500).json({ message: "Error updating retailer", error });
  }
};

// lat,lng from query; join user_details like in farms service
exports.getNearbyRetailers = async (req, res) => {
  const { lat, lng } = req.query;

  if (!lat || !lng) {
    return res
      .status(400)
      .json({ message: "lat and lng query params are required" });
  }

  try {
    const sql = `
      WITH nearby AS (
        SELECT 
          r.retailer_id,
          r.shop_name,
          r.business_type,
          ud.latitude,
          ud.longitude,
          ud.name AS owner_name,
          (6371 * acos(
            cos(radians($1)) * cos(radians(ud.latitude)) *
            cos(radians(ud.longitude) - radians($2)) +
            sin(radians($1)) * sin(radians(ud.latitude))
          )) AS distance_km
        FROM retailers r
        JOIN user_details ud ON r.user_id = ud.user_id
        WHERE ud.latitude BETWEEN $1-0.05 AND $1+0.05
          AND ud.longitude BETWEEN $2-0.05 AND $2+0.05
      )
      SELECT * FROM nearby
      WHERE distance_km <= 5
      ORDER BY distance_km
    `;
    const result = await pool.query(sql, [parseFloat(lat), parseFloat(lng)]);
    res.json(result.rows);
  } catch (error) {
    console.error("getNearbyRetailers error:", error);
    res.status(500).json({ message: "Error fetching nearby retailers", error });
  }
};

// ---- Products ----

exports.createProduct = async (req, res) => {
  const {
    retailer_id,
    category,
    product_name,
    brand,
    price,
    unit,
    stock_qty,
    description,
    image_id, // <- from images table (optional)
  } = req.body;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const product_id = await generateUniqueId(
      client,
      "retailer_products",
      "product_id"
    );

    const result = await client.query(
      `INSERT INTO retailer_products 
        (product_id, retailer_id, category, product_name, brand, price, unit, stock_qty, description, image_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [
        product_id,
        retailer_id,
        category,
        product_name,
        brand,
        price,
        unit,
        stock_qty || 0,
        description,
        image_id || null,
      ]
    );

    await client.query("COMMIT");
    res.json({ message: "Product added", product: result.rows[0] });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("createProduct error:", error);
    res.status(500).json({ message: "Error adding product", error });
  } finally {
    client.release();
  }
};

exports.getProductsByRetailer = async (req, res) => {
  const { id } = req.params; // retailer_id
  try {
    const sql = `
      SELECT 
        rp.*,
        img.image_url AS product_image_url
      FROM retailer_products rp
      LEFT JOIN images img ON rp.image_id = img.image_id
      WHERE rp.retailer_id = $1
      ORDER BY rp.created_at DESC
    `;
    const result = await pool.query(sql, [id]);
    res.json(result.rows);
  } catch (error) {
    console.error("getProductsByRetailer error:", error);
    res.status(500).json({ message: "Error fetching products", error });
  }
};

exports.updateProduct = async (req, res) => {
  const { id } = req.params; // product_id
  const {
    category,
    product_name,
    brand,
    price,
    unit,
    stock_qty,
    is_active,
    image_id, // <- NEW optional
  } = req.body;

  try {
    const sql = `
      UPDATE retailer_products
      SET category    = COALESCE($2, category),
          product_name = COALESCE($3, product_name),
          brand       = COALESCE($4, brand),
          price       = COALESCE($5, price),
          unit        = COALESCE($6, unit),
          stock_qty   = COALESCE($7, stock_qty),
          is_active   = COALESCE($8, is_active),
          image_id    = COALESCE($9, image_id)
      WHERE product_id = $1
      RETURNING *
    `;
    const result = await pool.query(sql, [
      id,
      category,
      product_name,
      brand,
      price,
      unit,
      stock_qty,
      is_active,
      image_id,
    ]);

    if (result.rowCount === 0) {
      return res.status(404).json({ message: "Product not found" });
    }

    res.json({ message: "Product updated", product: result.rows[0] });
  } catch (error) {
    console.error("updateProduct error:", error);
    res.status(500).json({ message: "Error updating product", error });
  }
};

exports.toggleProduct = async (req, res) => {
  const { id } = req.params;
  const { is_active } = req.body;

  try {
    const sql = `
      UPDATE retailer_products
      SET is_active = $2
      WHERE product_id = $1
      RETURNING *
    `;
    const result = await pool.query(sql, [id, !!is_active]);

    if (result.rowCount === 0) {
      return res.status(404).json({ message: "Product not found" });
    }

    res.json({ message: "Product status updated", product: result.rows[0] });
  } catch (error) {
    console.error("toggleProduct error:", error);
    res.status(500).json({ message: "Error updating status", error });
  }
};

exports.deleteProduct = async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query("DELETE FROM retailer_products WHERE product_id = $1", [
      id,
    ]);
    res.json({ message: "Product deleted" });
  } catch (error) {
    console.error("deleteProduct error:", error);
    res.status(500).json({ message: "Error deleting product", error });
  }
};
