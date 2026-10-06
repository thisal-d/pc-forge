import os
import logging
import pytest
from unittest.mock import MagicMock, AsyncMock

from ai_service.config import (
    get_api_keys,
    is_retryable_gemini_error,
    RotatingChatGoogleGenerativeAI,
    RotatingRunnable,
    set_active_key_index,
    get_active_key_index,
)
from langchain_core.messages import HumanMessage, AIMessage
from langchain_core.outputs import ChatResult, ChatGeneration


class DummyRateLimitError(Exception):
    status_code = 429


class DummyAuthError(Exception):
    status_code = 401


class DummyUnavailableError(Exception):
    status_code = 503


class DummyNonRetryableError(ValueError):
    pass


def test_get_api_keys_discovers_numbered_keys(monkeypatch):
    """Verifies that GEMINI_API_KEY_1..6 are discovered in order."""
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    for i in range(1, 21):
        monkeypatch.delenv(f"GEMINI_API_KEY_{i}", raising=False)
        monkeypatch.delenv(f"GOOGLE_API_KEY_{i}", raising=False)

    monkeypatch.setenv("GEMINI_API_KEY_1", "valid_key_alpha_11111")
    monkeypatch.setenv("GEMINI_API_KEY_2", "valid_key_beta_22222")
    monkeypatch.setenv("GEMINI_API_KEY_3", "valid_key_gamma_33333")

    keys = get_api_keys()
    assert keys == [
        "valid_key_alpha_11111",
        "valid_key_beta_22222",
        "valid_key_gamma_33333",
    ]


def test_get_api_keys_filters_placeholders_and_duplicates(monkeypatch):
    """Ignores placeholder strings, empty values, and deduplicates identical keys."""
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    for i in range(1, 21):
        monkeypatch.delenv(f"GEMINI_API_KEY_{i}", raising=False)
        monkeypatch.delenv(f"GOOGLE_API_KEY_{i}", raising=False)

    monkeypatch.setenv("GEMINI_API_KEY_1", "valid_key_alpha_11111")
    monkeypatch.setenv("GEMINI_API_KEY_2", "your_key_here")  # placeholder
    monkeypatch.setenv("GEMINI_API_KEY_3", "")               # empty
    monkeypatch.setenv("GEMINI_API_KEY_4", "valid_key_alpha_11111")  # duplicate
    monkeypatch.setenv("GEMINI_API_KEY_5", "valid_key_delta_44444")

    keys = get_api_keys()
    assert keys == [
        "valid_key_alpha_11111",
        "valid_key_delta_44444",
    ]


def test_get_api_keys_works_with_only_two_keys(monkeypatch):
    """Verifies that if only 2 keys are configured, only those 2 are used."""
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    for i in range(1, 21):
        monkeypatch.delenv(f"GEMINI_API_KEY_{i}", raising=False)
        monkeypatch.delenv(f"GOOGLE_API_KEY_{i}", raising=False)

    monkeypatch.setenv("GEMINI_API_KEY_1", "key_first_123456789")
    monkeypatch.setenv("GEMINI_API_KEY_2", "key_second_123456789")

    keys = get_api_keys()
    assert len(keys) == 2
    assert keys == ["key_first_123456789", "key_second_123456789"]


def test_is_retryable_gemini_error():
    """Validates classification of quota, auth, and transient failures."""
    # 1. Quota / Rate limit (429, ResourceExhausted)
    assert is_retryable_gemini_error(DummyRateLimitError("Quota limit reached"))
    assert is_retryable_gemini_error(Exception("429 Resource has been exhausted"))
    assert is_retryable_gemini_error(Exception("Rate limit exceeded. Please try again later."))
    assert is_retryable_gemini_error(Exception("exceeded your current quota"))

    # 2. Authentication / Invalid key / 401 / 403
    assert is_retryable_gemini_error(DummyAuthError("Unauthorized"))
    assert is_retryable_gemini_error(Exception("API_KEY_INVALID: API key not valid"))
    assert is_retryable_gemini_error(Exception("403 Forbidden: permission denied"))
    assert is_retryable_gemini_error(Exception("unauthenticated request"))

    # 3. Transient Gemini API failures (500, 503, timeout)
    assert is_retryable_gemini_error(DummyUnavailableError("Service unavailable"))
    assert is_retryable_gemini_error(Exception("503 Service Unavailable"))
    assert is_retryable_gemini_error(Exception("500 Internal Server Error"))
    assert is_retryable_gemini_error(Exception("Deadline exceeded: timed out waiting for response"))
    assert is_retryable_gemini_error(TimeoutError("Request timed out"))

    # 4. Non-retryable application errors
    assert not is_retryable_gemini_error(DummyNonRetryableError("Invalid argument format in prompt"))
    assert not is_retryable_gemini_error(KeyError("missing_field"))
    assert not is_retryable_gemini_error(None)


