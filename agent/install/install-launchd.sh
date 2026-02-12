#!/bin/bash
set -e

# Install serdash-agent as launchd service (macOS)

CONFIG_DIR="${HOME}/.config/serdash-agent"
PLIST_USER="${HOME}/Library/LaunchAgents/com.serdash.agent.plist"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pip install "$PROJECT_ROOT"

mkdir -p "$CONFIG_DIR"
# Use user's config dir in plist
sed "s|/usr/local/etc/serdash-agent|$CONFIG_DIR|g" \
  "$SCRIPT_DIR/launchd/com.serdash.agent.plist" > /tmp/com.serdash.agent.plist
# Fix path to serdash-agent (use python -m if installed in venv)
python_path=$(which serdash-agent 2>/dev/null || echo "/usr/local/bin/serdash-agent")
sed -i.bak "s|/usr/local/bin/serdash-agent|$python_path|g" /tmp/com.serdash.agent.plist

cp /tmp/com.serdash.agent.plist "$PLIST_USER"
launchctl load "$PLIST_USER"

echo "Installed as user LaunchAgent. Register with: serdash-agent register https://your-host CODE"
