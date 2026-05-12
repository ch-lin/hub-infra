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

# Validate critical variables to prevent 'rm -rf /' accidents
: "${PROJECT:?PROJECT not set in config}"
: "${DOCKER_AUTH_DB:?DOCKER_AUTH_DB not set in config}"
: "${DOCKER_DOWNLOADER_DB:?DOCKER_DOWNLOADER_DB not set in config}"
: "${DOCKER_YOUTUBE_HUB_DB:?DOCKER_YOUTUBE_HUB_DB not set in config}"

# ==============================================================================
# User Guide & Usage Combinations
# ==============================================================================
# This script cleans up Docker resources and optionally deletes database files.
#
# Scopes:
#   auth       - Apply actions only to Authentication Service.
#   youtube    - Apply actions only to YouTube Hub (and Downloader).
#   downloader - Apply actions only to Downloader.
#   ui         - Apply actions only to YouTube Hub UI.
#   s3         - Apply actions only to S3 Object Storage.
#   (default)  - If neither is specified, actions apply to BOTH.
#
# Actions:
#   backend    - Clean backend resources (images, containers).
#   ui         - Clean UI resources.
#   downloader - Clean downloader resources.
#   db         - Stop database containers.
#   delete-db  - Delete actual database files on disk (requires stopping db).
#   all        - Clean everything (default action).
#
# Common Combinations:
#   ./clean-all.sh                   -> Cleans all resources for both services.
#   ./clean-all.sh delete-db         -> Stops DBs and deletes ALL database files.
#   ./clean-all.sh auth delete-db    -> Stops Auth DB and deletes ONLY Auth DB files.
#   ./clean-all.sh youtube delete-db -> Stops YouTube DBs and deletes ONLY YouTube DB files.
#   ./clean-all.sh downloader delete-db -> Stops Downloader DB and deletes ONLY Downloader DB files.
#   ./clean-all.sh auth backend      -> Cleans backend resources for Auth Service only.
# ==============================================================================

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

DELETE_FILES=false
SCOPE_AUTH=false
SCOPE_YOUTUBE=false
SCOPE_DOWNLOADER=false
SCOPE_UI=false
SCOPE_S3=false
ARGS_FOR_SUBSCRIPTS=""

