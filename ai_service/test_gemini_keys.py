#!/usr/bin/env python3
"""PCForge - Gemini API Key Access Tester & Diagnostic Utility.

Inspects every configured Gemini API key (GEMINI_API_KEY_1 through GEMINI_API_KEY_6)
individually to determine usability, authentication status, permissions, and quotas.
Never exposes raw keys or rotates keys to bypass quotas.
"""

import os
import sys
import re
from pathlib import Path
from typing import Any, Dict, List, Optional
from dotenv import load_dotenv

# Ensure ai_service root is on sys.path
_current_dir = Path(__file__).resolve().parent
if str(_current_dir.parent) not in sys.path:
    sys.path.insert(0, str(_current_dir.parent))

# Load environment configuration
load_dotenv(_current_dir / ".env")
load_dotenv(_current_dir.parent / ".env")

from ai_service.config import CHAT_MODEL


def mask_key(key: str) -> str:
    """Returns a safe, masked representation of an API key (e.g. 'TEST...FFIX')."""
    if not key or not key.strip():
        return "[NOT_CONFIGURED]"
    k = key.strip()
    if len(k) <= 8:
        return k[:2] + "..." + k[-2:]
    return f"{k[:4]}...{k[-4:]}"


def sanitize_text(text: str, secret: Optional[str] = None) -> str:
    """Removes sensitive key strings from error messages."""
    if not text:
        return ""
    clean = str(text)
    if secret and len(secret) > 6:
        clean = clean.replace(secret, "[MASKED_KEY]")
    # Also strip common API key patterns if present
    clean = re.sub(r'AIza[0-9A-Za-z-_]{35}', '[MASKED_KEY]', clean)
    clean = re.sub(r'AQ\.[0-9A-Za-z-_]{40,}', '[MASKED_KEY]', clean)
    return clean.strip()


def parse_gemini_error(exc: Exception, raw_key: str) -> Dict[str, Any]:
    """Classifies an exception into clear diagnostic categories."""
    raw_msg = sanitize_text(str(exc), raw_key)
    msg_lower = raw_msg.lower()

    # Extract HTTP status code if present
    code = getattr(exc, "status_code", None) or getattr(exc, "code", None)
    if hasattr(code, "value"):
        code = code.value
    if not isinstance(code, int):
        code_match = re.search(r'\b(200|400|401|403|404|429|500|502|503|504)\b', raw_msg)
        code = int(code_match.group(1)) if code_match else None

    # Check for Project-Level access denial in 403
    is_project_level = (
        "project has been denied access" in msg_lower
        or "your project has been denied" in msg_lower
        or ("project" in msg_lower and "denied" in msg_lower)
        or ("project" in msg_lower and "disabled" in msg_lower)
    )

    # 1. PERMISSION DENIED (HTTP 403)
    if code == 403 or "permission_denied" in msg_lower or "permission denied" in msg_lower or "denied access" in msg_lower:
        reason = "Project-level access denied (project disabled/restricted)" if is_project_level else "Permission denied for this key"
        return {
            "result": "PERMISSION_DENIED",
            "http_code": 403,
            "reason": reason,
            "is_project_level": is_project_level,
            "details": raw_msg[:120] + ("..." if len(raw_msg) > 120 else ""),
        }

    # 2. INVALID / AUTHENTICATION FAILED (HTTP 401)
    if (
        code == 401
        or "unauthenticated" in msg_lower
        or "api_key_invalid" in msg_lower
        or "api key not valid" in msg_lower
        or "invalid api key" in msg_lower
        or "invalid_argument: api key" in msg_lower
    ):
        return {
            "result": "INVALID / AUTHENTICATION_FAILED",
            "http_code": 401,
            "reason": "Authentication failed / Invalid or expired key",
            "is_project_level": False,
            "details": raw_msg[:120] + ("..." if len(raw_msg) > 120 else ""),
        }

    # 3. RATE LIMITED / QUOTA EXHAUSTED (HTTP 429)
    if (
        code == 429
        or "resource_exhausted" in msg_lower
        or "quota" in msg_lower
        or "rate limit" in msg_lower
        or "too many requests" in msg_lower
    ):
        return {
            "result": "RATE_LIMITED",
            "http_code": 429,
            "reason": "Temporary quota / Rate limit reached (Key is valid, quota exhausted)",
            "is_project_level": False,
            "details": raw_msg[:120] + ("..." if len(raw_msg) > 120 else ""),
        }

    # 4. TEMPORARY PROVIDER / NETWORK ERROR (HTTP 5xx, timeouts)
    if (
        (code and code in (500, 502, 503, 504))
        or "unavailable" in msg_lower
        or "service unavailable" in msg_lower
        or "deadline exceeded" in msg_lower
        or "timeout" in msg_lower
        or "timed out" in msg_lower
        or "connection error" in msg_lower
        or "connection reset" in msg_lower
    ):
        return {
            "result": "TEMPORARY_ERROR",
            "http_code": code or 503,
            "reason": "Transient provider / network error",
            "is_project_level": False,
            "details": raw_msg[:120] + ("..." if len(raw_msg) > 120 else ""),
        }

    # 5. OTHER / UNEXPECTED ERROR
    return {
        "result": "OTHER_ERROR",
        "http_code": code or "ERR",
        "reason": f"Unexpected error ({type(exc).__name__})",
        "is_project_level": False,
        "details": raw_msg[:120] + ("..." if len(raw_msg) > 120 else ""),
    }


