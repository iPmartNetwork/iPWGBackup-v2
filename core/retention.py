import os

MAX_BACKUPS = 10

def apply_retention(backup_dir: str):
    backups = sorted(
        [f for f in os.listdir(backup_dir) if f.endswith(".tar.gz")],
        reverse=True
    )
    for old in backups[MAX_BACKUPS:]:
        os.remove(os.path.join(backup_dir, old))
