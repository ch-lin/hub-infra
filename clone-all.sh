#!/bin/bash

# CloneAll.sh
# Helper script to setup the poly-repo workspace structure.
# This script clones all microservices into the parent directory.

# 1. Lock the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "${SCRIPT_DIR}")"

echo "📦 Setting up Hub Workspace..."
echo "📂 Workspace Root: ${WORKSPACE_ROOT}"
echo "---------------------------------------------------"

# Helper function
clone_if_missing() {
    local DIR=$1
    local URL=$2
    local TARGET_PATH="${WORKSPACE_ROOT}/${DIR}"
    
    if [ ! -d "$TARGET_PATH" ]; then
        echo "⬇️  Cloning $DIR..."
        git clone "$URL" "$TARGET_PATH"
    else
        echo "✅ $DIR already exists."
    fi
}

# Clone Repositories
# Note: Folder names must match what build-all.sh expects.
clone_if_missing "authentication-service" "https://github.com/ch-lin/authentication-service.git"
clone_if_missing "downloader" "https://github.com/ch-lin/downloader.git"
clone_if_missing "platform" "https://github.com/ch-lin/platform.git"
clone_if_missing "youtube-hub" "https://github.com/ch-lin/youtube-hub.git"
clone_if_missing "hub-ui" "https://github.com/ch-lin/hub-ui.git"
clone_if_missing "backing-services" https://github.com/ch-lin/backing-services.git

echo "---------------------------------------------------"
echo "🎉 Workspace setup complete."
echo "👉 You can now configure 'local.conf' and run './build-all.sh'."
