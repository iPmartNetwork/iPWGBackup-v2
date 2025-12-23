
import tarfile, os, json, subprocess

def restore_backup(archive_path: str, dry_run=False):
    extract_dir = "/tmp/ipwgbackup_restore"
    os.makedirs(extract_dir, exist_ok=True)

    with tarfile.open(archive_path, "r:gz") as tar:
        tar.extractall(extract_dir)

    if dry_run:
        return os.listdir(extract_dir)

    for f in os.listdir(extract_dir):
        if f.endswith(".conf"):
            src = os.path.join(extract_dir, f)
            dst = os.path.join("/etc/wireguard", f)
            os.replace(src, dst)

    subprocess.run(["systemctl", "restart", "wg-quick@wg0"], check=False)
    return True
