#!/bin/bash
# Makes the wallpaper library reachable from the internet, so a Mac it's shared
# with needs the API key and nothing else (no Tailscale there). Tailscale Funnel
# on the home server carries https://<server>.<tailnet>.ts.net to Caddy, which
# still asks the catalog service about the key before serving anything.
#
#   scripts/cloud/publish_library.sh           # publish, then check from outside
#   scripts/cloud/publish_library.sh --stop    # take it off the internet again
#
# The first run may print a tailscale.com link: open it to allow Funnel (and
# HTTPS certificates) for the server, and the script carries on by itself.
#
# After this, the key is the only thing between the internet and the library.
set -euo pipefail

SERVER="allset-server"   # ~/.ssh/config alias
TAILSCALE="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
CADDYFILE="/opt/homebrew/etc/Caddyfile"
PORT=8080

if [[ "${1:-}" == "--stop" ]]; then
    ssh "$SERVER" "$TAILSCALE funnel --https=443 off"
    echo "The library is off the internet. It still answers over Tailscale."
    exit 0
fi

echo "Letting Caddy answer Funnel (which reaches it on localhost) as well as Tailscale"
ssh "$SERVER" /usr/bin/python3 - "$CADDYFILE" "$PORT" <<'PY'
import re, shutil, sys
path, port = sys.argv[1], sys.argv[2]
text = open(path).read()
# From one site on the Tailscale address to the same site on that address and localhost.
site = re.search(r"^http://(\d+\.\d+\.\d+\.\d+):%s \{\n" % port, text, re.M)
if site:
    shutil.copy(path, path + ".before-public")
    text = text[:site.start()] + "http://:%s {\n\tbind %s 127.0.0.1\n" % (port, site.group(1)) + text[site.end():]
    open(path, "w").write(text)
    print("Caddyfile changed; the old one is %s.before-public" % path)
elif re.search(r"^\tbind \S+ 127\.0\.0\.1$", text, re.M):
    print("Caddyfile already answers on localhost")
else:
    sys.exit("Didn't find the library's site in %s; nothing changed." % path)
PY
ssh "$SERVER" "/opt/homebrew/bin/caddy validate --config $CADDYFILE --adapter caddyfile >/dev/null 2>&1 \
    && /opt/homebrew/bin/caddy reload --config $CADDYFILE --adapter caddyfile 2>/dev/null \
    && curl -s -o /dev/null -m 10 -w 'Caddy on localhost answers %{http_code} without a key (401 is right)\n' http://127.0.0.1:$PORT/api/library"

echo "Turning on Funnel (if a tailscale.com link appears, open it; this waits)"
ssh "$SERVER" "$TAILSCALE funnel --bg --https=443 http://127.0.0.1:$PORT"

name=$(ssh "$SERVER" "$TAILSCALE status --json" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')
url="https://$name"

# From outside the tailnet: the name's public address, not the one Tailscale gives this Mac.
echo "Checking $url from the internet (the first answer waits for its certificate)"
for attempt in 1 2 3 4 5 6; do
    address=$(dig +short "$name" A @1.1.1.1 | grep -E '^[0-9.]+$' | head -1 || true)
    if [[ -n "$address" ]]; then
        code=$(curl -s -o /dev/null -m 60 -w '%{http_code}' --resolve "$name:443:$address" "$url/api/library" || true)
        if [[ "$code" == 401 ]]; then
            echo "It answers, and refuses without the key."
            echo
            echo "The library's public address: $url"
            echo "Build the copy of the app to send with:"
            echo "  ALLSET_LIBRARY_SERVER_URL=$url ALLSET_APP_DIR=build/share/AllSet.app scripts/build-app.sh"
            exit 0
        fi
    fi
    sleep 10
done
echo "No answer from $url yet (last status: ${code:-none}). Run this again in a minute; if it still fails, check '$TAILSCALE funnel status' on the server."
exit 1
