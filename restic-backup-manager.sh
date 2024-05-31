#!/bin/bash

# Set the current directory
CURRENT_DIR=$(dirname "$0")

# Load configuration
source "$CURRENT_DIR/config.sh"

# Log file
LOG_FILE="$CURRENT_DIR/restic-backup.log"

# Password for the Restic repository
RESTIC_PASSWORD="Uj56#UUKas"

# Function to log messages
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}


# Function to initialize the repository
initialize_repo() {
    if [ ! -d "$RESTIC_REPOSITORY" ]; then
        log_message "Initializing the restic repository..."
        RESTIC_PASSWORD=$RESTIC_PASSWORD restic -r "$RESTIC_REPOSITORY" init 2>&1 | tee -a $LOG_FILE
        if [ $? -ne 0 ]; then
            log_message "Failed to initialize the restic repository."
            exit 1
        fi
    else
        log_message "Restic repository already initialized."
    fi
}

# Function to create a backup
create_backup() {
    initialize_repo
    log_message "Starting backup for $BACKUP_SOURCE..."
    RESTIC_PASSWORD=$RESTIC_PASSWORD restic -r "$RESTIC_REPOSITORY" backup "$BACKUP_SOURCE" 2>&1 | tee -a $LOG_FILE
    if [ $? -ne 0 ]; then
        log_message "Backup failed."
        exit 1
    else
        log_message "Backup completed successfully."
    fi
}

# Function to list snapshots
list_snapshots() {
    log_message "Listing restic snapshots..."
    SNAPSHOT_LIST=$(RESTIC_PASSWORD=$RESTIC_PASSWORD restic -r "$RESTIC_REPOSITORY" snapshots 2>&1)

    # Display snapshots with SNo
    SNAPSHOT_COUNT=$(echo "$SNAPSHOT_LIST" | grep -E '^\s*[a-f0-9]{8}' | wc -l)
    if [ $SNAPSHOT_COUNT -eq 0 ]; then
        log_message "No snapshots found."
        exit 1
    fi

    echo "$SNAPSHOT_LIST" | grep -E '^\s*[a-f0-9]{8}' | nl -w3 -s'. '
}

# Function to restore a backup
restore_backup() {
    list_snapshots
    read -p "Enter the SNo of the snapshot to restore: " SNAPSHOT_SNO

    if ! [[ "$SNAPSHOT_SNO" =~ ^[0-9]+$ ]] || [ "$SNAPSHOT_SNO" -lt 1 ] || [ "$SNAPSHOT_SNO" -gt "$SNAPSHOT_COUNT" ]; then
        log_message "Invalid SNo."
        exit 1
    fi

    SNAPSHOT_ID=$(RESTIC_PASSWORD=$RESTIC_PASSWORD restic -r "$RESTIC_REPOSITORY" snapshots --json | jq -r ".[$((SNAPSHOT_SNO - 1))].short_id")
    RESTORE_DIR="${BACKUP_SOURCE}/../"
    mkdir -p "$RESTORE_DIR"
    log_message "Starting restore from snapshot $SNAPSHOT_ID to $RESTORE_DIR..."
    RESTIC_PASSWORD=$RESTIC_PASSWORD restic -r "$RESTIC_REPOSITORY" restore "$SNAPSHOT_ID" --target "$RESTORE_DIR" 2>&1 | tee -a $LOG_FILE
    if [ $? -ne 0 ]; then
        log_message "Restore failed."
        exit 1
    else
        log_message "Restore completed successfully."
    fi
}

