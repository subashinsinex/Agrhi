const db = require("../db/database");
const { v4: uuidv4 } = require("uuid");
const logger = require("../utils/logger");

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

// Get all feedbacks with user names, latest first
const getAllFeedbacks = async () => {
  logger.info("Fetching all feedbacks");
  try {
    const result = await db.query(
      `SELECT f.*, u.name AS user_name
       FROM feedback f
       LEFT JOIN user_details u ON f.user_id = u.user_id
       ORDER BY f.created_at DESC`,
    );
    logger.info("Fetched all feedbacks", { count: result.rowCount });
    return result.rows;
  } catch (error) {
    logger.error("getAllFeedbacks - Error:", error);
    throw error;
  }
};

// Add new feedback from user
const addFeedback = async ({ user_id, message, isproblem }) => {
  logger.info("Adding feedback", { user_id, isproblem });
  try {
    const id = await generateUniqueId(db, "feedback", "id");
    const result = await db.query(
      `INSERT INTO feedback (id, user_id, message, isproblem, created_at, status)
       VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP, 'not viewed') RETURNING *`,
      [id, user_id, message, isproblem],
    );
    logger.info("Feedback added successfully", { id, user_id });
    return result.rows[0];
  } catch (error) {
    logger.error("addFeedback - Error:", error);
    throw new Error("Error adding feedback: " + error.message);
  }
};

// Get all feedbacks for a user by user_id
const getFeedbackById = async (user_id) => {
  logger.info("Fetching feedbacks by user_id", { user_id });
  try {
    const result = await db.query(`SELECT * FROM feedback WHERE user_id = $1`, [
      user_id,
    ]);
    logger.info("Fetched feedbacks by user_id", {
      user_id,
      count: result.rowCount,
    });
    return result.rows;
  } catch (error) {
    logger.error("getFeedbackById - Error:", { user_id, error });
    throw error;
  }
};

// Admin replies to feedback and marks as responded
const replyToFeedback = async ({ id, reply }) => {
  logger.info("Replying to feedback", { id });
  try {
    const result = await db.query(
      `UPDATE feedback SET reply = $1, status = 'responsed' WHERE id = $2 RETURNING *`,
      [reply, id],
    );
    logger.info("Feedback replied successfully", { id });
    return result.rows[0];
  } catch (error) {
    logger.error("replyToFeedback - Error:", { id, error });
    throw error;
  }
};

// Admin updates feedback status
const updateFeedbackStatus = async ({ id, status }) => {
  logger.info("Updating feedback status", { id, status });
  const allowed = ["responsed", "solved", "viewed", "not_viewed"];

  if (!allowed.includes(status)) {
    logger.error("updateFeedbackStatus - Invalid status", { id, status });
    throw new Error("Invalid status value");
  }

  try {
    const result = await db.query(
      `UPDATE feedback SET status = $1 WHERE id = $2 RETURNING *`,
      [status, id],
    );
    logger.info("Feedback status updated", { id, status });
    return result.rows[0];
  } catch (error) {
    logger.error("updateFeedbackStatus - Error:", { id, status, error });
    throw error;
  }
};

// Delete feedback by ID
const deleteFeedback = async (id) => {
  logger.info("Deleting feedback", { id });
  try {
    const result = await db.query(`DELETE FROM feedback WHERE id = $1`, [id]);
    const deleted = result.rowCount > 0;
    logger.info("Feedback delete result", { id, deleted });
    return deleted;
  } catch (error) {
    logger.error("deleteFeedback - Error:", { id, error });
    throw error;
  }
};

module.exports = {
  getAllFeedbacks,
  addFeedback,
  getFeedbackById,
  replyToFeedback,
  updateFeedbackStatus,
  deleteFeedback,
};
