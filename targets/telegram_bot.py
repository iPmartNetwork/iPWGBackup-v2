import time
import requests
from ipwgbackup.core.backup import run_backup

API = "https://api.telegram.org/bot{}/{}"

def send_message(token, chat_id, text):
    requests.post(
        API.format(token, "sendMessage"),
        data={"chat_id": chat_id, "text": text}
    )

def send_file(token, chat_id, path):
    with open(path, "rb") as f:
        requests.post(
            API.format(token, "sendDocument"),
            data={"chat_id": chat_id},
            files={"document": f}
        )

def start_bot(token, admin_id):
    offset = None
    send_message(token, admin_id, "🤖 iPWGBackup bot started")

    while True:
        r = requests.get(
            API.format(token, "getUpdates"),
            params={"timeout": 60, "offset": offset}
        ).json()

        for upd in r.get("result", []):
            offset = upd["update_id"] + 1
            msg = upd.get("message", {})
            text = msg.get("text", "")
            chat = str(msg.get("chat", {}).get("id"))

            if chat != str(admin_id):
                send_message(token, chat, "⛔ Access denied")
                continue

            if text == "/backup":
                send_message(token, admin_id, "⏳ Backup started...")
                try:
                    path = run_backup()
                    send_file(token, admin_id, path)
                    send_message(token, admin_id, "✅ Backup completed")
                except Exception as e:
                    send_message(token, admin_id, f"❌ Backup failed:\n{e}")

        time.sleep(2)
