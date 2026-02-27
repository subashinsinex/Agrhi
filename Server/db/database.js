// Server/db/database.js
const { Pool, types } = require("pg");
const { AsyncLocalStorage } = require("async_hooks");

// Parse PostgreSQL numeric/date types as strings to avoid JS precision issues
types.setTypeParser(1082, (val) => val);

const asyncLocalStorage = new AsyncLocalStorage();

// This pool uses the 'agrhi_app_user' (not superuser)
const basePool = new Pool({
  connectionString: `postgresql://${process.env.DB_USER}:${process.env.DB_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`,
  max: 20,
  idleTimeoutMillis: 30000,
});

const CATEGORY_TO_ROLE = {
  admin: "agrhi_admin",
  Farmer: "agrhi_farmer",
  Consumer: "agrhi_consumer",
  Retailer: "agrhi_retailer",
  Expert: "agrhi_expert",
};

class RLSEnabledPool {
  constructor(pool) {
    this.pool = pool;
    this.roleCache = new Map();
  }

  async getUserRole(userId) {
    if (this.roleCache.has(userId)) return this.roleCache.get(userId);

    try {
      // Use the basePool directly to bypass RLS for role lookup
      const result = await this.pool.query(
        `SELECT uc.category 
         FROM user_details ud
         JOIN user_category uc ON ud.category_id = uc.category_id
         WHERE ud.user_id = $1`,
        [userId],
      );

      if (result.rows.length === 0) return "agrhi_farmer";

      const category = result.rows[0].category;
      const role = CATEGORY_TO_ROLE[category] || "agrhi_farmer";

      // Cache for 5 mins to prevent hitting the DB on every single request
      this.roleCache.set(userId, role);
      setTimeout(() => this.roleCache.delete(userId), 5 * 60 * 1000);

      return role;
    } catch (error) {
      console.error(`❌ Role Lookup Error: ${error.message}`);
      return "agrhi_farmer";
    }
  }

  /**
   * Main query method used by the rest of the app
   */
  async query(text, params) {
    const store = asyncLocalStorage.getStore();
    const userId = store?.userId;

    // If no valid user context (public routes), run standard query
    if (!userId || typeof userId !== "string" || userId.trim() === "") {
      return this.pool.query(text, params);
    }

    const client = await this.pool.connect();
    try {
      const role = await this.getUserRole(userId);

      // Start a transaction so SET LOCAL ROLE stays isolated to this request
      await client.query("BEGIN");
      await client.query(`SET LOCAL ROLE ${role}`);

      // The 'true' parameter in set_config prevents "unrecognized parameter" errors
      await client.query("SELECT set_config('app.current_user_id', $1, true)", [
        userId,
      ]);

      const res = await client.query(text, params);

      await client.query("COMMIT");
      return res;
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      // Release client back to pool (Postgres automatically resets LOCAL vars on release)
      client.release();
    }
  }
}

const enhancedPool = new RLSEnabledPool(basePool);

module.exports = {
  query: (text, params) => enhancedPool.query(text, params),
  basePool, // Used for login where RLS isn't active yet
  asyncLocalStorage,
  clearRoleCache: (id) => enhancedPool.roleCache.delete(id),
};
