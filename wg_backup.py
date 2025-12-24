#!/usr/bin/env python3
# ====================================================
# iPWGBackup Main Script (v3) – Works for Manual and Auto Backup
# ====================================================
import os
import sys
import requests
from datetime import datetime

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
    backup_filename = f"/tmp/iPWGBackup_{timestamp}.txt"
    
    # Example backup content (replace with real backup commands)
    with open(backup_filename, "w") as f:
        f.write(f"Backup created at {timestamp}\n")
        f.write("This is a real backup file.\n")
    
    print(f"Backup file created: {backup_filename}")
    
    # Send to Telegram
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendDocument"
    files = {"document": open(backup_filename, "rb")}
    data = {"chat_id": TELEGRAM_CHAT_ID, "caption": f"iPWGBackup: {timestamp}"}
    
    response = requests.post(url, files=files, data=data)
    if response.status_code == 200:
        print("✅ Backup sent to Telegram successfully")
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
