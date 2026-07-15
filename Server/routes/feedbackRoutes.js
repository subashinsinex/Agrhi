const express = require("express");
const router = express.Router();
const feedbackServices = require("../services/feedbackServices");
const jwtChecker = require("../middleware/jwtChecker");
const adminChecker = require("../middleware/adminChecker");
const logger = require("../utils/logger");

// Submit new feedback
router.post("/addfeedback", jwtChecker, async (req, res) => {
  
  try {
    const { user_id, message, isproblem } = req.body;
    const feedback = await feedbackServices.addFeedback({
      user_id,
      message,
      isproblem,
    });
    res.status(201).json(feedback);
  } catch (err) {
    logger.error("POST /addfeedback - Error:", err);
    res.status(500).json({ error: err.message || "Failed to add feedback" });
  }
});

// Get all feedbacks (admin only)
router.get("/getfeedback", jwtChecker, adminChecker, async (req, res) => {
  
  try {
    const feedbacks = await feedbackServices.getAllFeedbacks();
    res.json(feedbacks);
  } catch (err) {
    logger.error("GET /getfeedback - Error:", err);
    res.status(500).json({ error: "Failed to fetch feedbacks" });
  }
});

// Get single feedback by ID
router.get("/getfeedback/:id", jwtChecker, async (req, res) => {
  
  try {
    const feedback = await feedbackServices.getFeedbackById(req.params.id);
    if (!feedback) {
      return res.status(404).json({ error: "Feedback not found" });
    }
    res.json(feedback);
  } catch (err) {
    logger.error("GET /getfeedback/:id - Error:", { id: req.params.id, err });
    res.status(500).json({ error: "Failed to fetch feedback" });
  }
});

// Reply to feedback (admin only)
router.put("/reply/:id", jwtChecker, adminChecker, async (req, res) => {
  
  try {
    const updatedFeedback = await feedbackServices.replyToFeedback({
      id: req.params.id,
      reply: req.body.reply,
    });
    res.json(updatedFeedback);
  } catch (err) {
    logger.error("PUT /reply/:id - Error:", { id: req.params.id, err });
    res.status(500).json({ error: "Failed to reply to feedback" });
  }
});

// Update feedback status (admin only)
router.put("/status/:id", jwtChecker, adminChecker, async (req, res) => {
  
  try {
    const updatedFeedback = await feedbackServices.updateFeedbackStatus({
      id: req.params.id,
      status: req.body.status,
    });
    res.json(updatedFeedback);
  } catch (err) {
    logger.error("PUT /status/:id - Error:", { id: req.params.id, err });
    res.status(400).json({ error: err.message });
  }
});

// Delete feedback (admin only)
router.delete("/delete/:id", jwtChecker, adminChecker, async (req, res) => {
  
  try {
    const success = await feedbackServices.deleteFeedback(req.params.id);
    if (!success) {
      return res.status(404).json({ error: "Feedback not found" });
    }
    res.json({ message: "Feedback deleted successfully" });
  } catch (err) {
    logger.error("DELETE /delete/:id - Error:", { id: req.params.id, err });
    res.status(500).json({ error: "Failed to delete feedback" });
  }
});

module.exports = router;
