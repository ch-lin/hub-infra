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

CONFIG_FILE="${SCRIPT_DIR}/local.conf"

# Auto-detect ds720 environment
if hostname | grep -q -i "ds720"; then
    CONFIG_FILE="${SCRIPT_DIR}/ds720.conf"
fi

# Check if the first argument is a .conf file
if [[ $# -gt 0 ]] && [[ "$1" == *.conf ]]; then
    CONFIG_FILE="$1"
    shift
fi

# ==============================================================================
# Load Configuration with Validation
# ==============================================================================
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading configuration from ${CONFIG_FILE}..."
    source "$CONFIG_FILE"
else
    echo -e "\033[0;31mError: Configuration file '$CONFIG_FILE' not found.\033[0m"
    echo "----------------------------------------------------------------"
    echo "Please create a configuration file based on the example:"
    echo "  cp local.conf.example local.conf"
    echo "  vi local.conf  # Edit paths and settings"
    echo "----------------------------------------------------------------"
    exit 1
fi

# Validate Required Variables
: "${PROJECT:?Variable PROJECT is not set in $CONFIG_FILE}"

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# Helper function to run commands with sudo if PW is set
run_priv() {
    if [[ -z "${PW:-}" ]]; then
        "$@"
    else
        echo "${PW}" | sudo -S "$@"
    fi
}

DO_AUTH=false
DO_YOUTUBE=false
DO_DOWNLOADER=false
DO_UI=false
DO_S3=false

if [ $# -eq 0 ]; then
  set -- "all"
fi

for arg in "$@"; do
  case "${arg}" in
    auth) DO_AUTH=true ;;
    youtube) DO_YOUTUBE=true ;;
    downloader) DO_DOWNLOADER=true ;;
    ui) DO_UI=true ;;
    s3) DO_S3=true ;;
    all)
      DO_AUTH=true
      DO_YOUTUBE=true
      DO_DOWNLOADER=true
      DO_UI=true
      DO_S3=true
      ;;
    help)
      echo "Usage: $0 {auth|youtube|downloader|ui|s3|all|help}"
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}"
      echo "Usage: $0 {auth|youtube|downloader|ui|s3|all|help}"
      exit 1
      ;;
  esac
done

echo "Initializing secrets..."
bash "${SCRIPT_DIR}/init-secrets.sh" --skip

if [[ "${DO_S3}" == "true" ]]; then
  echo "Running build.sh for S3 Object Storage with build environment: '${BUILD_ENV}'..."
  (cd "${PROJECT}/backing-services/object-storage" && run_priv bash build.sh "${BUILD_ENV}")
fi

if [[ "${DO_AUTH}" == "true" ]]; then
  echo "Running build.sh for Authentication Service with build environment: '${BUILD_ENV}'..."
  (cd "${PROJECT}/authentication-service" && run_priv bash build.sh "${BUILD_ENV}")
fi

if [[ "${DO_DOWNLOADER}" == "true" ]]; then
  echo "Running build.sh for Downloader with build environment: '${BUILD_ENV}'..."
  (cd "${PROJECT}/downloader" && run_priv bash build.sh "${BUILD_ENV}")
fi

if [[ "${DO_YOUTUBE}" == "true" ]]; then
  echo "Running build.sh for YouTube Hub with build environment: '${BUILD_ENV}'..."
  (cd "${PROJECT}/youtube-hub" && run_priv bash build.sh "${BUILD_ENV}")
fi

if [[ "${DO_UI}" == "true" ]]; then
  echo "Running build.sh for Hub UI with build environment: '${BUILD_ENV}'..."
  (cd "${PROJECT}/hub-ui" && run_priv bash build.sh "${BUILD_ENV}")
fi
