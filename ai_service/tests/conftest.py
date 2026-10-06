import os
import pytest
from ai_service.config import get_api_keys

def pytest_collection_modifyitems(config, items):
    """Automatically skips tests requiring a live Google Gemini API network call
    when running in CI or an environment without valid live Gemini credentials.
    """
    keys = get_api_keys()
    has_live_key = bool(keys and not any("placeholder" in k.lower() or "ci-" in k.lower() for k in keys))

    # In CI runners without explicit LIVE_GEMINI_TESTS secret enabled, skip live LLM tests
    if os.getenv("CI") == "true" and not os.getenv("LIVE_GEMINI_TESTS"):
        has_live_key = False

    if not has_live_key:
        skip_live = pytest.mark.skip(
            reason="Live Google Gemini API key required (skipped in CI / offline test runner)"
        )
        live_test_names = {
            "test_api_after_sales_chat_troubleshooting",
            "test_api_after_sales_chat_switch_to_service_request_mode",
            "test_after_sales_chat_suggest_service_request_after_5_attempts",
            "test_generate_compatible_build_gaming_1440p",
            "test_generate_compatible_build_high_end_4k",
            "test_post_build_generate_endpoint",
            "test_api_verify_stock_endpoint",
            "test_api_create_proposal_endpoint",
            "test_first_turn_extracts_purpose_and_budget",
            "test_multi_turn_no_amnesia",
            "test_4k_is_resolution_not_budget",
            "test_user_correction_during_confirmation",
            "test_confirmation_completes_profile",
            "test_boundary_guardrail_no_part_recommendations",
        }
        for item in items:
            if item.name in live_test_names or "live" in item.keywords:
                item.add_marker(skip_live)
