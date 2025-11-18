import os
from typing import List, Tuple

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import AzureOpenAI
from pinecone import Pinecone, ServerlessSpec
from tenacity import retry, stop_after_attempt, wait_exponential

DEFAULT_INDEX_NAME = "insurance-rag-index"


class RagPipeline:
  def __init__(self) -> None:
    self.deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4o-mini")
    self.embedding_deployment = os.getenv("AZURE_OPENAI_EMBEDDING", "text-embedding-ada-002")
    self.azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT", "https://api.openai.com")
    self.pinecone_index = os.getenv("PINECONE_INDEX_NAME", DEFAULT_INDEX_NAME)
    self.pinecone_env = os.getenv("PINECONE_ENV", "us-east1-gcp")
    self.pinecone_api_key = os.getenv("PINECONE_API_KEY", "FAKE-KEY")

    self.credential = DefaultAzureCredential(exclude_interactive_browser_credential=False)
    token_provider = get_bearer_token_provider(
      self.credential, "https://cognitiveservices.azure.com/.default"
    )

    self.openai_client = AzureOpenAI(
      azure_endpoint=self.azure_endpoint,
      api_version="2024-02-01",
      azure_ad_token_provider=token_provider,
    )
    self.pinecone_client = Pinecone(api_key=self.pinecone_api_key)
    self.index = self._ensure_index()

  def _ensure_index(self):
    if self.pinecone_index not in [index["name"] for index in self.pinecone_client.list_indexes()]:
      self.pinecone_client.create_index(
        name=self.pinecone_index,
        dimension=1536,
        metric="cosine",
        spec=ServerlessSpec(cloud="aws", region="us-east-1"),
      )
    return self.pinecone_client.Index(self.pinecone_index)

  @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=2, min=1, max=8))
  def _embed(self, text: str) -> List[float]:
    response = self.openai_client.embeddings.create(
      input=text, model=self.embedding_deployment
    )
    return response.data[0].embedding

  def _retrieve(self, query_vector: List[float], top_k: int = 4) -> List[dict]:
    results = self.index.query(vector=query_vector, top_k=top_k, include_metadata=True)
    return results["matches"]

  def _generate(self, question: str, context: str) -> str:
    completion = self.openai_client.chat.completions.create(
      model=self.deployment,
      messages=[
        {
          "role": "system",
          "content": "You are an insurance financial analyst. Cite sources when possible.",
        },
        {
          "role": "user",
          "content": f"Context chunks:\n{context}\n\nQuestion: {question}",
        },
      ],
      temperature=0.2,
    )
    return completion.choices[0].message.content

  def answer(self, question: str) -> Tuple[str, List[dict]]:
    query_vector = self._embed(question)
    chunks = self._retrieve(query_vector)
    context = "\n\n".join(
      f"Chunk {idx+1}: {chunk['metadata'].get('summary', chunk['metadata'].get('text'))}"
      for idx, chunk in enumerate(chunks)
    )
    answer = self._generate(question, context)
    references = [
      {
        "document_id": chunk["metadata"].get("document_id"),
        "page": chunk["metadata"].get("page"),
        "score": chunk["score"],
      }
      for chunk in chunks
    ]
    return answer, references
