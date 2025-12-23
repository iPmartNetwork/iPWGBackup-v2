#!/bin/bash
set -e
echo "==============================="
echo " iPWGBackup Auto Installer "
echo "==============================="

# Root check
if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root"
  exit 1
fi

# Telegram info
read -rp "🔑 Enter Telegram Bot Token: " TG_TOKEN
read -rp "👤 Enter Telegram Admin Chat ID: " TG_CHAT_ID

if [[ -z "$TG_TOKEN" || -z "$TG_CHAT_ID" ]]; then
  echo "❌ Telegram credentials cannot be empty"
  exit 1
fi

INSTALL_DIR="/opt/iPWGBackup"
BACKUP_DIR="/var/backups/ipwgbackup"
CONFIG_FILE="$INSTALL_DIR/config.env"

echo "📦 Installing dependencies..."
apt update -y
apt install -y python3 python3-pip git wireguard curl tar

pip3 install --upgrade pip
pip3 install requests

echo "📥 Installing iPWGBackup..."
if [[ -d "$INSTALL_DIR" ]]; then
  cd "$INSTALL_DIR" && git pull
else
  git clone https://github.com/iPmartNetwork/iPWGBackup.git "$INSTALL_DIR"
fi

echo "📂 Installing Python package..."
cp -r "$INSTALL_DIR/ipwgbackup" /usr/local/lib/

echo "📁 Creating backup directory..."
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

echo "⚙️ Writing config.env..."
cat > "$CONFIG_FILE" <<EOF
TG_TOKEN=$TG_TOKEN
TG_CHAT_ID=$TG_CHAT_ID
BACKUP_DIR=$BACKUP_DIR
EOF
chmod 600 "$CONFIG_FILE"

# systemd service
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

path = run_backup()
send_telegram(os.environ["TG_TOKEN"], os.environ["TG_CHAT_ID"], path)
PY
EOF

# systemd timer
echo "⏱ Creating systemd timer (12h)..."
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

echo "🔄 Reloading systemd..."
systemctl daemon-reexec
systemctl daemon-reload

echo "▶️ Enabling service and timer..."
systemctl enable --now ipwgbackup.timer

echo "✅ Installation completed successfully!"
echo ""
echo "📌 Manual usage:"
echo "  Backup now:   systemctl start ipwgbackup.service"
echo "  Restore:      python3 -m ipwgbackup.cli.main restore FILE --dry-run"
echo "  Timer status: systemctl list-timers | grep ipwgbackup"
