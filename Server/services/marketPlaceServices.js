// Marketplace services (products, sellers, stats)
const pool = require("../db/database");
const logger = require("../utils/logger");

// Shared bounding box calculator for geo queries
function getBoundingBox(latitude, longitude, maxDistance) {
  const latDelta = maxDistance / 111.32;
  const lngDelta =
    maxDistance / (111.32 * Math.cos((latitude * Math.PI) / 180));

  return {
    minLat: latitude - latDelta,
    maxLat: latitude + latDelta,
    minLng: longitude - lngDelta,
    maxLng: longitude + lngDelta,
  };
}

// Get unified marketplace products (farm + retail) by location
exports.getMarketplaceProducts = async (req, res) => {
  const { lat, lng, search, max_distance, product_type } = req.query;

  logger.info("getMarketplaceProducts - Request", {
    lat,
    lng,
    search,
    max_distance,
    product_type,
  });

  if (!lat || !lng) {
    logger.error("getMarketplaceProducts - Missing lat/lng");
    return res.status(400).json({
      success: false,
      message: "User location (lat, lng) is required",
    });
  }

  const latitude = parseFloat(lat);
  const longitude = parseFloat(lng);
  const maxDistance = max_distance ? parseFloat(max_distance) : 50;

  if (isNaN(latitude) || isNaN(longitude)) {
    logger.error("getMarketplaceProducts - Invalid lat/lng", { lat, lng });
    return res.status(400).json({
      success: false,
      message: "Invalid latitude or longitude",
    });
  }

  try {
    const { minLat, maxLat, minLng, maxLng } = getBoundingBox(
      latitude,
      longitude,
      maxDistance,
    );

    const params = [latitude, longitude, minLat, maxLat, minLng, maxLng];
    let paramIndex = 7;

    let searchCondition = "";
    if (search) {
      searchCondition = `AND (product_name ILIKE $${paramIndex} OR description ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }

    const fetchFarmerProducts =
      !product_type || product_type === "all" || product_type === "farm";
    const fetchRetailerProducts =
      !product_type || product_type === "all" || product_type === "retail";

    const queries = [];

    if (fetchFarmerProducts) {
      queries.push(`
        SELECT
          fp.product_id,
          fp.product_name,
          fp.variety,
          fp.description,
          fp.price_per_unit,
          fp.unit,
          fp.quantity_available,
          fp.is_available,
          fp.created_at,
          NULL AS category,
          'farm' AS product_type,
          'Farm Product' AS product_type_label,
          ud.name AS seller_name,
          ud.pic_url AS seller_pic,
          ua.phone_number AS seller_phone,
          fp.farmer_id AS seller_id,
          i.image_url,
          fsp.latitude AS shop_latitude,
          fsp.longitude AS shop_longitude,
          fsp.farmer_id AS place_id,
          (
            6371 * acos(
              LEAST(1.0, GREATEST(-1.0,
                cos(radians($1)) * cos(radians(fsp.latitude)) *
                cos(radians(fsp.longitude) - radians($2)) +
                sin(radians($1)) * sin(radians(fsp.latitude))
              ))
            )
          ) AS distance_km
        FROM farmer_products fp
        INNER JOIN farmer_shop_place fsp ON fp.farmer_id = fsp.farmer_id
          AND fsp.latitude BETWEEN $3 AND $4
          AND fsp.longitude BETWEEN $5 AND $6
        LEFT JOIN user_details ud ON fp.farmer_id = ud.user_id
        LEFT JOIN users_auth ua ON fp.farmer_id = ua.user_id
        LEFT JOIN images i ON fp.image_id = i.image_id
        WHERE fp.is_available = true
        ${searchCondition}
      `);
    }

    if (fetchRetailerProducts) {
      queries.push(`
        SELECT
          rp.product_id,
          rp.product_name,
          rp.brand AS variety,
          rp.description,
          rp.price AS price_per_unit,
          rp.unit,
          rp.stock_qty AS quantity_available,
          rp.is_active AS is_available,
          rp.created_at,
          rp.category,
          'retail' AS product_type,
          'Retail Product' AS product_type_label,
          r.shop_name AS seller_name,
          i_shop.image_url AS seller_pic,
          ua.phone_number AS seller_phone,
          rp.retailer_id AS seller_id,
          i.image_url,
          r.latitude AS shop_latitude,
          r.longitude AS shop_longitude,
          r.retailer_id AS place_id,
          (
            6371 * acos(
              LEAST(1.0, GREATEST(-1.0,
                cos(radians($1)) * cos(radians(r.latitude)) *
                cos(radians(r.longitude) - radians($2)) +
                sin(radians($1)) * sin(radians(r.latitude))
              ))
            )
          ) AS distance_km
        FROM retailer_products rp
        INNER JOIN retailers r ON rp.retailer_id = r.retailer_id
          AND r.latitude BETWEEN $3 AND $4
          AND r.longitude BETWEEN $5 AND $6
        LEFT JOIN users_auth ua ON r.user_id = ua.user_id
        LEFT JOIN images i ON rp.image_id = i.image_id
        LEFT JOIN images i_shop ON r.image_id = i_shop.image_id
        WHERE rp.is_active = true
        ${searchCondition}
      `);
    }

    if (queries.length === 0) {
      logger.info(
        "getMarketplaceProducts - No product type matched, returning empty",
      );
      return res.json({
        success: true,
        products: [],
        total: 0,
        filters: {
          latitude,
          longitude,
          max_distance: maxDistance,
          search: search || null,
          product_type: product_type || "all",
        },
      });
    }

    const sql = `
      WITH all_products AS (
        ${queries.join(" UNION ALL ")}
      )
      SELECT *
      FROM all_products
      WHERE distance_km <= $${paramIndex}
      ORDER BY distance_km ASC, created_at DESC
    `;
    params.push(maxDistance);

    logger.info("getMarketplaceProducts - Executing query", {
      maxDistance,
      fetchFarmerProducts,
      fetchRetailerProducts,
    });

    const result = await pool.query(sql, params);

    logger.info("getMarketplaceProducts - Success", {
      count: result.rowCount,
      maxDistance,
    });

    return res.json({
      success: true,
      products: result.rows,
      total: result.rowCount,
      filters: {
        latitude,
        longitude,
        max_distance: maxDistance,
        search: search || null,
        product_type: product_type || "all",
      },
    });
  } catch (error) {
    logger.error("getMarketplaceProducts - Error:", error);
    return res.status(500).json({
      success: false,
      message: "Error fetching marketplace products",
      error: error.message,
    });
  }
};

// Get single product details (farm or retail)
exports.getProductDetails = async (req, res) => {
  const { productId } = req.params;
  const { product_type } = req.query;

  logger.info("getProductDetails - Request", { productId, product_type });

  if (!product_type || !["farm", "retail"].includes(product_type)) {
    logger.error("getProductDetails - Invalid or missing product_type", {
      product_type,
    });
    return res.status(400).json({
      success: false,
      message: "product_type (farm or retail) is required",
    });
  }

  try {
    let sql = "";

    if (product_type === "farm") {
      sql = `
        SELECT
          fp.*,
          'farm' AS product_type,
          ud.name AS seller_name,
          ud.address AS seller_address,
          ua.phone_number AS seller_phone,
          ud.pic_url AS seller_pic,
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
    } else {
      sql = `
        SELECT
          rp.product_id,
          rp.retailer_id,
          rp.product_name,
          rp.brand AS variety,
          rp.description,
          rp.price AS price_per_unit,
          rp.unit,
          rp.stock_qty AS quantity_available,
          rp.is_active AS is_available,
          rp.created_at,
          rp.category,
          'retail' AS product_type,
          r.shop_name AS seller_name,
          r.shop_address AS seller_address,
          ua.phone_number AS seller_phone,
          i_shop.image_url AS seller_pic,
          i.image_url,
          r.latitude AS shop_latitude,
          r.longitude AS shop_longitude
        FROM retailer_products rp
        LEFT JOIN retailers r ON rp.retailer_id = r.retailer_id
        LEFT JOIN users_auth ua ON r.user_id = ua.user_id
        LEFT JOIN images i ON rp.image_id = i.image_id
        LEFT JOIN images i_shop ON r.image_id = i_shop.image_id
        WHERE rp.product_id = $1
      `;
    }

    const result = await pool.query(sql, [productId]);

    if (result.rowCount === 0) {
      logger.warn("getProductDetails - Product not found", {
        productId,
        product_type,
      });
      return res.status(404).json({
        success: false,
        message: "Product not found",
      });
    }

    logger.info("getProductDetails - Success", { productId, product_type });
    return res.json({ success: true, product: result.rows[0] });
  } catch (error) {
    logger.error("getProductDetails - Error:", { productId, error });
    return res.status(500).json({
      success: false,
      message: "Error fetching product details",
      error: error.message,
    });
  }
};

