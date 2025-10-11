# My Dotfiles

This repository contains my personal dotfiles for creating a consistent development environment across macOS and WSL (Ubuntu).

## Workflow

The repository is designed with a clear, separated workflow:

1.  **Installation (One-Time)**: Use `install.sh` (or `install.ps1` on Windows) to install all necessary software and dependencies on a new machine.
2.  **Configuration (One-Time)**: Use `configure.sh` to set up your local secrets and machine-specific settings (e.g., Git identity, private tokens).
3.  **Stowing (One-Time)**: Use `stow.sh` to create symlinks from this repository to your home directory, activating your dotfiles.
4.  **Synchronization (Automatic)**: Use `sync.sh` to set up an hourly cron job that pulls the latest changes, keeping your dotfiles automatically up-to-date across all your machines.

---

## 🪟 Windows Setup (Prerequisites)

If you are on a fresh Windows machine, you need to install WSL (Windows Subsystem for Linux) and some essential tools before proceeding with the main dotfiles setup.

1.  **Clone the Repository and Run the Installer:**
    First, clone this repository to your machine. Open a PowerShell terminal as an Administrator and run:
    ```powershell
    git clone https://github.com/your-username/dotfiles.git C:\Users\YourUser\dotfiles
    cd C:\Users\YourUser\dotfiles
    .\install.ps1
    ```
    ⚠️ **A system reboot will likely be required after this step.** Follow any on-screen instructions.

2.  **Launch Ubuntu and Start the Main Setup:**
    After rebooting, open "Ubuntu" from the Start Menu. This will complete the Ubuntu installation and drop you into a Linux terminal. From there, you can proceed with the Quick Start steps below.

## 🚀 Quick Start (macOS or WSL/Ubuntu)

These steps should be run from your terminal on macOS or inside your Ubuntu environment on WSL.

1.  **Clone the Repository:**
    (If you are on WSL and already cloned the repo in Windows, you can skip this step and `cd` to `~/.dotfiles`).
    ```bash
    git clone https://github.com/your-username/dotfiles.git ~/.dotfiles
    cd ~/.dotfiles
    ```

2.  **Run the Installation Script:**
    This will install all the necessary software and packages using Homebrew on macOS or `apt` on Ubuntu.
    ```bash
    ./install.sh
    ```

3.  **Set Up Your Local Configurations:**
    Run the interactive configuration script. This will guide you through setting up your Git identity and private registry tokens.
    ```bash
    ./configure.sh
    ```
    This script creates local, untracked files (e.g., `git/.gitconfig.local`, `~/.env`) so your private information is never committed to the repository.

4.  **Symlink (Stow) the Dotfiles:**
    This command uses GNU Stow to create symlinks from the files in this repository to your home directory.
    ```bash
    ./stow.sh
    ```
    > **Note on WSL Pathing Bugs:**
    > If your WSL home directory (`~`) is a symlink to your Windows user profile, you may see harmless `BUG in find_stowed_path` messages. This is a known issue with how Stow interacts with WSL's mixed pathing. The script is designed to detect and suppress these messages. If you need to debug, you can view them by running `./stow.sh --verbose-stow-bugs`.

5.  **(Optional) Set Up Automatic Syncing:**
    This script adds a cron job to pull the latest changes from the repository every hour. This is highly recommended for keeping your environment consistent across multiple machines.
    ```bash
    ./sync.sh
    ```

## 📂 Repository Structure

*   `install.ps1`: (Windows only) Installs WSL, Ubuntu, and VS Code.
*   `install.sh`: Installs software and dependencies for macOS and WSL/Ubuntu.
*   `configure.sh`: An interactive script to set up local, untracked configurations.
*   `stow.sh`: Symlinks the dotfiles using `stow`. Handles WSL pathing issues gracefully.
*   `sync.sh`: Sets up a cron job to sync the repository automatically.
*   `git/`, `zsh/`, `shell/`, etc.: Stow packages containing the dotfiles to be linked.
