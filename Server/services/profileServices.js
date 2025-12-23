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
      ua.email_verified,
      uc.category AS user_category,
      ud.name, 
      ud.dob, 
      ud.address, 
      ud.pincode, 
      ud.category_id,
      ud.updated_at
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

    // Insert into users_auth
    await client.query(
      `INSERT INTO users_auth (user_id, password, phone_number, email)
       VALUES ($1, $2, $3, $4)`,
      [user_id, hashedPassword, newUser.phone_number, newUser.email]
    );

    // Insert into user_details
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

    // 1) Get auth info (for email_verified)
    const authRes = await client.query(
      `SELECT email_verified FROM users_auth WHERE user_id = $1`,
      [user_id]
    );

    if (authRes.rowCount === 0) {
      throw new Error("User not found");
    }

    const { email_verified } = authRes.rows[0];

    // 2) Dynamically update users_auth (ONLY email, never phone/password)
    const authSet = [];
    const authValues = [];
    let idx = 1;

    if (!email_verified && updatedUser.email) {
      authSet.push(`email = $${idx++}`);
      authValues.push(updatedUser.email);
    }

    if (authSet.length > 0) {
      authValues.push(user_id); // last parameter is user_id
      await client.query(
        `UPDATE users_auth SET ${authSet.join(", ")} WHERE user_id = $${idx}`,
        authValues
      );
    }

    // 3) Dynamically update user_details (only provided fields)
    const detailSet = [];
    const detailValues = [];
    idx = 1;

    if (Object.prototype.hasOwnProperty.call(updatedUser, "name")) {
      detailSet.push(`name = $${idx++}`);
      detailValues.push(updatedUser.name);
    }
    if (Object.prototype.hasOwnProperty.call(updatedUser, "dob")) {
      detailSet.push(`dob = $${idx++}`);
      detailValues.push(updatedUser.dob);
    }
    if (Object.prototype.hasOwnProperty.call(updatedUser, "address")) {
      detailSet.push(`address = $${idx++}`);
      detailValues.push(updatedUser.address);
    }
    if (Object.prototype.hasOwnProperty.call(updatedUser, "pincode")) {
      detailSet.push(`pincode = $${idx++}`);
      detailValues.push(updatedUser.pincode);
    }
    if (Object.prototype.hasOwnProperty.call(updatedUser, "category_id")) {
      detailSet.push(`category_id = $${idx++}`);
      detailValues.push(updatedUser.category_id);
    }

    if (detailSet.length > 0) {
      detailValues.push(user_id);
      await client.query(
        `UPDATE user_details
         SET ${detailSet.join(", ")}, updated_at = NOW()
         WHERE user_id = $${idx}`,
        detailValues
      );
    }

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