// services/aiChatServices.js
const Groq = require("groq-sdk");
const { v4: uuidv4 } = require("uuid");
const { query } = require("../db/database");

const groq = new Groq({ apiKey: process.env.GEMINI_API_KEY });
const MODEL = "llama-3.1-8b-instant";

const SYSTEM_PROMPT = `You are AGRHI, an AI agricultural advisor built into the AGRHI app for Indian farmers.

RESPONSE RULES — follow strictly:
- Always reply in short, crisp bullet points (use • symbol)
- Maximum 5 to 6 bullet points per response
- Each bullet must be one concise sentence — no long explanations
- Never cut off mid-answer — always complete your response fully
- give greetings, filler phrases like "Great question!" or "Sure!"
- No paragraphs, no headers, no markdown formatting
- If asked about crop diseases, pests, fertilizers, soil, irrigation, or weather — answer directly
- If asked something unrelated to agriculture, reply: "I can only assist with farming-related queries."

CONTENT RULES:
- Always mention dosage and frequency when recommending treatments
- Include one safety precaution per chemical/pesticide recommendation`;

// ─── Token Utilities ──────────────────────────────────────────────────────────

const estimateTokens = (text) => Math.ceil(text.length / 4);

const SYSTEM_TOKENS = estimateTokens(SYSTEM_PROMPT);
const MAX_HISTORY_TOKENS = 3000;
const WINDOW_LIMIT = 6; // last 6 messages = 3 exchanges

const trimHistoryToTokenBudget = (messages) => {
  let total = 0;
  const trimmed = [];
  for (let i = messages.length - 1; i >= 0; i--) {
    const tokens = estimateTokens(messages[i].content);
    if (total + tokens > MAX_HISTORY_TOKENS) break;
    trimmed.unshift(messages[i]);
    total += tokens;
  }
  return trimmed;
};

// ─── Session Management ───────────────────────────────────────────────────────

const createSession = async (user_Id, title = "New Chat") => {
  const sessionId = uuidv4();
  const result = await query(
    `INSERT INTO chat_sessions (session_id, user_id, title)
     VALUES ($1, $2, $3)
     RETURNING session_id, user_id, title, created_at, updated_at`,
    [sessionId, user_Id, title],
  );
  return result.rows[0];
};

const getUserSessions = async (user_Id) => {
  const result = await query(
    `SELECT s.session_id, s.title, s.created_at, s.updated_at,
            COUNT(m.message_id) AS message_count
     FROM chat_sessions s
     LEFT JOIN chat_messages m ON s.session_id = m.session_id
     WHERE s.user_id = $1 AND s.is_active = TRUE
     GROUP BY s.session_id
     ORDER BY s.updated_at DESC`,
    [user_Id],
  );
  return result.rows;
};

const deleteSession = async (sessionId, user_Id) => {
  const result = await query(
    `UPDATE chat_sessions
     SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP
     WHERE session_id = $1 AND user_id = $2
     RETURNING session_id`,
    [sessionId, user_Id],
  );
  return result.rows[0];
};

// ─── Message Management ───────────────────────────────────────────────────────

const getSessionMessages = async (sessionId, user_Id) => {
  const result = await query(
    `SELECT message_id, role, content, created_at
     FROM chat_messages
     WHERE session_id = $1
     ORDER BY created_at ASC`,
    [sessionId],
  );
  return result.rows;
};

const saveMessage = async (sessionId, role, content) => {
  const message_Id = uuidv4();
  const result = await query(
    `INSERT INTO chat_messages (message_id, session_id, role, content)
     VALUES ($1, $2, $3, $4)
     RETURNING message_id, session_id, role, content, created_at`,
    [message_Id, sessionId, role, content],
  );
  await query(
    `UPDATE chat_sessions
     SET updated_at = CURRENT_TIMESTAMP
     WHERE session_id = $1`,
    [sessionId],
  );
  return result.rows[0];
};

// ─── Core Chat with Memory ────────────────────────────────────────────────────

const chat = async (user_Id, sessionId, userMessage) => {
  // Validate session belongs to this user
  const sessionCheck = await query(
    `SELECT session_id FROM chat_sessions
     WHERE session_id = $1 AND user_id = $2 AND is_active = TRUE`,
    [sessionId, user_Id],
  );
  if (sessionCheck.rowCount === 0) {
    throw new Error("Session not found or unauthorized");
  }

  // Load last 6 messages only (sliding window)
  const historyResult = await query(
    `SELECT role, content
     FROM chat_messages
     WHERE session_id = $1
     ORDER BY created_at DESC
     LIMIT $2`,
    [sessionId, WINDOW_LIMIT],
  );
  const rawHistory = historyResult.rows.reverse(); // restore chronological order

  // Apply token budget trim as safety net
  const history = trimHistoryToTokenBudget(rawHistory);

  // Build Groq messages: system + trimmed history + new user message
  const messages = [
    { role: "system", content: SYSTEM_PROMPT },
    ...history,
    { role: "user", content: userMessage },
  ];

  // Log estimated token usage
  const estimatedInputTokens =
    SYSTEM_TOKENS +
    history.reduce((sum, m) => sum + estimateTokens(m.content), 0) +
    estimateTokens(userMessage);
  console.log(
    `[Token Estimate] Input: ~${estimatedInputTokens} tokens | History messages used: ${history.length}`,
  );

  // Save user message first
  const savedUserMsg = await saveMessage(sessionId, "user", userMessage);

  // Call Groq API
  const response = await groq.chat.completions.create({
    model: MODEL,
    messages,
    temperature: 0.7,
    max_tokens: 512,
  });

  const assistantReply = response.choices[0].message.content;

  // Save assistant reply
  const savedAssistantMsg = await saveMessage(
    sessionId,
    "assistant",
    assistantReply,
  );

  console.log(
    `[Groq Usage] Prompt: ${response.usage.prompt_tokens} | Completion: ${response.usage.completion_tokens} | Total: ${response.usage.total_tokens}`,
  );

  return {
    sessionId,
    userMessageId: savedUserMsg.message_id,
    assistantMessageId: savedAssistantMsg.message_id,
    reply: assistantReply,
    usage: response.usage,
  };
};

module.exports = {
  createSession,
  getUserSessions,
  deleteSession,
  getSessionMessages,
  chat,
};