if [ $# -eq 0 ]; then
  set -- "all"
fi

for arg in "$@"; do
  if [[ "${arg}" == "delete-db" ]]; then
    DELETE_FILES=true
  elif [[ "${arg}" == "auth" ]]; then
    SCOPE_AUTH=true
  elif [[ "${arg}" == "youtube" ]]; then
    SCOPE_YOUTUBE=true
  elif [[ "${arg}" == "downloader" ]]; then
    SCOPE_DOWNLOADER=true
  elif [[ "${arg}" == "ui" ]]; then
    SCOPE_UI=true
  elif [[ "${arg}" == "s3" ]]; then
    SCOPE_S3=true
  elif [[ "${arg}" == "help" ]]; then
    echo "Usage: $0 {auth|youtube|downloader|ui|s3|backend|db|apps|all|delete-db|help} [more args...]"
    exit 0
  else
    ARGS_FOR_SUBSCRIPTS="${ARGS_FOR_SUBSCRIPTS} ${arg}"
  fi
done

# Default to both if neither specified
if [[ "${SCOPE_AUTH}" == "false" ]] && [[ "${SCOPE_YOUTUBE}" == "false" ]] && [[ "${SCOPE_DOWNLOADER}" == "false" ]] && [[ "${SCOPE_UI}" == "false" ]] && [[ "${SCOPE_S3}" == "false" ]]; then
  SCOPE_AUTH=true
  SCOPE_YOUTUBE=true
  SCOPE_DOWNLOADER=true
  SCOPE_UI=true
  SCOPE_S3=true
fi

# If delete-db is requested, ensure 'db' target is included to stop containers
if [[ "${DELETE_FILES}" == "true" ]]; then
  if [[ "${ARGS_FOR_SUBSCRIPTS}" != *"all"* ]] && [[ "${ARGS_FOR_SUBSCRIPTS}" != *"db"* ]]; then
    ARGS_FOR_SUBSCRIPTS="${ARGS_FOR_SUBSCRIPTS} db"
  fi
fi

# Trim leading space
ARGS_FOR_SUBSCRIPTS="${ARGS_FOR_SUBSCRIPTS## }"

AUTH_ARGS=""
YOUTUBE_ARGS=""
DOWNLOADER_ARGS=""
UI_ARGS=""
S3_ARGS=""

if [[ -z "${ARGS_FOR_SUBSCRIPTS}" ]]; then
  if [[ "${SCOPE_AUTH}" == "true" ]]; then
    AUTH_ARGS="backend db"
  fi
  if [[ "${SCOPE_YOUTUBE}" == "true" ]]; then
    YOUTUBE_ARGS="backend db"
  fi
  if [[ "${SCOPE_DOWNLOADER}" == "true" ]]; then
    DOWNLOADER_ARGS="backend db"
  fi
  if [[ "${SCOPE_UI}" == "true" ]]; then
    UI_ARGS="all"
  fi
  if [[ "${SCOPE_S3}" == "true" ]]; then
    S3_ARGS="all"
  fi
else
  # Prepare arguments for specific services
  # Authentication Service does not have ui or downloader
  for arg in ${ARGS_FOR_SUBSCRIPTS}; do
    if [[ "${arg}" != "ui" ]] && [[ "${arg}" != "downloader" ]]; then
      AUTH_ARGS="${AUTH_ARGS} ${arg}"
    fi
    if [[ "${arg}" != "downloader" ]] && [[ "${arg}" != "ui" ]]; then
      YOUTUBE_ARGS="${YOUTUBE_ARGS} ${arg}"
    fi
    if [[ "${arg}" != "ui" ]]; then
      DOWNLOADER_ARGS="${DOWNLOADER_ARGS} ${arg}"
    fi
    if [[ "${arg}" == "ui" ]] || [[ "${arg}" == "all" ]]; then
      UI_ARGS="${UI_ARGS} ${arg}"
    fi
    if [[ "${arg}" == "all" ]]; then
      S3_ARGS="${S3_ARGS} ${arg}"
    fi
  done
  AUTH_ARGS="${AUTH_ARGS## }"
  YOUTUBE_ARGS="${YOUTUBE_ARGS## }"
  DOWNLOADER_ARGS="${DOWNLOADER_ARGS## }"
  UI_ARGS="${UI_ARGS## }"
  S3_ARGS="${S3_ARGS## }"
fi

if [[ "${SCOPE_S3}" == "true" ]] && [[ -n "${S3_ARGS}" ]]; then
  echo "Running clean.sh for S3 Object Storage..."
  (cd "${PROJECT}/backing-services/object-storage" && run_priv bash clean.sh ${S3_ARGS})
fi

if [[ "${SCOPE_UI}" == "true" ]] && [[ -n "${UI_ARGS}" ]]; then
  echo "Running clean.sh for Hub UI..."
  (cd "${PROJECT}/hub-ui" && run_priv bash clean.sh ${UI_ARGS})
fi

if [[ "${SCOPE_YOUTUBE}" == "true" ]] && [[ -n "${YOUTUBE_ARGS}" ]]; then
  echo "Running clean.sh for YouTube Hub..."
  (cd "${PROJECT}/youtube-hub" && run_priv bash clean.sh ${YOUTUBE_ARGS})
fi

if [[ "${SCOPE_DOWNLOADER}" == "true" ]] && [[ -n "${DOWNLOADER_ARGS}" ]]; then
  echo "Running clean.sh for Downloader..."
  (cd "${PROJECT}/downloader" && run_priv bash clean.sh ${DOWNLOADER_ARGS})
fi

if [[ "${SCOPE_AUTH}" == "true" ]] && [[ -n "${AUTH_ARGS}" ]]; then
  echo "Running clean.sh for Authentication Service..."
  (cd "${PROJECT}/authentication-service" && run_priv bash clean.sh ${AUTH_ARGS})
fi

if [[ "${DELETE_FILES}" == "true" ]]; then
  echo -e "\n\033[0;31mWARNING: You are about to delete all database data!\033[0m"
  read -p "Are you sure you want to continue? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deleting database data..."

    if [[ "${SCOPE_YOUTUBE}" == "true" ]]; then
      if [ -d "$DOCKER_YOUTUBE_HUB_DB" ]; then
         echo "Cleaning $DOCKER_YOUTUBE_HUB_DB ..."
         run_priv bash -c "rm -rf \"$DOCKER_YOUTUBE_HUB_DB\"/*"
      else
         echo "Skipping $DOCKER_YOUTUBE_HUB_DB (Not found)"
      fi
    fi

    if [[ "${SCOPE_DOWNLOADER}" == "true" ]]; then
      if [ -d "$DOCKER_DOWNLOADER_DB" ]; then
         echo "Cleaning $DOCKER_DOWNLOADER_DB ..."
         run_priv bash -c "rm -rf \"$DOCKER_DOWNLOADER_DB\"/*"
      else
         echo "Skipping $DOCKER_DOWNLOADER_DB (Not found)"
      fi
    fi
    
    if [[ "${SCOPE_AUTH}" == "true" ]]; then
      if [ -d "$DOCKER_AUTH_DB" ]; then
         echo "Cleaning $DOCKER_AUTH_DB ..."
         run_priv bash -c "rm -rf \"$DOCKER_AUTH_DB\"/*"
      else
         echo "Skipping $DOCKER_AUTH_DB (Not found)"
      fi
    fi
    echo "✅ Database files deleted."
  else
    echo "Deletion cancelled."
  fi
else
  echo "Database data preserved. Run with 'delete-db' to delete."
fi
