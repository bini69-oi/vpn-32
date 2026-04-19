"""Unit tests for the small pure helpers in remnawave_client.py."""
from __future__ import annotations

import pytest

from vpn_bot.services.remnawave_client import (
    _normalize_api_root,
    _parse_telegram_user_id,
    _unwrap_response,
    _username_for_telegram,
)


class TestNormalizeApiRoot:
    def test_appends_api_when_missing(self) -> None:
        assert _normalize_api_root("https://panel.example.com") == "https://panel.example.com/api"

    def test_strips_trailing_slash_then_appends(self) -> None:
        assert _normalize_api_root("https://panel.example.com/") == "https://panel.example.com/api"

    def test_keeps_api_when_already_present(self) -> None:
        assert _normalize_api_root("https://panel.example.com/api") == "https://panel.example.com/api"

    def test_empty_returns_empty(self) -> None:
        assert _normalize_api_root("") == ""
        assert _normalize_api_root("   ") == ""

    def test_http_scheme_preserved(self) -> None:
        assert _normalize_api_root("http://127.0.0.1:3000") == "http://127.0.0.1:3000/api"


class TestParseTelegramUserId:
    @pytest.mark.parametrize(
        "raw,expected",
        [
            ("tg_123", 123),
            ("TG_42", 42),
            ("Tg_999999999", 999999999),
            ("123", 123),
            ("", None),
            ("abc", None),
            ("tg_", None),
            ("tg_abc", None),
            ("tg-123", None),
            (" 123", 123),
            ("tg_123 ", 123),
        ],
    )
    def test_cases(self, raw: str, expected: int | None) -> None:
        assert _parse_telegram_user_id(raw) == expected


class TestUsernameForTelegram:
    def test_normal_id(self) -> None:
        assert _username_for_telegram(42) == "tg42"

    def test_minimal_length_is_enforced_for_short_ids(self) -> None:
        # "tg1" already >= 3 chars, but the helper still guarantees length.
        assert len(_username_for_telegram(1)) >= 3

    def test_never_exceeds_remnawave_username_limit(self) -> None:
        huge = 10**30
        name = _username_for_telegram(huge)
        assert len(name) <= 36


class TestUnwrapResponse:
    def test_unwraps_response_key(self) -> None:
        data = {"response": {"uuid": "x"}}
        assert _unwrap_response(data) == {"uuid": "x"}

    def test_returns_input_when_no_wrapper(self) -> None:
        data = {"uuid": "x"}
        assert _unwrap_response(data) is data

    def test_returns_input_when_response_is_list(self) -> None:
        # API wraps list responses too, but our wrapper only strips dicts — list stays wrapped.
        data = {"response": [{"uuid": "x"}]}
        assert _unwrap_response(data) is data
