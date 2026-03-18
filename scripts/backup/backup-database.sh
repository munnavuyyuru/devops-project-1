#!/bin/bash

set -e  # Exit on error

# Configuration
CONTAINER_NAME="todo-database"
DB_NAME="todoapp"
DB_USER="todouser"
BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE=$(date +%Y%m%d)
RETENTION_DAYS=7
RETENTION_WEEKS=4
RETENTION_MONTHS=12

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "   PostgreSQL Backup Script"
echo "============================================"
echo ""
echo "Timestamp: $(date)"
echo "Database: $DB_NAME"
echo "Container: $CONTAINER_NAME"
echo ""

# Check if container is running
if ! docker ps | grep -q $CONTAINER_NAME; then
    echo -e "${RED}❌ Error: Container $CONTAINER_NAME is not running${NC}"
    exit 1
fi

# Check if container is healthy
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_NAME 2>/dev/null || echo "none")
if [ "$HEALTH" != "healthy" ]; then
    echo -e "${YELLOW}⚠️  Warning: Container is not healthy (status: $HEALTH)${NC}"
    echo "Proceeding anyway..."
fi

# Determine backup type based on day
DAY_OF_MONTH=$(date +%d)
DAY_OF_WEEK=$(date +%u)

if [ "$DAY_OF_MONTH" -eq 1 ]; then
    BACKUP_TYPE="monthly"
    BACKUP_SUBDIR="$BACKUP_DIR/monthly"
elif [ "$DAY_OF_WEEK" -eq 7 ]; then
    BACKUP_TYPE="weekly"
    BACKUP_SUBDIR="$BACKUP_DIR/weekly"
else
    BACKUP_TYPE="daily"
    BACKUP_SUBDIR="$BACKUP_DIR/daily"
fi

BACKUP_FILE="$BACKUP_SUBDIR/${DB_NAME}_${BACKUP_TYPE}_${TIMESTAMP}.sql"

echo "Backup type: $BACKUP_TYPE"
echo "Backup file: $BACKUP_FILE"
echo ""

# Create backup
echo "📦 Creating backup..."
if docker exec $CONTAINER_NAME pg_dump -U $DB_USER $DB_NAME > "$BACKUP_FILE"; then
    echo -e "${GREEN}✅ Backup created successfully${NC}"
else
    echo -e "${RED}❌ Backup failed${NC}"
    exit 1
fi

# Compress backup
echo ""
echo "🗜️  Compressing backup..."
if gzip "$BACKUP_FILE"; then
    BACKUP_FILE="${BACKUP_FILE}.gz"
    echo -e "${GREEN}✅ Backup compressed${NC}"
else
    echo -e "${RED}❌ Compression failed${NC}"
    exit 1
fi

# Get backup size
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "Backup size: $BACKUP_SIZE"

# Verify backup is not empty
FILE_SIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE")
if [ "$FILE_SIZE" -lt 100 ]; then
    echo -e "${RED}❌ Error: Backup file is too small ($FILE_SIZE bytes)${NC}"
    echo "This indicates the backup may have failed"
    exit 1
fi

echo -e "${GREEN}✅ Backup verified (size: $FILE_SIZE bytes)${NC}"

# Clean up old backups
echo ""
echo "🧹 Cleaning up old backups..."

# Clean daily backups older than RETENTION_DAYS
echo "Removing daily backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR/daily" -name "*.gz" -mtime +$RETENTION_DAYS -delete
DAILY_COUNT=$(find "$BACKUP_DIR/daily" -name "*.gz" | wc -l)
echo "Daily backups remaining: $DAILY_COUNT"

# Clean weekly backups older than RETENTION_WEEKS weeks
echo "Removing weekly backups older than $RETENTION_WEEKS weeks..."
find "$BACKUP_DIR/weekly" -name "*.gz" -mtime +$((RETENTION_WEEKS * 7)) -delete
WEEKLY_COUNT=$(find "$BACKUP_DIR/weekly" -name "*.gz" | wc -l)
echo "Weekly backups remaining: $WEEKLY_COUNT"

# Clean monthly backups older than RETENTION_MONTHS months
echo "Removing monthly backups older than $RETENTION_MONTHS months..."
find "$BACKUP_DIR/monthly" -name "*.gz" -mtime +$((RETENTION_MONTHS * 30)) -delete
MONTHLY_COUNT=$(find "$BACKUP_DIR/monthly" -name "*.gz" | wc -l)
echo "Monthly backups remaining: $MONTHLY_COUNT"

# Calculate total backup size
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

echo ""
echo "============================================"
echo "   Backup Summary"
echo "============================================"
echo -e "Status: ${GREEN}SUCCESS${NC}"
echo "Type: $BACKUP_TYPE"
echo "File: $(basename $BACKUP_FILE)"
echo "Size: $BACKUP_SIZE"
echo "Location: $BACKUP_SUBDIR"
echo ""
echo "📊 Retention Summary:"
echo "  Daily: $DAILY_COUNT backups"
echo "  Weekly: $WEEKLY_COUNT backups"
echo "  Monthly: $MONTHLY_COUNT backups"
echo "  Total size: $TOTAL_SIZE"
echo ""
echo "✅ Backup completed successfully!"
