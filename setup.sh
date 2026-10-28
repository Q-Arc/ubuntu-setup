#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "[-] Error: Please run this script with sudo."
  echo "    Usage: sudo bash $0"
  exit 1
fi

# Capture the actual non-root user who ran sudo
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"

# ---------------------------------------------------------
# SECTION 1: Root Tasks (Apt & System Configs)
# ---------------------------------------------------------

echo "[+] Updating package lists and installing programs and dependencies..."
apt update
apt install -y build-essential systemd-zram-generator keyd flatpak 

echo "[+] Creating /etc/systemd/zram-generator.conf..."
mkdir -p /etc/systemd
cat << 'EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
EOF

echo "[+] Creating /etc/keyd/default.conf..."
mkdir -p /etc/keyd
cat << 'EOF' > /etc/keyd/default.conf
[ids]

*

[main]

# Maps capslock to escape when pressed and control when held.
capslock = overload(control, esc)

# Remaps the escape key to capslock
esc = capslock
EOF

echo "[+] Explicitly enabling and starting the keyd service..."
systemctl enable --now keyd

# ---------------------------------------------------------
# SECTION 2: User Tasks (Flatpak & Flathub apps)
# ---------------------------------------------------------

echo "[+] Setting up Flathub repository for user: $REAL_USER..."

# Add Flathub for the user (does not require root)
sudo -u "$REAL_USER" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Define the flatpak apps you want to install here
FLATPAK_APPS=(
	org.libreoffice.LibreOffice
	be.alexandervanhee.gradia
	com.mattjakeman.ExtensionManager
	com.github.tchx84.Flatseal
	com.usebottles.bottles
	com.obsproject.Studio
	io.github.Faugus.faugus-launcher
	io.github.diegopvlk.Cine
	io.github.flattool.Warehouse
	io.github.sitraorg.sitra
	it.mijorus.gearlever
	org.blender.Blender
	org.localsend.localsend_app
)

if [ ${#FLATPAK_APPS[@]} -gt 0 ]; then
  echo "[+] Installing requested Flatpak applications..."
  for app in "${FLATPAK_APPS[@]}"; do
    echo "    -> Installing $app"
    sudo -u "$REAL_USER" flatpak install --user -y flathub "$app"
  done
else
  echo "[*] No Flatpak apps listed in the array to install. You can add them inside the script later."
fi

echo "[+] Success! System configurations and Flatpak setup completed."
