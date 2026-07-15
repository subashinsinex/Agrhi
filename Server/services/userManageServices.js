// Core dependencies
const { basePool } = require("../db/database");
const bcrypt = require("bcrypt");
const { v4: uuidv4 } = require("uuid");
const logger = require("../utils/logger"); // Import shared logger
const pool = basePool;

// Utility: generate unique user_id using UUID
async function generateUniqueUserId(client) {
  logger.info("Generating new user_id");
  let user_id;
  let exists;
  do {
    user_id = uuidv4();
    const check = await client.query(
      "SELECT 1 FROM users_auth WHERE user_id = $1",
      [user_id],
    );
    exists = check.rowCount > 0;
  } while (exists);
  logger.info("Generated unique user_id", user_id);
  return user_id;
}

// Fetch all users with auth, details and category
async function getUsers() {
  const sql = `
    SELECT ua.user_id, ua.phone_number, ua.email, uc.category AS user_category,
           ud.name, ud.dob, ud.address, ud.pincode, ud.category_id
    FROM users_auth ua
    JOIN user_details ud ON ua.user_id = ud.user_id
    JOIN user_category uc ON ud.category_id = uc.category_id
    ORDER BY ua.user_id;
  `;

  logger.info("Fetching users");
  try {
    const result = await pool.query(sql);
    logger.info("Fetched users count:", result.rowCount);
    return result.rows;
  } catch (error) {
    logger.error("Error fetching users:", error);
    throw error;
  }
}

// Create new user (auth + details)
async function postUser(newUser) {
  const client = await pool.connect();
  logger.info("Starting user creation", {
    phone_number: newUser.phone_number,
    email: newUser.email,
  });

  try {
    await client.query("BEGIN");

    const user_id = await generateUniqueUserId(client);

    const hashedPassword = await bcrypt.hash(newUser.password, 10);
    logger.info("Password hashed for user_id", user_id);

    await client.query(
      `INSERT INTO users_auth (user_id, password, phone_number, email)
       VALUES ($1, $2, $3, $4)`,
      [user_id, hashedPassword, newUser.phone_number, newUser.email],
    );
    logger.info("Inserted into users_auth", user_id);

    const categoryResult = await client.query(
      `SELECT category_id FROM user_category WHERE category_id = $1`,
      [newUser.category_id],
    );

    if (categoryResult.rowCount === 0) {
      logger.error("Invalid category_id for user creation", {
        user_id,
        category_id: newUser.category_id,
      });
      throw new Error("Invalid category_id: category does not exist");
    }

    await client.query(
      `INSERT INTO user_details (user_id, name, dob, address, pincode, category_id, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP)`,
      [
        user_id,
        newUser.name,
        newUser.dob,
        newUser.address,
        newUser.pincode,
        newUser.category_id,
      ],
    );
    logger.info("Inserted into user_details", user_id);

    await client.query("COMMIT");
    logger.info("User created successfully", user_id);
    return { message: "User created successfully" };
  } catch (error) {
    logger.error("Error creating user, rolling back", error);
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
    logger.info("Released DB client after user creation");
  }
}

// Update existing user (auth + details)
async function putUser(user_id, updatedUser) {
  const client = await pool.connect();
  logger.info("Starting user update", { user_id });

  try {
    await client.query("BEGIN");

    if (updatedUser.password) {
      const hashedPassword = await bcrypt.hash(updatedUser.password, 10);
      await client.query(
        "UPDATE users_auth SET password = $1 WHERE user_id = $2",
        [hashedPassword, user_id],
      );
      logger.info("Updated password for user", user_id);
    }

    await client.query(
      `UPDATE users_auth
       SET phone_number = $1, email = $2
       WHERE user_id = $3`,
      [updatedUser.phone_number, updatedUser.email, user_id],
    );
    logger.info("Updated users_auth for user", user_id);

    await client.query(
      `UPDATE user_details
       SET name = $1, dob = $2, address = $3, pincode = $4, category_id = $5
       WHERE user_id = $6`,
      [
        updatedUser.name,
        updatedUser.dob,
        updatedUser.address,
        updatedUser.pincode,
        updatedUser.category_id,
        user_id,
      ],
    );
    logger.info("Updated user_details for user", user_id);

    await client.query("COMMIT");
    logger.info("User updated successfully", user_id);
    return { message: "User updated successfully" };
  } catch (error) {
    logger.error("Error updating user, rolling back", { user_id, error });
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
    logger.info("Released DB client after user update", user_id);
  }
}

// Delete user (details then auth)
async function deleteUser(user_id) {
  const client = await pool.connect();
  logger.info("Starting user delete", { user_id });

  try {
    await client.query("BEGIN");

    await client.query("DELETE FROM user_details WHERE user_id = $1", [
      user_id,
    ]);
    logger.info("Deleted from user_details", user_id);

    await client.query("DELETE FROM users_auth WHERE user_id = $1", [user_id]);
    logger.info("Deleted from users_auth", user_id);

    await client.query("COMMIT");
    logger.info("User deleted successfully", user_id);
    return { message: "User deleted successfully" };
  } catch (error) {
    logger.error("Error deleting user, rolling back", { user_id, error });
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
    logger.info("Released DB client after user delete", user_id);
  }
}

// Fetch reference table versions for sync
async function getReferenceTableVersions() {
  const sql =
    "SELECT ref_table_name, updated_at FROM reference_table_versions ORDER BY ref_table_name;";

  logger.info("Fetching reference_table_versions");
  try {
    const result = await pool.query(sql);
    logger.info("Fetched reference_table_versions count:", result.rowCount);
    return result.rows;
  } catch (error) {
    logger.error("Error fetching reference_table_versions:", error);
    throw error;
  }
}

// Export user operations and reference version fetcher
module.exports = {
  getUsers,
  postUser,
  putUser,
  deleteUser,
  getReferenceTableVersions,
};
