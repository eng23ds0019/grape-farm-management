"""
Groq LLM Provider — Powered by Llama 3.3 70B Versatile & Llama 3.2 11B Vision.
High accuracy agritech reasoning with automatic model fallback.
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
        self._primary_model = "llama-3.3-70b-versatile"
        self._fallback_model = "llama-3.1-8b-instant"
        self._vision_model = "llama-3.2-11b-vision-preview"

        if _groq_available and self._api_key:
            try:
                self._client = Groq(api_key=self._api_key)
                print(f"✅ GroqProvider initialized with primary: {self._primary_model}, fallback: {self._fallback_model}")
            except Exception as e:
                print(f"❌ GroqProvider init failed: {e}")
        else:
            if not _groq_available:
                print("⚠️ groq package not installed")
            if not self._api_key:
                print("⚠️ GROQ_API_KEY not set in environment")

    @property
    def name(self) -> str:
        return f"Groq/{self._primary_model}"

    @property
    def is_available(self) -> bool:
        return self._client is not None

    def generate(self, system_prompt: str, user_message: str, temperature: float = 0.2, image_base64: Optional[str] = None) -> str:
        if not self._client:
            return '{"response": "AI reasoning engine is not configured. Please set GROQ_API_KEY in Render environment variables.", "diseaseRisk": "Low", "diseaseName": "None", "recommendedSpray": "None"}'

        user_content = []
        models_to_try = [self._primary_model, self._fallback_model]

        if image_base64:
            models_to_try = [self._vision_model, self._primary_model, self._fallback_model]
            if not image_base64.startswith("data:image"):
                image_base64 = f"data:image/jpeg;base64,{image_base64}"
            user_content = [
                {"type": "text", "text": user_message},
                {"type": "image_url", "image_url": {"url": image_base64}},
            ]
        else:
            user_content = user_message

        last_error = None
        for model in models_to_try:
            try:
                # If doing text-only with vision model, skip to text model
                if not image_base64 and "vision" in model:
                    continue
                
                completion = self._client.chat.completions.create(
                    model=model,
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_content if image_base64 and "vision" in model else user_message},
                    ],
                    temperature=temperature,
                    max_tokens=2500,
                    stream=False,
                )
                res = completion.choices[0].message.content.strip()
                if res:
                    return res
            except Exception as e:
                print(f"⚠️ Model {model} failed: {e}. Trying fallback...")
                last_error = e

        print(f"❌ All Groq models failed: {last_error}")
        return f'{{"response": "Reasoning engine error: {str(last_error)[:100]}", "diseaseRisk": "Low", "diseaseName": "None", "recommendedSpray": "None"}}'


# Singleton instance
_provider = None

def get_llm_provider() -> GroqProvider:
    global _provider
    if _provider is None:
        _provider = GroqProvider()
    return _provider
