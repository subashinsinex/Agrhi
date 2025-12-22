const { Pool, types } = require("pg");

types.setTypeParser(1082, (val) => val);
const pool = new Pool({
  connectionString: `postgresql://${process.env.DB_USER}:${process.env.DB_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`,
});

module.exports = pool;
