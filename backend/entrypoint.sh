#!/bin/sh
set -e

#chmod 644 /run/secrets/db_password 2>/dev/null || true
#chmod 644 /run/secrets/jwt_secret 2>/dev/null || true

#Load secrets into environment safely
export DB_PASSWORD=$(cat /run/secrets/db_password)
export JWT_SECRET=$(cat /run/secrets/jwt_secret)

#exec su-exec appuser "$@"

exec "$@"
