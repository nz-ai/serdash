FROM python:3.12-slim

WORKDIR /app

# Install agent (build context must be repo root)
COPY agent/ /app/agent/
RUN pip install --no-cache-dir -e /app/agent

# Config dir
ENV SERDASH_CONFIG_DIR=/etc/serdash-agent
RUN mkdir -p /etc/serdash-agent

# Short interval for dev (60 seconds)
ENV SERDASH_INTERVAL_SECONDS=60

COPY test-server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
