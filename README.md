# My Dotfiles

This repository contains my personal dotfiles for creating a consistent development environment across macOS and WSL (Ubuntu).

## 🪟 Windows Setup (Prerequisites)

If you are on a fresh Windows machine, you need to install WSL (Windows Subsystem for Linux) and some essential tools before proceeding with the main dotfiles setup.

1.  **Run the Windows installation script:**
    First, clone this repository to your machine. Open a PowerShell terminal and run:
    ```powershell
    git clone <your-repository-url> dotfiles
    cd dotfiles
    ```

    Then, run the `install.ps1` script. This script will install WSL, Ubuntu, and Visual Studio Code. It requires Administrator privileges and will attempt to elevate itself.
    
    From the PowerShell terminal:
    ```powershell
    .\install.ps1
    ```

    ⚠️ **A system reboot will likely be required after this step.** Follow any on-screen instructions.

2.  **Launch Ubuntu and start the main setup:**
    After rebooting, open "Ubuntu" from the Start Menu. This will complete the Ubuntu installation and drop you into a Linux terminal. From there, you can proceed with the Quick Start steps below.

## 🚀 Quick Start (macOS or WSL/Ubuntu)

These steps should be run from your terminal on macOS or inside your Ubuntu environment on WSL.

1.  **Clone the repository:**

    ```bash
    git clone <your-repository-url> ~/.dotfiles
    cd ~/.dotfiles
    ```

2.  **Run the installation script:**

    This will install all the necessary software and packages using Homebrew on macOS or `apt` on Ubuntu.

    ```bash
    ./install.sh
    ```

3.  **Set up your local configurations:**
    Run the interactive configuration script. This will guide you through setting up Git, private registries for NPM, Pip, Docker, and Go.
    ```bash
    ./configure.sh
    ```

    Alternatively, you can manually copy the templates and edit them:
    *   **Git:**

        ```bash
        cp git/.gitconfig.template git/.gitconfig.local
        ```

        Then, edit `git/.gitconfig.local` with your name, email, and GitHub username.

    *   **Environment Variables:**

        ```bash
        cp shell/env.template ~/.env
        ```

        Edit `~/.env` to add your private registry tokens and any other environment variables you need.

4.  **Symlink the dotfiles:**

    This will create symlinks from the files in this repository to your home directory.

    ```bash
    ./stow.sh
    ```

5.  **(Optional) Set up automatic syncing:**

    If you want to keep your dotfiles automatically updated, run the sync script. This will add a cron job to pull the latest changes from the repository every hour.

    ```bash
    ./sync.sh
    ```

## 📂 Repository Structure

*   `install.ps1`: (Windows only) Installs WSL, Ubuntu, and VS Code.
*   `install.sh`: Installs software and dependencies for macOS and WSL/Ubuntu.
*   `configure.sh`: An interactive script to set up your local configurations.
*   `stow.sh`: Symlinks the dotfiles using `stow`.
*   `sync.sh`: Sets up a cron job to sync the repository.
*   `git/`: Contains `.gitconfig`, `.gitignore_global`, and templates.
*   `zsh/`: Contains `.zshrc`.
*   `shell/`: Contains `.bashrc`, `.bash_profile`, and `.env.template`.
*   `npm/`, `pip/`, `docker/`, `go/`: Configuration for private registries.
*   `copilot/`: Contains `.copilot-instructions`.
*   `nvim/`: Contains `.vimrc`.
*   `scripts/`: Utility scripts.
