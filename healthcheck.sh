#!/bin/bash

# Check if Webdrive is mounted
if findmnt -r /mnt/webdrive > /dev/null; then
  echo "WebDAV is mounted"
else
  echo "[ERROR] WebDAV is not mounted."
  exit 1
fi
echo " | "
# Check if `inotifywait` is still running
if pgrep -f "inotifywait" > /dev/null; then
  echo "Filewatcher is running"
else
  echo "[ERROR] Filewatcher is not running"
  exit 1
fi

exit 0
