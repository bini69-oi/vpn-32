"""Settings tests for Remnawave integration."""
from __future__ import annotations

import pytest

from vpn_bot.config.settings import Settings


def _build(**env: str) -> Settings:
    # `_env_file=None` disables pydantic's `.env` discovery so local dev files
    # cannot contaminate the test. We still set the required BOT_TOKEN.
    base = {"BOT_TOKEN": "stub"}
    base.update(env)
    return Settings(_env_file=None, **{k: v for k, v in base.items()})  # type: ignore[arg-type]


class TestVpnBackendNormalized:
    @pytest.mark.parametrize(
        "raw,expected",
        [
            ("", "productd"),
            ("productd", "productd"),
            ("PRODUCTD", "productd"),
            (" remnawave ", "remnawave"),
            ("Remnawave", "remnawave"),
            ("garbage", "productd"),
        ],
    )
    def test_cases(self, raw: str, expected: str) -> None:
        assert _build(VPN_BACKEND=raw).vpn_backend_normalized() == expected


class TestApiConfigured:
    def test_productd_requires_token(self) -> None:
        assert _build().api_configured() is False
        assert _build(VPN_API_TOKEN="x").api_configured() is True

    def test_remnawave_requires_panel_and_token(self) -> None:
        s = _build(VPN_BACKEND="remnawave")
        assert s.api_configured() is False

        s = _build(VPN_BACKEND="remnawave", REMNAWAVE_API_TOKEN="t")
        assert s.api_configured() is False

        s = _build(
            VPN_BACKEND="remnawave",
            REMNAWAVE_API_TOKEN="t",
            REMNAWAVE_PANEL_URL="https://p.example",
        )
        assert s.api_configured() is True


class TestSquadParsing:
    def test_empty_is_empty_list(self) -> None:
        assert _build().remnawave_internal_squad_uuids() == []

    def test_csv_splitting(self) -> None:
        s = _build(REMNAWAVE_INTERNAL_SQUAD_UUIDS="a,b , ,c")
        assert s.remnawave_internal_squad_uuids() == ["a", "b", "c"]

    def test_singular_alias(self) -> None:
        s = _build(REMNAWAVE_INTERNAL_SQUAD_UUID="only-one")
        assert s.remnawave_internal_squad_uuids() == ["only-one"]


class TestAliasPanelUrl:
    def test_both_aliases_work(self) -> None:
        assert _build(REMNAWAVE_PANEL_URL="https://x").remnawave_panel_url == "https://x"
        assert _build(REMNAWAVE_BASE_URL="https://y").remnawave_panel_url == "https://y"
