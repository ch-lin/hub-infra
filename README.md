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
    The `CloneAll.sh` script will automatically clone all other required microservices into the workspace folder.
    ```bash
    chmod +x CloneAll.sh
    ./CloneAll.sh
    ```

## 📂 Configuration Files

Before running any script, you must prepare the configuration files. These files are git-ignored to protect your secrets.

1.  **`local.conf`** (Required)
    *   Defines the root paths for your project and database volumes.
    *   Copy from template: `cp local.conf.example local.conf`

2.  **`user-info.conf`** (Optional but Recommended)
    *   Sets the initial Admin credentials for the Authentication Service.
    *   Copy from template: `cp user-info.conf.example user-info.conf`

3.  **`youtube-api-key.conf`** (Optional)
    *   Sets the Google Cloud API Key for the YouTube Hub.
    *   Copy from template: `cp youtube-api-key.conf.example youtube-api-key.conf`

## 🛠️ Scripts Overview

### 1. `CloneAll.sh`
**The Workspace Setup.**
*   **Function**: Automates the cloning of all microservice repositories (`authentication-service`, `downloader`, `youtube-hub`, `hub-ui`, `platform`) into the parent directory.
*   **Usage**:
    ```bash
    ./CloneAll.sh
    ```

### 2. `Init-secrets.sh`
**The Bootstrapper.**
*   **Function**:
    *   Generates RSA Key Pairs (Private/Public) for JWT signing.
    *   Generates UUIDs for Client IDs and Secrets (for inter-service auth).
    *   Injects these secrets directly into the `.env` files of `authentication-service`, `downloader`, and `youtube-hub`.
*   **Usage**:
    ```bash
    ./Init-secrets.sh
    # Use --skip to keep existing secrets and only fill missing ones
    ./Init-secrets.sh --skip
    ```

### 3. `BuildAll.sh`
**The Builder.**
*   **Function**: Orchestrates the build process for all microservices. It ensures `Init-secrets.sh` is run first (in skip mode), then triggers the `Build.sh` script inside each service directory.
*   **Usage**:
    ```bash
    # Build everything (Recommended)
    ./BuildAll.sh

    # Build specific services
    ./BuildAll.sh auth
    ./BuildAll.sh downloader
    ./BuildAll.sh youtube
    ./BuildAll.sh ui
    ```

### 4. `CleanAll.sh`
**The Cleaner.**
*   **Function**: Stops containers and removes Docker images to free up space or ensure a fresh build.
*   **⚠️ Danger Zone**: Can optionally delete database files from the disk.
*   **Usage**:
    ```bash
    # Clean Docker resources (Containers/Images) for all services
    ./CleanAll.sh

    # Clean specific service
    ./CleanAll.sh auth

    # ⚠️ Stop DBs and DELETE ALL DATA on disk
    ./CleanAll.sh delete-db
    ```

### 5. `BackupAll.sh`
**The Lifesaver.**
*   **Function**:
    1.  Stops all running containers (to ensure data consistency).
    2.  Creates a `.tar.gz` archive of the database directories defined in `local.conf`.
    3.  Restarts the containers.
*   **Output**: Backups are saved to the `Backups/` directory (relative to the project root).
*   **Usage**:
    ```bash
    ./BackupAll.sh
    ```

## 🚀 Workflow Example

1.  **Setup Configs**:
    ```bash
    cd hub-infra
    cp local.conf.example local.conf
    # Edit local.conf to set PROJECT path and DB paths
    ```

2.  **Initialize & Build**:
    ```bash
    ./BuildAll.sh
    ```

3.  **Reset (If things go wrong)**:
    ```bash
    ./CleanAll.sh
    ./BuildAll.sh
    ```

## 📜 License

MIT
