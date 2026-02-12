#!/bin/bash
set -e

# Install serdash-agent as systemd service (Ubuntu, Fedora)

AGENT_USER=serdash-agent
AGENT_GROUP=serdash-agent
CONFIG_DIR=/etc/serdash-agent
INSTALL_DIR=/usr/local

# Create user if not exists
if ! id "$AGENT_USER" &>/dev/null; then
  useradd -r -s /bin/false "$AGENT_USER"
fi

# Install agent (pip install from parent dir or use installed)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
pip install "$PROJECT_ROOT"
# Or: pip install serdash-agent

# Config dir
mkdir -p "$CONFIG_DIR"
chown "$AGENT_USER:$AGENT_GROUP" "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

# Copy systemd unit
cp "$SCRIPT_DIR/systemd/serdash-agent.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable serdash-agent
systemctl start serdash-agent

echo "Installed. Register with: serdash-agent register https://your-host CODE"
echo "Config and keys go in $CONFIG_DIR (run register as root first, or copy keys)"