def test_rotating_chat_model_falls_back_and_remembers_working_key(caplog):
    """When key 1 fails with 429, it falls back to key 2, returns result, and remembers key 2."""
    set_active_key_index(0)

    mock_m1 = MagicMock()
    mock_m1.invoke.side_effect = DummyRateLimitError("429 Quota exhausted for key 1")

    mock_m2 = MagicMock()
    expected_resp = AIMessage(content="Hello from Key 2")
    mock_m2.invoke.return_value = expected_resp

    mock_m3 = MagicMock()

    rotator = RotatingChatGoogleGenerativeAI(models=[mock_m1, mock_m2, mock_m3])

    with caplog.at_level(logging.WARNING):
        res = rotator.invoke([HumanMessage(content="Hello")])

    assert res == expected_resp
    assert mock_m1.invoke.call_count == 1
    assert mock_m2.invoke.call_count == 1
    assert mock_m3.invoke.call_count == 0
    assert get_active_key_index() == 1  # pointer persisted to key 2 (0-indexed 1)

    # Next request starts immediately from key 2!
    mock_m2.invoke.reset_mock()
    mock_m1.invoke.reset_mock()
    res2 = rotator.invoke([HumanMessage(content="Second message")])
    assert res2 == expected_resp
    assert mock_m2.invoke.call_count == 1
    assert mock_m1.invoke.call_count == 0

    # Verify safe logging was emitted without revealing keys
    warning_logs = [r.message for r in caplog.records if r.levelno == logging.WARNING]
    assert any("Gemini API key 1 failed, trying next configured key." in msg for msg in warning_logs)


def test_rotating_chat_model_raises_when_all_keys_fail():
    """When all configured keys fail with retryable errors, raises the final error after 1 attempt each."""
    set_active_key_index(0)

    mock_m1 = MagicMock()
    mock_m1.invoke.side_effect = DummyRateLimitError("Key 1 429")

    mock_m2 = MagicMock()
    mock_m2.invoke.side_effect = DummyAuthError("Key 2 401")

    mock_m3 = MagicMock()
    mock_m3.invoke.side_effect = DummyUnavailableError("Key 3 503")

    rotator = RotatingChatGoogleGenerativeAI(models=[mock_m1, mock_m2, mock_m3])

    with pytest.raises(DummyUnavailableError):
        rotator.invoke([HumanMessage(content="Hello")])

    assert mock_m1.invoke.call_count == 1
    assert mock_m2.invoke.call_count == 1
    assert mock_m3.invoke.call_count == 1


def test_rotating_chat_model_does_not_retry_non_retryable_errors():
    """Non-retryable exceptions (like ValueError) fail immediately without exhausting other keys."""
    set_active_key_index(0)

    mock_m1 = MagicMock()
    mock_m1.invoke.side_effect = DummyNonRetryableError("Bad parameter")

    mock_m2 = MagicMock()

    rotator = RotatingChatGoogleGenerativeAI(models=[mock_m1, mock_m2])

    with pytest.raises(DummyNonRetryableError):
        rotator.invoke([HumanMessage(content="Hello")])

    assert mock_m1.invoke.call_count == 1
    assert mock_m2.invoke.call_count == 0


def test_rotating_runnable_bind_tools_fallback():
    """Verifies that RotatingRunnable created by bind_tools rotates across keys."""
    set_active_key_index(0)

    mock_b1 = MagicMock()
    mock_b1.invoke.side_effect = Exception("429 Quota Exceeded")

    mock_b2 = MagicMock()
    expected_resp = AIMessage(content="Tool execution plan from key 2")
    mock_b2.invoke.return_value = expected_resp

    runnable = RotatingRunnable([mock_b1, mock_b2])
    res = runnable.invoke([HumanMessage(content="Plan something")])

    assert res == expected_resp
    assert mock_b1.invoke.call_count == 1
    assert mock_b2.invoke.call_count == 1
    assert get_active_key_index() == 1


def test_rotating_chat_model_ainvoke_fallback():
    """Verifies asynchronous ainvoke fallback across keys."""
    import asyncio

    async def _test():
        set_active_key_index(0)

        mock_m1 = MagicMock()
        mock_m1.ainvoke = AsyncMock(side_effect=Exception("503 Server overloaded"))

        mock_m2 = MagicMock()
        expected_resp = AIMessage(content="Async reply from key 2")
        mock_m2.ainvoke = AsyncMock(return_value=expected_resp)

        rotator = RotatingChatGoogleGenerativeAI(models=[mock_m1, mock_m2])
        res = await rotator.ainvoke([HumanMessage(content="Async request")])

        assert res == expected_resp
        assert mock_m1.ainvoke.call_count == 1
        assert mock_m2.ainvoke.call_count == 1
        assert get_active_key_index() == 1

    asyncio.run(_test())

