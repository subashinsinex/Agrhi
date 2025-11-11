// const { Pool } = require("pg");

// const pool = new Pool({
//   connectionString: `postgresql://${process.env.DB_USER}:${process.env.DB_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`,
//   max: 20,
//   idleTimeoutMillis: 30000,
//   connectionTimeoutMillis: 2000,
// });

// // Test connection
// pool.on("connect", () => {
//   console.log("✅ Connected to PostgreSQL database");
// });

// pool.on("error", (err) => {
//   console.error("❌ Unexpected database error:", err);
// });

// // Export as object with pool property
// module.exports = {
//   pool,
//   query: (text, params) => pool.query(text, params),
// };

const { Pool } = require("pg");

const pool = new Pool({
  connectionString: `postgresql://${process.env.DB_USER}:${process.env.DB_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`,
});

module.exports = pool;
