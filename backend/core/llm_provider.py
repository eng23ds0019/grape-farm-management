"""
Abstract LLM Provider Interface.
Swap providers without changing any other code.
"""
from abc import ABC, abstractmethod
from typing import Optional


class LLMProvider(ABC):
    @abstractmethod
    def generate(self, system_prompt: str, user_message: str, temperature: float = 0.2, image_base64: Optional[str] = None) -> str:
        """Generate a response from the LLM. Returns raw text. Supports optional base64 image."""
        pass

    @property
    @abstractmethod
    def name(self) -> str:
        """Provider name for logging."""
        pass
