const { basePool } = require("../db/database");
const bcrypt = require("bcrypt");
const { v4: uuidv4 } = require("uuid");
const logger = require("../utils/logger");
const pool = basePool;

// Generate unique UUID for any table
async function generateUniqueId(client, tableName, idColumn) {
  logger.info("Generating unique ID", { tableName, idColumn });
  let id, exists;
  do {
    id = uuidv4();
    const check = await client.query(
      `SELECT 1 FROM ${tableName} WHERE ${idColumn} = $1`,
      [id],
    );
    exists = check.rowCount > 0;
  } while (exists);
  logger.info("Generated unique ID", { id, tableName });
  return id;
}

// Get full user profile by user_id
async function getUserById(userId) {
  logger.info("Fetching user by ID", { userId });
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
      ud.updated_at,
      ud.pic_url
    FROM users_auth ua
    JOIN user_details ud ON ua.user_id = ud.user_id
    JOIN user_category uc ON ud.category_id = uc.category_id
    WHERE ua.user_id = $1;
  `;

  try {
    const result = await pool.query(sql, [userId]);
    logger.info("User fetched", { userId, found: result.rows.length > 0 });
    return result.rows[0];
  } catch (error) {
    logger.error("Error fetching user by ID", { userId, error });
    throw error;
  }
}

// Get profile picture URL for a user
async function getProfilePictureUrl(userId) {
  logger.info("Fetching profile picture URL", { userId });

  try {
    const result = await pool.query(
      `SELECT pic_url FROM user_details WHERE user_id = $1`,
      [userId],
    );

    if (result.rows.length === 0) {
      logger.warn("No user found for pic_url fetch", { userId });
      return null;
    }

    logger.info("Profile picture URL fetched", {
      userId,
      pic_url: result.rows[0].pic_url,
    });
    return result.rows[0].pic_url;
  } catch (error) {
    logger.error("Error getting profile picture URL", { userId, error });
    throw error;
  }
}

// Create new user (auth + details)
async function createUser(newUser) {
  const client = await pool.connect();
  logger.info("Creating new user", {
    phone_number: newUser.phone_number,
    email: newUser.email,
  });

  try {
    // Check for duplicate phone/email
    const existingCheck = await client.query(
      `SELECT phone_number, email FROM users_auth WHERE phone_number = $1 OR email = $2`,
      [newUser.phone_number, newUser.email],
    );

    if (existingCheck.rows.length > 0) {
      const existing = existingCheck.rows[0];
      if (
        existing.phone_number === newUser.phone_number &&
        existing.email === newUser.email
      ) {
        logger.error("Duplicate phone and email", {
          phone_number: newUser.phone_number,
          email: newUser.email,
        });
        throw new Error("Phone number and email already exist");
      } else if (existing.phone_number === newUser.phone_number) {
        logger.error("Duplicate phone number", {
          phone_number: newUser.phone_number,
        });
        throw new Error("Phone number already exist");
      } else if (existing.email === newUser.email) {
        logger.error("Duplicate email", { email: newUser.email });
        throw new Error("Email already exist");
      }
    }

    await client.query("BEGIN");

    const user_id = await generateUniqueId(client, "users_auth", "user_id");
    const hashedPassword = await bcrypt.hash(newUser.password, 10);
    logger.info("Password hashed for new user", { user_id });

    // Insert into users_auth
    await client.query(
      `INSERT INTO users_auth (user_id, password, phone_number, email)
       VALUES ($1, $2, $3, $4)`,
      [user_id, hashedPassword, newUser.phone_number, newUser.email],
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
      ],
    );

    await client.query("COMMIT");
    logger.info("User created successfully", { user_id });
    return { message: "User created successfully", user_id };
  } catch (error) {
    logger.error("Error creating user", error);
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

// Update user auth and details (only provided fields)
async function updateUser(user_id, updatedUser) {
  const client = await pool.connect();
  logger.info("Updating user", { user_id });

  try {
    await client.query("BEGIN");

    // Check user exists and get email_verified status
    const authRes = await client.query(
      `SELECT email_verified FROM users_auth WHERE user_id = $1`,
      [user_id],
    );

    if (authRes.rowCount === 0) {
      logger.error("User not found for update", { user_id });
      throw new Error("User not found");
    }

    const { email_verified } = authRes.rows[0];

    // Update email only if not yet verified
    if (!email_verified && updatedUser.email) {
      await client.query(
        "UPDATE users_auth SET email = $1 WHERE user_id = $2",
        [updatedUser.email, user_id],
      );
      logger.info("Email updated (not yet verified)", {
        user_id,
        email: updatedUser.email,
      });
    }

    // Build dynamic update for user_details
    const detailSet = [];
    const detailValues = [];
    let idx = 1;

    const fields = ["name", "dob", "address", "pincode", "category_id"];
    for (const field of fields) {
      if (Object.prototype.hasOwnProperty.call(updatedUser, field)) {
        detailSet.push(`${field} = $${idx++}`);
        detailValues.push(updatedUser[field]);
      }
    }

    if (detailSet.length > 0) {
      detailValues.push(user_id);
      await client.query(
        `UPDATE user_details
         SET ${detailSet.join(", ")}, updated_at = NOW()
         WHERE user_id = $${idx}`,
        detailValues,
      );
      logger.info("User details updated", { user_id, fields: detailSet });
    }

    await client.query("COMMIT");
    logger.info("User updated successfully", { user_id });
    return { message: "User updated successfully" };
  } catch (error) {
    logger.error("Error updating user", { user_id, error });
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

// Update profile picture URL
async function updateProfilePictureUrl(userId, picUrl) {
  const client = await pool.connect();
  logger.info("Updating profile picture URL", { userId, picUrl });

  try {
    await client.query("BEGIN");

    const result = await client.query(
      "UPDATE user_details SET pic_url = $1, updated_at = NOW() WHERE user_id = $2 RETURNING user_id, pic_url",
      [picUrl, userId],
    );

    if (result.rowCount === 0) {
      logger.error("User not found for profile picture update", { userId });
      throw new Error("User not found");
    }

    await client.query("COMMIT");
    logger.info("Profile picture updated successfully", { userId, picUrl });
    return result.rows[0];
  } catch (error) {
    logger.error("Error updating profile picture", { userId, error });
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

module.exports = {
  getUserById,
  getProfilePictureUrl,
  createUser,
  updateUser,
  updateProfilePictureUrl,
};
