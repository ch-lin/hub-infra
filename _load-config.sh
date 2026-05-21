#!/bin/bash

# The MIT License (MIT)
#
# Copyright (c) 2025 Che-Hung Lin
#
# This script is intended to be sourced by other scripts and is not executable on its own.
# It standardizes the loading of configuration files, providing robust path resolution
# and auto-creation of default configurations for a seamless first-time user experience.

# ==============================================================================
# Color Settings
# ==============================================================================
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# This script assumes SCRIPT_DIR has been set by the calling script.
if [ -z "${SCRIPT_DIR:-}" ]; then
    echo -e "${RED}Error: SCRIPT_DIR is not set. This script must be sourced from another script.${NC}"
    exit 1
fi

CONFIG_FILE="${SCRIPT_DIR}/local.conf"
EXAMPLE_CONFIG_FILE="${CONFIG_FILE}.example"

# Auto-detect ds720 environment
if hostname | grep -q -i "ds720"; then
    CONFIG_FILE="${SCRIPT_DIR}/ds720.conf"
    EXAMPLE_CONFIG_FILE="${CONFIG_FILE}.example"
fi

# Allow overriding config file via command-line argument
if [[ $# -gt 0 ]] && [[ "$1" == *.conf ]]; then
    CONFIG_FILE="$1"
    # Do not auto-create if a specific file is passed
    EXAMPLE_CONFIG_FILE=""
fi

# ==============================================================================
# Load Configuration with Auto-Creation Fallback
# ==============================================================================
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}⚠️  Configuration file '$CONFIG_FILE' not found.${NC}"

    if [ -f "$EXAMPLE_CONFIG_FILE" ]; then
        echo "   -> Found '$EXAMPLE_CONFIG_FILE', creating a default configuration for you..."
        cp "$EXAMPLE_CONFIG_FILE" "$CONFIG_FILE"

        # Automatically configure default paths
        user_home="${HOME}"
        project_root="$(dirname "$SCRIPT_DIR")"
        # Place docker data inside the project workspace for better encapsulation
        docker_data_path="${project_root}/.docker-data"

        # Use '|' as a separator for sed to handle paths with slashes gracefully
        # The -i '' is for macOS compatibility.
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "s|^HOME=.*|HOME=\"${user_home}\"|" "$CONFIG_FILE"
            sed -i '' "s|^PROJECT=.*|PROJECT=\"${project_root}\"|" "$CONFIG_FILE"
            sed -i '' "s|^DOCKER_DATA=.*|DOCKER_DATA=\"${docker_data_path}\"|" "$CONFIG_FILE"
        else # Linux
            sed -i "s|^HOME=.*|HOME=\"${user_home}\"|" "$CONFIG_FILE"
            sed -i "s|^PROJECT=.*|PROJECT=\"${project_root}\"|" "$CONFIG_FILE"
            sed -i "s|^DOCKER_DATA=.*|DOCKER_DATA=\"${docker_data_path}\"|" "$CONFIG_FILE"
        fi

        echo -e "${GREEN}✅ Successfully created '$CONFIG_FILE' with default paths.${NC}"
        echo -e "${YELLOW}👉 IMPORTANT: Please review the auto-generated paths in '$CONFIG_FILE' to ensure they are correct for your system.${NC}"
    else
        echo -e "${RED}Error: Configuration file '$CONFIG_FILE' not found.${NC}"
        echo "----------------------------------------------------------------"
        echo "Please create a configuration file based on the example:"
        echo "  cp local.conf.example local.conf"
        echo "  vi local.conf  # Edit paths and settings"
        echo "----------------------------------------------------------------"
        exit 1
    fi
fi

echo "Loading configuration from ${CONFIG_FILE}..."
source "$CONFIG_FILE"

# ==============================================================================
# Helper Functions
# ==============================================================================
# Helper function to run commands with sudo if PW is set
run_priv() {
    if [[ -z "${PW:-}" ]]; then
        "$@"
    else
        echo "${PW}" | sudo -S "$@"
    fi
}

# ==============================================================================
# Validate Required Variables
# ==============================================================================
if [ -z "${HOME:-}" ]; then
    echo -e "${RED}❌ Error: Variable HOME is not set in '$CONFIG_FILE'.${NC}"
    exit 1
fi

if [ ! -d "$HOME" ]; then
    echo -e "${RED}❌ Error: HOME directory '$HOME' does not exist.${NC}"
    echo -e "   Please check the HOME path setting in '$CONFIG_FILE'."
    exit 1
fi

if [ -z "${PROJECT:-}" ]; then
    echo -e "${RED}❌ Error: Variable PROJECT is not set in '$CONFIG_FILE'.${NC}"
    exit 1
fi

if [ ! -d "$PROJECT" ]; then
    echo -e "${RED}❌ Error: PROJECT directory '$PROJECT' does not exist.${NC}"
    echo -e "   Please check the PROJECT path setting in '$CONFIG_FILE'."
    exit 1
fi

if [ -z "${DOCKER_DATA:-}" ]; then
    echo -e "${RED}❌ Error: Variable DOCKER_DATA is not set in '$CONFIG_FILE'.${NC}"
    exit 1
fi

if [ ! -d "$DOCKER_DATA" ]; then
    echo -e "${YELLOW}⚠️  DOCKER_DATA directory '$DOCKER_DATA' does not exist. Attempting to create it...${NC}"
    run_priv mkdir -p "$DOCKER_DATA" || {
        echo -e "${RED}❌ Error: Failed to create DOCKER_DATA directory '$DOCKER_DATA'. Please check permissions or create it manually.${NC}"
        exit 1
    }
fi
