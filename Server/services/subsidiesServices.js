const pool = require("../db/database");
const { v4: uuidv4 } = require("uuid");
const logger = require("../utils/logger");

// Generate unique UUID for table
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
  logger.info("Generated unique ID", id);
  return id;
}

// Get all subsidies with state names
async function getSubsidies() {
  logger.info("Fetching all subsidies");
  const sql = `
    SELECT s.id, s.title, s.description, s.link, st.state_name, s.state_id
    FROM subsidies s
    LEFT JOIN state st ON s.state_id = st.state_id
    ORDER BY s.id;
  `;

  try {
    const result = await pool.query(sql);
    logger.info("Fetched subsidies count:", result.rowCount);
    return result.rows;
  } catch (error) {
    logger.error("Error fetching subsidies:", error);
    throw error;
  }
}

// Create new subsidy with state lookup
async function postSubsidy(newSubsidy) {
  const client = await pool.connect();
  logger.info("Creating subsidy", { state_name: newSubsidy.state_name });

  try {
    await client.query("BEGIN");

    // Lookup state_id from state_name
    const stateRes = await client.query(
      "SELECT state_id FROM state WHERE state_name = $1",
      [newSubsidy.state_name],
    );

    logger.info("State lookup for subsidy", {
      state_name: newSubsidy.state_name,
      found: stateRes.rowCount > 0,
    });

    if (stateRes.rowCount === 0) {
      throw new Error("Invalid state name");
    }
    const state_id = stateRes.rows[0].state_id;

    // Generate unique subsidy ID
    const id = await generateUniqueId(client, "subsidies", "id");

    // Insert subsidy
    await client.query(
      `INSERT INTO subsidies (id, title, description, state_id, link, created_at)
       VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)`,
      [id, newSubsidy.title, newSubsidy.description, state_id, newSubsidy.link],
    );

    await client.query("COMMIT");
    logger.info("Subsidy created successfully", { id });
    return { message: "Subsidy created successfully", id: id };
  } catch (error) {
    logger.error("Error creating subsidy", error);
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

// Update existing subsidy
async function putSubsidy(subsidy_id, updatedSubsidy) {
  const client = await pool.connect();
  logger.info("Updating subsidy", { subsidy_id });

  try {
    await client.query("BEGIN");

    // Lookup state_id from state_name
    const stateRes = await client.query(
      "SELECT state_id FROM state WHERE state_name = $1",
      [updatedSubsidy.state_name],
    );

    logger.info("State lookup for subsidy update", {
      state_name: updatedSubsidy.state_name,
      found: stateRes.rowCount > 0,
    });

    if (stateRes.rowCount === 0) {
      throw new Error("Invalid state name");
    }
    const state_id = stateRes.rows[0].state_id;

    await client.query(
      `UPDATE subsidies
         SET title = $1, description = $2, state_id = $3, link = $4
         WHERE id = $5`,
      [
        updatedSubsidy.title,
        updatedSubsidy.description,
        state_id,
        updatedSubsidy.link,
        subsidy_id,
      ],
    );

    await client.query("COMMIT");
    logger.info("Subsidy updated successfully", { subsidy_id });
    return { message: "Subsidy updated successfully" };
  } catch (error) {
    logger.error("Error updating subsidy", { subsidy_id, error });
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

// Delete subsidy by ID
async function deleteSubsidy(subsidy_id) {
  const client = await pool.connect();
  logger.info("Deleting subsidy", { subsidy_id });

  try {
    await client.query("BEGIN");
    const result = await client.query("DELETE FROM subsidies WHERE id = $1", [
      subsidy_id,
    ]);

    await client.query("COMMIT");
    logger.info("Subsidy deleted successfully", {
      subsidy_id,
      deletedRows: result.rowCount,
    });
    return { message: "Subsidy deleted successfully" };
  } catch (error) {
    logger.error("Error deleting subsidy", { subsidy_id, error });
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

// Get all state names for dropdowns
async function getStateNames() {
  logger.info("Fetching state names");

  try {
    const result = await pool.query(
      "SELECT state_name FROM state ORDER BY state_name",
    );
    logger.info("Fetched state names count:", result.rowCount);
    return result.rows;
  } catch (error) {
    logger.error("Error fetching state names:", error);
    throw error;
  }
}

module.exports = {
  getSubsidies,
  postSubsidy,
  putSubsidy,
  deleteSubsidy,
  getStateNames,
};
