import os
import tarfile
import json
from ipwgbackup.wg.detect import detect_wg_path
from ipwgbackup.wg.export import export_configs
from ipwgbackup.security.masker import mask_wg_config
from ipwgbackup.security.checksum import sha256sum
from ipwgbackup.core.metadata import generate_metadata

BACKUP_DIR = "/var/backups/ipwgbackup"

def run_backup():
    os.makedirs(BACKUP_DIR, exist_ok=True)

    wg_path = detect_wg_path()
    configs = export_configs(wg_path)

    masked = {k: mask_wg_config(v) for k, v in configs.items()}
    interfaces = list(masked.keys())
    metadata = generate_metadata(interfaces)

    name = f"wg_backup_{metadata['created_at'].replace(':','_')}.tar.gz"
    path = os.path.join(BACKUP_DIR, name)

    with tarfile.open(path, "w:gz") as tar:
        for cfg, content in masked.items():
            tmp = f"/tmp/{cfg}"
            with open(tmp, "w") as f:
                f.write(content)
            tar.add(tmp, arcname=cfg)
            os.remove(tmp)

        meta_tmp = "/tmp/metadata.json"
        with open(meta_tmp, "w") as f:
            json.dump(metadata, f, indent=2)
        tar.add(meta_tmp, arcname="metadata.json")
        os.remove(meta_tmp)

    with open(path + ".sha256", "w") as f:
        f.write(sha256sum(path))

    return path
