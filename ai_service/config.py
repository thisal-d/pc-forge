import os
import re
import logging
import threading
from pathlib import Path
from typing import Any, List, Optional, Sequence
from dotenv import load_dotenv

from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.messages import BaseMessage
from langchain_core.outputs import ChatResult
from langchain_core.runnables import Runnable, RunnableConfig

logger = logging.getLogger(__name__)

# Load service-local .env and root repository .env
_current_dir = Path(__file__).resolve().parent
load_dotenv(_current_dir / ".env")
load_dotenv(_current_dir.parent / ".env")


def _is_placeholder_key(key: str) -> bool:
    """Detects empty or placeholder keys that should not be used."""
    if not key:
        return True
    low = key.strip().lower()
    return (
        low.startswith("your_")
        or low.startswith("ci-")
        or "placeholder" in low
        or low == "none"
        or low == "null"
        or len(low) < 10
    )


def get_api_keys() -> list[str]:
    """Collects all configured Gemini API keys from environment variables.

    Supports:
      - GEMINI_API_KEY_1, GEMINI_API_KEY_2, ..., GEMINI_API_KEY_6 (and higher)
      - GOOGLE_API_KEY_1, GOOGLE_API_KEY_2, ... (backward compatibility)
      - Fallback to GEMINI_API_KEY / GOOGLE_API_KEY

    Filters out empty values and placeholder strings (e.g. 'your_key_here').
    Deduplicates keys while preserving configuration order.
    """
    candidate_keys: list[str] = []

    # 1. Collect numbered keys (checking 1 to 20 for GEMINI and GOOGLE prefixes)
    for i in range(1, 21):
        for prefix in ("GEMINI_API_KEY_", "GOOGLE_API_KEY_"):
            val = (os.getenv(f"{prefix}{i}") or "").strip()
            if val and not _is_placeholder_key(val):
                candidate_keys.append(val)

    # 2. Collect unnumbered keys if provided
    for single_var in ("GEMINI_API_KEY", "GOOGLE_API_KEY"):
        val = (os.getenv(single_var) or "").strip()
        if val and not _is_placeholder_key(val):
            candidate_keys.append(val)

    # 3. Deduplicate while preserving order
    seen = set()
    unique_keys: list[str] = []
    for k in candidate_keys:
        if k not in seen:
            seen.add(k)
            unique_keys.append(k)

    return unique_keys


GOOGLE_API_KEYS = get_api_keys()
GOOGLE_API_KEY = GOOGLE_API_KEYS[0] if GOOGLE_API_KEYS else os.getenv("GOOGLE_API_KEY", "")
CHAT_MODEL = os.getenv("CHAT_MODEL", "gemini-3.8-flash")
AI_SERVICE_PORT = int(os.getenv("AI_SERVICE_PORT", "5050"))
AI_SERVICE_HOST = os.getenv("AI_SERVICE_HOST", "0.0.0.0")
BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:5000")

# Thread-safe pointer to currently active key index
_active_key_index: int = 0
_key_lock = threading.Lock()


def get_active_key_index() -> int:
    """Returns currently selected key index (0-indexed)."""
    with _key_lock:
        return _active_key_index


def set_active_key_index(index: int) -> None:
    """Sets currently selected key index (0-indexed)."""
    global _active_key_index
    with _key_lock:
        _active_key_index = index


