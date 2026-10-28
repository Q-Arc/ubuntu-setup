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
apt install -y build-essential systemd-zram-generator keyd flatpak curl git ca-certificates libfuse2t64 ripgrep fastfetch btop fd-find bat tealdeer fzf eza vim trash-cli ncdu duf gufw wl-clipboard pandoc ubuntu-restricted-addons ubuntu-restricted-extras qalculate-gtk

echo "[+] Setting up Docker's official GPG key and repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources
cat << EOF > /etc/apt/sources.list.d/docker.sources
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "[+] Installing Docker Engine and plugins..."
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[+] Adding user '$REAL_USER' to the docker group..."
usermod -aG docker "$REAL_USER"
systemctl enable --now docker

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

echo "[+] Disabling unnecessary system services..."
systemctl disable --now NetworkManager-wait-online.service 2>/dev/null || true
systemctl disable --now switcheroo-control.service 2>/dev/null || true
systemctl disable --now ModemManager.service 2>/dev/null || true
systemctl disable --now cups.service 2>/dev/null || true

# ---------------------------------------------------------
# SECTION 2: User Tasks (Symlinks, Flatpak & Flathub apps)
# ---------------------------------------------------------

echo "[+] Creating user binary directory and symlinks for bat and fd..."

# Ensure ~/.local/bin exists for the regular user
sudo -u "$REAL_USER" mkdir -p "/home/$REAL_USER/.local/bin"

# Create symlinks (ignoring error if they already exist)
sudo -u "$REAL_USER" ln -sf /usr/bin/batcat "/home/$REAL_USER/.local/bin/bat"
sudo -u "$REAL_USER" ln -sf /usr/bin/fdfind "/home/$REAL_USER/.local/bin/fd"

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
  echo "[*] No Flatpak apps listed in the array to install"
fi

echo "[+] Configuring user shell environment (.bashrc)..."

# Safely append configurations if they aren't already there
if ! sudo -u "$REAL_USER" grep -q 'eval "$(fzf --bash)"' "/home/$REAL_USER/.bashrc"; then
    sudo -u "$REAL_USER" bash -c 'cat << "EOF" >> "$HOME/.bashrc"

# --- Added by setup.sh ---
eval "$(fzf --bash)"
. "$HOME/.cargo/env"
EOF
'
    echo "    -> Added fzf and cargo configurations to .bashrc"
else
    echo "    -> .bashrc already contains the configurations. Skipping."
fi

echo "[+] Success! System Setup Done."
