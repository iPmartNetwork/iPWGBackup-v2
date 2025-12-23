
from ipwgbackup.security.checksum import sha256sum

def validate_backup(archive_path: str) -> bool:
    with open(archive_path + ".sha256") as f:
        expected = f.read().strip()
    return sha256sum(archive_path) == expected
