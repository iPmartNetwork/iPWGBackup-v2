
import argparse
from ipwgbackup.core.backup import run_backup
from ipwgbackup.core.restore import restore_backup

def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd")

    sub.add_parser("backup")
    r = sub.add_parser("restore")
    r.add_argument("file")
    r.add_argument("--dry-run", action="store_true")

    args = parser.parse_args()

    if args.cmd == "backup":
        print(run_backup())
    elif args.cmd == "restore":
        print(restore_backup(args.file, args.dry_run))
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