def is_retryable_gemini_error(exc: Exception) -> bool:
    """Identifies if an error is a quota/rate limit, auth/invalid key, or temporary Gemini API failure."""
    if exc is None:
        return False

    # Check status_code or code attribute if available
    status_code = getattr(exc, "status_code", None) or getattr(exc, "code", None)
    if isinstance(status_code, int) and status_code in (401, 403, 429, 500, 502, 503, 504):
        return True
    if hasattr(status_code, "value") and isinstance(status_code.value, int) and status_code.value in (401, 403, 429, 500, 502, 503, 504):
        return True

    exc_type_name = type(exc).__name__.lower()
    retryable_type_names = (
        "googleratelimiterror",
        "googleauthenticationerror",
        "googlepermissiondeniederror",
        "googleapierror",
        "resourceexhausted",
        "ratelimiterror",
        "serviceunavailable",
        "deadlineexceeded",
        "servererror",
        "unauthenticated",
        "permissiondenied",
        "timeouterror",
        "connecterror",
        "connectionerror",
    )
    if any(rt in exc_type_name for rt in retryable_type_names):
        return True

    msg = str(exc).lower()

    # 1. Quota / Rate Limit / HTTP 429 / API key limit
    if any(term in msg for term in [
        "429",
        "resource_exhausted",
        "resourceexhausted",
        "quota",
        "quota exceeded",
        "rate limit",
        "ratelimit",
        "too many requests",
        "exceeded your current quota",
    ]):
        return True

    # 2. Authentication / Invalid API key / 401 / 403 / API key error
    if any(term in msg for term in [
        "401",
        "403",
        "api_key_invalid",
        "api key not valid",
        "invalid api key",
        "invalid_argument: api key",
        "permission_denied",
        "unauthenticated",
        "forbidden",
    ]):
        return True

    # 3. Temporary Gemini API failure / 5xx / Unavailable / Timeout
    if any(term in msg for term in [
        "500",
        "502",
        "503",
        "504",
        "service unavailable",
        "temporarily unavailable",
        "deadline exceeded",
        "deadline_exceeded",
        "server error",
        "overloaded",
        "internal server error",
        "connection error",
        "connection reset",
        "timeout",
        "timed out",
    ]):
        return True

    return False


class RotatingRunnable(Runnable):
    """Wraps bound models with automatic key rotation and fallback."""

    def __init__(self, runnables: List[Any]):
        self.runnables = runnables

    def invoke(self, input: Any, config: Optional[RunnableConfig] = None, **kwargs: Any) -> Any:
        global _active_key_index
        if not self.runnables:
            raise ValueError("No configured models available.")

        with _key_lock:
            start_idx = _active_key_index % len(self.runnables)

        last_err = None
        for attempt in range(len(self.runnables)):
            idx = (start_idx + attempt) % len(self.runnables)
            r = self.runnables[idx]
            try:
                out = r.invoke(input, config=config, **kwargs)
                with _key_lock:
                    _active_key_index = idx
                return out
            except Exception as e:
                last_err = e
                if is_retryable_gemini_error(e) and attempt < len(self.runnables) - 1:
                    logger.warning("Gemini API key %d failed, trying next configured key.", idx + 1)
                    with _key_lock:
                        _active_key_index = (idx + 1) % len(self.runnables)
                    continue
                raise last_err

    async def ainvoke(self, input: Any, config: Optional[RunnableConfig] = None, **kwargs: Any) -> Any:
        global _active_key_index
        if not self.runnables:
            raise ValueError("No configured models available.")

        with _key_lock:
            start_idx = _active_key_index % len(self.runnables)

        last_err = None
        for attempt in range(len(self.runnables)):
            idx = (start_idx + attempt) % len(self.runnables)
            r = self.runnables[idx]
            try:
                out = await r.ainvoke(input, config=config, **kwargs)
                with _key_lock:
                    _active_key_index = idx
                return out
            except Exception as e:
                last_err = e
                if is_retryable_gemini_error(e) and attempt < len(self.runnables) - 1:
                    logger.warning("Gemini API key %d failed, trying next configured key.", idx + 1)
                    with _key_lock:
                        _active_key_index = (idx + 1) % len(self.runnables)
                    continue
                raise last_err

    def bind(self, **kwargs: Any) -> Runnable:
        bound = [r.bind(**kwargs) for r in self.runnables]
        return RotatingRunnable(bound)


