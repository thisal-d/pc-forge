import os
from pathlib import Path
from dotenv import load_dotenv

# Try loading from local .env or parent directory .env
_current_dir = Path(__file__).resolve().parent
load_dotenv(_current_dir / ".env")
load_dotenv(_current_dir.parent / ".env")


def get_api_keys() -> list[str]:
    """Collects configured Gemini API keys (GOOGLE_API_KEY_1 to GOOGLE_API_KEY_5, with fallback to GOOGLE_API_KEY)."""
    keys = []
    for i in range(1, 6):
        k = (os.getenv(f"GOOGLE_API_KEY_{i}") or "").strip()
        if k and not k.lower().startswith("your_"):
            keys.append(k)

    if not keys:
        single = (os.getenv("GOOGLE_API_KEY") or "").strip()
        if single and not single.lower().startswith("your_"):
            keys.append(single)
    return keys


GOOGLE_API_KEYS = get_api_keys()
GOOGLE_API_KEY = GOOGLE_API_KEYS[0] if GOOGLE_API_KEYS else os.getenv("GOOGLE_API_KEY", "")
CHAT_MODEL = os.getenv("CHAT_MODEL", "gemini-2.5-flash-lite")
AI_SERVICE_PORT = int(os.getenv("AI_SERVICE_PORT", "5050"))
AI_SERVICE_HOST = os.getenv("AI_SERVICE_HOST", "0.0.0.0")
BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:5000")


def get_llm():
    """Returns a ChatGoogleGenerativeAI client with automatic multi-key fallbacks (1 -> 2 -> 3 -> 4 -> 5)."""
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

        if len(models) == 1:
            return models[0]

        # Cascading fallback chain: model[0] -> fallback model[1] -> model[2] -> model[3] -> model[4]
        return models[0].with_fallbacks(models[1:])
    except Exception as e:
        print(f"[config] Failed to initialize ChatGoogleGenerativeAI: {e}")
        return None
