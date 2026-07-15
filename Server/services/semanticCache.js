// services/semanticCache.js
const { query } = require("../db/database");

const RETRIEVAL_THRESHOLD = 0.75;
const INSERTION_THRESHOLD = 0.8;

const toVector = (arr) => `[${arr.join(",")}]`;

const searchCache = async (embedding) => {
  const result = await query(
    `SELECT id, question, answer,
            1 - (embedding <=> $1::vector) AS similarity
     FROM qa_cache
     ORDER BY embedding <=> $1::vector
     LIMIT 1`,
    [toVector(embedding)],
  );
  console.log(
    `[Cache Debug] Best match: "${result.rows[0]?.question}" | Score: ${result.rows[0]?.similarity}`,
  );
  return result.rows[0] || null;
};

// ─── Smart Follow-Up Detection (No manual keyword lists) ─────────────────────

const AGRICULTURE_NOUNS =
  /\b(crop|plant|soil|water|farm|pest|disease|fertilizer|seed|harvest|irrigation|weather|rice|wheat|tomato|paddy|cotton|sugarcane|mango|banana|coconut|chili|onion|potato|insect|fungus|blight|yield|field|spray|manure|urea|npk|drip|flood|monsoon|season|sowing)\b/i;

const REFERENCE_WORDS =
  /^(it|its|this|that|they|them|those|these|the same|above|previous)\b/i;

const LANGUAGE_REQUEST =
  /\b(tamil|hindi|telugu|kannada|malayalam|english|marathi|bengali|gujarati|punjabi|urdu|odia)\b/i;

const ACTION_WORDS =
  /\b(explain|translate|say|tell|write|convert|repeat|describe|elaborate|summarize|simplify|detail|clarify|rephrase|rewrite|expand|more|again)\b/i;

const isFollowUpQuestion = (text) => {
  const q = text.trim().toLowerCase();
  const wordCount = q.split(/\s+/).length;

  // Signal 1: Very short message (≤ 3 words) — almost always a follow-up
  if (wordCount <= 3) return true;

  // Signal 2: Starts with a reference pronoun (it, this, that, they...)
  if (REFERENCE_WORDS.test(q)) return true;

  // Signal 3: Language request with short message
  if (LANGUAGE_REQUEST.test(q) && wordCount <= 6) return true;

  // Signal 4: Action word present BUT no agriculture subject noun
  if (ACTION_WORDS.test(q) && !AGRICULTURE_NOUNS.test(q)) return true;

  return false;
};

// ─────────────────────────────────────────────────────────────────────────────

const insertCache = async (question, answer, embedding) => {
  await query(
    `INSERT INTO qa_cache (question, answer, embedding)
     VALUES ($1, $2, $3::vector)`,
    [question, answer, toVector(embedding)],
  );
};

const incrementHitCount = async (id) => {
  await query(
    `UPDATE qa_cache
     SET hit_count = hit_count + 1, updated_at = NOW()
     WHERE id = $1`,
    [id],
  );
};

const isQualityAnswer = (answer) => {
  if (!answer || answer.length < 50) return false;
  if (answer.includes("I can only assist with")) return false;
  return true;
};

module.exports = {
  isFollowUpQuestion,
  searchCache,
  insertCache,
  incrementHitCount,
  isQualityAnswer,
  RETRIEVAL_THRESHOLD,
  INSERTION_THRESHOLD,
};
