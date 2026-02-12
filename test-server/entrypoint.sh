#!/bin/sh
set -e

# Register once, then run
if [ -n "$REGISTRATION_CODE" ] && [ ! -f "$SERDASH_CONFIG_DIR/agent_id" ]; then
  echo "Registering agent with code $REGISTRATION_CODE..."
  serdash-agent register "$COLLECTOR_URL" "$REGISTRATION_CODE" \
    --config-dir "$SERDASH_CONFIG_DIR" \
    --hostname "${AGENT_HOSTNAME:-test-server}"
  echo "Registration complete."
fi

if [ ! -f "$SERDASH_CONFIG_DIR/agent_id" ]; then
  echo "Not registered. Set REGISTRATION_CODE and COLLECTOR_URL env vars."
  exit 1
fi

echo "Starting agent (interval: ${SERDASH_INTERVAL_SECONDS:-1800}s)..."
exec serdash-agent run --config-dir "$SERDASH_CONFIG_DIR"
