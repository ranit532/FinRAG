"""
Placeholder ingestion utility to push simulated insurance documents into Pinecone.
"""

import json
import os
from pathlib import Path
from typing import Iterable, List

from dotenv import load_dotenv
from pinecone import Pinecone
from tenacity import retry, stop_after_attempt, wait_exponential

from .rag_pipeline import RagPipeline

load_dotenv()

DATASET_PATH = Path(os.getenv("DATASET_PATH", "data/synthetic_policies.json"))


def chunk_text(text: str, chunk_size: int = 800, overlap: int = 150) -> Iterable[str]:
  start = 0
  while start < len(text):
    end = start + chunk_size
    yield text[start:end]
    start += chunk_size - overlap


class Seeder:
  def __init__(self) -> None:
    self.pipeline = RagPipeline()
    self.pc = Pinecone(api_key=os.getenv("PINECONE_API_KEY", "FAKE-KEY"))
    self.index = self.pc.Index(os.getenv("PINECONE_INDEX_NAME", "insurance-rag-index"))

  @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=2, min=1, max=8))
  def upsert(self, vectors: List[dict]) -> None:
    self.index.upsert(vectors=vectors, namespace="insurance")

  def ingest(self) -> None:
    with open(DATASET_PATH, "r", encoding="utf-8") as handle:
      dataset = json.load(handle)

    vector_batch = []
    for document in dataset:
      for section in document["sections"]:
        for idx, chunk in enumerate(chunk_text(section["content"])):
          embedding = self.pipeline._embed(chunk)  # pylint: disable=protected-access
          vector_batch.append(
            {
              "id": f"{document['policy_id']}-{section['title']}-{idx}",
              "values": embedding,
              "metadata": {
                "document_id": document["policy_id"],
                "text": chunk,
                "section": section["title"],
                "page": section.get("page", idx),
                "summary": section.get("summary"),
              },
            }
          )

    self.upsert(vector_batch)
    print(f"Ingested {len(vector_batch)} chunks into Pinecone.")


if __name__ == "__main__":
  Seeder().ingest()
