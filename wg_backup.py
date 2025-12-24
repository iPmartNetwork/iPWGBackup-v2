#!/usr/bin/env python3
# ====================================================
# iPWGBackup Main Script (v4) – Sends Backup as ZIP to Telegram
# ====================================================
import os
import sys
import requests
from datetime import datetime
import zipfile

# Load Telegram configuration
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

# Backup function
def take_backup():
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    backup_dir = os.path.join("/tmp", f"iPWGBackup_{timestamp}")
    os.makedirs(backup_dir, exist_ok=True)
    
    # Example backup content (replace with real backup commands/files)
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
    
    # Send ZIP to Telegram
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendDocument"
    files = {"document": open(zip_filename, "rb")}
    data = {"chat_id": TELEGRAM_CHAT_ID, "caption": f"iPWGBackup: {timestamp}"}
    
    response = requests.post(url, files=files, data=data)
    if response.status_code == 200:
        print("✅ Backup ZIP sent to Telegram successfully")
    else:
        print(f"❌ Failed to send backup. Response: {response.text}")

# Main execution
if __name__ == "__main__":
    if "--manual" in sys.argv or "/backup" in sys.argv:
        print("🟢 Manual backup triggered")
        take_backup()
    else:
        print("🟢 Automatic backup triggered")
        take_backup()
