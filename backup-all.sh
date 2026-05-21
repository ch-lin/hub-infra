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

# 1. Lock the script directory (ensure relative paths are correct regardless of execution location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration using the shared helper script
source "${SCRIPT_DIR}/_load-config.sh" "$@"

# Shift arguments if a config file was passed to the helper
if [[ $# -gt 0 ]] && [[ "$1" == *.conf ]]; then
    shift
fi

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

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