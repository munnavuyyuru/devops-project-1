#!/bin/bash

# Resolve script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Setting up daily backups for project at $PROJECT_DIR"
echo ""

# Define cron job
CRON_JOB="0 2 * * * cd $PROJECT_DIR && $SCRIPT_DIR/backup-database.sh >> $PROJECT_DIR/backups/backup.log 2>&1"

echo "This cron job will run the backup every day at 2:00 AM:"
echo "  $CRON_JOB"
echo ""

# Ask for confirmation
read -p "Do you want to add this cron job? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Setup cancelled."
    exit 0
fi

# Add the cron job
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo ""
echo "✅ Cron job added successfully!"
echo ""
echo "Current backup-related cron jobs:"
crontab -l | grep backup-database.sh || echo "  No backup jobs found"

echo ""
echo "Backup logs will be stored in:"
echo "  $PROJECT_DIR/backups/backup.log"
echo "You can monitor logs with:"
echo "  tail -f $PROJECT_DIR/backups/backup.log"
