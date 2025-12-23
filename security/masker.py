import re

SENSITIVE_KEYS = ["PrivateKey", "PresharedKey"]

def mask_wg_config(config_text: str) -> str:
    masked = []
    for line in config_text.splitlines():
        if any(k in line for k in SENSITIVE_KEYS):
            key = line.split("=")[0]
            masked.append(f"{key}=MASKED")
        else:
            masked.append(line)
    return "\n".join(masked
