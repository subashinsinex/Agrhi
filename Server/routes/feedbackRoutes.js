const express = require("express");
const router = express.Router();
const feedbackServices = require("../services/feedbackServices");

// User submits feedback (no crop_id)
router.post("/addfeedback", async (req, res) => {
  try {
    const { user_id, message, isproblem } = req.body;
    const feedback = await feedbackServices.addFeedback({
      user_id,
      message,
      isproblem,
    });
    res.status(201).json(feedback);
  } catch (err) {
    res.status(500).json({ error: err.message || "Failed to add feedback" });
  }
});

// Admin fetches all feedbacks
router.get("/getfeedback", async (req, res) => {
  try {
    const feedbacks = await feedbackServices.getAllFeedbacks();
    res.json(feedbacks);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch feedbacks" });
  }
});

// Get single feedback by ID
router.get("/getfeedback/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const feedback = await feedbackServices.getFeedbackById(id);
    if (feedback) res.json(feedback);
    else res.status(404).json({ error: "Feedback not found" });
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch feedback" });
  }
});

// Admin responds to feedback (sets reply, sets status to responsed)
router.put("/reply/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { reply } = req.body;
    const updatedFeedback = await feedbackServices.replyToFeedback({
      id,
      reply,
    });
    res.json(updatedFeedback);
  } catch (err) {
    res.status(500).json({ error: "Failed to reply to feedback" });
  }
});

// Admin updates feedback status
router.put("/status/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const updatedFeedback = await feedbackServices.updateFeedbackStatus({
      id,
      status,
    });
    res.json(updatedFeedback);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
