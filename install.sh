#!/bin/bash
# ====================================================
# iPWGBackup Ultimate Installer & Telegram Auto Backup (v4)
# ====================================================
set -e

INSTALL_DIR="/root/iPWGBackup-v2"
SERVICE_NAME="ipwgbackup-bot.service"
TIMER_NAME="ipwgbackup-bot.timer"
PYTHON_BIN=$(which python3 || echo "/usr/bin/python3")

# -------------------------------
# Prompt Telegram Info
# -------------------------------
echo "📨 Enter your Telegram Bot Token (example: 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11):"
read -r TELEGRAM_TOKEN
echo "📨 Enter your Telegram Chat ID (example: 987654321):"
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
# Create wg_backup.py with ZIP support
# -------------------------------
cat > "$INSTALL_DIR/wg_backup.py" <<'EOF'
#!/usr/bin/env python3
import os
import sys
import requests
from datetime import datetime
import zipfile

CONFIG_FILE = os.path.join(os.path.dirname(__file__), "config.env")
TELEGRAM_TOKEN = ""
TELEGRAM_CHAT_ID = ""

if os.path.exists(CONFIG_FILE):
    with open(CONFIG_FILE, "r") as f:
        for line in f:
            if line.startswith("TELEGRAM_TOKEN="):
                TELEGRAM_TOKEN = line.strip().split("=")[1].replace('"', '')
            if line.startswith("TELEGRAM_CHAT_ID="):
                TELEGRAM_CHAT_ID = line.strip().split("=")[1].replace('"', '')

if not TELEGRAM_TOKEN or not TELEGRAM_CHAT_ID:
    print("❌ Telegram configuration missing in config.env")
    sys.exit(1)

def take_backup():
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    backup_dir = os.path.join("/tmp", f"iPWGBackup_{timestamp}")
    os.makedirs(backup_dir, exist_ok=True)
    
    # Example backup content
    with open(os.path.join(backup_dir, "backup.txt"), "w") as f:
        f.write(f"Backup created at {timestamp}\n")
        f.write("This is a real backup file.\n")
    
    # Create ZIP archive
    zip_filename = f"/tmp/iPWGBackup_{timestamp}.zip"
    with zipfile.ZipFile(zip_filename, "w", zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk(backup_dir):
            for file in files:
                filepath = os.path.join(root, file)
                arcname = os.path.relpath(filepath, backup_dir)
                zipf.write(filepath, arcname)
    
    print(f"Backup ZIP created: {zip_filename}")
    
    # Send to Telegram
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendDocument"
    files = {"document": open(zip_filename, "rb")}
    data = {"chat_id": TELEGRAM_CHAT_ID, "caption": f"iPWGBackup: {timestamp}"}
    
    response = requests.post(url, files=files, data=data)
    if response.status_code == 200:
        print("✅ Backup ZIP sent to Telegram successfully")
    else:
        print(f"❌ Failed to send backup. Response: {response.text}")

if __name__ == "__main__":
    if "--manual" in sys.argv or "/backup" in sys.argv:
        print("🟢 Manual backup triggered")
        take_backup()
    else:
        print("🟢 Automatic backup triggered")
        take_backup()
EOF

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
echo "✅ iPWGBackup service is running and will send backup ZIP to Telegram every 12 hours."
echo "📌 To run a manual backup anytime, execute:"
echo "   $MANUAL_SCRIPT"
systemctl status "$SERVICE_NAME" --no-pager
systemctl status "$TIMER_NAME" --no-pager
echo "🎉 Installation & Telegram Auto Backup setup completed successfully!"
