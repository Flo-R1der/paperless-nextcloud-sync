#!/bin/bash

# Set local Variables for full UTF-8 support
if [[ $LC_ALL != "en_US.UTF-8" ]]; then
  locale-gen "${LC_ALL}"
fi
if [[ $LANG != "en_US.UTF-8" ]]; then
  update-locale LANG="$LANG"
fi

# Check mandatory variables and store them to secrets file
if [[ -z "${WEBDRIVE_USER}" ]]; then
  echo "[ERROR] WEBDRIVE_USER is not set!"
  exit 1
fi

if [[ -n "${WEBDRIVE_PASSWORD_FILE}" ]]; then
    WEBDRIVE_PASSWORD=$(read "${WEBDRIVE_PASSWORD_FILE}")
fi
if [[ -z "${WEBDRIVE_PASSWORD}" ]]; then
  echo "[ERROR] WEBDRIVE_PASSWORD is not set!"
    exit 1
fi

if [[ -z "${WEBDRIVE_URL}" ]]; then
  echo "[ERROR] WEBDRIVE_URL is not set!"
  exit 1
fi

echo "\"$WEBDRIVE_URL\" \"$WEBDRIVE_USER\" \"$WEBDRIVE_PASSWORD\"" > /etc/davfs2/secrets

# Set optional variables
DIR_USER=${SYNC_USERID:-0}
DIR_GROUP=${SYNC_GROUPID:-0}
ACCESS_DIR=${SYNC_ACCESS_DIR:-755}
ACCESS_FILE=${SYNC_ACCESS_FILE:-755}
SOURCE_DIR="/mnt/source"
WEBDRIVE_DIR="/mnt/webdrive"

# Create user
if [ $DIR_USER -gt 0 ]; then
  useradd webdrive -u $DIR_USER -N -G $DIR_GROUP
fi

# Mount the webdav drive 
echo "[INFO] WEBDRIVE_URL: $WEBDRIVE_URL"
echo "[INFO] WEBDRIVE_USER: $WEBDRIVE_USER"
if [ -f "/var/run/mount.davfs/mnt-webdrive.pid" ]; then
  rm /var/run/mount.davfs/mnt-webdrive.pid
fi
mount -t davfs "$WEBDRIVE_URL" /mnt/webdrive -v \
  -o uid="$DIR_USER",gid="$DIR_GROUP",dir_mode="$ACCESS_DIR",file_mode="$ACCESS_FILE"
if [ $? -ne 0 ]; then
  echo "[ERROR] Failed to mount $WEBDRIVE_URL"
  echo "[ERROR] Please check your credentials or URL."
  exit 1
fi


# Trap signals (SIGTERM, SIGINT) and pass them to child processes
function container_exit() {
  SIGNAL=$1
  echo "[WARNING] Received $SIGNAL, ending processes..."
  while $(kill -$SIGNAL $(jobs -p) 2>/dev/null); do
    sleep 3
  done
  wait
  exit 0
}
trap "container_exit SIGTERM" SIGTERM
trap "container_exit SIGINT" SIGINT


echo "[INFO] Start completed. Start initial synchronization and file watcher"
echo "===================================================================================================="


# start the initial synchronization as background job
# this script prints output in container logs, when finished
# usage sync_full.sh: $1 = source | $2 = destination | $3 = reason
/bin/bash sync_full.sh "$SOURCE_DIR" "$WEBDRIVE_DIR" "container-start" &


# setting up file watcher and actions for for high-performance instant synchronization per-event
# supports renaming and file-move, to preserve existing files in Nextcloud (instead of delete+recreate)
/bin/bash sync_live.sh "$SOURCE_DIR" "$WEBDRIVE_DIR" &


wait
