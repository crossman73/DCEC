#!/bin/bash
# Restore script for NAS Docker Development Environment
# This script restores the NAS Docker environment from a backup.

set -euo pipefail

# ===========================================
# Configuration
# ===========================================
BACKUP_DIR="/volume1/docker/backup"

# ===========================================
# Restore Function
# ===========================================
restore_backup() {
    if [ -z "${1:-}" ]; then
        echo "Usage: $0 <backup_date>"
        echo "Please provide the backup date in the format YYYYMMDD_HHMMSS."
        exit 1
    fi

    BACKUP_DATE="$1"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_DATE"

    if [ ! -d "$BACKUP_PATH" ]; then
        echo "Backup not found: $BACKUP_PATH"
        exit 1
    fi

    echo "Restoring from backup: $BACKUP_PATH"

    # Restore configurations
    cp -r "$BACKUP_PATH/config"/* /volume1/docker/dev/config/
    cp "$BACKUP_PATH/docker-compose.yml" /volume1/docker/dev/
    cp "$BACKUP_PATH/.env" /volume1/docker/dev/

    # Restore data
    rsync -av "$BACKUP_PATH/data/" /volume1/docker/dev/data/

    echo "Restore completed successfully."
}

# ===========================================
# Main Function
# ===========================================
main() {
    echo "=========================================="
    echo "NAS Docker Development Environment Restore"
    echo "=========================================="

    restore_backup "$@"
}

# ===========================================
# Script Execution
# ===========================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi