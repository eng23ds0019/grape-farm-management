"""
Abstract LLM Provider Interface.
Swap providers without changing any other code.
"""
from abc import ABC, abstractmethod


class LLMProvider(ABC):
    @abstractmethod
    def generate(self, system_prompt: str, user_message: str, temperature: float = 0.2) -> str:
        """Generate a response from the LLM. Returns raw text."""
        pass

    @property
    @abstractmethod
    def name(self) -> str:
        """Provider name for logging."""
        pass
