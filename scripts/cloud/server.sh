#!/bin/bash
# The public wallpaper server, all of it on one Mac: its own Postgres 17, the
# private storage folder, and the public folder a web server serves. No
# Tailscale, no SSH tunnel: everything here talks to 127.0.0.1.
#
#   scripts/cloud/server.sh start     # make the folder if needed, start Postgres, apply migrations
#   scripts/cloud/server.sh stop
#   scripts/cloud/server.sh status
#   scripts/cloud/server.sh url       # the DATABASE_URL, for --url on the other scripts
#   scripts/cloud/server.sh load [library folder]   # a library's list and files into the database and storage
#   scripts/cloud/server.sh sync      # only the list (sync_catalog.py)
#   scripts/cloud/server.sh sample    # three made-up wallpapers that may be published (dev_sample.py)
#   scripts/cloud/server.sh publish [--dry-run]     # build public/ (publish_catalog.py)
#   scripts/cloud/server.sh serve     # serve public/ (Caddyfile.public), until ctrl-C
#   scripts/cloud/server.sh backup    # a backup into backups/, restored and checked (backup.py)
#   scripts/cloud/server.sh backup-db # only the database, a small pg_dump file into backups/db/ (keeps the last 14)
#   scripts/cloud/server.sh key create|revoke|delete|list [name]   # access keys for the app's key screen
#   scripts/cloud/server.sh api       # the key screen's service (catalog_service.py), until ctrl-C
#   scripts/cloud/server.sh install   # start Postgres, the web server and the key service at login, back up nightly
#   scripts/cloud/server.sh uninstall
#
# The folder is $ALLSET_SERVER_DIR (default ~/Downloads/allSetServer):
#
#   postgres/            the database (never copy it while Postgres runs)
#   storage/wallpapers/  private files, laid out like the app's library folder
#   public/              the only folder the web server serves
#   backups/  logs/
#   database.env         DATABASE_URL with the generated password (chmod 600)
#   server.env           optional: ALLSET_PUBLIC_SITE, ALLSET_PUBLIC_BIND,
#                        ALLSET_LIBRARY_LOCK and ALLSET_API_PORT for the web
#                        server (Caddyfile.public says what they mean)
#
# To move the server to another Mac: `stop` (and `uninstall`) here, copy the
# whole folder across, install postgresql@17 and caddy there, then `start`.
#
# Postgres listens on 127.0.0.1:5433 only. Not 5432: that port was the home
# server's while scripts/cloud/tunnel.sh ran, and the two must never be confused.
set -euo pipefail

ROOT="${ALLSET_SERVER_DIR:-$HOME/Downloads/allSetServer}"
BIN="${ALLSET_PG_BIN:-/opt/homebrew/opt/postgresql@17/bin}"
PORT="${ALLSET_SERVER_PG_PORT:-5433}"
DATA="$ROOT/postgres"
ENV_FILE="$ROOT/database.env"
HERE="$(cd "$(dirname "$0")" && pwd)"
SELF="$HERE/$(basename "$0")"

[[ -x "$BIN/initdb" ]] || { echo "Postgres 17 isn't installed: brew install postgresql@17" >&2; exit 1; }

running() {
    "$BIN/pg_ctl" -D "$DATA" status >/dev/null 2>&1
}

need_running() {
    running || { echo "Postgres is not running: '$0 start' first." >&2; exit 1; }
}

# Whether launchd keeps Postgres up (`install`): then it starts and stops it.
kept_by_launchd() {
    /bin/launchctl print "gui/$(id -u)/com.allset.public-postgres" >/dev/null 2>&1
}

database_url() {
    [[ -f "$ENV_FILE" ]] || { echo "No server folder yet: run '$0 start' first." >&2; exit 1; }
    sed -n 's/^DATABASE_URL=//p' "$ENV_FILE"
}

