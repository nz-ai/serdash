"""CLI for serdash-agent."""

import argparse
import sys
import time
from pathlib import Path

import os

from .auth import load_or_create_keypair, create_signed_jwt
from .collector import collect
from .publisher import register, publish


def _config_dir() -> Path:
    for d in [
        Path("/etc/serdash-agent"),
        Path.home() / ".config" / "serdash-agent",
    ]:
        if d.exists() or d.parent.exists():
            return d
    return Path.home() / ".config" / "serdash-agent"


def cmd_register(args):
    """Register agent with collector."""
    config_dir = Path(args.config_dir) if args.config_dir else _config_dir()
    priv, pub_pem = load_or_create_keypair(config_dir)

    import socket
    hostname = args.hostname or socket.gethostname()

    config_dir.mkdir(parents=True, exist_ok=True)
    agent_id = register(args.url, args.code, pub_pem, hostname)
    # Store agent_id and collector URL for run
    (config_dir / "agent_id").write_text(str(agent_id))
    (config_dir / "collector_url").write_text(args.url.strip())
    print(f"Registered. Agent ID: {agent_id}")
    return 0


def cmd_run(args):
    """Collect and publish metrics every 30 minutes."""
    config_dir = Path(args.config_dir) if args.config_dir else _config_dir()
    agent_id_path = config_dir / "agent_id"
    if not agent_id_path.exists():
        print("Not registered. Run: serdash-agent register <url> <code>", file=sys.stderr)
        return 1

    agent_id = int(agent_id_path.read_text().strip())
    priv, _ = load_or_create_keypair(config_dir)

    base_url = args.url
    if not base_url and (config_dir / "collector_url").exists():
        base_url = (config_dir / "collector_url").read_text().strip()
    if not base_url:
        print("No collector URL. Set --url or run register first.", file=sys.stderr)
        return 1

    interval = int(os.environ.get("SERDASH_INTERVAL_SECONDS", 30 * 60))

    while True:
        try:
            metrics = collect()
            publish(base_url, agent_id, priv, metrics)
            print(f"Published metrics at {metrics.get('sampled_at', '?')}")
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)

        time.sleep(interval)


def main():
    parser = argparse.ArgumentParser(prog="serdash-agent")
    sub = parser.add_subparsers(dest="cmd", required=True)

    reg = sub.add_parser("register", help="Register with collector")
    reg.add_argument("url", help="Collector base URL (e.g. https://host)")
    reg.add_argument("code", help="Registration code from dashboard")
    reg.add_argument("--hostname", help="Override hostname")
    reg.add_argument("--config-dir", help="Config directory")
    reg.set_defaults(func=cmd_register)

    run = sub.add_parser("run", help="Run agent (collect and publish every 30 min)")
    run.add_argument("--url", help="Collector base URL (or set in config)")
    run.add_argument("--config", "--config-dir", dest="config_dir", help="Config directory")
    run.set_defaults(func=cmd_run)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
