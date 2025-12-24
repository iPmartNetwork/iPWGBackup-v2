#!/bin/bash
set -e

INSTALL_DIR="/opt/iPWGBackup"
BACKUP_DIR="/var/backups/ipwgbackup"
CONFIG_FILE="$INSTALL_DIR/config.env"

echo "==============================="
echo " iPWGBackup Auto Installer"
echo "==============================="

# -------------------------
# Root check
# -------------------------
if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root"
  exit 1
fi

# -------------------------
# Read from TTY (safe for curl | bash)
# -------------------------
read_from_tty() {
  local v
  read -r -p "$1" v </dev/tty
  echo "$v"
}

# -------------------------
# Detect existing install
# -------------------------
if [[ -d "$INSTALL_DIR" && -f "$CONFIG_FILE" ]]; then
  echo ""
  echo "🟡 Existing installation detected"
  echo "1) Update iPWGBackup (recommended)"
  echo "2) Reinstall (keep config)"
  echo "3) Exit"
  read -r -p "Select option [1-3]: " OPT </dev/tty

  case "$OPT" in
    1)
      echo "🔄 Updating iPWGBackup..."
      cd "$INSTALL_DIR"
      git fetch --all
      git reset --hard origin/master

      pip3 install -r requirements.txt --upgrade || true

      systemctl daemon-reexec
      systemctl daemon-reload
      systemctl restart ipwgbackup.service || true
      systemctl restart ipwgbackup-bot.service || true

      echo "✅ Update completed successfully!"
      exit 0
      ;;
    2)
      echo "🔁 Reinstalling (config preserved)..."
      ;;
    *)
      exit 0
      ;;
  esac
fi

# -------------------------
# Telegram config (only if not exists)
# -------------------------
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo ""
  echo "🤖 Telegram Configuration"

  TG_BOT_TOKEN=$(read_from_tty "Enter Telegram Bot Token: ")
  TG_CHAT_ID=$(read_from_tty "Enter Telegram Admin Chat ID (numeric): ")

  if [[ -z "$TG_BOT_TOKEN" || -z "$TG_CHAT_ID" ]]; then
    echo "❌ Telegram credentials cannot be empty"
    exit 1
  fi

  if ! [[ "$TG_CHAT_ID" =~ ^[0-9]+$ ]]; then
    echo "❌ Chat ID must be numeric"
    exit 1
  fi
fi

# -------------------------
# Install dependencies
# -------------------------
echo ""
echo "📦 Installing dependencies..."

apt update -y
apt install -y python3 python3-pip git curl tar systemd
pip3 install --upgrade pip
pip3 install requests

# -------------------------
# Install project
# -------------------------
echo ""
echo "📥 Installing iPWGBackup..."

if [[ -d "$INSTALL_DIR" ]]; then
  cd "$INSTALL_DIR"
  git pull
else
  git clone https://github.com/iPmartNetwork/iPWGBackup-v2.git "$INSTALL_DIR"
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# -------------------------
# Write config.env (first install only)
# -------------------------
if [[ ! -f "$CONFIG_FILE" ]]; then
  cat > "$CONFIG_FILE" <<EOF
TG_BOT_TOKEN="$TG_BOT_TOKEN"
TG_CHAT_ID="$TG_CHAT_ID"
BACKUP_DIR="$BACKUP_DIR"
EOF
  chmod 600 "$CONFIG_FILE"
else
  echo "🔒 Existing config preserved"
fi

# -------------------------
# systemd backup service
# -------------------------
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

# -------------------------
# systemd timer (12h)
# -------------------------
cat > /etc/systemd/system/ipwgbackup.timer <<EOF
[Timer]
OnBootSec=5min
OnUnitActiveSec=12h
Persistent=true

[Install]
WantedBy=timers.target
EOF

# -------------------------
# Telegram bot service (/backup)
# -------------------------
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

# -------------------------
# Enable services
# -------------------------
systemctl daemon-reexec
systemctl daemon-reload

systemctl enable --now ipwgbackup.timer
systemctl enable --now ipwgbackup-bot.service

# -------------------------
# Done
# -------------------------
echo ""
echo "✅ iPWGBackup installed successfully!"
echo ""
echo "Telegram commands:"
echo "  /backup   → Run manual backup"
echo ""
echo "System commands:"
echo "  systemctl status ipwgbackup"
echo "  systemctl status ipwgbackup-bot"
echo "  systemctl list-timers | grep ipwgbackup"
