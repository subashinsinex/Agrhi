const { Pool } = require("pg");

// Create a new pool instance to manage PostgreSQL connections
const pool = new Pool({
  connectionString: `postgresql://${process.env.DB_USER}:${process.env.DB_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_DATABASE}`,
});

module.exports = pool;
