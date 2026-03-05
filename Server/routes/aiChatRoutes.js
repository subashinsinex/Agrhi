const express = require("express");
const router = express.Router();
const aiChatServices = require("../services/aiChatServices");
const jwtChecker = require("../middleware/jwtChecker");

// Create new chat session
router.post("/createSession", jwtChecker, async (req, res) => {
  try {
    const { title } = req.body;
    const session = await aiChatServices.createSession(req.user_id, title);
    res.status(201).json(session);
  } catch (error) {
    console.error("Route createSession error:", error);
    res.status(500).json({ message: "Error creating session" });
  }
});

// Get all sessions for logged-in user
router.get("/getSessions", jwtChecker, async (req, res) => {
  try {
    const sessions = await aiChatServices.getUserSessions(req.user_id);
    res.json(sessions);
  } catch (error) {
    console.error("Route getSessions error:", error);
    res.status(500).json({ message: "Error fetching sessions" });
  }
});

// Soft delete a session
router.delete("/deleteSession/:sessionId", jwtChecker, async (req, res) => {
  try {
    const sessionId = req.params.sessionId;
    const result = await aiChatServices.deleteSession(sessionId, req.user_id);
    res.json(result);
  } catch (error) {
    console.error("Route deleteSession error:", error);
    res.status(500).json({ message: "Error deleting session" });
  }
});

// Get all messages for a session (chat history)
router.get("/getMessages/:sessionId", jwtChecker, async (req, res) => {
  try {
    const sessionId = req.params.sessionId;
    const messages = await aiChatServices.getSessionMessages(
      sessionId,
      req.user_id,
    );
    res.json(messages);
  } catch (error) {
    console.error("Route getMessages error:", error);
    res.status(500).json({ message: "Error fetching messages" });
  }
});

// Send a message and get AI reply
router.post("/chat/:sessionId", jwtChecker, async (req, res) => {
  try {
    const sessionId = req.params.sessionId;
    const { message } = req.body;
    if (!message || message.trim() === "") {
      return res.status(400).json({ message: "Message cannot be empty" });
    }
    const result = await aiChatServices.chat(
      req.user_id,
      sessionId,
      message.trim(),
    );
    res.json(result);
  } catch (error) {
    console.error("Route chat error:", error);
    if (error.message === "Session not found or unauthorized") {
      return res.status(403).json({ message: error.message });
    }
    res.status(500).json({ message: "Error processing chat" });
  }
});

module.exports = router;
