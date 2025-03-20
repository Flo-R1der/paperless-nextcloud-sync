#!/bin/bash

# Set local Variables for full UTF-8 support
if [[ $LC_ALL != "en_US.UTF-8" ]]; then
  locale-gen "${LC_ALL}"
fi

# Check mandatory variables and store them to secrets file
if [ -z ${WEBDRIVE_USER} ]; then
  echo "[ERROR] Webdrive user is not set!"
  exit 1
fi

if [ -n "${WEBDRIVE_PASSWORD_FILE}" ]; then
    WEBDRIVE_PASSWORD=$(read ${WEBDRIVE_PASSWORD_FILE})
fi
if [ -z ${WEBDRIVE_PASSWORD} ]; then
  echo "[ERROR] Webdrive password is not set!"
    exit 1
fi

if [ -z ${WEBDRIVE_URL} ]; then
  echo "[ERROR] Webdrive url is not set!"
  exit 1
fi

echo "$WEBDRIVE_URL $WEBDRIVE_USER $WEBDRIVE_PASSWORD" > /etc/davfs2/secrets

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
mount -t davfs "$WEBDRIVE_URL" /mnt/webdrive \
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
# usage sync.sh: $1 = source | $2 = destination | $3 = reason
/bin/bash sync.sh "$SOURCE_DIR" "$WEBDRIVE_DIR" "container-start" &


# setting up file watcher and actions for for high-performance instant synchronization per-event
# supports renaming and file-move, to preserve existing files in Nextcloud (instead of delete+recreate)
inotifywait -m -r -e modify,create,delete,move "$SOURCE_DIR" --format '%e|%w%f|%f' |
while IFS='|' read -r event full_path filename; do
  RELATIVE_PATH="${full_path/${SOURCE_DIR}\//''}"
  case "$event" in
    MODIFY|CREATE)
      echo "[ACTION] Detected $event-Event - Copying file: $filename"
      cp "$SOURCE_DIR/$RELATIVE_PATH" "$WEBDRIVE_DIR/$RELATIVE_PATH" --verbose
      ;;
    DELETE)
      echo "[ACTION] Detected $event-Event - Deleting file: $filename"
      rm "$WEBDRIVE_DIR/$RELATIVE_PATH" --verbose
      ;;
    CREATE,ISDIR)
      echo "[ACTION] Detected $event-Event - Creating directory: $RELATIVE_PATH"
      mkdir "$WEBDRIVE_DIR/$RELATIVE_PATH" --verbose
      ;;
    DELETE,ISDIR)
      echo "[ACTION] Detected $event-Event - Deleting directory: $RELATIVE_PATH"
      rm -d "$WEBDRIVE_DIR/$RELATIVE_PATH" --verbose
      ;;
    MOVED_FROM)
      echo "[INFO] Detected $event-Event - File moved: $RELATIVE_PATH"
      OLD_PATH_WEBDRIVE="$WEBDRIVE_DIR/$RELATIVE_PATH"
      ;;
    MOVED_TO)
      echo "[ACTION] Detected $event-Event - Moving file: $RELATIVE_PATH"
      NEW_PATH_WEBDRIVE="$WEBDRIVE_DIR/$RELATIVE_PATH"
      if [[ -n "$OLD_PATH_WEBDRIVE" && -f "$OLD_PATH_WEBDRIVE" ]]; then
          mv "$OLD_PATH_WEBDRIVE" "$NEW_PATH_WEBDRIVE" --verbose
      else
        if [[ ! -n "$OLD_PATH_WEBDRIVE" ]]; then
          echo "[WARNING] Variable \"OLD_PATH_WEBDRIVE\" not set! Copying as new file!"
        fi
        if [[ ! -f "$OLD_PATH_WEBDRIVE" ]]; then
          echo "[WARNING] File from MOVED_FROM event does not exist! Copying as new file!"
        fi
        cp "$SOURCE_DIR/$RELATIVE_PATH" "$WEBDRIVE_DIR/$RELATIVE_PATH" --verbose
        echo "[INFO] Start complete sync run to fix other potential failures"
        /bin/bash sync.sh "$SOURCE_DIR" "$WEBDRIVE_DIR" "missed-events" &
        # usage sync.sh: $1 = source | $2 = destination | $3 = reason
      fi
      unset OLD_PATH_WEBDRIVE
      unset NEW_PATH_WEBDRIVE
      ;;
    *)
      echo "[ERROR] Unknown $event-Event for $filename"
      echo "Full path: $full_path"
      ;;
  esac
  unset RELATIVE_PATH
done &
wait
