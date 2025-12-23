import socket
import datetime
import subprocess

def get_wg_version():
    try:
        return subprocess.check_output(["wg", "--version"]).decode().strip()
    except Exception:
        return "unknown"

def generate_metadata(interfaces: list) -> dict:
    return {
        "hostname": socket.gethostname(),
        "created_at": datetime.datetime.utcnow().isoformat(),
        "interfaces": interfaces,
        "wg_version": get_wg_version()
    }
