// Server/services/retailManagementServices.js (or similar)
const { query } = require("../db/database");
const { v4: uuidv4 } = require("uuid");

async function generateUniqueId(queryFn, tableName, idColumn) {
  let id, exists;
  do {
    id = uuidv4();
    const check = await queryFn(
      `SELECT 1 FROM ${tableName} WHERE ${idColumn} = $1`,
      [id],
    );
    exists = check.rowCount > 0;
  } while (exists);
  return id;
}

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
    shop_number,
  } = req.body;

  try {
    await query("BEGIN");

    // Validate user exists
    const userRes = await query(
      "SELECT user_id FROM users_auth WHERE user_id = $1 LIMIT 1",
      [user_id],
    );
    if (userRes.rowCount === 0) {
      throw new Error("Invalid user_id. User not found.");
    }

    // Generate retailer_id
    const retailer_id = await generateUniqueId(
      query,
      "retailers",
      "retailer_id",
    );

    // Generate image_id and insert into images table with NULL image_url
    const image_id = uuidv4();
    await query("INSERT INTO images (image_id, image_url) VALUES ($1, NULL)", [
      image_id,
    ]);

    // Create retailer with the pre-generated image_id
    const result = await query(
      `INSERT INTO retailers 
         (retailer_id, user_id, shop_name, shop_address, gst_number, business_type, license_number, latitude, longitude, shop_number, image_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
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
        shop_number,
        image_id,
      ],
    );

    await query("COMMIT");
    res.json({
      message: "Retailer created",
      retailer_id: result.rows[0].retailer_id,
    });
  } catch (error) {
    await query("ROLLBACK");
    console.error("createRetailer error:", error);
    res
      .status(500)
      .json({ message: "Error creating retailer", error: error.message });
  }
};

exports.createRetailerAdmin = async (req, res) => {
  const {
    phone_number, // ← instead of user_id
    shop_name,
    shop_address,
    gst_number,
    business_type,
    license_number,
    latitude,
    longitude,
    shop_number,
  } = req.body;

  try {
    await query("BEGIN");

    // Step 1: Lookup user_id from phone_number in users_auth
    const userRes = await query(
      "SELECT user_id FROM users_auth WHERE phone_number = $1 LIMIT 1",
      [phone_number],
    );

    if (userRes.rowCount === 0) {
      await query("ROLLBACK");
      return res.status(404).json({
        success: false,
        message: "No user found with this phone number.",
      });
    }

    const user_id = userRes.rows[0].user_id;

    // Step 2: Check if retailer already exists for this user
    const existingRetailer = await query(
      "SELECT retailer_id FROM retailers WHERE user_id = $1 LIMIT 1",
      [user_id],
    );

    if (existingRetailer.rowCount > 0) {
      await query("ROLLBACK");
      return res.status(409).json({
        success: false,
        message: "A retailer already exists for this user.",
        retailer_id: existingRetailer.rows[0].retailer_id,
      });
    }

    // Step 3: Generate retailer_id
    const retailer_id = await generateUniqueId(
      query,
      "retailers",
      "retailer_id",
    );

    // Step 4: Generate image_id and insert into images table
    const image_id = uuidv4();
    await query("INSERT INTO images (image_id, image_url) VALUES ($1, NULL)", [
      image_id,
    ]);

    // Step 5: Insert retailer
    const result = await query(
      `INSERT INTO retailers 
         (retailer_id, user_id, shop_name, shop_address, gst_number, business_type, license_number, latitude, longitude, shop_number, image_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
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
        shop_number,
        image_id,
      ],
    );

    await query("COMMIT");

    res.status(201).json({
      success: true,
      message: "Retailer created successfully by admin",
      retailer_id: result.rows[0].retailer_id,
      user_id: user_id,
      phone_number: phone_number,
    });
  } catch (error) {
    await query("ROLLBACK");
    console.error("createRetailerAdmin error:", error);
    res.status(500).json({
      success: false,
      message: "Error creating retailer",
      error: error.message,
    });
  }
};

