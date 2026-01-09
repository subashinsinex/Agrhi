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
      ud.image_id,
    FROM users_auth ua
    JOIN user_details ud ON ua.user_id = ud.user_id
    JOIN user_category uc ON ud.category_id = uc.category_id
    WHERE ua.user_id = $1
    ORDER BY ua.user_id;
  `;
  const result = await pool.query(sql, [userId]);
  return result.rows[0];
}

async function getImageIdByUserId(userId) {
  const result = await pool.query(
    "SELECT image_id FROM user_details WHERE user_id = $1",
    [userId]
  );
  if (result.rowCount === 0) {
    throw new Error("User not found");
  }
  return result.rows[0].imageid;
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

    // Generate image_id upfront
    const image_id = await generateUniqueId(client, "images", "image_id");

    // Insert into images with null imageurl
    await client.query("INSERT INTO images (image_id) VALUES ($1)", [image_id]);

    // Insert into user_details
    await client.query(
      `INSERT INTO user_details (user_id, name, dob, address, pincode, category_id, image_id, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP)`,
      [
        user_id,
        newUser.name,
        newUser.dob,
        newUser.address,
        newUser.pincode,
        newUser.category_id,
        image_id,
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
    if (!email_verified && updatedUser.email) {
      await client.query(
        "UPDATE users_auth SET email = $1, updated_at = NOW() WHERE user_id = $2",
        [updatedUser.email, user_id]
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

async function updateProfileImageUrl(imageId, imageUrl) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await client.query(
      "UPDATE images SET image_url = $1 WHERE image_id = $2 RETURNING image_id, image_url",
      [imageUrl, imageId]
    );
    if (result.rowCount === 0) {
      throw new Error("Image not found");
    }
    await client.query("COMMIT");
    return result.rows[0];
  } catch (error) {
    console.error("Error updating image url:", error);
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

module.exports = {
  getUserById,
  createUser,
  updateUser,
  getImageIdByUserId,
  updateProfileImageUrl,
};
