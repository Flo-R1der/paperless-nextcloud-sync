#!/bin/bash

# usage sync_live.sh: $1 = source | $2 = destination 

SOURCE_DIR="$1"
WEBDRIVE_DIR="$2"


inotifywait -m -r -e modify,create,delete,move --exclude '.*\.swp|.*\.tmp' "$SOURCE_DIR" --format '%e|%w%f' |
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
        /bin/bash sync_full.sh "$SOURCE_DIR" "$WEBDRIVE_DIR" "missed-events" &
        # usage sync_full.sh: $1 = source | $2 = destination | $3 = reason
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
done
