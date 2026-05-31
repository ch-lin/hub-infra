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

# ==============================================================================
# 0. Load Configuration (local.conf / ds720.conf)
# ==============================================================================
# Lock script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration using the shared helper script
source "${SCRIPT_DIR}/_load-config.sh" "$@"

# Fallback for PROJECT if not set in config file
# This is now handled by the _load-config.sh script
if [ -z "${PROJECT:-}" ]; then
    PROJECT="$(dirname "$SCRIPT_DIR")"
fi

# ==============================================================================
# Set file paths (Using Absolute Paths based on PROJECT and SCRIPT_DIR)
# ==============================================================================
AUTH_ENV="${PROJECT}/authentication-service/.env"
HUB_ENV="${PROJECT}/youtube-hub/.env"
DOWNLOADER_ENV="${PROJECT}/downloader/.env"
S3_ENV="${PROJECT}/backing-services/object-storage/.env"
LOGGING_ENV="${PROJECT}/backing-services/central-logging/.env"
API_KEY_CONF="${SCRIPT_DIR}/youtube-api-key.conf"
USER_INFO_CONF="${SCRIPT_DIR}/user-info.conf"

# Use path from config, or default if not set
AUTH_CERTS_DIR="${HOST_AUTH_CERTS_PATH:-${PROJECT}/authentication-service/certs}"

# ==============================================================================
# Argument Parsing (--skip)
# ==============================================================================
SKIP_EXISTING=false
if [[ "$1" == "--skip" ]]; then
    SKIP_EXISTING=true
fi

# ==============================================================================
# Color Settings
# ==============================================================================
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# ==============================================================================
# Utility Functions
# ==============================================================================

generate_uuid() {
    uuidgen | tr '[:upper:]' '[:lower:]'
}

# Update or add .env variable
# Usage: update_env "file_path" "key" "value" "project_label"
update_env() {
    local file=$1
    local key=$2
    local value=$3
    local label=$4

    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ File not found: $file${NC}"
        return
    fi

    # 1. Prepare value for .env format (Escape backslashes, double quotes, and dollar signs)
    local env_val="${value//\\/\\\\}"
    env_val="${env_val//\"/\\\"}"
    env_val="${env_val//\$/\$\$}"

    # Check if variable exists
    if grep -q "^$key=" "$file"; then
        # Get current value (trim whitespace)
        local current_val=$(grep "^$key=" "$file" | cut -d '=' -f2- | xargs)

        # Logic: Whether to skip
        if [ "$SKIP_EXISTING" = true ] && [ ! -z "$current_val" ]; then
            echo -e "   [${GRAY}${label}${NC}] Skipped: $key (Value exists)"
        else
            # Overwrite (using Mac sed)
            # 2. Prepare value for sed replacement (Escape & and | and backslashes and $ again)
            local sed_val="${env_val//\\/\\\\}"
            sed_val="${sed_val//&/\\&}"
            sed_val="${sed_val//|/\\|}"
            sed_val="${sed_val//\$/\\$}"

            if [[ "$(uname)" == "Darwin" ]]; then
                sed -i '' "s|^$key=.*|$key=\"$sed_val\"|" "$file"
            else
                sed -i "s|^$key=.*|$key=\"$sed_val\"|" "$file"
            fi
            echo -e "   [${CYAN}${label}${NC}] Updated: $key"
        fi
    else
        # Append if not exists
        echo "$key=\"$env_val\"" >> "$file"
        echo -e "   [${GREEN}${label}${NC}] Added: $key"
    fi
}

# Helper function: Read value from file (for displaying correct info for Postman)
read_env_value() {
    local file=$1
    local key=$2
    grep "^$key=" "$file" | cut -d '=' -f2- | xargs
}

echo -e "\n${YELLOW}🛠️  Starting initialization of Project Secrets & Certificates...${NC}"
echo -e "   Config Source: ${CYAN}${CONFIG_FILE}${NC}"
echo -e "   Certs Path:    ${CYAN}${AUTH_CERTS_DIR}${NC}\n"

