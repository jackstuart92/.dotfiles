# This script installs dependencies for a Windows development environment.
# It requires Administrator privileges to run.

# Self-elevate the script if not running as Administrator
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script needs to be run as Administrator."
    Write-Host "Attempting to restart with elevated privileges..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -File `"$PSCommandPath`""
    Exit
}

Write-Host "Running with Administrator privileges."

# --- Install WSL and Ubuntu ---
Write-Host "Checking WSL status..."
wsl --status > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "WSL not found. Installing WSL and Ubuntu..."
    Write-Host "This may require a system reboot."
    wsl --install -d Ubuntu
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install WSL. Please install it manually from the Microsoft Store or by following Microsoft's documentation."
        Exit 1
    }
    Write-Host "WSL and Ubuntu have been installed."
    Write-Host "Please REBOOT your machine now."
    Write-Host "After rebooting, open 'Ubuntu' from the Start Menu to complete the installation."
    Write-Host "Once inside Ubuntu, you can proceed with the standard setup by running './install.sh' from your dotfiles directory."
} else {
    Write-Host "WSL is already installed."
}


# --- Install VS Code ---
Write-Host "Checking for Visual Studio Code..."
$vsCodePath = Get-Command code -ErrorAction SilentlyContinue
if (-not $vsCodePath) {
    Write-Host "VS Code not found. Installing via winget..."
    winget install --id Microsoft.VisualStudioCode --exact --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to install VS Code using winget. Please install it manually from https://code.visualstudio.com/"
    } else {
        Write-Host "VS Code installed successfully."
    }
} else {
    Write-Host "Visual Studio Code is already installed."
}

Write-Host "Windows dependency setup complete."
