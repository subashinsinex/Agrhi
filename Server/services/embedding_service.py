# services/embedding_service.py
from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer

app = FastAPI()
model = SentenceTransformer('paraphrase-MiniLM-L6-v2')  # free, 384-dim

class TextInput(BaseModel):
    text: str

@app.post("/embed")
def embed(input: TextInput):
    return {"embedding": model.encode(input.text).tolist()}