exports.getRetailerById = async (req, res) => {
  const { id } = req.params; // user_id
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
      WHERE r.user_id = $1
    `;
    const result = await query(sql, [id]);
    if (result.rowCount === 0) {
      return res.status(404).json({ message: "Retailer not found" });
    }
    res.json(result.rows);
  } catch (error) {
    console.error("getRetailerById error:", error);
    res.status(500).json({ message: "Error fetching retailer", error });
  }
};

exports.getRetailerByRetailId = async (req, res) => {
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
    const result = await query(sql, [id]);
    if (result.rowCount === 0) {
      return res.status(404).json({ message: "Retailer not found" });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error("getRetailerByRetailId error:", error);
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
    image_id,
    shop_number,
  } = req.body;

  try {
    const sql = `
      UPDATE retailers
      SET shop_name     = COALESCE($2, shop_name),
          shop_address  = COALESCE($3, shop_address),
          gst_number    = COALESCE($4, gst_number),
          business_type = COALESCE($5, business_type),
          license_number= COALESCE($6, license_number),
          is_verified   = COALESCE($7, is_verified),
          image_id      = COALESCE($8, image_id),
          shop_number   = COALESCE($9, shop_number)
      WHERE retailer_id = $1
      RETURNING *
    `;
    const result = await query(sql, [
      id,
      shop_name,
      shop_address,
      gst_number,
      business_type,
      license_number,
      is_verified,
      image_id,
      shop_number,
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
    const result = await query(sql, [parseFloat(lat), parseFloat(lng)]);
    res.json(result.rows);
  } catch (error) {
    console.error("getNearbyRetailers error:", error);
    res.status(500).json({ message: "Error fetching nearby retailers", error });
  }
};

// ---- Products ----

// Server/services/retailManagementServices.js

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
  } = req.body;

  try {
    const userId = req.user_id;

    const ownerCheck = await query(
      "SELECT 1 FROM retailers WHERE retailer_id = $1 AND user_id = $2",
      [retailer_id, userId],
    );

    if (ownerCheck.rowCount === 0) {
      return res.status(403).json({ message: "You don't own this shop" });
    }

    await query("BEGIN");

    // Generate product_id
    const product_id = await generateUniqueId(
      query,
      "retailer_products",
      "product_id",
    );

    // Generate image_id and insert placeholder into images table
    const image_id = uuidv4();
    await query(
      "INSERT INTO images (image_id, image_url) VALUES ($1, 'no-image')",
      [image_id],
    );

    // Insert product with the pre-generated image_id
    const result = await query(
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
        image_id, // Always include the generated image_id
      ],
    );

    await query("COMMIT");
    res.json({
      message: "Product added",
      product_id: result.rows[0].product_id,
      image_id: image_id, // Return image_id to frontend
    });
  } catch (error) {
    await query("ROLLBACK");
    console.error("createProduct error:", error);
    res
      .status(500)
      .json({ message: "Error adding product", error: error.message });
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
    const result = await query(sql, [id]);
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
    image_id,
  } = req.body;

  try {
    const sql = `
      UPDATE retailer_products
      SET category     = COALESCE($2, category),
          product_name = COALESCE($3, product_name),
          brand        = COALESCE($4, brand),
          price        = COALESCE($5, price),
          unit         = COALESCE($6, unit),
          stock_qty    = COALESCE($7, stock_qty),
          is_active    = COALESCE($8, is_active),
          image_id     = COALESCE($9, image_id)
      WHERE product_id = $1
      RETURNING *
    `;
    const result = await query(sql, [
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

exports.toggleProductStatus = async (req, res) => {
  const { id } = req.params;

  try {
    const sql = `
      UPDATE retailer_products
      SET is_active = NOT is_active
      WHERE product_id = $1
      RETURNING product_id, product_name, is_active
    `;
    const result = await query(sql, [id]);

    if (result.rowCount === 0) {
      return res.status(404).json({ message: "Product not found" });
    }

    const product = result.rows[0];
    res.json({
      message: `Product ${product.is_active ? "activated" : "deactivated"} successfully`,
      is_active: product.is_active,
    });
  } catch (error) {
    console.error("toggleProductStatus error:", error);
    res.status(500).json({ message: "Error toggling product status", error });
  }
};

exports.deleteProduct = async (req, res) => {
  const { id } = req.params;
  try {
    await query("DELETE FROM retailer_products WHERE product_id = $1", [id]);
    res.json({ message: "Product deleted" });
  } catch (error) {
    console.error("deleteProduct error:", error);
    res.status(500).json({ message: "Error deleting product", error });
  }
};

// ---- List all retailers with basic details + owner + image ----

exports.getAllRetailers = async (req, res) => {
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
      ORDER BY r.created_at DESC
    `;
    const result = await query(sql);
    res.json(result.rows);
  } catch (error) {
    console.error("getAllRetailers error:", error);
    res.status(500).json({ message: "Error fetching retailers", error });
  }
};

