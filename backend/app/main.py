from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from .rag_pipeline import RagPipeline


class RagRequest(BaseModel):
  question: str


app = FastAPI(title="Insurance RAG API", version="0.1.0")

app.add_middleware(
  CORSMiddleware,
  allow_origins=["*"],
  allow_credentials=True,
  allow_methods=["*"],
  allow_headers=["*"],
)

pipeline = RagPipeline()


@app.get("/healthz")
async def health_check():
  return {"status": "ok"}


@app.post("/api/rag/query")
async def rag_query(payload: RagRequest):
  try:
    answer, references = pipeline.answer(payload.question)
    return {"answer": answer, "references": references}
  except Exception as exc:
    raise HTTPException(status_code=500, detail=f"Pipeline error: {exc}") from exc
