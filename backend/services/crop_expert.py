import os
import requests
from dotenv import load_dotenv

load_dotenv()

PINECONE_API_KEY = os.getenv("PINECONE_API_KEY", "")
PINECONE_INDEX_URL = os.getenv("PINECONE_INDEX_URL", "")

class CropExpertService:
    @staticmethod
    def retrieve_knowledge(query: str):
        """
        Retrieves permanent grape knowledge base data from Pinecone vector DB.
        This provides RAG context for the reasoning engine.
        """
        if not PINECONE_API_KEY or not PINECONE_INDEX_URL:
            return "[KNOWLEDGE_DB_OFFLINE] Default knowledge: Grapes require careful canopy management, timely irrigation, and strict adherence to spray schedules."
            
        try:
            # Note: In a true production system, you would embed the `query` text into a 768-dim vector using an embedding model (like Google's text-embedding-004) before sending it to Pinecone.
            # Here we mock the embedding vector structure for simplicity since we don't have the embedding model initialized.
            headers = {"Api-Key": PINECONE_API_KEY, "Content-Type": "application/json"}
            payload = {"vector": [0.01] * 768, "topK": 5, "includeMetadata": True}
            
            resp = requests.post(f"{PINECONE_INDEX_URL}/query", json=payload, headers=headers, timeout=5)
            if resp.status_code == 200:
                matches = resp.json().get('matches', [])
                knowledge_context = "\n\n".join([m['metadata'].get('text', '') for m in matches])
                if knowledge_context.strip():
                    return knowledge_context
            return "[NO_SPECIFIC_KNOWLEDGE_FOUND]"
        except Exception as e:
            print(f"CropExpertService Vector DB Error: {e}")
            return "[KNOWLEDGE_DB_ERROR]"