def inspect_key(key: str, model_name: str = CHAT_MODEL) -> Dict[str, Any]:
    """Performs a single minimal diagnostic request for a single key."""
    if not key or not key.strip() or key.strip().lower().startswith("your_"):
        return {
            "result": "NOT_CONFIGURED",
            "http_code": "-",
            "reason": "Key not configured or placeholder",
            "is_project_level": False,
            "details": "Empty or default placeholder",
        }

    try:
        from langchain_google_genai import ChatGoogleGenerativeAI
        from langchain_core.messages import HumanMessage

        # max_retries=0 ensures exactly 1 attempt per key without background retry loops
        llm = ChatGoogleGenerativeAI(
            model=model_name,
            google_api_key=key.strip(),
            temperature=0.0,
            max_retries=0,
            timeout=15,
        )

        # Single lightweight ping prompt
        _ = llm.invoke([HumanMessage(content="ping")])

        return {
            "result": "WORKING",
            "http_code": 200,
            "reason": "Test request succeeded",
            "is_project_level": False,
            "details": "Model responded successfully with HTTP 200",
        }
    except Exception as exc:
        return parse_gemini_error(exc, key.strip())


# Backward-compatible alias
test_key = inspect_key



def run_diagnostics(total_keys: int = 6) -> List[Dict[str, Any]]:
    """Inspects all configured keys individually and returns diagnostic results."""
    results: List[Dict[str, Any]] = []

    print("=" * 82)
    print("           PCForge - Google Gemini API Key Diagnostic Tester")
    print(f"           Model under test: {CHAT_MODEL}")
    print("=" * 82)
    print("Testing each configured key individually (1 attempt, 0 retries)...\n")

    for i in range(1, total_keys + 1):
        # Check GEMINI_API_KEY_i first, then GOOGLE_API_KEY_i
        var_name = f"GEMINI_API_KEY_{i}"
        key_val = os.getenv(var_name) or os.getenv(f"GOOGLE_API_KEY_{i}") or ""

        masked = mask_key(key_val)
        print(f"[{i}/{total_keys}] Testing {var_name} ({masked})...", end=" ", flush=True)

        info = test_key(key_val)
        info["key_name"] = var_name
        info["masked_key"] = masked
        info["raw_key_present"] = bool(key_val and not key_val.startswith("your_"))
        results.append(info)

        print(f"-> {info['result']} (HTTP {info['http_code']})")

    return results


def print_diagnostic_report(results: List[Dict[str, Any]]) -> None:
    """Formats and prints the diagnostic report table and actionable insights."""
    print("\n" + "=" * 90)
    print(f"{'Key':<18} | {'Masked Key':<14} | {'Result':<26} | {'HTTP':>4} | {'Reason'}")
    print("-" * 90)

    for r in results:
        print(
            f"{r['key_name']:<18} | "
            f"{r['masked_key']:<14} | "
            f"{r['result']:<26} | "
            f"{str(r['http_code']):>4} | "
            f"{r['reason']}"
        )

    print("=" * 90)

    # Statistical breakdown
    working = [r for r in results if r["result"] == "WORKING"]
    auth_failed = [r for r in results if "AUTHENTICATION_FAILED" in r["result"]]
    perm_denied = [r for r in results if r["result"] == "PERMISSION_DENIED"]
    rate_limited = [r for r in results if r["result"] == "RATE_LIMITED"]
    temp_error = [r for r in results if r["result"] == "TEMPORARY_ERROR"]
    not_configured = [r for r in results if r["result"] == "NOT_CONFIGURED"]

    print("\nDiagnostic Summary:")
    print(f"  • WORKING:                     {len(working)}")
    print(f"  • PERMISSION_DENIED (403):     {len(perm_denied)}")
    print(f"  • RATE_LIMITED (429):          {len(rate_limited)}")
    print(f"  • AUTHENTICATION_FAILED (401): {len(auth_failed)}")
    print(f"  • TEMPORARY_ERROR (5xx):       {len(temp_error)}")
    print(f"  • NOT_CONFIGURED / EMPTY:      {len(not_configured)}")

    # Project-level failure analysis
    project_level_denied = [r for r in perm_denied if r.get("is_project_level")]
    if len(project_level_denied) > 1:
        key_names = ", ".join(r["key_name"] for r in project_level_denied)
        print("\n" + "!" * 90)
        print("PROJECT-LEVEL ACCESS RESTRICTION DETECTED:")
        print(f"  Keys [{key_names}] returned the same project-level permission-denied response:")
        print(f"  \"{project_level_denied[0]['details']}\"")
        print("  -> These keys belong to the same restricted or disabled Google Cloud Project.")
        print("  -> Do NOT assume the keys were banned individually; the parent Google Cloud project")
        print("     has access restrictions, billing suspension, or API restrictions enabled.")
        print("!" * 90)
    elif len(perm_denied) == 1:
        print(f"\nNote: {perm_denied[0]['key_name']} returned 403 Permission Denied ({perm_denied[0]['reason']}).")

    # Rate limiting advice
    if rate_limited:
        rl_names = ", ".join(r["key_name"] for r in rate_limited)
        print(f"\nQuota Notice: Keys [{rl_names}] are VALID but currently exhausted on their daily/per-minute free tier limit.")
        print("  -> These keys will become usable again once Google refreshes the quota window.")

    print("\n" + "=" * 90 + "\n")


if __name__ == "__main__":
    test_results = run_diagnostics(total_keys=6)
    print_diagnostic_report(test_results)
