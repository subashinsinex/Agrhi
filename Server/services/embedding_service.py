import os
from typing import List

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer

app = FastAPI(title="AGRHI Embedding Service")

HF_TOKEN = os.getenv("HF_TOKEN")
if HF_TOKEN:
    print("[Embedding Service] HF_TOKEN detected")
else:
    print("[Embedding Service] HF_TOKEN not found; using unauthenticated HF Hub access")

model = SentenceTransformer("paraphrase-MiniLM-L6-v2")

class TextInput(BaseModel):
    text: str

class EmbeddingResponse(BaseModel):
    embedding: List[float]

@app.get("/health")
def health():
    return {"status": "ok", "model": "paraphrase-MiniLM-L6-v2"}

@app.post("/embed", response_model=EmbeddingResponse)
def embed(input: TextInput):
    text = input.text.strip()

    if not text:
        raise HTTPException(status_code=400, detail="Text cannot be empty")

    embedding = model.encode(text).tolist()
    return {"embedding": embedding}