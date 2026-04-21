#!/bin/bash

# CloneAll.sh
# Helper script to setup the poly-repo workspace structure.
# This script clones all microservices into the parent directory.

# Ensure we are in the script's directory
cd "$(dirname "$0")"

# Go to the workspace root (one level up)
cd ..

echo "📦 Setting up Hub Workspace..."
echo "📂 Workspace Root: $(pwd)"
echo "---------------------------------------------------"

# Helper function
clone_if_missing() {
    local DIR=$1
    local URL=$2
    if [ ! -d "$DIR" ]; then
        echo "⬇️  Cloning $DIR..."
        git clone "$URL" "$DIR"
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

echo "---------------------------------------------------"
echo "🎉 Workspace setup complete."
echo "👉 You can now configure 'local.conf' and run './build-all.sh'."
