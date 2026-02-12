"""Publish metrics to collector API."""

import sys
import requests

from .auth import create_signed_jwt


def register(base_url: str, code: str, public_key_pem: str, hostname: str) -> int:
    """Register agent, return agent_id."""
    url = f"{base_url.rstrip('/')}/serdash/api/v1/register"
    resp = requests.post(
        url,
        json={
            "code": code,
            "public_key": public_key_pem,
            "hostname": hostname,
        },
        timeout=30,
    )
    resp.raise_for_status()
    data = resp.json()
    if not data.get("success"):
        raise RuntimeError(data.get("error", "Registration failed"))
    return data["agent_id"]


def publish(base_url: str, agent_id: int, private_key, metrics: dict) -> None:
    """Publish metrics to collector."""
    url = f"{base_url.rstrip('/')}/serdash/api/v1/metrics"
    token = create_signed_jwt(agent_id, private_key)
    resp = requests.post(
        url,
        json=metrics,
        headers={"Authorization": f"Bearer {token}"},
        timeout=30,
    )
    resp.raise_for_status()
    data = resp.json()
    if not data.get("success"):
        raise RuntimeError(data.get("error", "Publish failed"))
