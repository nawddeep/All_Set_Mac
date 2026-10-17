"""Puts the public wallpaper server under launchd, so it starts at login and
comes back if it stops. Run through the server script, which knows the folder:

    scripts/cloud/server.sh install
    scripts/cloud/server.sh uninstall
    /usr/bin/python3 scripts/cloud/install_public_server.py --print DIR --server PATH --root DIR   # write the files; install nothing

Three launch agents, each a `server.sh` command:

  com.allset.public-postgres   `server.sh postgres`: the database, restarted whenever it exits
  com.allset.public-web        `server.sh serve`: Caddy on the public folder, the same
  com.allset.public-backup     `server.sh backup`, every night at 03:30: a backup
                               into the folder's backups/, then a restore of it
                               into scratch copies to prove it restores

Their output goes to <folder>/logs/<name>.log. No password is in these files:
the commands read it from the folder's database.env.

Launch agents run while this account is logged in. A Mac that restarts needs
automatic login for it, and must not sleep (System Settings › Energy).

Tests: /usr/bin/python3 -m unittest scripts/cloud/test_install_public_server.py
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from install_services import launchctl, write  # noqa: E402

LABELS = ("com.allset.public-postgres", "com.allset.public-web", "com.allset.public-backup")
COMMANDS = ("postgres", "serve", "backup")


def agents(server, root, backup_hour=3, backup_minute=30):
    """The launch agents, by label, as property-list dictionaries."""
    def agent(label, command, **extra):
        log = os.path.join(root, "logs", label.split(".")[-1] + ".log")
        return {"Label": label, "ProgramArguments": ["/bin/bash", server, command], "WorkingDirectory": root,
                "StandardOutPath": log, "StandardErrorPath": log,
                # Homebrew's caddy and psql; the folder, wherever it is.
                "EnvironmentVariables": {"PATH": "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin",
                                         "ALLSET_SERVER_DIR": root},
                "ProcessType": "Background", **extra}

    # Restarted whenever it exits, but not faster than every 10 s if it can't stay up.
    kept = {"RunAtLoad": True, "KeepAlive": True, "ThrottleInterval": 10}
    return {
        LABELS[0]: agent(LABELS[0], COMMANDS[0], **kept),
        LABELS[1]: agent(LABELS[1], COMMANDS[1], **kept),
        LABELS[2]: agent(LABELS[2], COMMANDS[2], StartCalendarInterval={"Hour": backup_hour, "Minute": backup_minute}),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--server", help="the server script (scripts/cloud/server.sh)")
    parser.add_argument("--root", help="the server folder")
    parser.add_argument("--print", dest="folder", help="write the launch agents to this folder and install nothing")
    parser.add_argument("--uninstall", action="store_true", help="stop and remove the launch agents")
    args = parser.parse_args()
    installed = os.path.join(os.path.expanduser("~"), "Library/LaunchAgents")
    domain = f"gui/{os.getuid()}"

    if args.uninstall:
        for label in LABELS:
            launchctl("bootout", f"{domain}/{label}")
            path = os.path.join(installed, label + ".plist")
            if os.path.exists(path):
                os.remove(path)
                print(f"removed {label}")
        return

    if not args.server or not args.root:
        sys.exit("Say which server: --server <server.sh> --root <its folder> (scripts/cloud/server.sh install does).")
    made = agents(os.path.abspath(args.server), os.path.abspath(args.root))
    if args.folder:
        for path in write(args.folder, made):
            print(path)
        return
    os.makedirs(os.path.join(args.root, "logs"), exist_ok=True)
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
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
