"""Tests for `VPNApiClient` wire format (vpn-productd backend)."""
from __future__ import annotations

import json

from tests._fake_session import FakeSession
from vpn_bot.services.api_client import VPNApiClient, VPNBackend


def _client(session: FakeSession) -> VPNApiClient:
    return VPNApiClient(session, "http://vpnd:8080", "secret-token")  # type: ignore[arg-type]


class TestAuthHeader:
    async def test_bearer_on_get(self) -> None:
        s = FakeSession()
        s.on("GET", "/v1/health", 200, "{}")
        await _client(s).get_health()
        assert s.last_call().headers["Authorization"] == "Bearer secret-token"

    async def test_idempotency_key_forwarded_on_issue_link(self) -> None:
        s = FakeSession()
        s.on("POST", "/v1/issue/link", 200, json.dumps({"subscription": {"id": "x"}}))
        await _client(s).issue_link("tg_1", "n", "src", ["p1"], "idem-1")
        call = s.last_call()
        assert call.headers["X-Idempotency-Key"] == "idem-1"
        assert call.json == {
            "userId": "tg_1",
            "name": "n",
            "source": "src",
            "profileIds": ["p1"],
        }


class TestIssueStatus:
    async def test_calls_with_userId_param(self) -> None:
        s = FakeSession()
        s.on("GET", "/v1/issue/status", 200, json.dumps({"subscriptionId": "abc"}))
        status, body = await _client(s).issue_status("tg_42")
        assert status == 200
        assert body["subscriptionId"] == "abc"
        assert s.last_call().params == {"userId": "tg_42"}


class TestLifecycleRenew:
    async def test_posts_renew_days(self) -> None:
        s = FakeSession()
        s.on("POST", "/v1/subscriptions/lifecycle", 200, "{}")
        status, _ = await _client(s).lifecycle_renew("tg_42", 30)
        assert status == 200
        body = s.last_call().json
        assert body == {"userId": "tg_42", "action": "renew", "days": 30}


class TestProtocolConformance:
    def test_vpn_api_client_matches_vpn_backend_protocol(self) -> None:
        c = _client(FakeSession())
        backend: VPNBackend = c  # noqa: F841
        for attr in (
            "issue_status",
            "issue_link",
            "lifecycle_renew",
            "get_subscription",
            "get_delivery_links",
            "get_health",
            "get_profile_stats",
        ):
            assert callable(getattr(c, attr))
