#!/bin/bash

# Check if Webdrive is mounted
if findmnt -r /mnt/webdrive > /dev/null; then
  echo "WebDAV: OK"
else
  echo "[ERROR] WebDAV: not mounted."
  exit 1
fi
echo " | "
# Check if `inotifywait` is still running
if pgrep -f "inotifywait" > /dev/null; then
  echo "Filewatcher: OK"
else
  echo "[ERROR] Filewatcher: process not found"
  exit 1
fi
echo " | "
# Check if `cron` is still running
if pgrep -f "cron" > /dev/null; then
  echo "Cron: OK"
else
  echo "[ERROR] Cron: process not found"
  exit 1
fi

exit 0