// Get marketplace stats (seller and product counts by location)
exports.getMarketplaceStats = async (req, res) => {
  const { lat, lng, max_distance } = req.query;

  logger.info("getMarketplaceStats - Request", { lat, lng, max_distance });

  if (!lat || !lng) {
    logger.error("getMarketplaceStats - Missing lat/lng");
    return res.status(400).json({
      success: false,
      message: "User location (lat, lng) is required",
    });
  }

  const latitude = parseFloat(lat);
  const longitude = parseFloat(lng);
  const maxDistance = max_distance ? parseFloat(max_distance) : 50;

  try {
    const { minLat, maxLat, minLng, maxLng } = getBoundingBox(
      latitude,
      longitude,
      maxDistance,
    );

    const statsQuery = `
      WITH nearby_sellers AS (
        SELECT 
          fp.farmer_id as seller_id,
          'farm' as seller_type,
          COUNT(DISTINCT fp.product_id) as product_count,
          (
            6371 * acos(
              LEAST(1.0, GREATEST(-1.0,
                cos(radians($1)) * cos(radians(fsp.latitude)) *
                cos(radians(fsp.longitude) - radians($2)) +
                sin(radians($1)) * sin(radians(fsp.latitude))
              ))
            )
          ) AS distance_km
        FROM farmer_products fp
        INNER JOIN farmer_shop_place fsp ON fp.farmer_id = fsp.farmer_id
          AND fsp.latitude BETWEEN $3 AND $4
          AND fsp.longitude BETWEEN $5 AND $6
        WHERE fp.is_available = true
        GROUP BY fp.farmer_id, fsp.latitude, fsp.longitude

        UNION ALL

        SELECT 
          rp.retailer_id as seller_id,
          'retail' as seller_type,
          COUNT(DISTINCT rp.product_id) as product_count,
          (
            6371 * acos(
              LEAST(1.0, GREATEST(-1.0,
                cos(radians($1)) * cos(radians(r.latitude)) *
                cos(radians(r.longitude) - radians($2)) +
                sin(radians($1)) * sin(radians(r.latitude))
              ))
            )
          ) AS distance_km
        FROM retailer_products rp
        INNER JOIN retailers r ON rp.retailer_id = r.retailer_id
          AND r.latitude BETWEEN $3 AND $4
          AND r.longitude BETWEEN $5 AND $6
        WHERE rp.is_active = true
        GROUP BY rp.retailer_id, r.latitude, r.longitude
      )
      SELECT 
        COUNT(DISTINCT CASE WHEN seller_type = 'farm' THEN seller_id END) as farm_sellers,
        COUNT(DISTINCT CASE WHEN seller_type = 'retail' THEN seller_id END) as retail_sellers,
        COUNT(DISTINCT seller_id) as total_sellers,
        SUM(CASE WHEN seller_type = 'farm' THEN product_count ELSE 0 END) as total_farm_products,
        SUM(CASE WHEN seller_type = 'retail' THEN product_count ELSE 0 END) as total_retail_products,
        SUM(product_count) as total_products
      FROM nearby_sellers
      WHERE distance_km <= $7
    `;

    const result = await pool.query(statsQuery, [
      latitude,
      longitude,
      minLat,
      maxLat,
      minLng,
      maxLng,
      maxDistance,
    ]);

    const stats = result.rows[0];

    logger.info("getMarketplaceStats - Success", {
      latitude,
      longitude,
      maxDistance,
      stats,
    });

    return res.json({
      success: true,
      stats: {
        total_farm_products: parseInt(stats.total_farm_products || 0, 10),
        total_retail_products: parseInt(stats.total_retail_products || 0, 10),
        total_products: parseInt(stats.total_products || 0, 10),
        nearby_sellers: parseInt(stats.total_sellers || 0, 10),
      },
    });
  } catch (error) {
    logger.error("getMarketplaceStats - Error:", error);
    return res.status(500).json({
      success: false,
      message: "Error fetching marketplace stats",
      error: error.message,
    });
  }
};

