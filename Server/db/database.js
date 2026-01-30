// Server/db/database.js
const { Pool, types } = require("pg");

types.setTypeParser(1082, (val) => val);

// Create the base connection pool
const basePool = new Pool({
  connectionString: `postgresql://${process.env.DB_USER}:${process.env.DB_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`,
});

// ✅ AsyncLocalStorage to track user context across async calls
const { AsyncLocalStorage } = require("async_hooks");
const asyncLocalStorage = new AsyncLocalStorage();

/**
 * Map category name to PostgreSQL role
 */
const CATEGORY_TO_ROLE = {
  admin: "agrhi_admin",
  Farmer: "agrhi_farmer",
  Consumer: "agrhi_consumer",
  Retailer: "agrhi_retailer",
  Expert: "agrhi_expert",
};

/**
 * Enhanced Pool wrapper that automatically sets RLS context
 */
class RLSEnabledPool {
  constructor(pool) {
    this.pool = pool;
    // Cache user roles to avoid repeated DB queries
    this.roleCache = new Map();
  }

  /**
   * Get user's database role from category
   */
  async getUserRole(userId) {
    // Check cache first
    if (this.roleCache.has(userId)) {
      return this.roleCache.get(userId);
    }

    try {
      // Query user's category using base pool (no RLS context needed)
      const result = await this.pool.query(
        `
        SELECT uc.category 
        FROM user_details ud
        JOIN user_category uc ON ud.category_id = uc.category_id
        WHERE ud.user_id = $1
      `,
        [userId],
      );

      if (result.rows.length === 0) {
        console.warn(`⚠️ User ${userId} not found, defaulting to farmer role`);
        return "agrhi_farmer";
      }

      const category = result.rows[0].category;
      const role = CATEGORY_TO_ROLE[category] || "agrhi_farmer";

      // Cache the role for 5 minutes
      this.roleCache.set(userId, role);
      setTimeout(() => this.roleCache.delete(userId), 5 * 60 * 1000);

      console.log(
        `🔑 User ${userId.substring(0, 8)}... mapped to role: ${role} (category: ${category})`,
      );

      return role;
    } catch (error) {
      console.error(`❌ Error fetching user role: ${error.message}`);
      return "agrhi_farmer"; // Default fallback
    }
  }

  /**
   * Validate and sanitize role name to prevent SQL injection
   */
  isValidRole(role) {
    const validRoles = [
      "agrhi_admin",
      "agrhi_farmer",
      "agrhi_consumer",
      "agrhi_retailer",
      "agrhi_expert",
    ];
    return validRoles.includes(role);
  }

  /**
   * Override query method to automatically set RLS context
   */
  async query(textOrConfig, values) {
    const store = asyncLocalStorage.getStore();
    const userId = store?.userId;

    // If no user context, execute query normally (for public routes)
    if (!userId) {
      return this.pool.query(textOrConfig, values);
    }

    // Get a client from pool
    const client = await this.pool.connect();

    try {
      // ✅ Get user's role from category
      const role = await this.getUserRole(userId);

      // Validate role to prevent SQL injection
      if (!this.isValidRole(role)) {
        throw new Error(`Invalid role: ${role}`);
      }

      // ✅ Set PostgreSQL role for this session
      await client.query(`SET LOCAL ROLE ${role}`);

      // ✅ Set RLS context using set_config (works without custom_variable_classes)
      await client.query("SELECT set_config('app.current_user_id', $1, true)", [
        userId,
      ]);

      console.log(
        `🔒 RLS Context: user=${userId.substring(0, 8)}..., role=${role}`,
      );

      // Execute the actual query with proper parameter handling
      let result;
      if (typeof textOrConfig === "string") {
        // String query with values array
        result = await client.query(textOrConfig, values);
      } else {
        // Query config object
        result = await client.query(textOrConfig);
      }

      return result;
    } catch (error) {
      console.error(`❌ Query error:`, error.message);
      throw error;
    } finally {
      // Reset role and release client
      try {
        await client.query("RESET ROLE");
      } catch (e) {
        // Ignore reset errors
      }
      client.release();
    }
  }

  /**
   * Override connect method for transaction support
   */
  async connect() {
    const client = await this.pool.connect();
    const store = asyncLocalStorage.getStore();
    const userId = store?.userId;

    // Wrap the original release method
    const originalRelease = client.release.bind(client);
    let released = false;

    client.release = async () => {
      if (!released) {
        released = true;
        try {
          await client.query("RESET ROLE");
        } catch (e) {
          // Ignore reset errors
        }
        return originalRelease();
      }
    };

    // If user context exists, set role and RLS context
    if (userId) {
      const role = await this.getUserRole(userId);

      // Validate role
      if (!this.isValidRole(role)) {
        throw new Error(`Invalid role: ${role}`);
      }

      await client.query(`SET LOCAL ROLE ${role}`);
      await client.query("SELECT set_config('app.current_user_id', $1, true)", [
        userId,
      ]);

      console.log(
        `🔒 Transaction context: user=${userId.substring(0, 8)}..., role=${role}`,
      );
    }

    return client;
  }

  /**
   * Clear role cache (useful after user category changes)
   */
  clearRoleCache(userId) {
    if (userId) {
      this.roleCache.delete(userId);
      console.log(`🗑️ Cleared role cache for user: ${userId}`);
    } else {
      this.roleCache.clear();
      console.log(`🗑️ Cleared entire role cache`);
    }
  }

  /**
   * Expose other pool methods
   */
  async end() {
    return this.pool.end();
  }

  on(event, listener) {
    return this.pool.on(event, listener);
  }

  removeListener(event, listener) {
    return this.pool.removeListener(event, listener);
  }
}

// Export the enhanced pool
const enhancedPool = new RLSEnabledPool(basePool);

module.exports = enhancedPool;
module.exports.asyncLocalStorage = asyncLocalStorage;
module.exports.basePool = basePool; // Export base pool for admin operations
module.exports.clearRoleCache = enhancedPool.clearRoleCache.bind(enhancedPool);