if [ "$SKIP_EXISTING" = true ]; then
    echo -e "${GRAY}(Mode: Keep existing values, fill missing only)${NC}\n"
else
    echo -e "${GRAY}(Mode: Force overwrite all values)${NC}\n"
fi

# Check files
if [ ! -f "$AUTH_ENV" ] || [ ! -f "$HUB_ENV" ] || [ ! -f "$DOWNLOADER_ENV" ] || [ ! -f "$S3_ENV" ] || [ ! -f "$LOGGING_ENV" ]; then
    echo -e "${RED}❌ Error: Target .env files not found.${NC}"
    exit 1
fi

# ==============================================================================
# 0. Set Host Path Variables
# ==============================================================================
# We need to write paths determined by local.conf into .env so docker-compose can read them
echo "----------------------------------------------------------------"
echo -e "📂 0. Sync ${YELLOW}Host Paths${NC}"
echo "----------------------------------------------------------------"
# Write AUTH_CERTS_HOST_PATH to Auth Service .env
update_env "$AUTH_ENV" "AUTH_CERTS_HOST_PATH" "$AUTH_CERTS_DIR" "Auth"

# ==============================================================================
# 0.5. Set Admin User Info
# ==============================================================================
echo "----------------------------------------------------------------"
echo -e "👤 0.5. Set ${YELLOW}Admin User Info${NC}"
echo "----------------------------------------------------------------"

if [ -f "$USER_INFO_CONF" ]; then
    # Load user-info.conf
    source "$USER_INFO_CONF"

    [ ! -z "$USER_FIRSTNAME" ] && update_env "$AUTH_ENV" "INIT_ADMIN_FIRSTNAME" "$USER_FIRSTNAME" "Auth"
    [ ! -z "$USER_LASTNAME" ]  && update_env "$AUTH_ENV" "INIT_ADMIN_LASTNAME"  "$USER_LASTNAME"  "Auth"
    [ ! -z "$USER_EMAIL" ]     && update_env "$AUTH_ENV" "INIT_ADMIN_EMAIL"     "$USER_EMAIL"     "Auth"
    [ ! -z "$USER_PASSWORD" ]  && update_env "$AUTH_ENV" "INIT_ADMIN_PASSWORD"  "$USER_PASSWORD"  "Auth"
else
    echo -e "   ${RED}⚠️  Skipped: $USER_INFO_CONF not found${NC}"
fi

# ==============================================================================
# 1. Set YouTube API Key
# ==============================================================================
echo "----------------------------------------------------------------"
echo -e "🔑 1. Set ${YELLOW}YouTube API Key${NC}"
echo "----------------------------------------------------------------"

if [ -f "$API_KEY_CONF" ]; then
    API_KEY=$(grep "^YOUTUBE_API_KEY=" "$API_KEY_CONF" | cut -d '=' -f2 | tr -d '"' | tr -d "'")
    if [ ! -z "$API_KEY" ]; then
        update_env "$HUB_ENV" "YOUTUBE_HUB_DEFAULT_CONFIG_YOUTUBE_API_KEY" "$API_KEY" "Youtube Hub"
    else
        echo -e "   ${RED}⚠️  Warning: No Key in config file${NC}"
    fi
else
    echo -e "   ${RED}⚠️  Skipped: $API_KEY_CONF not found${NC}"
fi

# ==============================================================================
# 2. Sync Downloader Client
# ==============================================================================
echo -e "\n----------------------------------------------------------------"
echo -e "📡 2. Sync ${YELLOW}Downloader Client${NC} Credentials"
echo "----------------------------------------------------------------"

DL_ID=$(generate_uuid)
DL_SECRET=$(generate_uuid)

update_env "$AUTH_ENV" "INIT_DOWNLOADER_CLIENT_ID"     "$DL_ID"     "Auth"
update_env "$AUTH_ENV" "INIT_DOWNLOADER_CLIENT_SECRET" "$DL_SECRET" "Auth"
update_env "$DOWNLOADER_ENV" "DOWNLOADER_CLIENT_ID"     "$DL_ID"     "Downloader"
update_env "$DOWNLOADER_ENV" "DOWNLOADER_CLIENT_SECRET" "$DL_SECRET" "Downloader"

