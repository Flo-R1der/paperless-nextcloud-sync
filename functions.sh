#!/bin/bash

# small logging helpers with optional ANSI colors
# Disable colors by setting NO_COLOR=1 or TERM=dumb
function init_logging() {
    if [[ -t 1 && -z "${NO_COLOR}" && "${TERM}" != "dumb" ]]; then
        RED='\033[0;31m'
        YELLOW='\033[0;33m'
        GREEN='\033[0;32m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        RESET='\033[0m'
    else
        RED=''
        YELLOW=''
        GREEN=''
        BLUE=''
        CYAN=''
        RESET=''
    fi

    LOGLEVEL=${LOGLEVEL:-3}  # Default log level is 3 (info)
    log_error() { printf "%b\n" "${RED}[ERROR] $*${RESET}" >&2; }
    log_warn() { # LOGLEVEL=1
        if (( $LOGLEVEL >= 1 )); then
            printf "%b\n" "${YELLOW}[WARNING] $*${RESET}"
        fi
    }
    log_action() { # LOGLEVEL=2
        if (( $LOGLEVEL >= 2 )); then
            printf "%b\n" "${BLUE}[ACTION] $*${RESET}"
        fi
    }
    log_info() { # LOGLEVEL=3
        if (( $LOGLEVEL >= 3 )); then
            printf "%b\n" "${GREEN}[INFO] $*${RESET}"
        fi
    }
    log_debug() { # LOGLEVEL=4
        if (( $LOGLEVEL >= 4 )); then
            printf "%b\n" "${CYAN}[DEBUG] $*${RESET}"
        fi
    }
    
    
}

# Run a command and control its output according to LOGLEVEL
# Usage: run_cmd <min_level> "command" cmd args...
# - If LOGLEVEL >= 4 (debug) the command is streamed live to stdout/stderr.
# - Otherwise the output is captured; it is printed only if LOGLEVEL >= min_level
#   or if the command fails (non-zero exit). On failure the captured output is shown.
function run_cmd() {
    local min_level=$1
    local command=$2
    local tmp
    tmp=$(mktemp) || tmp="/tmp/run_cmd.$$"
    # führt $2 aus und fängt stdout/stderr in $tmp
    "${@:2}" >"$tmp" 2>&1
    local rc=$?

    if (( rc != 0 )); then
        log_error "$command failed (rc=$rc)"
        while IFS= read -r line; do log_error "$line" >&2; done <"$tmp"
        rm -f "$tmp"
        return $rc
    fi

    case "$min_level" in
        [4]*)
            while IFS= read -r line; do log_debug "$line"; done <"$tmp"
            ;;
        [3]*)
            while IFS= read -r line; do log_info "$line"; done <"$tmp"
            ;;
        [2]*)
            while IFS= read -r line; do log_action "$line"; done <"$tmp"
            ;;
        [1]*)
            while IFS= read -r line; do log_warn "$line"; done <"$tmp"
            ;;
        *)
            while IFS= read -r line; do log_info "$line"; done <"$tmp"
            ;;
    esac
    rm -f "$tmp"
    return $rc
}

# Trap signals (SIGTERM, SIGINT) and pass them to child processes
function container_exit() {
  SIGNAL=$1
  log_error "Received $SIGNAL, ending processes..."
  while $(kill -$SIGNAL $(jobs -p) 2>/dev/null); do
    sleep 3
  done
  wait
  exit 0
}

# Check mandatory variables and store them to secrets file
function check_mandatory_vars() {
    if [[ -z "${WEBDRIVE_USER}" ]]; then
        log_error "WEBDRIVE_USER is not set!"
        exit 1
    fi

    if [[ -n "${WEBDRIVE_PASSWORD_FILE}" ]]; then
        WEBDRIVE_PASSWORD=$(read "${WEBDRIVE_PASSWORD_FILE}")
    fi
    if [[ -z "${WEBDRIVE_PASSWORD}" ]]; then
        log_error "WEBDRIVE_PASSWORD is not set!"
        exit 1
    fi

    if [[ -z "${WEBDRIVE_URL}" ]]; then
        log_error "WEBDRIVE_URL is not set!"
        exit 1
    fi

    echo "\"$WEBDRIVE_URL\" \"$WEBDRIVE_USER\" \"$WEBDRIVE_PASSWORD\"" > /etc/davfs2/secrets
}