// Search nearby sellers (farmers and retailers)
exports.searchSellers = async (req, res) => {
  const { lat, lng, search, max_distance } = req.query;

  logger.info("searchSellers - Request", { lat, lng, search, max_distance });

  if (!lat || !lng) {
    logger.error("searchSellers - Missing lat/lng");
    return res.status(400).json({
      success: false,
      message: "User location (lat, lng) is required",
    });
  }

  const latitude = parseFloat(lat);
  const longitude = parseFloat(lng);
  const maxDistance = max_distance ? parseFloat(max_distance) : 50;

  try {
    const { minLat, maxLat, minLng, maxLng } = getBoundingBox(
      latitude,
      longitude,
      maxDistance,
    );

    const params = [latitude, longitude, minLat, maxLat, minLng, maxLng];

    let searchCondition = "";
    if (search) {
      searchCondition = `AND seller_name ILIKE $7`;
      params.push(`%${search}%`);
      params.push(maxDistance);
    } else {
      params.push(maxDistance);
    }

    const sql = `
      WITH all_sellers AS (
        SELECT
          fp.farmer_id AS seller_id,
          ud.name AS seller_name,
          'farmer' AS seller_type,
          ud.pic_url AS seller_pic,
          ua.phone_number AS seller_phone,
          fsp.latitude AS shop_latitude,
          fsp.longitude AS shop_longitude,
          COUNT(DISTINCT fp.product_id) as product_count,
          (
            6371 * acos(
              LEAST(1.0, GREATEST(-1.0,
                cos(radians($1)) * cos(radians(fsp.latitude)) *
                cos(radians(fsp.longitude) - radians($2)) +
                sin(radians($1)) * sin(radians(fsp.latitude))
              ))
            )
          ) AS distance_km
        FROM farmer_products fp
        INNER JOIN farmer_shop_place fsp ON fp.farmer_id = fsp.farmer_id
          AND fsp.latitude BETWEEN $3 AND $4
          AND fsp.longitude BETWEEN $5 AND $6
        LEFT JOIN user_details ud ON fp.farmer_id = ud.user_id
        LEFT JOIN users_auth ua ON fp.farmer_id = ua.user_id
        WHERE fp.is_available = true
        GROUP BY fp.farmer_id, ud.name, ud.pic_url, ua.phone_number, fsp.latitude, fsp.longitude

        UNION ALL

        SELECT
          rp.retailer_id AS seller_id,
          r.shop_name AS seller_name,
          'retailer' AS seller_type,
          i.image_url AS seller_pic,
          ua.phone_number AS seller_phone,
          r.latitude AS shop_latitude,
          r.longitude AS shop_longitude,
          COUNT(DISTINCT rp.product_id) as product_count,
          (
            6371 * acos(
              LEAST(1.0, GREATEST(-1.0,
                cos(radians($1)) * cos(radians(r.latitude)) *
                cos(radians(r.longitude) - radians($2)) +
                sin(radians($1)) * sin(radians(r.latitude))
              ))
            )
          ) AS distance_km
        FROM retailer_products rp
        INNER JOIN retailers r ON rp.retailer_id = r.retailer_id
          AND r.latitude BETWEEN $3 AND $4
          AND r.longitude BETWEEN $5 AND $6
        LEFT JOIN users_auth ua ON r.user_id = ua.user_id
        LEFT JOIN images i ON r.image_id = i.image_id
        WHERE rp.is_active = true
        GROUP BY rp.retailer_id, r.shop_name, i.image_url, ua.phone_number, r.latitude, r.longitude
      )
      SELECT *
      FROM all_sellers
      WHERE distance_km <= $${params.length}
      ${searchCondition}
      ORDER BY distance_km ASC
    `;

    const result = await pool.query(sql, params);

    logger.info("searchSellers - Success", {
      lat,
      lng,
      search,
      count: result.rowCount,
    });

    return res.json({
      success: true,
      sellers: result.rows,
      total: result.rowCount,
    });
  } catch (error) {
    logger.error("searchSellers - Error:", error);
    return res.status(500).json({
      success: false,
      message: "Error searching sellers",
      error: error.message,
    });
  }
};