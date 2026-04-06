#!/bin/bash

source /functions.sh

init_logging
container_exit
trap "container_exit SIGTERM" SIGTERM
trap "container_exit SIGINT" SIGINT

check_mandatory_vars
set_optional_vars

generate_locale
setup_timezone
init_cron
persist_env

create_user
mount_webdrive


log_info "Start completed. Start initial synchronization and file watcher"
echo "===================================================================================================="


# start the initial synchronization as background job
# this script prints output in container logs, when finished
# usage sync_full.sh: $1 = source | $2 = destination | $3 = reason
bash sync_full.sh "$SOURCE_DIR" "$WEBDRIVE_DIR" "container-start" &


# setting up file watcher and actions for for high-performance instant synchronization per-event
# supports renaming and file-move, to preserve existing files in Nextcloud (instead of delete+recreate)
bash sync_live.sh "$SOURCE_DIR" "$WEBDRIVE_DIR" &


wait
