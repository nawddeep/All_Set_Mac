"""Puts the wallpaper server's services under launchd, so they start at login
and come back if they stop, and schedules the nightly backup.

    /usr/bin/python3 scripts/cloud/install_services.py --backups /Volumes/Backup/AllSet
    /usr/bin/python3 scripts/cloud/install_services.py --print DIR --backups ...   # write the files there; install nothing
    /usr/bin/python3 scripts/cloud/install_services.py --uninstall

Run on the server, as the account that owns ~/AllSetStorage (the same one
Postgres and Caddy run under). Installs three launch agents:

  com.allset.delete-service    delete_service.py, restarted whenever it exits
  com.allset.catalog-service   catalog_service.py, the same (it waits for
                               Tailscale by exiting and being restarted)
  com.allset.backup            backup.py backup --drill, every night at 03:30:
                               a backup, then a restore of it into scratch
                               copies to prove it restores

Their output goes to ~/Library/Logs/AllSet/<name>.log. A failed drill is in
backup.log, and `launchctl list com.allset.backup` shows its last exit code.

Launch agents run while that account is logged in. A server that restarts
needs automatic login for it (as Homebrew's Postgres already does), or these
moved to /Library/LaunchDaemons by hand.

Without --backups no backup is scheduled, and it says so.

Tests: /usr/bin/python3 -m unittest scripts/cloud/test_install_services.py
"""
import argparse
import os
import plistlib
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PYTHON = "/usr/bin/python3"
LABELS = ("com.allset.delete-service", "com.allset.catalog-service", "com.allset.backup")


def agents(home, backups=None, include_quarantined=False, backup_hour=3, backup_minute=30):
    """The launch agents, by label, as property-list dictionaries."""
    logs = os.path.join(home, "Library/Logs/AllSet")

    def agent(label, arguments, **extra):
        log = os.path.join(logs, label.split(".")[-1] + ".log")
        return {"Label": label, "ProgramArguments": [PYTHON] + arguments, "WorkingDirectory": home,
                "StandardOutPath": log, "StandardErrorPath": log,
                # Homebrew's psql and pg_dump, and the system's rsync.
                "EnvironmentVariables": {"PATH": "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"},
                "ProcessType": "Background", **extra}

    # Restarted whenever it exits, but not faster than every 10 s if it can't stay up.
    kept = {"RunAtLoad": True, "KeepAlive": True, "ThrottleInterval": 10}
    catalog = [os.path.join(HERE, "catalog_service.py")] + (["--include-quarantined"] if include_quarantined else [])
    made = {
        LABELS[0]: agent(LABELS[0], [os.path.join(HERE, "delete_service.py")], **kept),
        LABELS[1]: agent(LABELS[1], catalog, **kept),
    }
    if backups:
        made[LABELS[2]] = agent(LABELS[2], [os.path.join(HERE, "backup.py"), "backup", backups, "--drill"],
                                StartCalendarInterval={"Hour": backup_hour, "Minute": backup_minute})
    return made


def write(folder, made):
    os.makedirs(folder, exist_ok=True)
    paths = []
    for label, body in made.items():
        path = os.path.join(folder, label + ".plist")
        with open(path, "wb") as handle:
            plistlib.dump(body, handle)
        paths.append(path)
    return paths


def launchctl(*arguments):
    return subprocess.run(["/bin/launchctl", *arguments], capture_output=True, text=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--backups", help="folder for the nightly backups, on another disk")
    parser.add_argument("--include-quarantined", action="store_true",
                        help="start the catalog service with --include-quarantined (your own tester only)")
    parser.add_argument("--print", dest="folder", help="write the launch agents to this folder and install nothing")
    parser.add_argument("--uninstall", action="store_true", help="stop and remove the launch agents")
    args = parser.parse_args()
    home = os.path.expanduser("~")
    installed = os.path.join(home, "Library/LaunchAgents")
    domain = f"gui/{os.getuid()}"

    if args.uninstall:
        for label in LABELS:
            launchctl("bootout", f"{domain}/{label}")
            path = os.path.join(installed, label + ".plist")
            if os.path.exists(path):
                os.remove(path)
                print(f"removed {label}")
        return

    made = agents(home, backups=args.backups, include_quarantined=args.include_quarantined)
    if args.folder:
        for path in write(args.folder, made):
            print(path)
        return
    os.makedirs(os.path.join(home, "Library/Logs/AllSet"), exist_ok=True)
    failed = False
    for path in write(installed, made):
        label = os.path.basename(path)[:-len(".plist")]
        launchctl("bootout", f"{domain}/{label}")  # replace one already loaded
        loaded = launchctl("bootstrap", domain, path)
        if loaded.returncode != 0:
            failed = True
            print(f"couldn't load {label}: {loaded.stderr.strip()}", file=sys.stderr)
        else:
            print(f"loaded {label}")
    if not args.backups:
        print("No backup scheduled: run again with --backups <folder on another disk>.")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
