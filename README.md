# Setup Scripts (Hub)

![Bash](https://img.shields.io/badge/Script-Bash-4EAA25)
![Docker](https://img.shields.io/badge/Orchestration-Docker%20Compose-2496ED)
![License](https://img.shields.io/badge/License-MIT-green)

This directory contains the **automation and orchestration scripts** for the Hub ecosystem.

Since the project is split into multiple repositories (microservices), these scripts act as the "glue" to manage the lifecycle of the entire system—from generating secrets to building, cleaning, and backing up data.

> **Note**: This script-based orchestration is the current starting point. A migration to **Ansible** or **Docker Compose `include`** is planned for the future to provide a more robust deployment strategy.

## 🚀 Quick Start (Workspace Setup)

Since this project follows a **Poly-repo** structure (multiple repositories), you need to set up a specific directory structure for the automation scripts to work correctly.

1.  **Create a Workspace Directory**:
    ```bash
    mkdir Hub-Workspace
    cd Hub-Workspace
    ```

2.  **Clone this Infrastructure Repo**:
    ```bash
    git clone https://github.com/ch-lin/hub-infra.git hub-infra
    cd hub-infra
    ```

3.  **Run the Setup Script**:
    The `clone-all.sh` script will automatically clone all other required microservices into the workspace folder.
    ```bash
    bash clone-all.sh
    ```

## 📂 Configuration Files

Before running any script, you must prepare the configuration files. These files are git-ignored to protect your secrets.

1.  **`local.conf`** (Required)
    *   Defines the root paths for your project and database volumes.
    *   **Auto-generated**: If missing, infra scripts will automatically create this from `local.conf.example` and set default paths (`.docker-data`) based on your environment. You can review and adjust it later.

2.  **`user-info.conf`** (Optional but Recommended)
    *   Sets the initial Admin credentials for the Authentication Service.
    *   Copy from template: `cp user-info.conf.example user-info.conf`

3.  **`youtube-api-key.conf`** (Optional)
    *   Sets the Google Cloud API Key for the YouTube Hub.
    *   Copy from template: `cp youtube-api-key.conf.example youtube-api-key.conf`

## 🛠️ Scripts Overview

### 0. `_load-config.sh` (The Sentinel)
*   **Function**: A shared helper script sourced by other scripts. It handles loading configurations, validating the workspace (ensuring all microservices are cloned), and auto-provisioning `local.conf` if it's missing. It also centralizes the `run_priv` (sudo) logic.
*   **Usage**: Sourced internally. Do not run directly.

### 1. `clone-all.sh`
**The Workspace Setup.**
*   **Function**: Automates the cloning of all microservice repositories (`authentication-service`, `downloader`, `youtube-hub`, `hub-ui`, `platform`) into the parent directory.
*   **Usage**:
    ```bash
    bash clone-all.sh
    ```

### 2. `init-secrets.sh`
**The Bootstrapper.**
*   **Function**:
    *   Generates RSA Key Pairs (Private/Public) for JWT signing.
    *   Generates UUIDs for Client IDs and Secrets (for inter-service auth).
    *   Injects these secrets directly into the `.env` files of `authentication-service`, `downloader`, and `youtube-hub`.
*   **Usage**:
    ```bash
    bash init-secrets.sh
    # Use --skip to keep existing secrets and only fill missing ones
    bash init-secrets.sh --skip
    ```

### 3. `build-all.sh`
**The Builder.**
*   **Function**: Orchestrates the build process for all microservices. It ensures `init-secrets.sh` is run first (in skip mode), then triggers the `build.sh` script inside each service directory.
*   **Usage**:
    ```bash
    # Build everything (Recommended)
    bash build-all.sh

    # Build specific services
    bash build-all.sh auth
    bash build-all.sh downloader
    bash build-all.sh youtube
    bash build-all.sh ui
    bash build-all.sh s3
    ```

### 4. `clean-all.sh`
**The Cleaner.**
*   **Function**: Stops containers and removes Docker images to free up space or ensure a fresh build.
*   **⚠️ Danger Zone**: Can optionally delete database files from the disk.
*   **Usage**:
    ```bash
    # Clean Docker resources (Containers/Images) for all services
    bash clean-all.sh

    # Clean specific service
    bash clean-all.sh auth

    # ⚠️ Stop DBs and DELETE ALL DATA on disk
    bash clean-all.sh delete-db
    ```

### 5. `backup-all.sh`
**The Lifesaver.**
*   **Function**:
    1.  Stops all running containers (to ensure data consistency).
    2.  Creates a `.tar.gz` archive of the database directories defined in `local.conf`.
    3.  Restarts the containers.
*   **Output**: Backups are saved to the `Backups/` directory (relative to the project root).
*   **Usage**:
    ```bash
    bash backup-all.sh
    ```

## 🚀 Typical Execution Order & Workflow Example

1.  **Setup Configs**:
    ```bash
    # 1. First, make sure you have all microservices cloned
    bash clone-all.sh
    
    # 2. (Optional) Setup your admin user or YouTube API keys
    cp user-info.conf.example user-info.conf
    cp youtube-api-key.conf.example youtube-api-key.conf
    ```

2.  **Initialize & Build**:
    ```bash
    # 3. This will auto-create local.conf, run init-secrets.sh, and build all docker containers
    bash build-all.sh
    ```

3.  **Reset (If things go wrong)**:
    ```bash
    bash clean-all.sh
    bash build-all.sh
    ```

## 📜 License

MIT
