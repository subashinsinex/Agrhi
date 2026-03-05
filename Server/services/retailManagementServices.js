// Retailer and product management services
const { query } = require("../db/database");
const { v4: uuidv4 } = require("uuid");
const logger = require("../utils/logger");

// ─── Utility ───────────────────────────────────────────────────────

async function generateUniqueId(queryFn, tableName, idColumn) {
  logger.info("Generating unique ID", { tableName, idColumn });
  let id, exists;
  do {
    id = uuidv4();
    const check = await queryFn(
      `SELECT 1 FROM ${tableName} WHERE ${idColumn} = $1`,
      [id],
    );
    exists = check.rowCount > 0;
  } while (exists);
  logger.info("Generated unique ID", { id, tableName });
  return id;
}

// ─── Retailer Services ─────────────────────────────────────────────

// Farmer/user creates their own retailer profile
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

  logger.info("Creating retailer", { user_id, shop_name });

  try {
    await query("BEGIN");

    const userRes = await query(
      "SELECT user_id FROM users_auth WHERE user_id = $1 LIMIT 1",
      [user_id],
    );

    logger.info("User validation", { user_id, exists: userRes.rowCount > 0 });

    if (userRes.rowCount === 0) {
      await query("ROLLBACK");
      logger.error("Invalid user_id", { user_id });
      return res.status(404).json({
        success: false,
        message: "Invalid user_id. User not found.",
      });
    }

    const retailer_id = await generateUniqueId(
      query,
      "retailers",
      "retailer_id",
    );
    const image_id = uuidv4();

    await query("INSERT INTO images (image_id, image_url) VALUES ($1, NULL)", [
      image_id,
    ]);

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
    logger.info("Retailer created successfully", { retailer_id });

    res.status(201).json({
      success: true,
      message: "Retailer created",
      retailer_id: result.rows[0].retailer_id,
    });
  } catch (error) {
    await query("ROLLBACK");
    logger.error("createRetailer error:", error);
    res.status(500).json({
      success: false,
      message: "Error creating retailer",
      error: error.message,
    });
  }
};

// Admin creates retailer by looking up user via phone number
exports.createRetailerAdmin = async (req, res) => {
  const {
    phone_number,
    shop_name,
    shop_address,
    gst_number,
    business_type,
    license_number,
    latitude,
    longitude,
    shop_number,
  } = req.body;

  logger.info("Admin creating retailer", { phone_number, shop_name });

  try {
    await query("BEGIN");

    // Step 1: Lookup user_id from phone_number
    const userRes = await query(
      "SELECT user_id FROM users_auth WHERE phone_number = $1 LIMIT 1",
      [phone_number],
    );

    if (userRes.rowCount === 0) {
      await query("ROLLBACK");
      logger.warn("No user found with phone number", { phone_number });
      return res.status(404).json({
        success: false,
        message: "No user found with this phone number.",
      });
    }

    const user_id = userRes.rows[0].user_id;

    // Step 2: Prevent duplicate retailer for same user
    const existingRetailer = await query(
      "SELECT retailer_id FROM retailers WHERE user_id = $1 LIMIT 1",
      [user_id],
    );

    if (existingRetailer.rowCount > 0) {
      await query("ROLLBACK");
      logger.warn("Retailer already exists for user", { user_id });
      return res.status(409).json({
        success: false,
        message: "A retailer already exists for this user.",
        retailer_id: existingRetailer.rows[0].retailer_id,
      });
    }

    // Step 3: Generate IDs and insert
    const retailer_id = await generateUniqueId(
      query,
      "retailers",
      "retailer_id",
    );
    const image_id = uuidv4();

    await query("INSERT INTO images (image_id, image_url) VALUES ($1, NULL)", [
      image_id,
    ]);

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
    logger.info("Admin created retailer successfully", {
      retailer_id,
      user_id,
    });

    res.status(201).json({
      success: true,
      message: "Retailer created successfully by admin",
      retailer_id: result.rows[0].retailer_id,
      user_id,
      phone_number,
    });
  } catch (error) {
    await query("ROLLBACK");
    logger.error("createRetailerAdmin error:", error);
    res.status(500).json({
      success: false,
      message: "Error creating retailer",
      error: error.message,
    });
  }
};

// Get retailer details by user_id
exports.getRetailerById = async (req, res) => {
  const { id } = req.params;
  logger.info("Fetching retailer by user_id", { id });

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
      logger.warn("Retailer not found by user_id", { id });
      return res.status(404).json({ message: "Retailer not found" });
    }

    logger.info("Retailer fetched by user_id", { id, count: result.rowCount });
    res.json(result.rows);
  } catch (error) {
    logger.error("getRetailerById error:", { id, error });
    res.status(500).json({ message: "Error fetching retailer", error });
  }
};

