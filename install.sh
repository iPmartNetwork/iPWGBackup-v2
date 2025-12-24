#!/bin/bash
set -e

echo "==============================="
echo " iPWGBackup Auto Installer"
echo "==============================="

# -------------------------
# Root check
# -------------------------
if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run this installer as root"
  exit 1
fi

# -------------------------
# Read input safely (TTY)
# -------------------------
read_from_tty() {
  local value
  read -r -p "$1" value </dev/tty
  echo "$value"
}

# -------------------------
# Telegram configuration
# -------------------------
echo ""
echo "🤖 Telegram Configuration"

TG_BOT_TOKEN="${TG_BOT_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

if [[ -z "$TG_BOT_TOKEN" ]]; then
  TG_BOT_TOKEN=$(read_from_tty "Enter Telegram Bot Token: ")
fi

if [[ -z "$TG_CHAT_ID" ]]; then
  TG_CHAT_ID=$(read_from_tty "Enter Telegram Admin Chat ID (numeric): ")
fi

if [[ -z "$TG_BOT_TOKEN" || -z "$TG_CHAT_ID" ]]; then
  echo "❌ Telegram credentials cannot be empty"
  exit 1
fi

if ! [[ "$TG_CHAT_ID" =~ ^[0-9]+$ ]]; then
  echo "❌ Telegram Chat ID must be numeric"
  exit 1
fi

# -------------------------
# Paths
# -------------------------
INSTALL_DIR="/opt/iPWGBackup"
BACKUP_DIR="/var/backups/ipwgbackup"
CONFIG_FILE="$INSTALL_DIR/config.env"

# -------------------------
# Install dependencies
# -------------------------
echo ""
echo "📦 Installing system dependencies..."

apt update -y
apt install -y \
  python3 \
  python3-pip \
  git \
  curl \
  tar \
  systemd

pip3 install --upgrade pip
pip3 install requests

# -------------------------
# Check WireGuard existence (NOT install)
# -------------------------
echo ""
if [[ ! -d "/etc/wireguard" ]]; then
  echo "⚠️  Warning: /etc/wireguard not found"
  echo "⚠️  Backups will be empty until WireGuard is installed"
else
  echo "✅ WireGuard directory detected"
fi

# -------------------------
# Install project
# -------------------------
echo ""
echo "📥 Installing iPWGBackup..."

if [[ -d "$INSTALL_DIR" ]]; then
  echo "🔄 Updating existing installation..."
  cd "$INSTALL_DIR"
  git pull
else
  git clone https://github.com/iPmartNetwork/iPWGBackup-v2.git "$INSTALL_DIR"
fi

# -------------------------
# Prepare directories
# -------------------------
echo ""
echo "📁 Preparing directories..."

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# -------------------------
# Write config.env
# -------------------------
echo ""
echo "⚙️ Writing configuration..."

cat > "$CONFIG_FILE" <<EOF
TG_BOT_TOKEN="$TG_BOT_TOKEN"
TG_CHAT_ID="$TG_CHAT_ID"
BACKUP_DIR="$BACKUP_DIR"
EOF

chmod 600 "$CONFIG_FILE"

# -------------------------
# systemd service
# -------------------------
echo ""
echo "🛠 Creating systemd service..."

cat > /etc/systemd/system/ipwgbackup.service <<EOF
[Unit]
Description=iPWGBackup Backup Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
EnvironmentFile=$CONFIG_FILE
ExecStart=/usr/bin/python3 - <<PY
import os
from ipwgbackup.core.backup import run_backup
from ipwgbackup.targets.telegram import send_telegram

backup_path = run_backup()
send_telegram(
    os.environ["TG_BOT_TOKEN"],
    os.environ["TG_CHAT_ID"],
    backup_path
)
PY
EOF

# -------------------------
# systemd timer
# -------------------------
echo ""
echo "⏱ Creating systemd timer (every 12 hours)..."

cat > /etc/systemd/system/ipwgbackup.timer <<EOF
[Unit]
Description=Run iPWGBackup every 12 hours

[Timer]
OnBootSec=5min
OnUnitActiveSec=12h
Persistent=true

[Install]
WantedBy=timers.target
EOF

# -------------------------
# Enable systemd
# -------------------------
echo ""
echo "🔄 Reloading systemd..."

systemctl daemon-reexec
systemctl daemon-reload

echo "▶️ Enabling backup timer..."
systemctl enable --now ipwgbackup.timer

# -------------------------
# Done
# -------------------------
echo ""
echo "✅ iPWGBackup installed successfully!"
echo ""
echo "Useful commands:"
echo "  Run backup now:   systemctl start ipwgbackup.service"
echo "  Check timers:     systemctl list-timers | grep ipwgbackup"
echo "  Restore backup:   python3 -m ipwgbackup.cli.main restore FILE --dry-run"
