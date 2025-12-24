#!/bin/bash
set -e

echo "==============================="
echo " iPWGBackup Auto Installer"
echo "==============================="

# Root check
if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root"
  exit 1
fi

# Read from TTY (curl | bash safe)
read_from_tty() {
  local v
  read -r -p "$1" v </dev/tty
  echo "$v"
}

echo ""
echo "🤖 Telegram Configuration"

TG_BOT_TOKEN="${TG_BOT_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

[[ -z "$TG_BOT_TOKEN" ]] && TG_BOT_TOKEN=$(read_from_tty "Enter Telegram Bot Token: ")
[[ -z "$TG_CHAT_ID" ]] && TG_CHAT_ID=$(read_from_tty "Enter Telegram Admin Chat ID (numeric): ")

if [[ -z "$TG_BOT_TOKEN" || -z "$TG_CHAT_ID" ]]; then
  echo "❌ Telegram credentials cannot be empty"
  exit 1
fi

if ! [[ "$TG_CHAT_ID" =~ ^[0-9]+$ ]]; then
  echo "❌ Chat ID must be numeric"
  exit 1
fi

INSTALL_DIR="/opt/iPWGBackup"
BACKUP_DIR="/var/backups/ipwgbackup"
CONFIG_FILE="$INSTALL_DIR/config.env"

echo ""
echo "📦 Installing dependencies..."
apt update -y
apt install -y python3 python3-pip git curl tar systemd
pip3 install --upgrade pip
pip3 install requests

echo ""
echo "📥 Installing iPWGBackup..."
if [[ -d "$INSTALL_DIR" ]]; then
  cd "$INSTALL_DIR" && git pull
else
  git clone https://github.com/iPmartNetwork/iPWGBackup-v2.git "$INSTALL_DIR"
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

echo ""
echo "⚙️ Writing config..."
cat > "$CONFIG_FILE" <<EOF
TG_BOT_TOKEN="$TG_BOT_TOKEN"
TG_CHAT_ID="$TG_CHAT_ID"
BACKUP_DIR="$BACKUP_DIR"
EOF
chmod 600 "$CONFIG_FILE"

# Backup service
cat > /etc/systemd/system/ipwgbackup.service <<EOF
[Unit]
Description=iPWGBackup Backup Service
After=network-online.target

[Service]
Type=oneshot
EnvironmentFile=$CONFIG_FILE
ExecStart=/usr/bin/python3 - <<PY
import os
from ipwgbackup.core.backup import run_backup
from ipwgbackup.targets.telegram import send_telegram
p = run_backup()
send_telegram(os.environ["TG_BOT_TOKEN"], os.environ["TG_CHAT_ID"], p)
PY
EOF

# Timer
cat > /etc/systemd/system/ipwgbackup.timer <<EOF
[Timer]
OnBootSec=5min
OnUnitActiveSec=12h
Persistent=true
[Install]
WantedBy=timers.target
EOF

# Telegram bot service
cat > /etc/systemd/system/ipwgbackup-bot.service <<EOF
[Unit]
Description=iPWGBackup Telegram Bot
After=network-online.target

[Service]
Type=simple
EnvironmentFile=$CONFIG_FILE
ExecStart=/usr/bin/python3 - <<PY
import os
from ipwgbackup.targets.telegram_bot import start_bot
start_bot(os.environ["TG_BOT_TOKEN"], os.environ["TG_CHAT_ID"])
PY
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload

systemctl enable --now ipwgbackup.timer
systemctl enable --now ipwgbackup-bot.service

echo ""
echo "✅ Installation completed successfully!"
echo ""
echo "Telegram commands:"
echo "  /backup   → Run manual backup"
echo ""
echo "System commands:"
echo "  systemctl status ipwgbackup-bot"
echo "  systemctl status ipwgbackup"