// Get retailer details by retailer_id
exports.getRetailerByRetailId = async (req, res) => {
  const { id } = req.params;
  logger.info("Fetching retailer by retailer_id", { id });

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
      logger.warn("Retailer not found by retailer_id", { id });
      return res.status(404).json({ message: "Retailer not found" });
    }

    logger.info("Retailer fetched by retailer_id", { id });
    res.json(result.rows[0]);
  } catch (error) {
    logger.error("getRetailerByRetailId error:", { id, error });
    res.status(500).json({ message: "Error fetching retailer", error });
  }
};

// Get all retailers with owner details and shop image
exports.getAllRetailers = async (req, res) => {
  logger.info("Fetching all retailers");

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

    logger.info("All retailers fetched", { count: result.rows.length });
    res.json(result.rows);
  } catch (error) {
    logger.error("getAllRetailers error:", error);
    res.status(500).json({ message: "Error fetching retailers", error });
  }
};

// Update retailer details
exports.updateRetailer = async (req, res) => {
  const { id } = req.params;
  const updates = req.body;
  logger.info("Updating retailer", { id });

  try {
    const sql = `
      UPDATE retailers
      SET shop_name      = COALESCE($2, shop_name),
          shop_address   = COALESCE($3, shop_address),
          gst_number     = COALESCE($4, gst_number),
          business_type  = COALESCE($5, business_type),
          license_number = COALESCE($6, license_number),
          is_verified    = COALESCE($7, is_verified),
          image_id       = COALESCE($8, image_id),
          shop_number    = COALESCE($9, shop_number)
      WHERE retailer_id = $1
      RETURNING *
    `;
    const result = await query(sql, [
      id,
      updates.shop_name,
      updates.shop_address,
      updates.gst_number,
      updates.business_type,
      updates.license_number,
      updates.is_verified,
      updates.image_id,
      updates.shop_number,
    ]);

    if (result.rowCount === 0) {
      logger.warn("Retailer not found for update", { id });
      return res.status(404).json({ message: "Retailer not found" });
    }

    logger.info("Retailer updated successfully", { id });
    res.json({ message: "Retailer updated", retailer: result.rows[0] });
  } catch (error) {
    logger.error("updateRetailer error:", { id, error });
    res.status(500).json({ message: "Error updating retailer", error });
  }
};

// Find nearby retailers within 5km radius
exports.getNearbyRetailers = async (req, res) => {
  const { lat, lng } = req.query;
  logger.info("Finding nearby retailers", { lat, lng });

  if (!lat || !lng) {
    logger.error("Missing lat/lng params");
    return res.status(400).json({
      message: "lat and lng query params are required",
    });
  }

  try {
    const sql = `
      WITH nearby AS (
        SELECT 
          r.retailer_id,
          r.shop_name,
          r.business_type,
          r.latitude,
          r.longitude,
          ud.name AS owner_name,
          (6371 * acos(
            cos(radians($1)) * cos(radians(r.latitude)) *
            cos(radians(r.longitude) - radians($2)) +
            sin(radians($1)) * sin(radians(r.latitude))
          )) AS distance_km
        FROM retailers r
        JOIN user_details ud ON r.user_id = ud.user_id
        WHERE r.latitude  BETWEEN $1 - 0.05 AND $1 + 0.05
          AND r.longitude BETWEEN $2 - 0.05 AND $2 + 0.05
      )
      SELECT * FROM nearby
      WHERE distance_km <= 5
      ORDER BY distance_km
    `;
    const result = await query(sql, [parseFloat(lat), parseFloat(lng)]);

    logger.info("Nearby retailers found", {
      lat,
      lng,
      count: result.rows.length,
    });
    res.json(result.rows);
  } catch (error) {
    logger.error("getNearbyRetailers error:", { lat, lng, error });
    res.status(500).json({ message: "Error fetching nearby retailers", error });
  }
};

