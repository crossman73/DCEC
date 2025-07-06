#!/bin/bash
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="/nas-docker-setup/backup/$BACKUP_DATE"

echo "Creating backup: $BACKUP_PATH"
mkdir -p "$BACKUP_PATH"

# Backup configurations
cp -r /nas-docker-setup/config "$BACKUP_PATH/"
cp /nas-docker-setup/docker/docker-compose.yml "$BACKUP_PATH/"
cp /nas-docker-setup/.env "$BACKUP_PATH/"

# Backup data (excluding large files)
rsync -av --exclude='*.log' /nas-docker-setup/data "$BACKUP_PATH/"

# Create archive
cd /nas-docker-setup/backup
tar -czf "nas-docker-backup-$BACKUP_DATE.tar.gz" "$BACKUP_DATE"
rm -rf "$BACKUP_DATE"

echo "Backup completed: nas-docker-backup-$BACKUP_DATE.tar.gz"

# Cleanup old backups (keep last 30 days)
find /nas-docker-setup/backup -name "nas-docker-backup-*.tar.gz" -mtime +30 -delete