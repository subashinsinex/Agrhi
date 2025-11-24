const pool = require("../db/database");
const bcrypt = require("bcrypt");
const { v4: uuidv4 } = require("uuid");

async function generateUniqueId(client, tableName, idColumn) {
  let id, exists;
  do {
    id = uuidv4();
    const check = await client.query(
      `SELECT 1 FROM ${tableName} WHERE ${idColumn} = $1`,
      [id]
    );
    exists = check.rowCount > 0;
  } while (exists);
  return id;
}

async function getUserById(userId) {
  const sql = `
    SELECT 
      ua.user_id, 
      ua.phone_number, 
      ua.email, 
      uc.category AS user_category,
      ud.name, 
      ud.dob, 
      ud.address, 
      ud.pincode, 
      ud.category_id
    FROM users_auth ua
    JOIN user_details ud ON ua.user_id = ud.user_id
    JOIN user_category uc ON ud.category_id = uc.category_id
    WHERE ua.user_id = $1
    ORDER BY ua.user_id;
  `;
  const result = await pool.query(sql, [userId]);
  return result.rows[0];
}

async function createUser(newUser) {
  const client = await pool.connect();
  try {
    // Check if phone number or email already exists
    const existingCheck = await client.query(
      `SELECT phone_number, email FROM users_auth WHERE phone_number = $1 OR email = $2`,
      [newUser.phone_number, newUser.email]
    );

    if (existingCheck.rows.length > 0) {
      const existing = existingCheck.rows[0];
      if (
        existing.phone_number === newUser.phone_number &&
        existing.email === newUser.email
      ) {
        throw new Error("Phone number and email already exist");
      } else if (existing.phone_number === newUser.phone_number) {
        throw new Error("Phone number already exist");
      } else if (existing.email === newUser.email) {
        throw new Error("Email already exist");
      }
    }

    await client.query("BEGIN");
    const user_id = await generateUniqueId(client, "users_auth", "user_id");

    // Hash password
    const hashedPassword = await bcrypt.hash(newUser.password, 10);
    console.log("Hashed Password:", hashedPassword);

    // Insert into users_auth - no category_id here
    await client.query(
      `INSERT INTO users_auth (user_id, password, phone_number, email)
       VALUES ($1, $2, $3, $4)`,
      [user_id, hashedPassword, newUser.phone_number, newUser.email]
    );

    // Insert into userdetails including category_id
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
      ]
    );

    await client.query("COMMIT");
    return { message: "User created successfully" };
  } catch (error) {
    console.error("Error creating user:", error);
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function updateUser(user_id, updatedUser) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    if (updatedUser.password) {
      const hashedPassword = await bcrypt.hash(updatedUser.password, 10);
      await client.query(
        "UPDATE users_auth SET password = $1 WHERE user_id = $2",
        [hashedPassword, user_id]
      );
    }

    await client.query(
      `UPDATE users_auth
       SET phone_number = $1, email = $2
       WHERE user_id = $3`,
      [updatedUser.phone_number, updatedUser.email, user_id]
    );

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
      ]
    );

    await client.query("COMMIT");
    return { message: "User updated successfully" };
  } catch (error) {
    console.error("Error updating user:", error);
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

module.exports = { getUserById, createUser, updateUser };
