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
