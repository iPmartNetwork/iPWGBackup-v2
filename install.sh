#!/bin/bash
# ====================================================
# iPWGBackup Auto Fix & Update Script
# ====================================================
# This script updates iPWGBackup, installs required Python packages,
# and ensures the systemd service is properly set up.
# ====================================================

set -e

# -------------------------------
# Variables
# -------------------------------
INSTALL_DIR="/root/iPWGBackup-v2"
SERVICE_NAME="ipwgbackup-bot.service"
PYTHON_BIN=$(which python3 || echo "/usr/bin/python3")

# -------------------------------
# Check Installation Directory
# -------------------------------
if [ ! -d "$INSTALL_DIR" ]; then
    echo "❌ Installation directory not found: $INSTALL_DIR"
    echo "Please make sure iPWGBackup is installed correctly."
    exit 1
fi

cd "$INSTALL_DIR"

# -------------------------------
# Update Repository
# -------------------------------
echo "🔄 Updating iPWGBackup repository..."
git fetch origin
git reset --hard origin/master
echo "✅ Repository updated."

# -------------------------------
# Install Python Requirements
# -------------------------------
REQ_FILE="$INSTALL_DIR/requirements.txt"

if [ -f "$REQ_FILE" ]; then
    echo "📦 Installing Python packages..."
    $PYTHON_BIN -m pip install --upgrade pip
    $PYTHON_BIN -m pip install -r "$REQ_FILE"
    echo "✅ Python packages installed."
else
    echo "⚠️ requirements.txt not found in $INSTALL_DIR. Skipping Python packages installation."
fi

# -------------------------------
# Setup systemd Service
# -------------------------------
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"

echo "🔧 Setting up systemd service..."

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=iPWGBackup Bot Service
After=network.target

[Service]
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON_BIN $INSTALL_DIR/wg_backup.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon and enable service
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

# -------------------------------
# Final Status
# -------------------------------
echo "✅ iPWGBackup service is now running."
systemctl status "$SERVICE_NAME" --no-pager
echo "🎉 Update and service setup completed successfully!"
