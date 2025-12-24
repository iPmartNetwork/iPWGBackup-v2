#!/bin/bash
# ====================================================
# iPWGBackup Ultimate Installer & Telegram Auto Backup
# ====================================================
set -e

INSTALL_DIR="/root/iPWGBackup-v2"
SERVICE_NAME="ipwgbackup-bot.service"
TIMER_NAME="ipwgbackup-bot.timer"
PYTHON_BIN=$(which python3 || echo "/usr/bin/python3")

# -------------------------------
# Prompt Telegram Info
# -------------------------------
echo "📨 Enter your Telegram Bot Token:"
read -r TELEGRAM_TOKEN
echo "📨 Enter your Telegram Chat ID:"
read -r TELEGRAM_CHAT_ID

# -------------------------------
# Clone or Update Repository
# -------------------------------
if [ ! -d "$INSTALL_DIR" ]; then
    echo "📥 Cloning iPWGBackup repository..."
    git clone https://github.com/iPmartNetwork/iPWGBackup-v2.git "$INSTALL_DIR"
else
    echo "🔄 Repository exists. Updating..."
    cd "$INSTALL_DIR"
    git fetch origin
    git reset --hard origin/master
fi

cd "$INSTALL_DIR"

# -------------------------------
# Write Telegram Config
# -------------------------------
cat > "$INSTALL_DIR/config.env" <<EOF
TELEGRAM_TOKEN="$TELEGRAM_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
EOF

# -------------------------------
# Install Python Requirements
# -------------------------------
REQ_FILE="$INSTALL_DIR/requirements.txt"
if [ -f "$REQ_FILE" ]; then
    echo "📦 Installing Python packages..."
    $PYTHON_BIN -m pip install --upgrade pip
    $PYTHON_BIN -m pip install -r "$REQ_FILE"
else
    echo "⚠️ requirements.txt not found. Skipping Python packages installation."
fi

# -------------------------------
# Setup systemd Service
# -------------------------------
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=iPWGBackup Bot Service
After=network.target

[Service]
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON_BIN $INSTALL_DIR/wg_backup.py
Restart=always
EnvironmentFile=$INSTALL_DIR/config.env

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

# -------------------------------
# Setup Auto Backup Every 12 Hours via systemd Timer
# -------------------------------
TIMER_FILE="/etc/systemd/system/$TIMER_NAME"
cat > "$TIMER_FILE" <<EOF
[Unit]
Description=Run iPWGBackup Bot every 12 hours

[Timer]
OnCalendar=*-*-* 00,12:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable "$TIMER_NAME"
systemctl start "$TIMER_NAME"

# -------------------------------
# Setup Manual Backup Script
# -------------------------------
MANUAL_SCRIPT="$INSTALL_DIR/backup_now.sh"
cat > "$MANUAL_SCRIPT" <<'EOF'
#!/bin/bash
INSTALL_DIR="/root/iPWGBackup-v2"
PYTHON_BIN=$(which python3 || echo "/usr/bin/python3")

if [ ! -f "$INSTALL_DIR/wg_backup.py" ]; then
    echo "❌ wg_backup.py not found in $INSTALL_DIR"
    exit 1
fi

if [ ! -f "$INSTALL_DIR/config.env" ]; then
    echo "❌ config.env not found. Make sure Telegram info is set."
    exit 1
fi

source "$INSTALL_DIR/config.env"

echo "📤 Running manual backup..."
$PYTHON_BIN "$INSTALL_DIR/wg_backup.py" --manual
echo "✅ Manual backup completed."
EOF

chmod +x "$MANUAL_SCRIPT"

# -------------------------------
# Final Status
# -------------------------------
echo "✅ iPWGBackup service is running and will send backup to Telegram every 12 hours."
echo "📌 To run a manual backup anytime, execute:"
echo "   $MANUAL_SCRIPT"
systemctl status "$SERVICE_NAME" --no-pager
systemctl status "$TIMER_NAME" --no-pager
echo "🎉 Installation & Telegram Auto Backup setup completed successfully!"