// ---- List all retailers with their products (nested) ----

exports.getRetailersWithProducts = async (req, res) => {
  try {
    const sql = `
      SELECT
        r.retailer_id,
        r.user_id,
        r.shop_name,
        r.shop_address,
        r.gst_number,
        r.business_type,
        r.license_number,
        r.is_verified,
        r.created_at,
        r.latitude,
        r.longitude,
        ud.name,
        ud.address,
        ud.pincode,
        img.image_url AS shop_image_url,
        rp.product_id,
        rp.category,
        rp.product_name,
        rp.brand,
        rp.price,
        rp.unit,
        rp.stock_qty,
        rp.is_active,
        rp.created_at AS product_created_at,
        img_p.image_url AS product_image_url
      FROM retailers r
      LEFT JOIN user_details ud ON r.user_id = ud.user_id
      LEFT JOIN images img ON r.image_id = img.image_id
      LEFT JOIN retailer_products rp ON r.retailer_id = rp.retailer_id
      LEFT JOIN images img_p ON rp.image_id = img_p.image_id
      ORDER BY r.created_at DESC, rp.created_at DESC
    `;

    const result = await query(sql);

    const map = new Map();

    for (const row of result.rows) {
      if (!map.has(row.retailer_id)) {
        map.set(row.retailer_id, {
          retailer_id: row.retailer_id,
          user_id: row.user_id,
          shop_name: row.shop_name,
          shop_address: row.shop_address,
          gst_number: row.gst_number,
          business_type: row.business_type,
          license_number: row.license_number,
          is_verified: row.is_verified,
          created_at: row.created_at,
          latitude: row.latitude,
          longitude: row.longitude,
          name: row.name,
          address: row.address,
          pincode: row.pincode,
          shop_image_url: row.shop_image_url,
          products: [],
        });
      }

      if (row.product_id) {
        map.get(row.retailer_id).products.push({
          product_id: row.product_id,
          retailer_id: row.retailer_id,
          category: row.category,
          product_name: row.product_name,
          brand: row.brand,
          price: row.price,
          unit: row.unit,
          stock_qty: row.stock_qty,
          is_active: row.is_active,
          created_at: row.product_created_at,
          product_image_url: row.product_image_url,
        });
      }
    }

    res.json(Array.from(map.values()));
  } catch (error) {
    console.error("getRetailersWithProducts error:", error);
    res
      .status(500)
      .json({ message: "Error fetching retailers & products", error });
  }
};

exports.getStoreLocations = async (req, res) => {
  try {
    const sql = `
      SELECT 
        retailer_id,
        shop_name,
        shop_address,
        business_type,
        latitude,
        longitude
      FROM retailers
      WHERE latitude IS NOT NULL 
        AND longitude IS NOT NULL
      ORDER BY created_at DESC
    `;
    const result = await query(sql);
    res.json(result.rows);
  } catch (error) {
    console.error("getStoreLocations error:", error);
    res.status(500).json({ message: "Error fetching store locations", error });
  }
};