# First run only: the folders, a password of its own, the cluster and its settings.
create() {
    mkdir -p "$ROOT"/{storage/wallpapers,public,backups,logs}
    local password pwfile
    password=$(openssl rand -hex 24)
    pwfile=$(mktemp)
    printf '%s\n' "$password" >"$pwfile"
    "$BIN/initdb" -D "$DATA" -U allset --encoding=UTF8 --locale=C \
        --auth=scram-sha-256 --pwfile="$pwfile" >/dev/null
    rm -f "$pwfile"
    cat >>"$DATA/postgresql.conf" <<EOF

# All Set (scripts/cloud/server.sh): this Mac only, over TCP.
port = $PORT
listen_addresses = '127.0.0.1'
unix_socket_directories = ''
EOF
    (umask 077 && printf 'DATABASE_URL=postgres://allset:%s@127.0.0.1:%s/allset\n' "$password" "$PORT" >"$ENV_FILE")
}

start() {
    local fresh=0
    if [[ ! -f "$DATA/PG_VERSION" ]]; then
        if [[ -e "$DATA" && -n "$(ls -A "$DATA")" ]]; then
            echo "$DATA exists but isn't a Postgres database; not touching it." >&2
            exit 1
        fi
        create
        fresh=1
    fi
    # A folder brought over from another Mac may have come without the empty ones.
    mkdir -p "$ROOT"/{storage/wallpapers,public,backups,logs}
    if ! running; then
        if kept_by_launchd; then
            /bin/launchctl kickstart "gui/$(id -u)/com.allset.public-postgres" >/dev/null
            "$BIN/pg_isready" -h 127.0.0.1 -p "$PORT" -t 30 -q || { echo "Postgres didn't come up: see $ROOT/logs" >&2; exit 1; }
        else
            "$BIN/pg_ctl" -D "$DATA" -l "$ROOT/logs/postgres.log" -w start >/dev/null
        fi
    fi
    local url
    url=$(database_url)
    if [[ $fresh == 1 ]]; then
        "$BIN/psql" "${url%/allset}/postgres" -q -v ON_ERROR_STOP=1 -c "create database allset;"
    fi
    /usr/bin/python3 "$HERE/migrate.py" --url "$url"
    echo "Postgres is up on 127.0.0.1:$PORT, in $ROOT"
}

# The web server's address and interface, if server.env sets them.
web_settings() {
    if [[ -f "$ROOT/server.env" ]]; then
        local name value
        for name in ALLSET_PUBLIC_SITE ALLSET_PUBLIC_BIND ALLSET_LIBRARY_LOCK ALLSET_API_PORT; do
            value=$(sed -n "s/^$name=//p" "$ROOT/server.env" | tr -d '"' | head -1)
            if [[ -n "$value" ]]; then export "$name=$value"; fi
        done
    fi
    export ALLSET_PUBLIC_DIR="$ROOT/public"
}

