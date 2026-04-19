"""Tests for tiny helpers living in the subscription handler.

They deal with the wire-level differences between vpn-productd (delivery/links
returns `{"links": {"vless": "vless://..."}}`) and Remnawave (returns
`{"links": {"subscription": "https://..."}}`).
"""
from __future__ import annotations

from vpn_bot.handlers.subscription import _happ_add_url, _pick_happ_import_link


class TestPickHappImportLink:
    def test_prefers_https_subscription_key(self) -> None:
        links = {
            "vless": "vless://abc",
            "subscription": "https://panel.example/sub/token",
        }
        assert _pick_happ_import_link(links) == "https://panel.example/sub/token"

    def test_prefers_subscriptionUrl_key_from_remnawave(self) -> None:
        links = {"subscriptionUrl": "https://r.example/sub/t"}
        assert _pick_happ_import_link(links) == "https://r.example/sub/t"

    def test_falls_back_to_vless(self) -> None:
        links = {"vless": "vless://abc"}
        assert _pick_happ_import_link(links) == "vless://abc"

    def test_returns_none_when_empty(self) -> None:
        assert _pick_happ_import_link({}) is None

    def test_ignores_non_string_values(self) -> None:
        links = {"subscription": 123, "vless": None, "trojan": "trojan://zzz"}
        assert _pick_happ_import_link(links) == "trojan://zzz"

    def test_ignores_unsupported_schemes(self) -> None:
        links = {"foo": "ftp://nope"}
        assert _pick_happ_import_link(links) is None


class TestHappAddUrl:
    def test_wraps_scheme(self) -> None:
        assert _happ_add_url("https://panel.example/sub/t") == "happ://add/https://panel.example/sub/t"

    def test_escapes_hash_only(self) -> None:
        # The `#` in vless fragments confuses Happ URL parser, so we escape it.
        raw = "vless://uuid@host:443?type=tcp#MyServer"
        out = _happ_add_url(raw)
        assert "#MyServer" not in out
        assert "%23MyServer" in out
