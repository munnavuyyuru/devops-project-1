#!/bin/bash

set -e  # exit on any error

# Configuration
CONTAINER="todo-database"
DB="todoapp"
USER="todouser"
BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/backups"

# Functions
die() {
    echo "Error: $1"
    exit 1
}


# Input Validation
if [ -z "$1" ]; then
    echo "Usage: $0 <backup-file>"
    echo "Available backups:"
    echo "  Daily backups:"
    ls -lh "$BACKUP_DIR/daily"/*.gz 2>/dev/null || echo "    None"
    echo "  Weekly backups:"
    ls -lh "$BACKUP_DIR/weekly"/*.gz 2>/dev/null || echo "    None"
    echo "  Monthly backups:"
    ls -lh "$BACKUP_DIR/monthly"/*.gz 2>/dev/null || echo "    None"
    exit 1
fi

BACKUP_FILE="$1"
[ -f "$BACKUP_FILE" ] || die "Backup file not found: $BACKUP_FILE"

echo "Restoring from backup: $BACKUP_FILE"
echo "Target database: $DB (container: $CONTAINER)"

# Warning
echo "WARNING: This will overwrite the current database and all data will be lost!"
read -p "Type 'yes' to continue: " CONFIRM

# Check container
docker ps | grep -q "$CONTAINER" || die "Container $CONTAINER is not running"

# Decompress if needed
if [[ "$BACKUP_FILE" == *.gz ]]; then
    echo "Decompressing backup..."
    TEMP_FILE="/tmp/restore_$(date +%s).sql"
    gunzip -c "$BACKUP_FILE" > "$TEMP_FILE"
    BACKUP_FILE="$TEMP_FILE"
    echo "Decompression done"
fi

# Drop connections & database
echo "Terminating active connections..."
docker exec "$CONTAINER" psql -U "$USER" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB';" >/dev/null

echo "Dropping database..."
docker exec "$CONTAINER" psql -U "$USER" -d postgres -c "DROP DATABASE IF EXISTS $DB;" >/dev/null

echo "Creating database..."
docker exec "$CONTAINER" psql -U "$USER" -d postgres -c "CREATE DATABASE $DB;" >/dev/null

# Restore backup
echo "Restoring database..."
cat "$BACKUP_FILE" | docker exec -i "$CONTAINER" psql -U "$USER" -d "$DB" >/dev/null
echo "Restore completed"

# Clean up temp file
[ -f "$TEMP_FILE" ] && rm "$TEMP_FILE"

# Verify restore
TABLES=$(docker exec "$CONTAINER" psql -U "$USER" -d "$DB" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" | tr -d ' ')
ROWS=$(docker exec "$CONTAINER" psql -U "$USER" -d "$DB" -t -c "SELECT COUNT(*) FROM todos;" 2>/dev/null || echo "0" | tr -d ' ')

echo "Tables restored: $TABLES"
echo "Rows in todos table: $ROWS"
echo "Database $DB successfully restored from $(basename "$BACKUP_FILE")"