# Function to delete a snapshot
delete_snapshot() {
    log_message "Listing restic snapshots..."
    SNAPSHOT_LIST=$(RESTIC_PASSWORD=$RESTIC_PASSWORD restic -r "$RESTIC_REPOSITORY" snapshots 2>&1)

    # Display snapshots with SNo
    SNAPSHOT_COUNT=$(echo "$SNAPSHOT_LIST" | grep -E '^\s*[a-f0-9]{8}' | wc -l)
    if [ $SNAPSHOT_COUNT -eq 0 ]; then
        log_message "No snapshots found."
        exit 1
    fi

    echo "$SNAPSHOT_LIST" | grep -E '^\s*[a-f0-9]{8}' | nl -w3 -s'. '

    read -p "Enter the SNo of the snapshot to delete: " SNAPSHOT_SNO

    if ! [[ "$SNAPSHOT_SNO" =~ ^[0-9]+$ ]] || [ "$SNAPSHOT_SNO" -lt 1 ] || [ "$SNAPSHOT_SNO" -gt "$SNAPSHOT_COUNT" ]; then
        log_message "Invalid SNo."
        exit 1
    fi

    SNAPSHOT_ID=$(RESTIC_PASSWORD=$RESTIC_PASSWORD restic -r "$RESTIC_REPOSITORY" snapshots --json | jq -r ".[$((SNAPSHOT_SNO - 1))].short_id")

    log_message "Deleting snapshot $SNAPSHOT_ID..."
    RESTIC_PASSWORD=$RESTIC_PASSWORD restic -r "$RESTIC_REPOSITORY" forget "$SNAPSHOT_ID" --prune 2>&1 | tee -a $LOG_FILE
    if [ $? -ne 0 ]; then
        log_message "Delete failed."
        exit 1
    else
        log_message "Snapshot $SNAPSHOT_ID deleted successfully."
    fi
}

# Function to download a backup
download_backup() {
    list_snapshots
    read -p "Enter the SNo of the snapshot to download: " SNAPSHOT_SNO

    if ! [[ "$SNAPSHOT_SNO" =~ ^[0-9]+$ ]] || [ "$SNAPSHOT_SNO" -lt 1 ] || [ "$SNAPSHOT_SNO" -gt "$SNAPSHOT_COUNT" ]; then
        log_message "Invalid SNo."
        exit 1
    fi

    SNAPSHOT_ID=$(RESTIC_PASSWORD=$RESTIC_PASSWORD restic -r "$RESTIC_REPOSITORY" snapshots --json | jq -r ".[$((SNAPSHOT_SNO - 1))].short_id")
    log_message "Starting download from snapshot $SNAPSHOT_ID to $DOWNLOAD_DIR..."
    mkdir -p "$DOWNLOAD_DIR"
    RESTIC_PASSWORD=$RESTIC_PASSWORD restic -r "$RESTIC_REPOSITORY" restore "$SNAPSHOT_ID" --target "$DOWNLOAD_DIR" 2>&1 | tee -a $LOG_FILE
    if [ $? -ne 0 ]; then
        log_message "Download failed."
        exit 1
    fi

    ZIP_FILE="$DOWNLOAD_DIR/snapshot_$SNAPSHOT_ID.zip"
    log_message "Compressing downloaded backup to $ZIP_FILE..."
    cd "$DOWNLOAD_DIR" && zip -r "$ZIP_FILE" ./* 2>&1 | tee -a $LOG_FILE
    if [ $? -ne 0 ]; then
        log_message "Compression failed."
        exit 1
    else
        log_message "Download and compression completed successfully."
        # Remove all files except .zip files
        find "$DOWNLOAD_DIR" \( -type f ! -name "*.zip" \) -exec rm {} +

        # Remove all directories except for the root directory
        find "$DOWNLOAD_DIR" -mindepth 1 -type d -exec rm -rf {} +
    fi
}




# Main script
if [ $# -lt 1 ]; then
    echo "Usage: $0 {backup|restore|list|delete|download}"
    exit 1
fi

COMMAND=$1
shift

case "$COMMAND" in
    backup)
        create_backup
        ;;
    restore)
        restore_backup
        ;;
    list)
        list_snapshots
        ;;
    delete)
        delete_snapshot
        ;;
    download)
        download_backup
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo "Usage: $0 {backup|restore|list|delete|download}"
        exit 1
        ;;
esac
