"""Ed25519 keypair and JWT signing for agent authentication."""

import os
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives import serialization
import jwt


def generate_keypair():
    """Generate Ed25519 keypair, return (private_key, public_key_pem)."""
    priv = ed25519.Ed25519PrivateKey.generate()
    pub = priv.public_key()
    pub_pem = pub.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode()
    return priv, pub_pem


def load_or_create_keypair(config_dir: Path) -> tuple:
    """Load keypair from config_dir or create new one."""
    priv_path = config_dir / "agent.key"
    pub_path = config_dir / "agent.pub"

    if priv_path.exists() and pub_path.exists():
        with open(priv_path, "rb") as f:
            priv = serialization.load_pem_private_key(f.read(), password=None)
        with open(pub_path) as f:
            pub_pem = f.read()
        return priv, pub_pem

    config_dir.mkdir(parents=True, exist_ok=True)
    priv, pub_pem = generate_keypair()
    priv_bytes = priv.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    with open(priv_path, "wb") as f:
        f.write(priv_bytes)
    os.chmod(priv_path, 0o600)
    with open(pub_path, "w") as f:
        f.write(pub_pem)
    os.chmod(pub_path, 0o600)
    return priv, pub_pem


def create_signed_jwt(agent_id: int, private_key) -> str:
    """Create JWT signed with Ed25519 for agent_id."""
    payload = {
        "agent_id": agent_id,
        "iat": __import__("time").time(),
        "exp": __import__("time").time() + 300,  # 5 min
    }
    return jwt.encode(
        payload,
        private_key,
        algorithm="EdDSA",
    )
