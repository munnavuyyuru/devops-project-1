#!/bin/sh
set -e

mkdir -p /app/secrets

if [ -d "/run/secrets" ]; then
  cp /run/secrets/* /app/secrets/ 2>/dev/null || true
fi

chown -R appuser:appgroup /app/secrets

exec su appuser -c "$*"
