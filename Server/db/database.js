const { Pool, types } = require("pg");
const { AsyncLocalStorage } = require("async_hooks");

types.setTypeParser(1082, (val) => val);

const asyncLocalStorage = new AsyncLocalStorage();

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

const VALID_ROLES = new Set(Object.values(CATEGORY_TO_ROLE));

class RLSEnabledPool {
  constructor(pool) {
    this.pool = pool;
    this.roleCache = new Map();
  }

  async getUserRole(userId) {
    if (this.roleCache.has(userId)) {
      console.log(`🗂️  Role cache hit for userId: ${userId}`);
      return this.roleCache.get(userId);
    }

    try {
      console.log(`🔍 Looking up role for userId: ${userId}`);
      const result = await this.pool.query(
        `SELECT uc.category
         FROM user_details ud
         JOIN user_category uc ON ud.category_id = uc.category_id
         WHERE ud.user_id = $1`,
        [userId],
      );

      if (result.rows.length === 0) {
        throw new Error(`No user_details found for userId: ${userId}`);
      }

      const category = result.rows[0].category;
      console.log(`📂 Category from DB: "${category}"`);

      const role = CATEGORY_TO_ROLE[category];

      if (!role) {
        throw new Error(`Unknown category "${category}" for userId: ${userId}`);
      }

      console.log(`✅ Role resolved: ${role}`);

      this.roleCache.set(userId, role);
      setTimeout(() => this.roleCache.delete(userId), 5 * 60 * 1000);

      return role;
    } catch (error) {
      console.error(`❌ Role Lookup Error: ${error.message}`);
      throw error;
    }
  }

  async query(text, params) {
    const store = asyncLocalStorage.getStore();
    const userId = store?.userId;

    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 ALS Store:", store);
    console.log("👤 userId:", userId);
    console.log("📝 Query:", text.trim().substring(0, 100));

    // No user context → public/unauthenticated route
    if (!userId || typeof userId !== "string" || userId.trim() === "") {
      console.log("⚠️  SKIPPING RLS — no userId in ALS store");
      return this.pool.query(text, params);
    }

    let role;
    try {
      role = await this.getUserRole(userId);
    } catch (err) {
      console.error("❌ getUserRole threw:", err.message);
      throw err;
    }

    // Whitelist check before interpolating role into SQL
    if (!VALID_ROLES.has(role)) {
      console.error(`❌ Invalid role: "${role}"`);
      throw new Error(`Invalid role "${role}" — possible injection attempt`);
    }

    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");

      await client.query(`SET LOCAL ROLE ${role}`);
      console.log(`🎭 SET LOCAL ROLE ${role} — OK`);

      await client.query("SELECT set_config('app.current_user_id', $1, true)", [
        userId,
      ]);
      console.log(`🔑 set_config app.current_user_id = ${userId} — OK`);

      // ── Critical: verify what Postgres actually sees ──
      const ctx = await client.query(`
        SELECT 
          current_user                                        AS current_user,
          session_user                                        AS session_user,
          current_setting('app.current_user_id', true)       AS uid
      `);
      console.log("🐘 Postgres context:", ctx.rows[0]);

      const res = await client.query(text, params);
      console.log(`✅ Query OK — rowCount: ${res.rowCount}`);

      await client.query("COMMIT");
      return res;
    } catch (err) {
      await client.query("ROLLBACK");
      console.error("💥 Query failed inside transaction:", err.message);
      throw err;
    } finally {
      client.release();
    }
  }
}

const enhancedPool = new RLSEnabledPool(basePool);

module.exports = {
  query: (text, params) => enhancedPool.query(text, params),
  basePool,
  asyncLocalStorage,
  clearRoleCache: (id) => enhancedPool.roleCache.delete(id),
};