# ==============================================================================
# 3. Sync Youtube Hub Web Client
# ==============================================================================
echo -e "\n----------------------------------------------------------------"
echo -e "🌐 3. Sync ${YELLOW}Youtube Hub Web Client${NC} Credentials"
echo "----------------------------------------------------------------"

HUB_ID=$(generate_uuid)
HUB_SECRET=$(generate_uuid)

update_env "$AUTH_ENV" "INIT_HUB_CLIENT_ID"     "$HUB_ID"     "Auth"
update_env "$AUTH_ENV" "INIT_HUB_CLIENT_SECRET" "$HUB_SECRET" "Auth"
update_env "$HUB_ENV" "YOUTUBE_HUB_DEFAULT_CONFIG_CLIENT_ID"     "$HUB_ID"     "Youtube Hub"
update_env "$HUB_ENV" "YOUTUBE_HUB_DEFAULT_CONFIG_CLIENT_SECRET" "$HUB_SECRET" "Youtube Hub"

# ==============================================================================
# 4. Generate Postman Client
# ==============================================================================
echo -e "\n----------------------------------------------------------------"
echo -e "🚀 4. Generate ${YELLOW}Postman Test Client${NC} Credentials"
echo "----------------------------------------------------------------"

POSTMAN_ID=$(generate_uuid)
POSTMAN_SECRET=$(generate_uuid)
POSTMAN_CALLBACK="https://oauth.pstmn.io/v1/callback"

update_env "$AUTH_ENV" "INIT_POSTMAN_CLIENT_ID"     "$POSTMAN_ID"     "Auth"
update_env "$AUTH_ENV" "INIT_POSTMAN_CLIENT_SECRET" "$POSTMAN_SECRET" "Auth"
update_env "$AUTH_ENV" "INIT_POSTMAN_REDIRECT_URIS" "$POSTMAN_CALLBACK" "Auth"

# --- Fix Display Logic ---
# If --skip is used, display the "old value from file" instead of the newly generated "new value"
if [ "$SKIP_EXISTING" = true ]; then
    CURRENT_ID=$(read_env_value "$AUTH_ENV" "INIT_POSTMAN_CLIENT_ID")
    if [ ! -z "$CURRENT_ID" ]; then
        POSTMAN_ID=$CURRENT_ID
        POSTMAN_SECRET=$(read_env_value "$AUTH_ENV" "INIT_POSTMAN_CLIENT_SECRET")
    fi
fi

# ==============================================================================
# 5. Sync S3 Object Storage Credentials
# ==============================================================================
echo -e "\n----------------------------------------------------------------"
echo -e "🪣 5. Sync ${YELLOW}S3 Object Storage${NC} Credentials"
echo "----------------------------------------------------------------"

S3_ROOT_U="admin"
S3_ROOT_P=$(generate_uuid)
S3_SVC_AK="youtube-hub-backend"
S3_SVC_SK=$(generate_uuid)

# Update S3 Root
update_env "$S3_ENV" "S3_ROOT_USER"     "$S3_ROOT_U"     "Object Storage"
update_env "$S3_ENV" "S3_ROOT_PASSWORD" "$S3_ROOT_P"     "Object Storage"

# Update S3 Service Account for setup
update_env "$S3_ENV" "S3_SVC_ACCESS_KEY" "$S3_SVC_AK" "Object Storage"
update_env "$S3_ENV" "S3_SVC_SECRET_KEY" "$S3_SVC_SK" "Object Storage"

# Update Spring Boot config to use the Service Account
update_env "$HUB_ENV" "YOUTUBE_HUB_STORAGE_S3_ACCESS_KEY" "$S3_SVC_AK" "Youtube Hub"
update_env "$HUB_ENV" "YOUTUBE_HUB_STORAGE_S3_SECRET_KEY" "$S3_SVC_SK" "Youtube Hub"

