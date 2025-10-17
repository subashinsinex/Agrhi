const pool = require("../db/database");

// Get all subsidies
async function getSubsidies() {
  const sql = `
    SELECT s.id, s.title, s.description, s.link, st.state_name, s.state_id
FROM subsidies s
LEFT JOIN state st ON s.state_id = st.state_id
ORDER BY s.id;
`;
  const result = await pool.query(sql);
  return result.rows;
}

// Create new subsidy
async function postSubsidy(newSubsidy) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(
      `INSERT INTO subsidies (id, title, description, state_id, link, created_at)
       VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)`,
      [
        newSubsidy.id,
        newSubsidy.title,
        newSubsidy.description,
        newSubsidy.state_id,
        newSubsidy.link,
      ]
    );
    await client.query("COMMIT");
    return { message: "Subsidy created successfully" };
  } catch (error) {
    console.error("Error creating subsidy:", error);
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

// Update subsidy
async function putSubsidy(subsidy_id, updatedSubsidy) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(
      `UPDATE subsidies
       SET title = $1, description = $2, state_id = $3, link = $4
       WHERE id = $5`,
      [
        updatedSubsidy.title,
        updatedSubsidy.description,
        updatedSubsidy.state_id,
        updatedSubsidy.link,
        subsidy_id,
      ]
    );
    await client.query("COMMIT");
    return { message: "Subsidy updated successfully" };
  } catch (error) {
    console.error("Error updating subsidy:", error);
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

// Delete subsidy
async function deleteSubsidy(subsidy_id) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("DELETE FROM subsidies WHERE id = $1", [subsidy_id]);
    await client.query("COMMIT");
    return { message: "Subsidy deleted successfully" };
  } catch (error) {
    console.error("Error deleting subsidy:", error);
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

module.exports = { getSubsidies, postSubsidy, putSubsidy, deleteSubsidy };
