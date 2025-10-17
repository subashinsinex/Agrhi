const pool = require("../db/database");
const bcrypt = require("bcrypt");

async function generateUniqueUserId(client) {
  let user_id, exists;
  do {
    user_id = Math.floor(100000 + Math.random() * 900000);
    const check = await client.query(
      "SELECT 1 FROM users_auth WHERE user_id = $1",
      [user_id]
    );
    exists = check.rowCount > 0;
  } while (exists);
  return user_id;
}

async function getUsers() {
  const sql = `
    SELECT ua.user_id, ua.phone_number, ua.email, uc.category AS user_category,
           ud.name, ud.dob, ud.address, ud.pincode, ud.category_id
    FROM users_auth ua
    JOIN user_details ud ON ua.user_id = ud.user_id
    JOIN user_category uc ON ud.category_id = uc.category_id
    ORDER BY ua.user_id;
  `;
  const result = await pool.query(sql);
  return result.rows;
}

async function postUser(newUser) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const user_id = await generateUniqueUserId(client);

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

async function putUser(user_id, updatedUser) {
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

async function deleteUser(user_id) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("DELETE FROM user_details WHERE user_id = $1", [
      user_id,
    ]);
    await client.query("DELETE FROM users_auth WHERE user_id = $1", [user_id]);
    await client.query("COMMIT");
    return { message: "User deleted successfully" };
  } catch (error) {
    console.error("Error deleting user:", error);
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

module.exports = { getUsers, postUser, putUser, deleteUser };