# ==============================================================================
# 6. Sync Central Logging Credentials
# ==============================================================================
echo -e "\n----------------------------------------------------------------"
echo -e "📜 6. Sync ${YELLOW}Central Logging${NC} Credentials"
echo "----------------------------------------------------------------"

LOGGING_ROOT_P=$(generate_uuid)
LOGGING_USER="logger"
LOGGING_P=$(generate_uuid)

# Update Central Logging DB
update_env "$LOGGING_ENV" "MYSQL_ROOT_PASSWORD" "$LOGGING_ROOT_P" "Central Logging"
update_env "$LOGGING_ENV" "MYSQL_USER"          "$LOGGING_USER"     "Central Logging"
update_env "$LOGGING_ENV" "MYSQL_PASSWORD"      "$LOGGING_P"        "Central Logging"

# Update Spring Boot config for microservices
update_env "$HUB_ENV"        "LOGGING_MYSQL_USER"     "$LOGGING_USER" "Youtube Hub"
update_env "$HUB_ENV"        "LOGGING_MYSQL_PASSWORD" "$LOGGING_P"    "Youtube Hub"
update_env "$AUTH_ENV"       "LOGGING_MYSQL_USER"     "$LOGGING_USER" "Auth Service"
update_env "$AUTH_ENV"       "LOGGING_MYSQL_PASSWORD" "$LOGGING_P"    "Auth Service"
update_env "$DOWNLOADER_ENV" "LOGGING_MYSQL_USER"     "$LOGGING_USER" "Downloader"
update_env "$DOWNLOADER_ENV" "LOGGING_MYSQL_PASSWORD" "$LOGGING_P"    "Downloader"

# ==============================================================================
# 7. Generate RSA Certificates (Auth Service)
# ==============================================================================
echo -e "\n----------------------------------------------------------------"
echo -e "🔐 7. Check and Generate ${YELLOW}RSA Key Pair${NC} (Auth Service)"
echo "----------------------------------------------------------------"

# 1. Ensure directory exists
if [ ! -d "$AUTH_CERTS_DIR" ]; then
    echo "   Creating directory: $AUTH_CERTS_DIR"
    mkdir -p "$AUTH_CERTS_DIR"
fi

# 2. Check private.pem
if [ -f "$AUTH_CERTS_DIR/private.pem" ]; then
    # Safety mechanism: If cert exists, do not overwrite even without --skip, as this invalidates all issued Tokens
    echo -e "   [${GRAY}Certs${NC}] Skipped: private.pem exists (delete file manually to reset)"
else
    # 3. Generate Private Key
    echo -e "   [${GREEN}Certs${NC}] Generating RSA Private Key (2048 bit)..."
    openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -out "$AUTH_CERTS_DIR/private.pem"

    # 4. Generate Public Key
    echo -e "   [${GREEN}Certs${NC}] Generating RSA Public Key..."
    openssl rsa -in "$AUTH_CERTS_DIR/private.pem" -pubout -out "$AUTH_CERTS_DIR/public.pem" > /dev/null 2>&1

    # 5. Fix permissions (Ensure Docker can read)
    chmod 644 "$AUTH_CERTS_DIR/private.pem"
    chmod 644 "$AUTH_CERTS_DIR/public.pem"

    echo -e "   [${GREEN}Certs${NC}] ✅ Certificate generation complete"
fi

echo -e "\n${GREEN}🎉 Initialization Complete!${NC}"
echo ""
echo "👇👇👇 Please copy the following info to Postman (Authorization: OAuth 2.0) 👇👇👇"
echo "================================================================"
echo -e " Grant Type    : ${CYAN}Authorization Code${NC}"
echo -e " Client ID     : ${GREEN}$POSTMAN_ID${NC}"
echo -e " Client Secret : ${GREEN}$POSTMAN_SECRET${NC}"
echo -e " Callback URL  : ${CYAN}$POSTMAN_CALLBACK${NC}"
echo -e " Auth URL      : http://localhost:8080/oauth2/authorize"
echo -e " Token URL     : http://localhost:8080/oauth2/token"
echo "================================================================"
echo ""
