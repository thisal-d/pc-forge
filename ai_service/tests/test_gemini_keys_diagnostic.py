import pytest
from unittest.mock import MagicMock, patch

from ai_service.test_gemini_keys import (
    mask_key,
    sanitize_text,
    parse_gemini_error,
    inspect_key,
    run_diagnostics,
)


def test_mask_key_security():
    """Ensures keys are properly masked and not leaked."""
    assert mask_key("") == "[NOT_CONFIGURED]"
    assert mask_key("   ") == "[NOT_CONFIGURED]"
    assert mask_key("short") == "sh...rt"
    assert mask_key("TEST_KEY_ALPHA_1234567890_SAMPLE_SUFFIX") == "TEST...FFIX"


def test_sanitize_text_removes_keys():
    """Ensures raw keys are redacted from error output."""
    raw = "TEST_KEY_ALPHA_1234567890_SAMPLE_SUFFIX"
    msg = f"Error communicating with Gemini with key {raw}: Failed"
    clean = sanitize_text(msg, secret=raw)
    assert raw not in clean
    assert "[MASKED_KEY]" in clean


def test_parse_gemini_error_classifications():
    """Validates classification into WORKING, 401, 403, 429, 5xx."""
    # 401 Invalid key
    class Err401(Exception):
        status_code = 401

    res_401 = parse_gemini_error(Err401("API key not valid"), raw_key="test_key_12345")
    assert res_401["result"] == "INVALID / AUTHENTICATION_FAILED"
    assert res_401["http_code"] == 401

    # 403 Project-level permission denied
    class Err403(Exception):
        status_code = 403

    res_403_proj = parse_gemini_error(
        Err403("Your project has been denied access. Please contact support."),
        raw_key="test_key_12345",
    )
    assert res_403_proj["result"] == "PERMISSION_DENIED"
    assert res_403_proj["http_code"] == 403
    assert res_403_proj["is_project_level"] is True

    # 403 Individual key permission denied
    res_403_key = parse_gemini_error(
        Err403("Caller does not have permission for this resource."),
        raw_key="test_key_12345",
    )
    assert res_403_key["result"] == "PERMISSION_DENIED"
    assert res_403_key["http_code"] == 403
    assert res_403_key["is_project_level"] is False

    # 429 Rate limited
    class Err429(Exception):
        status_code = 429

    res_429 = parse_gemini_error(Err429("Quota exceeded (limit: 20)"), raw_key="test_key_12345")
    assert res_429["result"] == "RATE_LIMITED"
    assert res_429["http_code"] == 429

    # 503 Provider unavailable
    class Err503(Exception):
        status_code = 503

    res_503 = parse_gemini_error(Err503("Service unavailable"), raw_key="test_key_12345")
    assert res_503["result"] == "TEMPORARY_ERROR"
    assert res_503["http_code"] == 503


def test_inspect_key_not_configured():
    """Handles empty or placeholder keys gracefully."""
    res = inspect_key("")
    assert res["result"] == "NOT_CONFIGURED"

    res_placeholder = inspect_key("your_gemini_api_key_1")
    assert res_placeholder["result"] == "NOT_CONFIGURED"


@patch("langchain_google_genai.ChatGoogleGenerativeAI.invoke")
def test_inspect_key_success(mock_invoke):
    """Handles successful diagnostic response."""
    mock_invoke.return_value = MagicMock(content="pong")
    res = inspect_key("TEST_KEY_ALPHA_1234567890_SAMPLE_SUFFIX")
    assert res["result"] == "WORKING"
    assert res["http_code"] == 200
