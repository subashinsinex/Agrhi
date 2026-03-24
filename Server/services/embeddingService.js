// services/embeddingService.js
const EMBEDDING_URL =
  process.env.EMBEDDING_SERVICE_URL || "http://localhost:8001/embed";

const getEmbedding = async (text) => {
  const res = await fetch(EMBEDDING_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text }),
  });
  if (!res.ok) throw new Error("Embedding service unavailable");
  const data = await res.json();
  return data.embedding; // returns float array [0.23, -0.87, ...]
};

module.exports = { getEmbedding };
