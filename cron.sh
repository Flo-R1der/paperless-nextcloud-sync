#!/bin/bash

# Usage:      cron.sh COMMAND
# Example 1:  cron.sh full-sync
# Example 2:  cron.sh cleanup-logs


# Logging
exec >> /var/log/cron.log
exec 2>&1

# Variables
SOURCE_DIR="/mnt/source"
WEBDRIVE_DIR="/mnt/webdrive"
KEEP_LOGFILE_DAYS=${KEEP_LOGFILE_DAYS:-90}

# Functions
function log () {
    echo "$(date +%Y-%m-%d) $(date +%H:%M:%S) $1"
}


# Working
case "$1" in
    full-sync)
        log "[ACTION] \"$1\" Command: starting a full synchronization"
        log "[INFO] Observe container-logs for results"
        /bin/bash sync_full.sh "$SOURCE_DIR" "$WEBDRIVE_DIR" "scheduled-scan" &
        ;;
    cleanup-logs)
        log "[ACTION] \"$1\" Command: delete Logfiles, older than $KEEP_LOGFILE_DAYS days"
        count=$(/usr/bin/find /var/log/ -name *.log -type f -mtime +$KEEP_LOGFILE_DAYS | wc -l)
        log "[INFO] found $count logfiles for deletation"
        if [ $count -gt 0 ]; then
            /usr/bin/find /var/log/ -name *.log -type f -mtime +$KEEP_LOGFILE_DAYS -exec rm -v {} \;
        fi
        ;;

    *)
        log "[ERROR] Command \"$1\" not regognized; exiting cron script"
        ;;
esac

echo ""  # empty log line
