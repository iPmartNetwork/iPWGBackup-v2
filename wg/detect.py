
import os

WG_PATHS = ["/etc/wireguard", "/usr/local/etc/wireguard"]

def detect_wg_path() -> str:
    for path in WG_PATHS:
        if os.path.isdir(path):
            return path
    raise FileNotFoundError("WireGuard path not found")
