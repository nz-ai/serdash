# Serdash Agent

Python agent that collects system metrics and pushes them to the Serdash collector.

## Requirements

- Python 3.10+
- Linux or macOS

## Install

```bash
cd agent
python3 -m venv .venv
source .venv/bin/activate  # or .venv\Scripts\activate on Windows
pip install -e .
```

## Register

1. Add a server in the Serdash dashboard
2. Copy the registration code (e.g. `A1B2C3D4`)
3. Run:

```bash
serdash-agent register https://your-collector-host A1B2C3D4
```

Replace `https://your-collector-host` with your nginx host (e.g. `http://localhost` for local dev).

## Run

```bash
serdash-agent run
```

Collects metrics every 30 minutes and pushes to the collector.

## Config

Config and keys are stored in:

- Linux: `/etc/serdash-agent` (when installed as service) or `~/.config/serdash-agent`
- macOS: `~/.config/serdash-agent`

## Service installation

### Ubuntu / Fedora (systemd)

```bash
sudo ./install/install-systemd.sh
```

### macOS (launchd)

```bash
./install/install-launchd.sh
```
