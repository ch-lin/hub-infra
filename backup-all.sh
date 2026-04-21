#!/bin/bash

# The MIT License (MIT)
#
# Copyright (c) 2025 Che-Hung Lin
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

CONFIG_FILE="local.conf"

# Auto-detect ds720 environment
if hostname | grep -q -i "ds720"; then
    CONFIG_FILE="ds720.conf"
fi

# Check if the first argument is a .conf file
if [[ $# -gt 0 ]] && [[ "$1" == *.conf ]]; then
    CONFIG_FILE="$1"
    shift
fi

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading configuration from ${CONFIG_FILE}..."
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file '$CONFIG_FILE' not found."
    exit 1
fi

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# Helper function to run commands with sudo if PW is set
run_priv() {
    if [[ -z "${PW}" ]]; then
        "$@"
    else
        echo "${PW}" | sudo -S "$@"
    fi
}

# Define BACKUP_DIR relative to PROJECT dir
BACKUP_DIR="$(dirname "${PROJECT}")/Backups"

DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
run_priv mkdir -p "${BACKUP_DIR}"

echo "Stopping containers..."
if [ -d "${PROJECT}/authentication-service" ]; then
  cd "${PROJECT}/authentication-service" && run_priv docker compose stop
fi

if [ -d "${PROJECT}/youtube-hub" ]; then
  cd "${PROJECT}/youtube-hub" && run_priv docker compose stop
fi

if [ -d "${PROJECT}/downloader" ]; then
  cd "${PROJECT}/downloader" && run_priv docker compose stop
fi

if [ -d "${PROJECT}/hub-ui" ]; then
  cd "${PROJECT}/hub-ui" && run_priv docker compose stop
fi

echo "Backing up database data..."
if [ -d "${DOCKER_AUTH_DB}" ]; then
  run_priv tar -czf "${BACKUP_DIR}/auth_db_${DATE}.tar.gz" -C "$(dirname "${DOCKER_AUTH_DB}")" "$(basename "${DOCKER_AUTH_DB}")"
fi

if [ -d "${DOCKER_DOWNLOADER_DB}" ]; then
  run_priv tar -czf "${BACKUP_DIR}/downloader_db_${DATE}.tar.gz" -C "$(dirname "${DOCKER_DOWNLOADER_DB}")" "$(basename "${DOCKER_DOWNLOADER_DB}")"
fi

if [ -d "${DOCKER_YOUTUBE_HUB_DB}" ]; then
  run_priv tar -czf "${BACKUP_DIR}/youtube_hub_db_${DATE}.tar.gz" -C "$(dirname "${DOCKER_YOUTUBE_HUB_DB}")" "$(basename "${DOCKER_YOUTUBE_HUB_DB}")"
fi

# Change ownership of backups to current user if sudo was used
if [[ -n "${PW}" ]]; then
    echo "Changing ownership of backup files..."
    run_priv chown "$(id -u):$(id -g)" "${BACKUP_DIR}"/*.tar.gz
fi

echo "Starting containers..."
if [ -d "${PROJECT}/authentication-service" ]; then
  cd "${PROJECT}/authentication-service" && run_priv docker compose start
fi

if [ -d "${PROJECT}/youtube-hub" ]; then
  cd "${PROJECT}/youtube-hub" && run_priv docker compose start
fi

if [ -d "${PROJECT}/downloader" ]; then
  cd "${PROJECT}/downloader" && run_priv docker compose start
fi

if [ -d "${PROJECT}/hub-ui" ]; then
  cd "${PROJECT}/hub-ui" && run_priv docker compose start
fi

echo "Backup completed. Files are in ${BACKUP_DIR}"