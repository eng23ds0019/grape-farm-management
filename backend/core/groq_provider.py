"""
Groq LLM Provider — Llama 3.1 8B Instruct
Free tier: 14,400 requests/day. ~600 tokens/sec.
To swap provider: create a new class implementing LLMProvider.
"""
import os
from core.llm_provider import LLMProvider

try:
    from groq import Groq
    _groq_available = True
except ImportError:
    _groq_available = False


class GroqProvider(LLMProvider):
    def __init__(self):
        self._api_key = os.getenv("GROQ_API_KEY", "")
        self._client = None
        self._model = "llama-3.1-8b-instant"  # Fast, capable, free

        if _groq_available and self._api_key:
            try:
                self._client = Groq(api_key=self._api_key)
                print(f"✅ GroqProvider initialized with model: {self._model}")
            except Exception as e:
                print(f"❌ GroqProvider init failed: {e}")
        else:
            if not _groq_available:
                print("⚠️  groq package not installed")
            if not self._api_key:
                print("⚠️  GROQ_API_KEY not set in environment")

    @property
    def name(self) -> str:
        return f"Groq/{self._model}"

    @property
    def is_available(self) -> bool:
        return self._client is not None

    def generate(self, system_prompt: str, user_message: str, temperature: float = 0.2) -> str:
        if not self._client:
            return '{"response": "AI reasoning engine is not configured. Please set GROQ_API_KEY in Render environment variables.", "diseaseRisk": "Low", "diseaseName": "None", "recommendedSpray": "None"}'

        try:
            completion = self._client.chat.completions.create(
                model=self._model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message},
                ],
                temperature=temperature,
                max_tokens=1024,
                stream=False,
            )
            return completion.choices[0].message.content.strip()
        except Exception as e:
            print(f"❌ GroqProvider.generate error: {e}")
            error_msg = str(e)[:100]
            return f'{{"response": "Reasoning engine error: {error_msg}", "diseaseRisk": "Low", "diseaseName": "None", "recommendedSpray": "None"}}'


# Singleton instance
_provider = None

def get_llm_provider() -> GroqProvider:
    global _provider
    if _provider is None:
        _provider = GroqProvider()
    return _provider
