# Serdash

LAN Server Monitoring Dashboard with Python agents, Ruby collector, and Rails dashboard.

## Quick Start

```bash
cp .env.example .env
docker compose up -d

# Run migrations (first time)
docker compose run --rm dashboard bin/rails db:migrate

# Open http://localhost
```

## Development: Test Server (E2E)

Run the full stack with a test agent that collects and pushes metrics every 60 seconds:

```bash
# 1. Seed test server with registration code TESTDEV
docker compose run --rm dashboard bin/rails db:seed

# 2. Start stack including test-server (profile: test)
docker compose --profile test up -d

# 3. Test server auto-registers and pushes metrics. Check http://localhost/servers
#    Click "test-server" to see CPU, disk, memory samples.
```

The test-server runs in a container on `python:3.12-slim`, collects Linux metrics (disk, memory, CPU, network), and pushes to the collector via nginx.

## Architecture

- **Nginx** (port 80): Reverse proxy
- **Dashboard** (Rails): `/` — auth (Google/GitHub OAuth), server list, metrics
- **Collector** (Ruby): `/serdash/api/` — agent registration, metrics ingestion
- **PostgreSQL** (port 15432): Shared database with TimescaleDB

## Adding a Server

1. Sign in to the dashboard
2. Click "Servers" → "Add server"
3. Enter hostname (optional) and submit
4. Copy the registration code shown
5. On the target server, run:

```bash
cd agent
python3 -m venv .venv && source .venv/bin/activate
pip install -e .
serdash-agent register http://your-host  YOUR_CODE
serdash-agent run
```

Replace `http://your-host` with your collector URL (e.g. `http://localhost` for local dev).

## Agent Installation

See [agent/README.md](agent/README.md) for systemd (Linux) and launchd (macOS) service setup.

## Network Discovery

From the dashboard, go to **Discover** to scan a subnet for visible hosts. Use `?subnet=192.168.1.0/24` or set `DISCOVERY_SUBNET` in `.env`.

**Note:** When running in Docker, the collector can only reach networks it has access to (Docker bridge by default). To discover your LAN, ensure the collector can route to the target subnet (e.g. if the host is the gateway, the collector may need host network access).

## OAuth Setup

Set in `.env` for social login:

- `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`
- `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET`

## Development

```bash
# Run without Docker (needs local PostgreSQL on 15432)
cd dashboard && bundle install && bin/rails server
cd collector && bundle install && bundle exec puma -p 3001
```
