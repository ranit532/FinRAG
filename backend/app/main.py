from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
import os
from opencensus.ext.azure.log_exporter import AzureLogHandler
import logging

from .rag_pipeline import RagPipeline

load_dotenv()

# Set up Application Insights logging
appinsights_conn_str = os.getenv("APPINSIGHTS_CONNECTION_STRING")
if appinsights_conn_str:
    logger = logging.getLogger("appinsights")
    logger.addHandler(AzureLogHandler(connection_string=appinsights_conn_str))
    logger.setLevel(logging.INFO)

app = FastAPI(title="Insurance RAG API", version="0.1.0")

app.add_middleware(
  CORSMiddleware,
  allow_origins=["*"],
  allow_credentials=True,
  allow_methods=["*"],
  allow_headers=["*"],
)

pipeline = RagPipeline()


class RagRequest(BaseModel):
  question: str


@app.get("/healthz")
async def health_check():
  return {"status": "ok"}


@app.post("/api/rag/query")
async def rag_query(payload: RagRequest):
  try:
    answer, references = pipeline.answer(payload.question)
    if appinsights_conn_str:
        logger.info("RAG query processed", extra={"custom_dimensions": {"question": payload.question}})
    return {"answer": answer, "references": references}
  except Exception as exc:
    if appinsights_conn_str:
        logger.exception("Pipeline error", extra={"custom_dimensions": {"error": str(exc)}})
    raise HTTPException(status_code=500, detail=f"Pipeline error: {exc}") from exc
