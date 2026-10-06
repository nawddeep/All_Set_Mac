#!/bin/bash
# Opens the SSH tunnel to the home server's Postgres and delete service,
# both bound to localhost there and reachable only over Tailscale via this
# tunnel. While this runs, postgres://allset@localhost:5432/allset and
# http://localhost:8081 on this Mac ARE the server's.
#
#   scripts/cloud/tunnel.sh          # hold the tunnel open (ctrl-C to stop)
#   scripts/cloud/tunnel.sh --check  # is it already up?
#
# Nothing here runs at login; start it when you need it.
set -euo pipefail

SERVER="allset-server"   # ~/.ssh/config alias
PG_PORT=5432
DELETE_PORT=8081

# The command holding a local port, or nothing.
listener() {
    lsof -nP -iTCP:"$1" -sTCP:LISTEN -Fc 2>/dev/null | sed -n 's/^c//p' | head -1
}

# Up means both forwards are held by ssh (a local Postgres on 5432 isn't the
# server) and the delete service answers at the far end.
check() {
    local problems=0 owner code
    for port in "$PG_PORT" "$DELETE_PORT"; do
        owner=$(listener "$port")
        if [[ -z "$owner" ]]; then
            echo "localhost:$port: nothing listening"
            problems=1
        elif [[ "$owner" != "ssh" ]]; then
            echo "localhost:$port is held by '$owner', not the tunnel"
            problems=1
        fi
    done
    if [[ $problems == 0 ]]; then
        code=$(curl -s -o /dev/null -m 5 -w '%{http_code}' "http://localhost:$DELETE_PORT/" || true)
        if [[ ! "$code" =~ ^[1-5] ]]; then
            echo "localhost:$DELETE_PORT is forwarded but the delete service doesn't answer"
            problems=1
        fi
    fi
    return $problems
}

if [[ "${1:-}" == "--check" ]]; then
    if check; then
        echo "tunnel is up: localhost:$PG_PORT and localhost:$DELETE_PORT go to $SERVER"
        exit 0
    fi
    echo "tunnel is down"
    exit 1
fi

for port in "$PG_PORT" "$DELETE_PORT"; do
    owner=$(listener "$port")
    if [[ "$owner" == "ssh" ]]; then
        echo "A tunnel already holds localhost:$port. Check it with: $0 --check"
        exit 1
    elif [[ -n "$owner" ]]; then
        echo "'$owner' already listens on localhost:$port — not starting a tunnel over it."
        [[ "$port" == "$PG_PORT" ]] && echo "If that's a local Postgres, stop it first: brew services stop postgresql@18"
        exit 1
    fi
done

echo "Opening tunnel to $SERVER (ctrl-C to close)..."
# ExitOnForwardFailure: if either forward can't be set up, ssh quits rather
# than running with half a tunnel.
exec ssh -N -o ExitOnForwardFailure=yes -L "$PG_PORT:localhost:$PG_PORT" -L "$DELETE_PORT:localhost:$DELETE_PORT" "$SERVER"