// Get all retailers with their nested products list
exports.getRetailersWithProducts = async (req, res) => {
  logger.info("Fetching retailers with products");

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
        img.image_url        AS shop_image_url,
        rp.product_id,
        rp.category,
        rp.product_name,
        rp.brand,
        rp.price,
        rp.unit,
        rp.stock_qty,
        rp.is_active,
        rp.created_at        AS product_created_at,
        img_p.image_url      AS product_image_url
      FROM retailers r
      LEFT JOIN user_details ud       ON r.user_id    = ud.user_id
      LEFT JOIN images img            ON r.image_id   = img.image_id
      LEFT JOIN retailer_products rp  ON r.retailer_id = rp.retailer_id
      LEFT JOIN images img_p          ON rp.image_id  = img_p.image_id
      ORDER BY r.created_at DESC, rp.created_at DESC
    `;

    const result = await query(sql);

    // Group products under each retailer
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

    const retailers = Array.from(map.values());
    logger.info("Retailers with products fetched", {
      retailerCount: retailers.length,
    });
    res.json(retailers);
  } catch (error) {
    logger.error("getRetailersWithProducts error:", error);
    res
      .status(500)
      .json({ message: "Error fetching retailers & products", error });
  }
};

// ─── Product Services ──────────────────────────────────────────────

// Create new product with image placeholder
exports.createProduct = async (req, res) => {
  const data = req.body;
  const userId = req.user_id;
  logger.info("Creating product", { retailer_id: data.retailer_id, userId });

  try {
    const ownerCheck = await query(
      "SELECT 1 FROM retailers WHERE retailer_id = $1 AND user_id = $2",
      [data.retailer_id, userId],
    );

    if (ownerCheck.rowCount === 0) {
      logger.error("User doesn't own retailer", {
        userId,
        retailer_id: data.retailer_id,
      });
      return res.status(403).json({ message: "You don't own this shop" });
    }

    await query("BEGIN");

    const product_id = await generateUniqueId(
      query,
      "retailer_products",
      "product_id",
    );
    const image_id = uuidv4();

    await query(
      "INSERT INTO images (image_id, image_url) VALUES ($1, 'no-image')",
      [image_id],
    );

    const result = await query(
      `INSERT INTO retailer_products 
         (product_id, retailer_id, category, product_name, brand, price, unit, stock_qty, description, image_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [
        product_id,
        data.retailer_id,
        data.category,
        data.product_name,
        data.brand,
        data.price,
        data.unit,
        data.stock_qty || 0,
        data.description,
        image_id,
      ],
    );

    await query("COMMIT");
    logger.info("Product created successfully", {
      product_id,
      retailer_id: data.retailer_id,
    });

    res.status(201).json({
      success: true,
      message: "Product added",
      product_id: result.rows[0].product_id,
      image_id,
    });
  } catch (error) {
    await query("ROLLBACK");
    logger.error("createProduct error:", error);
    res.status(500).json({
      success: false,
      message: "Error adding product",
      error: error.message,
    });
  }
};

// Get all products for a retailer
exports.getProductsByRetailer = async (req, res) => {
  const { id } = req.params;
  logger.info("Fetching products by retailer", { id });

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

    logger.info("Products fetched", {
      retailer_id: id,
      count: result.rows.length,
    });
    res.json(result.rows);
  } catch (error) {
    logger.error("getProductsByRetailer error:", { id, error });
    res.status(500).json({ message: "Error fetching products", error });
  }
};

// Update product details
exports.updateProduct = async (req, res) => {
  const { id } = req.params;
  const updates = req.body;
  logger.info("Updating product", { id });

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
      updates.category,
      updates.product_name,
      updates.brand,
      updates.price,
      updates.unit,
      updates.stock_qty,
      updates.is_active,
      updates.image_id,
    ]);

    if (result.rowCount === 0) {
      logger.warn("Product not found for update", { id });
      return res.status(404).json({ message: "Product not found" });
    }

    logger.info("Product updated successfully", { id });
    res.json({ message: "Product updated", product: result.rows[0] });
  } catch (error) {
    logger.error("updateProduct error:", { id, error });
    res.status(500).json({ message: "Error updating product", error });
  }
};

// Toggle product active/inactive status
exports.toggleProductStatus = async (req, res) => {
  const { id } = req.params;
  logger.info("Toggling product status", { id });

  try {
    const sql = `
      UPDATE retailer_products
      SET is_active = NOT is_active
      WHERE product_id = $1
      RETURNING product_id, product_name, is_active
    `;
    const result = await query(sql, [id]);

    if (result.rowCount === 0) {
      logger.warn("Product not found for toggle", { id });
      return res.status(404).json({ message: "Product not found" });
    }

    const product = result.rows[0];
    logger.info("Product status toggled", { id, is_active: product.is_active });

    res.json({
      message: `Product ${product.is_active ? "activated" : "deactivated"} successfully`,
      is_active: product.is_active,
    });
  } catch (error) {
    logger.error("toggleProductStatus error:", { id, error });
    res.status(500).json({ message: "Error toggling product status", error });
  }
};

// Delete product by product_id (admin only — enforced at route level)
exports.deleteProduct = async (req, res) => {
  const { id } = req.params;
  logger.info("Deleting product", { id });

  try {
    const result = await query(
      "DELETE FROM retailer_products WHERE product_id = $1 RETURNING product_id",
      [id],
    );

    if (result.rowCount === 0) {
      logger.warn("Product not found for delete", { id });
      return res.status(404).json({ message: "Product not found" });
    }

    logger.info("Product deleted successfully", { id });
    res.json({ success: true, message: "Product deleted" });
  } catch (error) {
    logger.error("deleteProduct error:", { id, error });
    res.status(500).json({ message: "Error deleting product", error });
  }
};

// ─── Store Location Service ────────────────────────────────────────

// Get store locations for map display
exports.getStoreLocations = async (req, res) => {
  logger.info("Fetching store locations");

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
      WHERE latitude  IS NOT NULL
        AND longitude IS NOT NULL
      ORDER BY created_at DESC
    `;
    const result = await query(sql);

    logger.info("Store locations fetched", { count: result.rows.length });
    res.json(result.rows);
  } catch (error) {
    logger.error("getStoreLocations error:", error);
    res.status(500).json({ message: "Error fetching store locations", error });
  }
};
