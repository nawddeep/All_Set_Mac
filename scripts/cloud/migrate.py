"""Brings the wallpaper database's schema up to date, one numbered step at a time.

    /usr/bin/python3 scripts/cloud/migrate.py            # apply what's pending
    /usr/bin/python3 scripts/cloud/migrate.py --status   # list applied and pending, change nothing

The steps are the files in scripts/cloud/migrations/, applied in name order
(0001_initial.sql, 0002_…). Each runs in a transaction of its own, under the
catalog lock (catalog_lock.py), together with a row in `schema_migrations`
recording it: a step that fails changes nothing and is not recorded, and the
run stops there. Steps already recorded are never run again.

To change the schema: add the next numbered file. Never edit one that has
been applied anywhere.

A database made before this existed (the table is there, `schema_migrations`
isn't) is adopted by the first run: 0001 only creates what's missing.

Connects like sync_catalog.py: DATABASE_URL from the environment or
scripts/cloud/.env, else the keychain password, through the SSH tunnel
(scripts/cloud/tunnel.sh). --url connects somewhere else.

Tests: /usr/bin/python3 -m unittest scripts/cloud/test_migrate.py
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import catalog_lock  # noqa: E402

MIGRATIONS = os.path.join(HERE, "migrations")
PSQL = "/opt/homebrew/bin/psql" if os.path.exists("/opt/homebrew/bin/psql") else "psql"
TIMEOUT = 300  # seconds for one step


class MigrationError(Exception):
    pass


def run(url, script, psql=None):
    try:
        result = subprocess.run([psql or PSQL, url, "-q", "-At", "-v", "ON_ERROR_STOP=1", "-f", "-"],
                                input=script, capture_output=True, text=True, timeout=TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise MigrationError(str(error))
    if result.returncode != 0:
        raise MigrationError(result.stderr.strip() or f"psql exited {result.returncode}")
    return result.stdout.splitlines()


def steps(directory=None):
    """The migration files, in the order they apply."""
    directory = directory or MIGRATIONS
    return sorted(name for name in os.listdir(directory) if name.endswith(".sql"))


def applied(url, psql=None):
    run(url, "create table if not exists schema_migrations "
             "(version text primary key, applied_at timestamptz not null default now());", psql)
    return set(run(url, "select version from schema_migrations;", psql))


def pending(url, psql=None, directory=None):
    done = applied(url, psql)
    return [name for name in steps(directory) if name not in done]


def apply(url, psql=None, directory=None):
    """Applies every pending step in order and returns their names. Raises
    MigrationError at the first that fails; that one and those after it are
    left unapplied."""
    directory = directory or MIGRATIONS
    finished = []
    for name in pending(url, psql, directory):
        with open(os.path.join(directory, name)) as handle:
            body = handle.read()
        version = name.replace("'", "''")
        try:
            run(url, f"begin;\nselect pg_advisory_xact_lock({catalog_lock.ASSET_LOCK});\n{body}\n"
                     f"insert into schema_migrations (version) values ('{version}');\ncommit;\n", psql)
        except MigrationError as error:
            raise MigrationError(f"{name} failed and was rolled back: {error}")
        finished.append(name)
    return finished


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--status", action="store_true", help="list applied and pending steps; change nothing")
    parser.add_argument("--url", help="database to connect to (default: as sync_catalog.py does)")
    args = parser.parse_args()
    url = args.url
    if not url:
        import sync_catalog
        url = sync_catalog.database_url(sync_catalog.load_env(os.path.join(HERE, ".env")))
    if not url:
        sys.exit("No database to connect to: set DATABASE_URL, or pass --url.")
    try:
        if args.status:
            done = applied(url)
            for name in steps():
                print(f"{'applied' if name in done else 'pending'}  {name}")
            return
        finished = apply(url)
    except MigrationError as error:
        sys.exit(str(error))
    print("\n".join(f"applied  {name}" for name in finished) if finished else "Nothing to apply: the schema is up to date.")


if __name__ == "__main__":
    main()
