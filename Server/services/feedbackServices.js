const db = require("../db/database"); // adjust this path if needed

async function generateUniqueId(tableName, idField) {
  let newId, exists, sql;
  do {
    newId = Math.floor(10000 + Math.random() * 90000); // 5-digit random integer
    sql = `SELECT 1 FROM ${tableName} WHERE ${idField} = $1`;
    const check = await db.query(sql, [newId]);
    exists = check.rowCount > 0;
  } while (exists);
  return newId;
}

// Get all feedbacks, latest first
const getAllFeedbacks = async () => {
  const result = await db.query(
    `SELECT * FROM feedback ORDER BY created_at DESC`
  );
  return result.rows;
};

// Add new feedback (from user/mobile)
const addFeedback = async ({ user_id, message, isproblem }) => {
  const id = await generateUniqueId("feedback", "id");
  const result = await db.query(
    `INSERT INTO feedback (id, user_id, message, isproblem, created_at, status)
     VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP, 'not_viewed') RETURNING *`,
    [id, user_id, message, isproblem]
  );
  return result.rows[0];
};

// Get feedback by ID
const getFeedbackById = async (id) => {
  const result = await db.query(`SELECT * FROM feedback WHERE id = $1`, [id]);
  return result.rows[0];
};

// Admin responds to feedback (sets reply, updates status)
const replyToFeedback = async ({ id, reply }) => {
  const result = await db.query(
    `UPDATE feedback SET reply = $1, status = 'responsed' WHERE id = $2 RETURNING *`,
    [reply, id]
  );
  return result.rows[0];
};

// Admin updates feedback status (solved, viewed, etc.)
const updateFeedbackStatus = async ({ id, status }) => {
  const allowed = ["responsed", "solved", "viewed", "not_viewed"];
  if (!allowed.includes(status)) throw new Error("Invalid status value");
  const result = await db.query(
    `UPDATE feedback SET status = $1 WHERE id = $2 RETURNING *`,
    [status, id]
  );
  return result.rows[0];
};

module.exports = {
  getAllFeedbacks,
  addFeedback,
  getFeedbackById,
  replyToFeedback,
  updateFeedbackStatus,
};