case "${1:-}" in
    start) start ;;
    stop)
        if kept_by_launchd; then
            echo "launchd keeps Postgres running here: '$0 uninstall' first." >&2
            exit 1
        fi
        if running; then "$BIN/pg_ctl" -D "$DATA" -m fast -w stop >/dev/null; fi
        echo "Postgres is stopped."
        ;;
    status)
        if running; then
            echo "Postgres is up on 127.0.0.1:$PORT, in $ROOT"
            /usr/bin/python3 "$HERE/migrate.py" --status --url "$(database_url)"
        else
            echo "Postgres is not running."
            exit 1
        fi
        ;;
    url) database_url ;;
    sync)
        need_running
        DATABASE_URL="$(database_url)" /usr/bin/python3 "$HERE/sync_catalog.py"
        ;;
    load)
        need_running
        library="${2:-$HOME/Library/Application Support/AllSet/Wallpaper/Library}"
        DATABASE_URL="$(database_url)" ALLSET_LIBRARY="$library" /usr/bin/python3 "$HERE/sync_catalog.py"
        /usr/bin/python3 "$HERE/load_library.py" --url "$(database_url)" \
            --storage "$ROOT/storage/wallpapers" --library "$library"
        ;;
    sample)
        need_running
        /usr/bin/python3 "$HERE/dev_sample.py" --url "$(database_url)" --storage "$ROOT/storage/wallpapers"
        ;;
    publish)
        need_running
        shift
        /usr/bin/python3 "$HERE/publish_catalog.py" --url "$(database_url)" \
            --storage "$ROOT/storage/wallpapers" --public "$ROOT/public" "$@"
        ;;
    serve)
        command -v caddy >/dev/null || { echo "Caddy isn't installed: brew install caddy" >&2; exit 1; }
        web_settings
        echo "Serving $ROOT/public at ${ALLSET_PUBLIC_SITE:-http://127.0.0.1:8090}, library lock ${ALLSET_LIBRARY_LOCK:-off} (ctrl-C to stop)"
        exec caddy run --config "$HERE/Caddyfile.public" --adapter caddyfile
        ;;
    api)
        # In the foreground, for launchd (`install`). This Mac only: Caddy passes
        # it /api/activate and /api/me, and asks /me about each file once the
        # library is locked. Postgres needn't be up yet: until it is, it answers 503.
        web_settings
        DATABASE_URL="$(database_url)"
        export DATABASE_URL
        exec /usr/bin/python3 "$HERE/catalog_service.py" --host 127.0.0.1 --port "${ALLSET_API_PORT:-8083}"
        ;;
    key)
        need_running
        shift
        DATABASE_URL="$(database_url)" /usr/bin/python3 "$HERE/accounts.py" key "$@"
        ;;
    postgres)
        # In the foreground, for launchd (`install`): it restarts it if it stops.
        [[ -f "$DATA/PG_VERSION" ]] || { echo "No database yet: run '$0 start' first." >&2; exit 1; }
        # launchd sets no locale, and Postgres on macOS then refuses to start
        # ("postmaster became multithreaded during startup").
        export LC_ALL="${LC_ALL:-en_US.UTF-8}"
        exec "$BIN/postgres" -D "$DATA"
        ;;
    backup)
        need_running
        # Postgres 17's own pg_dump and psql, whatever else is installed.
        ALLSET_PG_BIN="$BIN" /usr/bin/python3 "$HERE/backup.py" backup "$ROOT/backups" --drill \
            --database-url "$(database_url)" --storage "$ROOT/storage/wallpapers"
        ;;
    backup-db)
        need_running
        dest="${ALLSET_DB_BACKUP_DIR:-$ROOT/backups/db}"
        mkdir -p "$dest"
        stamp=$(date -u +%Y%m%dT%H%M%SZ)
        "$BIN/pg_dump" "$(database_url)" -Fc -f "$dest/allset-$stamp.dump.partial"
        mv "$dest/allset-$stamp.dump.partial" "$dest/allset-$stamp.dump"
        # Proves it reads: the dump's table of contents must list the wallpapers table.
        "$BIN/pg_restore" -l "$dest/allset-$stamp.dump" | grep -q 'TABLE DATA public wallpapers' \
            || { echo "Backup $dest/allset-$stamp.dump doesn't list the wallpapers table." >&2; exit 1; }
        ls -1t "$dest"/allset-*.dump | tail -n +15 | while read -r old; do rm -f "$old"; done
        echo "Database backed up: $dest/allset-$stamp.dump ($(du -h "$dest/allset-$stamp.dump" | cut -f1))"
        ;;
    install)
        [[ -f "$DATA/PG_VERSION" ]] || { echo "No database yet: run '$0 start' first." >&2; exit 1; }
        command -v caddy >/dev/null || { echo "Caddy isn't installed: brew install caddy" >&2; exit 1; }
        # macOS keeps background services out of these folders ("Operation not
        # permitted", found the hard way), so one installed from there never starts.
        for place in "$ROOT" "$HERE"; do
            case "$place/" in
                "$HOME/Downloads/"*|"$HOME/Desktop/"*|"$HOME/Documents/"*)
                    echo "Not installed: $place is inside Downloads, Desktop or Documents, and macOS doesn't let" >&2
                    echo "a service started at login read those. Move it (for example to ~/AllSetServer, with" >&2
                    echo "ALLSET_SERVER_DIR set to match), then run '$0 install' again." >&2
                    exit 1 ;;
            esac
        done
        # launchd starts Postgres from here on: not two of them on one folder.
        if running && ! kept_by_launchd; then "$BIN/pg_ctl" -D "$DATA" -m fast -w stop >/dev/null; fi
        /usr/bin/python3 "$HERE/install_public_server.py" --server "$SELF" --root "$ROOT"
        ;;
    uninstall)
        /usr/bin/python3 "$HERE/install_public_server.py" --uninstall
        ;;
    *)
        sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