class RotatingChatGoogleGenerativeAI(BaseChatModel):
    """ChatGoogleGenerativeAI wrapper providing automatic multi-key rotation and fallbacks."""

    models: List[Any] = []

    def invoke(self, input: Any, config: Optional[RunnableConfig] = None, **kwargs: Any) -> Any:
        global _active_key_index
        if not self.models:
            raise ValueError("No configured models available.")

        with _key_lock:
            start_idx = _active_key_index % len(self.models)

        last_err = None
        for attempt in range(len(self.models)):
            idx = (start_idx + attempt) % len(self.models)
            model = self.models[idx]
            try:
                res = model.invoke(input, config=config, **kwargs)
                with _key_lock:
                    _active_key_index = idx
                return res
            except Exception as e:
                last_err = e
                if is_retryable_gemini_error(e) and attempt < len(self.models) - 1:
                    logger.warning("Gemini API key %d failed, trying next configured key.", idx + 1)
                    with _key_lock:
                        _active_key_index = (idx + 1) % len(self.models)
                    continue
                raise last_err

    async def ainvoke(self, input: Any, config: Optional[RunnableConfig] = None, **kwargs: Any) -> Any:
        global _active_key_index
        if not self.models:
            raise ValueError("No configured models available.")

        with _key_lock:
            start_idx = _active_key_index % len(self.models)

        last_err = None
        for attempt in range(len(self.models)):
            idx = (start_idx + attempt) % len(self.models)
            model = self.models[idx]
            try:
                res = await model.ainvoke(input, config=config, **kwargs)
                with _key_lock:
                    _active_key_index = idx
                return res
            except Exception as e:
                last_err = e
                if is_retryable_gemini_error(e) and attempt < len(self.models) - 1:
                    logger.warning("Gemini API key %d failed, trying next configured key.", idx + 1)
                    with _key_lock:
                        _active_key_index = (idx + 1) % len(self.models)
                    continue
                raise last_err

    def _generate(
        self,
        messages: List[BaseMessage],
        stop: Optional[List[str]] = None,
        run_manager: Any = None,
        **kwargs: Any
    ) -> ChatResult:
        global _active_key_index
        if not self.models:
            raise ValueError("No configured models available.")

        with _key_lock:
            start_idx = _active_key_index % len(self.models)

        last_err = None
        for attempt in range(len(self.models)):
            idx = (start_idx + attempt) % len(self.models)
            model = self.models[idx]
            try:
                res = model._generate(messages, stop=stop, run_manager=run_manager, **kwargs)
                with _key_lock:
                    _active_key_index = idx
                return res
            except Exception as e:
                last_err = e
                if is_retryable_gemini_error(e) and attempt < len(self.models) - 1:
                    logger.warning("Gemini API key %d failed, trying next configured key.", idx + 1)
                    with _key_lock:
                        _active_key_index = (idx + 1) % len(self.models)
                    continue
                raise last_err

    async def _agenerate(
        self,
        messages: List[BaseMessage],
        stop: Optional[List[str]] = None,
        run_manager: Any = None,
        **kwargs: Any
    ) -> ChatResult:
        global _active_key_index
        if not self.models:
            raise ValueError("No configured models available.")

        with _key_lock:
            start_idx = _active_key_index % len(self.models)

        last_err = None
        for attempt in range(len(self.models)):
            idx = (start_idx + attempt) % len(self.models)
            model = self.models[idx]
            try:
                res = await model._agenerate(messages, stop=stop, run_manager=run_manager, **kwargs)
                with _key_lock:
                    _active_key_index = idx
                return res
            except Exception as e:
                last_err = e
                if is_retryable_gemini_error(e) and attempt < len(self.models) - 1:
                    logger.warning("Gemini API key %d failed, trying next configured key.", idx + 1)
                    with _key_lock:
                        _active_key_index = (idx + 1) % len(self.models)
                    continue
                raise last_err

    @property
    def _llm_type(self) -> str:
        return "rotating_chat_google_generative_ai"

    def bind_tools(
        self,
        tools: Sequence[Any],
        **kwargs: Any
    ) -> Runnable:
        bound = [m.bind_tools(tools, **kwargs) for m in self.models]
        return RotatingRunnable(bound)

    def bind(
        self,
        **kwargs: Any
    ) -> Runnable:
        bound = [m.bind(**kwargs) for m in self.models]
        return RotatingRunnable(bound)


def get_llm():
    """Returns a ChatGoogleGenerativeAI client with automatic multi-key rotation and fallback.
    
    Tries the currently active key first. If it fails with a quota, auth, or transient error,
    it automatically rotates to the next configured key until a key succeeds or all
    keys have been attempted.
    """
    keys = get_api_keys()
    if not keys:
        return None

    try:
        from langchain_google_genai import ChatGoogleGenerativeAI

        models = [
            ChatGoogleGenerativeAI(
                model=CHAT_MODEL,
                google_api_key=k,
                temperature=0.2,
                timeout=60,
                max_retries=1
            )
            for k in keys
        ]

        return RotatingChatGoogleGenerativeAI(models=models)
    except Exception as e:
        logger.error(f"[config] Failed to initialize ChatGoogleGenerativeAI: {e}")
        return None