# Set optional variables with defaults
function set_optional_vars() {
    DIR_USER=${DIR_USER:-0}
    DIR_GROUP=${DIR_GROUP:-0}
    ACCESS_DIR=${ACCESS_DIR:-755}
    ACCESS_FILE=${ACCESS_FILE:-755}
    SOURCE_DIR="/mnt/source"
    WEBDRIVE_DIR="/mnt/webdrive"
}

# Set local Variables for full UTF-8 support
function generate_locale() {
    if [[ $LC_ALL != "en_US.UTF-8" ]]; then
        log_action "Generating Locale: ${LC_ALL}"
        run_cmd 2 "locale-gen ${LC_ALL}"
    fi
    if [[ $LANG != "en_US.UTF-8" ]]; then
        run_cmd 2 "update-locale LANG=$LANG"
    fi
}

# Set timezone if TZ variable is set
function setup_timezone() {
    if [[ -n "${TZ}" ]]; then
        log_action "setting up Time-Zone: ${TZ}"
        run_cmd 2 "ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime"
        log_debug "symlink: /etc/localtime -> $(readlink -f /etc/localtime)"
        run_cmd 2 "dpkg-reconfigure -f noninteractive tzdata" dpkg-reconfigure -f noninteractive tzdata
    else
        log_info "Time-Zone Variable '$TZ' not set. using UTC as default."
    fi
}

# Initialize cron.log and start cron process
function init_cron() {
    touch /var/log/cron.log
    echo "" >> /var/log/cron.log    # empty log line
    echo "===== New Container Start: $(date +%Y-%m-%d) $(date +%H:%M:%S) =====" >> /var/log/cron.log
    # start cron in background; use run_cmd_bg so output obeys LOGLEVEL
    run_cmd 2 "cron &"
}

# Persist runtime environment for cron and other helpers (do NOT store secrets!)
function persist_env() {
    ENV_FILE="/etc/default/env"
    cat > "$ENV_FILE" <<EOF
SOURCE_DIR="${SOURCE_DIR}"
WEBDRIVE_DIR="${WEBDRIVE_DIR}"
WEBDRIVE_USER="${WEBDRIVE_USER}"
WEBDRIVE_URL="${WEBDRIVE_URL}"
KEEP_LOGFILE_DAYS=${KEEP_LOGFILE_DAYS:-90}
EOF
    run_cmd 2 "chmod 744 $ENV_FILE"
    log_debug "Wrote environment file: $ENV_FILE" && run_cmd 4 "cat $ENV_FILE"
}

# Create user if DIR_USER is set
function create_user() {
    if [ $DIR_USER -gt 0 ]; then
        run_cmd 2 "useradd webdrive uid=$DIR_USER" useradd webdrive -u $DIR_USER -N -G $DIR_GROUP
    fi
}

# Mount the WebDAV drive 
function mount_webdrive() {
    log_info "Connect to remote location as WebDAV-Webdrive"
    log_debug "WEBDRIVE_URL: $WEBDRIVE_URL"
    log_debug "WEBDRIVE_USER: $WEBDRIVE_USER"
    if [ -f "/var/run/mount.davfs/mnt-webdrive.pid" ]; then
      rm /var/run/mount.davfs/mnt-webdrive.pid > /dev/null 2>&1
    fi
        run_cmd 2 "mount -t davfs $WEBDRIVE_URL /mnt/webdrive -v \
            -o uid=$DIR_USER,gid=$DIR_GROUP,dir_mode=$ACCESS_DIR,file_mode=$ACCESS_FILE"
        local rc=$?
        if [ $rc -ne 0 ]; then
            log_error "Failed to mount $WEBDRIVE_URL"
            log_error "Please check your credentials or URL."
            exit 1
        fi
}

