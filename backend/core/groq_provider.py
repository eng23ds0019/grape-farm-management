"""
Groq LLM Provider — Llama 3.1 8B Instruct / Llama 3.2 11B Vision
Free tier: 14,400 requests/day. ~600 tokens/sec.
To swap provider: create a new class implementing LLMProvider.
"""
import os
from typing import Optional
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
        self._vision_model = "llama-3.2-11b-vision-preview" # For image understanding

        if _groq_available and self._api_key:
            try:
                self._client = Groq(api_key=self._api_key)
                print(f"✅ GroqProvider initialized with text model: {self._model} and vision model: {self._vision_model}")
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

    def generate(self, system_prompt: str, user_message: str, temperature: float = 0.2, image_base64: Optional[str] = None) -> str:
        if not self._client:
            return '{"response": "AI reasoning engine is not configured. Please set GROQ_API_KEY in Render environment variables.", "diseaseRisk": "Low", "diseaseName": "None", "recommendedSpray": "None"}'

        try:
            model_to_use = self._model
            user_content = []
            
            if image_base64:
                model_to_use = self._vision_model
                # Prefix data URL if it's missing (Groq vision API requires a valid data URL)
                if not image_base64.startswith("data:image"):
                    image_base64 = f"data:image/jpeg;base64,{image_base64}"
                
                user_content = [
                    {"type": "text", "text": user_message},
                    {"type": "image_url", "image_url": {"url": image_base64}},
                ]
            else:
                user_content = user_message

            completion = self._client.chat.completions.create(
                model=model_to_use,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_content},
                ],
                temperature=temperature,
                max_tokens=2048, # Increased to allow for more analytical responses
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
