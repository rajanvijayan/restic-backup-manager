#!/bin/bash

# Configuration for Restic Backup Plugin

# Path to the restic repository
RESTIC_REPOSITORY="$CURRENT_DIR/../backup-source"

# Source directory to backup
BACKUP_SOURCE="$CURRENT_DIR/../public"

# Directory to download backups
DOWNLOAD_DIR="$CURRENT_DIR/../download"

# Uncomment and configure for S3 (Example)
# RESTIC_REPOSITORY=s3:s3.amazonaws.com/your-bucket-name
