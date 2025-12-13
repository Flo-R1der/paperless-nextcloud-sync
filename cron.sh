#!/bin/bash

# Usage:      cron.sh COMMAND
# Example 1:  cron.sh full-sync
# Example 2:  cron.sh cleanup-logs


# Logging
function log () {
    echo "$(date +%Y-%m-%d) $(date +%H:%M:%S) $1"
}
exec >> /var/log/cron.log
exec 2>&1
log "[INFO] Received \"$1\" Command"

# Set/Load environment variables
function setup_environment() {
    SOURCE_DIR="/mnt/source"
    WEBDRIVE_DIR="/mnt/webdrive"

    ENV_FILE="/etc/default/env"
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
        log "[DEBUG] Sourced env file: ${ENV_FILE:-<none>}"
        cat "$ENV_FILE"
    else
        log "[INFO] No Environment File found in $ENV_FILE"
    fi
}


# Working
case "$1" in
    full-sync)
        setup_environment
        log "[ACTION] Starting a full synchronization - Observe container-logs for results"
        /bin/bash /sync_full.sh "$SOURCE_DIR" "$WEBDRIVE_DIR" "scheduled-scan" &
        ;;
    cleanup-logs)
        setup_environment
        log "[ACTION] Delete Logfiles, older than $KEEP_LOGFILE_DAYS days"
        count=$(/usr/bin/find /var/log/ -name "*.log" -type f -mtime +$KEEP_LOGFILE_DAYS | wc -l)
        log "[INFO] found $count logfiles for deletation"
        if [ $count -gt 0 ]; then
            /usr/bin/find /var/log/ -name "*.log" -type f -mtime +$KEEP_LOGFILE_DAYS -exec rm -v {} \;
        fi
        ;;

    *)
        log "[ERROR] Command \"$1\" unknown; exiting cron script"
        ;;
esac

echo ""  # empty log line
