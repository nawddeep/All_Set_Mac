#!/bin/bash
# Puts this checkout's catalog service on the home server and restarts it, then
# checks that the server's permanent API key opens the library through Caddy.
#
#   scripts/cloud/deploy_catalog.sh
#
# The key never leaves the server: the check runs there and prints only the
# HTTP status. Send someone the key itself with:
#   ssh allset-server cat .allset_catalog_token
set -euo pipefail
cd "$(dirname "$0")"

SERVER="allset-server"   # ~/.ssh/config alias
REMOTE="allset-cloud"    # relative to the server's home

echo "Copying catalog_service.py and accounts.py to $SERVER:$REMOTE/"
scp -q catalog_service.py accounts.py "$SERVER:$REMOTE/"

echo "Restarting the catalog service"
# It finds the server's Tailscale address itself. -u: what it prints reaches the log at once.
ssh "$SERVER" "pkill -f 'catalog_service.py' || true; sleep 1; cd ~/$REMOTE && \
    nohup /usr/bin/python3 -u catalog_service.py --port 8082 --include-quarantined > catalog.log 2>&1 < /dev/null & disown"
sleep 2

ssh "$SERVER" 'cat ~/allset-cloud/catalog.log
    address=$(sed -n "s/^catalog API on \([0-9.]*\):.*/\1/p" ~/allset-cloud/catalog.log | head -1)
    if [ -z "$address" ]; then echo "The catalog service did not start."; exit 1; fi
    with_key=$(curl -s -o /dev/null -m 20 -w "%{http_code}" -H "Authorization: Bearer $(cat ~/.allset_catalog_token)" "http://$address:8080/api/library")
    without=$(curl -s -o /dev/null -m 20 -w "%{http_code}" "http://$address:8080/api/library")
    echo "Library through Caddy: $with_key with the API key, $without without it"
    [ "$with_key" = 200 ] && [ "$without" = 401 ]'
echo "The library server accepts the API key."
