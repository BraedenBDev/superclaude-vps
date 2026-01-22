#!/bin/bash

# SuperClaude Backup Script
# Creates timestamped backups of important files

BACKUP_DIR=~/backups
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="superclaude_backup_${TIMESTAMP}.tar.gz"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Creating backup: $BACKUP_NAME"

# Files and directories to backup
tar -czf "$BACKUP_DIR/$BACKUP_NAME" \
    --exclude='node_modules' \
    --exclude='__pycache__' \
    --exclude='.git' \
    --exclude='*.log' \
    --exclude='models/*.bin' \
    ~/.env \
    ~/.claude/ \
    ~/.superclaude/ \
    ~/projects/ \
    ~/superclaude-vps/.env \
    2>/dev/null || true

# Keep only last 7 backups
cd "$BACKUP_DIR"
ls -t superclaude_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs -I {} rm {} 2>/dev/null || true

echo "Backup complete: $BACKUP_DIR/$BACKUP_NAME"
echo "Size: $(du -h "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)"

# Optional: Upload to remote storage
# Example with rclone (uncomment and configure if needed)
# if command -v rclone &> /dev/null; then
#     echo "Uploading to remote storage..."
#     rclone copy "$BACKUP_DIR/$BACKUP_NAME" remote:backups/
#     echo "Upload complete"
# fi