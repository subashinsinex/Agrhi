const db = require("../db/database"); // adjust this path if needed
const { v4: uuidv4 } = require("uuid");

async function generateUniqueId(client, tableName, idColumn) {
  let id, exists;
  do {
    id = uuidv4();
    const check = await client.query(
      `SELECT 1 FROM ${tableName} WHERE ${idColumn} = $1`,
      [id],
    );
    exists = check.rowCount > 0;
  } while (exists);
  return id;
}

// Get all feedbacks, latest first
const getAllFeedbacks = async () => {
  const result = await db.query(
    `SELECT f.*, u.name AS user_name
     FROM feedback f
     LEFT JOIN user_details u ON f.user_id = u.user_id
     ORDER BY f.created_at DESC`,
  );
  return result.rows;
};

// Add new feedback (from user/mobile)
const addFeedback = async ({ user_id, message, isproblem }) => {
  try {
    const id = await generateUniqueId(db, "feedback", "id");
    const result = await db.query(
      `INSERT INTO feedback (id, user_id, message, isproblem, created_at, status)
     VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP, 'not viewed') RETURNING *`,
      [id, user_id, message, isproblem],
    );
    return result.rows[0];
  } catch (error) {
    throw new Error("Error adding feedback: " + error.message);
  }
};

// Get feedback by USER_ID
const getFeedbackById = async (user_id) => {
  const result = await db.query(`SELECT * FROM feedback WHERE user_id = $1`, [
    user_id,
  ]);
  return result.rows;
};

// Admin responds to feedback (sets reply, updates status)
const replyToFeedback = async ({ id, reply }) => {
  const result = await db.query(
    `UPDATE feedback SET reply = $1, status = 'responsed' WHERE id = $2 RETURNING *`,
    [reply, id],
  );
  return result.rows[0];
};

// Admin updates feedback status (solved, viewed, etc.)
const updateFeedbackStatus = async ({ id, status }) => {
  const allowed = ["responsed", "solved", "viewed", "not_viewed"];
  if (!allowed.includes(status)) throw new Error("Invalid status value");
  const result = await db.query(
    `UPDATE feedback SET status = $1 WHERE id = $2 RETURNING *`,
    [status, id],
  );
  return result.rows[0];
};

const deleteFeedback = async (id) => {
  const result = await db.query(`DELETE FROM feedback WHERE id = $1`, [id]);
  return result.rowCount > 0;
};

module.exports = {
  getAllFeedbacks,
  addFeedback,
  getFeedbackById,
  replyToFeedback,
  updateFeedbackStatus,
  deleteFeedback,
};
