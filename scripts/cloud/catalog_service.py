"""Read-only wallpaper API for a tester: the catalog list and file downloads.

  GET /catalog     -> JSON list of {id, title, kind, category, tags, duration,
                      width, height, size_bytes}. No paths, no provenance.
                      The whole list, or one page with ?limit=N (1-500) and
                      ?offset=M: the body is the same list, and the headers
                      X-Total-Count and X-Next-Offset say how to go on.
  GET /file/<id>   -> that wallpaper's playback file. Supports `Range: bytes=`
                      so an interrupted download can resume.

  POST /activate   -> body {"key": "ALLSET-XXXX-XXXX-XXXX"} from the app's key screen
                      (accounts.py key create); returns {"token", "name", "expiresAt"}.
                      A wrong or revoked key: 401 {"error": "This key isn't valid."};
                      too many from one address: 429.
  POST /login      -> body {"email", "password"}; returns {"token", "must_change"}
                      for an invited person (accounts.py). Wrong details: 401.
  GET /me          -> 200 {"name", "expiresAt"} for an access key's token, {"email",
                      "name", "must_change"} for a session or the API key; 401 when the
                      token is no good, 403 while a temporary password is still in use.
                      Caddy asks this before serving any wallpaper file (Caddyfile.public
                      once the library is locked, Caddyfile.example on the old home server).
  POST /password   -> body {"password"}; sets a new password (required at first
                      sign-in when must_change is true). Returns a new token.
  POST /logout     -> ends this session.

  GET /library     -> the same wallpapers as the app's own catalog.json, with
                      each one's place in the storage folder: what the app's
                      `AllSet library <key>` command saves on a Mac that only
                      receives the library. No provenance, no origin paths.

Every catalog and file request needs `Authorization: Bearer <token>`: either
the permanent API key in ~/.allset_catalog_token (chmod 600; one key, reusable,
never expires; delete the file and restart to stop accepting it), or a session
token from /login. Accounts are made on the server with accounts.py (invite,
reset, disable); there is no sign-up. Nothing here writes or deletes wallpapers.

Sharing rule (WallpaperLibrary.swift): only `published` wallpapers are listed
or served. Quarantined ones have unknown sharing rights; serving them to a
tester of your own is a separate, explicit choice: --include-quarantined.
The same rule applies to /catalog and /file.

Listens on this machine's Tailscale address only (100.64.0.0/10), found at
startup; it refuses to start without one unless --host says where to listen.
Never forward the port to the internet. On the single-Mac server it is
`server.sh api`: 127.0.0.1:8083, with Caddy (Caddyfile.public) passing it
/api/activate and /api/me and nothing else.

Usage (on the server):
    /usr/bin/python3 scripts/cloud/catalog_service.py [--port 8082] [--host ADDRESS] [--include-quarantined]
    DATABASE_URL in the environment says which database (default: the home server's).
Tests:
    /usr/bin/python3 -m unittest scripts/cloud/test_catalog_service.py
"""
import argparse
import hmac
import ipaddress
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import accounts  # noqa: E402
import pgsql  # noqa: E402
from accounts import AccountError  # noqa: E402

# The most rows one page of /catalog may ask for, and requests served at once.
MAX_PAGE = 500
MAX_CONCURRENT = 8
MAX_BODY = 4096
# Wrong passwords for one email, or wrong keys from one address: LOGIN_LIMIT
# in LOGIN_WINDOW seconds, then a wait.
LOGIN_LIMIT = 10
LOGIN_WINDOW = 15 * 60
# Past this many emails and addresses with failures, the old ones are dropped.
MAX_FAILURE_KEYS = 10_000
# An access token /me accepted is trusted from memory this long (TokenMemory).
TOKEN_MEMORY = 60
MAX_REMEMBERED = 10_000
# How long a /me check waits for a slot before it's told to come back.
SLOT_WAIT = 10
# Set by Caddy (Caddyfile.public) to the visitor's address, Cloudflare's
# CF-Connecting-IP behind the tunnel; it replaces any the visitor sends.
CLIENT_HEADER = "X-Allset-Client"
INVALID_KEY = "This key isn't valid."
TOO_MANY_KEYS = "Too many attempts. Try again in a few minutes."

STORAGE = os.path.expanduser("~/AllSetStorage/wallpapers")
KEY_PATH = os.path.expanduser("~/.allset_catalog_token")
# Who /me says is asking when the request carries the API key.
KEY_HOLDER = "api-key"
# The one library folder a receiving Mac's catalog names.
LIBRARY_ROOT = "server"
PSQL = "/opt/homebrew/bin/psql" if os.path.exists("/opt/homebrew/bin/psql") else "psql"
# server.sh sets DATABASE_URL to the single-Mac server's own Postgres (port 5433).
DATABASE_URL = os.environ.get("DATABASE_URL") or "postgres://allset@localhost/allset"
COLUMNS = "id, title, kind, category, tags, duration, width, height, size_bytes"
ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
DATABASE_TIMEOUT = 20
TAILSCALE_NET = ipaddress.ip_network("100.64.0.0/10")
# The list is read from the database at most this often. The delete service
# touches changed_marker() when it changes a row, which ends the wait early;
# sync_catalog.py runs on another Mac, so what it writes shows within CATALOG_TTL.
CATALOG_TTL = 30
def changed_marker():
    """Read at call time: STORAGE can be pointed elsewhere (tests, --storage)."""
    return os.path.join(STORAGE, ".catalog-changed")

DatabaseError = pgsql.DatabaseError


def load_key():
    """The permanent API key, or "" when there is none (then only sessions work)."""
    try:
        with open(KEY_PATH) as handle:
            return handle.read().strip()
    except OSError:
        return ""


def stored(key):
    """A storage key, if its file is on this server; otherwise None."""
    return key if key and os.path.isfile(os.path.join(STORAGE, key)) else None


def query(sql, variables=None):
    """Values only ever travel as psql variables (`:'name'` in the SQL), never in its text."""
    return pgsql.run(DATABASE_URL, sql, variables, psql=PSQL, timeout=DATABASE_TIMEOUT)


def allowed_statuses(include_quarantined):
    return ("published", "quarantined") if include_quarantined else ("published",)


# Matches the rows `allowed_statuses` allows; needs the variable from `status_variables`.
STATUS_CLAUSE = "status in (select jsonb_array_elements_text((:'statuses')::jsonb))"


def status_variables(include_quarantined):
    return {"statuses": list(allowed_statuses(include_quarantined))}


class CatalogCache:
    """The rows /catalog serves, kept for CATALOG_TTL seconds or until the
    changed marker moves, so a burst of requests reads the database once."""

    def __init__(self):
        self.lock = threading.Lock()
        self.entries = {}

    @staticmethod
    def marker():
        try:
            return os.path.getmtime(changed_marker())
        except OSError:
            return 0

    def rows(self, include_quarantined, load, now=None):
        now = time.monotonic() if now is None else now
        marker = self.marker()
        with self.lock:
            entry = self.entries.get(include_quarantined)
            if entry and now - entry[0] < CATALOG_TTL and entry[1] == marker:
                return entry[2]
        rows = load()
        with self.lock:
            self.entries[include_quarantined] = (now, marker, rows)
        return rows

    def clear(self):
        with self.lock:
            self.entries.clear()


CACHE = CatalogCache()


class TokenMemory:
    """Access tokens /me accepted in the last TOKEN_MEMORY seconds, by hash.
    Caddy asks /me before every library file once the library is locked, so a
    gallery of thumbnails costs one database check, not one each. Revoking or
    deleting a key touches accounts.ACCESS_CHANGED, and everything remembered
    is forgotten at the next request: a revoked key stops at once."""

    def __init__(self):
        self.lock = threading.Lock()
        self.entries = {}
        self.seen = None

    @staticmethod
    def stamp():
        try:
            return os.path.getmtime(accounts.ACCESS_CHANGED)
        except OSError:
            return 0

    def _current(self, stamp):
        if stamp != self.seen:
            self.entries.clear()
            self.seen = stamp

    def get(self, token, now=None):
        if not token:
            return None
        now = time.monotonic() if now is None else now
        stamp = self.stamp()
        with self.lock:
            self._current(stamp)
            entry = self.entries.get(accounts.token_hash(token))
            return entry[1] if entry and now - entry[0] < TOKEN_MEMORY else None

    def keep(self, token, answer, since, now=None):
        """Remembers an answer looked up while the marker read `since`; not when
        a key was revoked meanwhile, or the answer could outlive the key."""
        now = time.monotonic() if now is None else now
        stamp = self.stamp()
        with self.lock:
            if stamp != since:
                return
            self._current(stamp)
            if len(self.entries) >= MAX_REMEMBERED:
                self.entries.clear()
            self.entries[accounts.token_hash(token)] = (now, answer)

    def clear(self):
        with self.lock:
            self.entries.clear()


MEMORY = TokenMemory()


def parse_range(header, size):
    """(start, end) inclusive for a single `bytes=` range, None for none/unsupported,
    or "invalid" for one that can't be satisfied."""
    if not header:
        return None
    match = re.fullmatch(r"bytes=(\d*)-(\d*)", header.strip())
    if not match or (match.group(1) == "" and match.group(2) == ""):
        return None
    first, last = match.groups()
    if first == "":
        length = int(last)
        if length == 0:
            return "invalid"
        return max(size - length, 0), size - 1
    start = int(first)
    end = min(int(last), size - 1) if last else size - 1
    if start >= size or start > end:
        return "invalid"
    return start, end


def tailscale_address():
    """This machine's Tailscale IPv4 address, or None."""
    for command in (["tailscale", "ip", "-4"], ["/Applications/Tailscale.app/Contents/MacOS/Tailscale", "ip", "-4"]):
        if shutil.which(command[0]) or os.path.exists(command[0]):
            try:
                out = subprocess.run(command, capture_output=True, text=True, timeout=5).stdout.split()
            except (OSError, subprocess.TimeoutExpired):
                continue
            for word in out:
                try:
                    if ipaddress.ip_address(word) in TAILSCALE_NET:
                        return word
                except ValueError:
                    pass
    try:
        out = subprocess.run(["ifconfig"], capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return None
    for address in re.findall(r"inet (\d+\.\d+\.\d+\.\d+)", out):
        if ipaddress.ip_address(address) in TAILSCALE_NET:
            return address
    return None


class Handler(BaseHTTPRequestHandler):
    include_quarantined = False
    timeout = 30  # seconds a client may stall sending its request
    accounts = None  # accounts.Accounts, set in main()
    access = None  # accounts.AccessKeys, set in main()
    key = ""  # the permanent API key, set in main()

    # Requests served at once, across every connection.
    slots = threading.BoundedSemaphore(MAX_CONCURRENT)

    # Failed sign-ins per email, and failed keys per ("activate", address), in
    # the last LOGIN_WINDOW seconds: the same answer to a wrong password or
    # key, and a wait once there are too many.
    failures = {}
    failures_lock = threading.Lock()

    def _json(self, status, body, headers=None):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(data)

    def _bearer(self):
        header = self.headers.get("Authorization", "")
        return header[len("Bearer "):] if header.startswith("Bearer ") else ""

    def _session(self):
        """(email, must_change) for the bearer token, or None."""
        token = self._bearer()
        if self.key and hmac.compare_digest(token.encode(), self.key.encode()):
            return KEY_HOLDER, False
        return self.accounts.who(token)

    def _body(self):
        """The JSON object sent with a POST, or None if it isn't one. A chunked
        body too: a proxy on the way may forward it like that."""
        if self.headers.get("Transfer-Encoding", "").strip().lower() == "chunked":
            raw = self._chunked()
        else:
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                return None
            raw = self.rfile.read(length) if 0 < length <= MAX_BODY else None
        if not raw:
            return None
        try:
            data = json.loads(raw)
        except ValueError:
            return None
        return data if isinstance(data, dict) else None

    def _chunked(self):
        """A chunked request body, or None when it's malformed or over MAX_BODY."""
        raw = b""
        while True:
            try:
                size = int(self.rfile.readline(64).split(b";")[0].strip(), 16)
            except ValueError:
                return None
            if size == 0:
                break
            if len(raw) + size > MAX_BODY:
                return None
            raw += self.rfile.read(size)
            self.rfile.readline(8)  # the line end after each chunk
        for _ in range(32):  # trailers, up to the blank line
            if not self.rfile.readline(1024).strip():
                break
        return raw

    def do_GET(self):
        if urllib.parse.urlsplit(self.path).path == "/me":
            return self._me()
        self._serve(self._route_get)

    def do_POST(self):
        self._serve(self._route_post)

    def _serve(self, route):
        # A fixed number of requests at a time: each one runs psql or streams a
        # file, and a thread per request without a limit is how a small server
        # falls over. Past it, the client is told to come back, not queued.
        if not self.slots.acquire(blocking=False):
            return self._json(503, {"error": "busy; try again shortly"}, {"Retry-After": "1"})
        try:
            route(urllib.parse.urlsplit(self.path))
        except DatabaseError as error:
            print(f"{self.path}: database error: {error}", file=sys.stderr)
            return self._json(503, {"error": "catalog database unavailable"})
        except (BrokenPipeError, ConnectionResetError):
            return  # the client went away mid-download
        finally:
            self.slots.release()

    def _me(self):
        """Whose the bearer token is. Caddy asks this before every library file
        once the library is locked, so an access token it accepted is answered
        from memory (TokenMemory), and a burst of first checks waits for a slot
        instead of being turned away."""
        try:
            token = self._bearer()
            answer = MEMORY.get(token)
            if answer is None:
                if not self.slots.acquire(timeout=SLOT_WAIT):
                    return self._json(503, {"error": "busy; try again shortly"}, {"Retry-After": "1"})
                try:
                    answer = MEMORY.get(token) or self._look_up(token)
                finally:
                    self.slots.release()
            if not answer:
                return self._json(401, {"error": "sign in"})
            if answer.get("must_change"):
                return self._json(403, {"error": "set a new password first"})
            self._json(200, answer)
        except DatabaseError as error:
            print(f"/me: database error: {error}", file=sys.stderr)
            self._json(503, {"error": "catalog database unavailable"})
        except (BrokenPipeError, ConnectionResetError):
            return

    def _look_up(self, token):
        """/me's answer for a token, from the API key or the database, or None.
        Only access tokens are remembered: a disabled account loses access at once."""
        if not token:
            return None
        if self.key and hmac.compare_digest(token.encode(), self.key.encode()):
            return {"email": KEY_HOLDER, "name": KEY_HOLDER, "must_change": False}
        since = MEMORY.stamp()
        held = self.access.who(token) if self.access else None
        if held:
            answer = {"name": held[0], "expiresAt": held[1]}
            MEMORY.keep(token, answer, since)
            return answer
        session = self.accounts.who(token)
        if session:
            return {"email": session[0], "name": session[0], "must_change": session[1]}
        return None

    def _route_get(self, url):
        if url.path not in ("/catalog", "/library") and not url.path.startswith("/file/"):
            return self._json(404, {"error": "not found"})
        who = self._session()
        if not who:
            return self._json(401, {"error": "sign in"})
        if who[1]:
            return self._json(403, {"error": "set a new password first"})
        if url.path == "/catalog":
            return self._catalog(urllib.parse.parse_qs(url.query))
        if url.path == "/library":
            return self._library()
        return self._file(url.path[len("/file/"):])

    def _route_post(self, url):
        if url.path == "/activate":
            return self._activate()
        if url.path == "/login":
            return self._login()
        if url.path == "/logout":
            self.accounts.sign_out(self.headers.get("Authorization", "")[len("Bearer "):])
            return self._json(200, {"ok": True})
        if url.path == "/password":
            return self._set_password()
        self._json(404, {"error": "not found"})

    def _login(self):
        body = self._body()
        if body is None:
            return self._json(400, {"error": "send {\"email\", \"password\"}"})
        email = str(body.get("email", "")).strip().lower()
        if self._too_many_failures(email):
            return self._json(429, {"error": "too many attempts; wait a few minutes"}, {"Retry-After": "600"})
        result = self.accounts.sign_in(email, str(body.get("password", "")))
        if not result:
            self._record_failure(email)
            return self._json(401, {"error": "wrong email or password"})
        token, must_change = result
        self._json(200, {"token": token, "must_change": must_change})

    def _activate(self):
        """The app's key screen: a key (accounts.AccessKeys) for a token."""
        body = self._body()
        if body is None:
            return self._json(400, {"error": "Send {\"key\": \"ALLSET-XXXX-XXXX-XXXX\"}."})
        client = ("activate", self.headers.get(CLIENT_HEADER) or self.client_address[0])
        if self._too_many_failures(client):
            return self._json(429, {"error": TOO_MANY_KEYS}, {"Retry-After": "600"})
        since = MEMORY.stamp()
        granted = self.access.activate(str(body.get("key", "")))
        if not granted:
            self._record_failure(client)
            return self._json(401, {"error": INVALID_KEY})
        token, name, expires = granted
        answer = {"name": name, "expiresAt": expires}
        MEMORY.keep(token, answer, since)
        self._json(200, {"token": token, **answer})

    def _set_password(self):
        body = self._body()
        token = self.headers.get("Authorization", "")[len("Bearer "):]
        if body is None:
            return self._json(400, {"error": "send {\"password\"}"})
        try:
            fresh = self.accounts.change_password(token, str(body.get("password", "")))
        except AccountError as error:
            status = 401 if "Sign in" in str(error) else 400
            return self._json(status, {"error": str(error)})
        self._json(200, {"token": fresh})

    def _too_many_failures(self, email):
        cutoff = time.time() - LOGIN_WINDOW
        with self.failures_lock:
            recent = [t for t in self.failures.get(email, []) if t > cutoff]
            self.failures[email] = recent
            return len(recent) >= LOGIN_LIMIT

    def _record_failure(self, email):
        with self.failures_lock:
            if len(self.failures) >= MAX_FAILURE_KEYS:
                cutoff = time.time() - LOGIN_WINDOW
                for stale in [name for name, times in self.failures.items() if not any(t > cutoff for t in times)]:
                    del self.failures[stale]
            self.failures.setdefault(email, []).append(time.time())

    def _catalog(self, parameters):
        """The whole list, or with ?limit= (and ?offset=) one page of it. The
        body is the same list either way; a page also says how many rows there
        are in all (X-Total-Count) and where the next page starts (X-Next-Offset,
        absent on the last one). Only wallpapers whose file is on this server
        count, and they are counted before the page is cut, so every page but
        the last is full and the total is what can actually be fetched."""
        headers = {}
        page = None
        if "limit" in parameters or "offset" in parameters:
            try:
                limit = int(parameters.get("limit", [str(MAX_PAGE)])[0])
                offset = int(parameters.get("offset", ["0"])[0])
            except ValueError:
                return self._json(400, {"error": "limit and offset must be whole numbers"})
            if not 1 <= limit <= MAX_PAGE or offset < 0:
                return self._json(400, {"error": f"limit must be 1 to {MAX_PAGE}, offset 0 or more"})
            page = (offset, limit)
        rows = CACHE.rows(self.include_quarantined, lambda: self._servable_rows())
        if page:
            offset, limit = page
            headers["X-Total-Count"] = str(len(rows))
            if offset + limit < len(rows):
                headers["X-Next-Offset"] = str(offset + limit)
            rows = rows[offset:offset + limit]
        return self._json(200, rows, headers)

    def _servable_rows(self):
        """Every listed wallpaper whose file is on this server, in catalog order."""
        rows = query(f"select coalesce(json_agg(t), '[]') from (select {COLUMNS}, playback_key from wallpapers "
                     f"where {STATUS_CLAUSE} order by category, title, id) t", status_variables(self.include_quarantined))
        return [{k: v for k, v in r.items() if k != "playback_key"}
                for r in json.loads(rows or "[]")
                if os.path.isfile(os.path.join(STORAGE, r["playback_key"] or "-"))]

    def _library(self):
        """Every wallpaper /catalog lists, shaped like the app's catalog.json
        (WallpaperLibraryCatalog): each file is named by where it is in the
        storage folder, which is where the app keeps its copy and asks for it."""
        rows = query("select coalesce(json_agg(t), '[]') from (select id, title, kind, category, tags, "
                     "playback_key, still_key, thumbnail_key, duration, width, height, fps, size_bytes, "
                     "status, content_rating, added_at from wallpapers "
                     f"where {STATUS_CLAUSE} order by category, title, id) t", status_variables(self.include_quarantined))
        items = []
        for row in json.loads(rows or "[]"):
            playback, still = stored(row["playback_key"]), stored(row["still_key"])
            if not playback and not still:
                continue
            item = {"id": row["id"], "title": row["title"], "kind": row["kind"], "category": row["category"],
                    "tags": row["tags"] or [], "root": LIBRARY_ROOT, "file": playback or still,
                    "thumbnail": stored(row["thumbnail_key"]), "playback": playback, "still": still,
                    "duration": row["duration"], "width": row["width"], "height": row["height"],
                    "fps": row["fps"], "size": row["size_bytes"], "status": row["status"],
                    "contentRating": row["content_rating"], "addedAt": row["added_at"]}
            items.append({name: value for name, value in item.items() if value is not None})
        self._json(200, {"version": 1, "roots": [], "items": items})

    def _file(self, item_id):
        if not ID_PATTERN.match(item_id):
            return self._json(400, {"error": "bad id"})
        key = query(f"select playback_key from wallpapers where id = :'id' and {STATUS_CLAUSE}",
                    {"id": item_id, **status_variables(self.include_quarantined)})
        path = os.path.realpath(os.path.join(STORAGE, key)) if key else ""
        if not key or not path.startswith(os.path.realpath(STORAGE) + os.sep) or not os.path.isfile(path):
            return self._json(404, {"error": "not found"})
        size = os.path.getsize(path)
        wanted = parse_range(self.headers.get("Range"), size)
        if wanted == "invalid":
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{size}")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        start, end = wanted if wanted else (0, size - 1)
        self.send_response(206 if wanted else 200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(end - start + 1))
        if wanted:
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Content-Disposition", f'attachment; filename="{item_id}{os.path.splitext(path)[1]}"')
        self.end_headers()
        remaining = end - start + 1
        with open(path, "rb") as handle:
            handle.seek(start)
            while remaining > 0:
                chunk = handle.read(min(1 << 20, remaining))
                if not chunk:
                    break
                self.wfile.write(chunk)
                remaining -= len(chunk)

    def log_message(self, format, *args):
        pass  # no per-request lines (they'd carry ids and paths); failures go to stderr


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8082)
    parser.add_argument("--host", help="address to listen on (default: this machine's Tailscale address)")
    parser.add_argument("--include-quarantined", action="store_true",
                        help="also list and serve quarantined wallpapers (unknown sharing rights): your own tester only")
    args = parser.parse_args()
    host = args.host or tailscale_address()
    if not host:
        sys.exit("No Tailscale address found on this machine. Start Tailscale, or pass --host to choose where to listen.")
    Handler.accounts = accounts.Accounts(query)
    Handler.access = accounts.AccessKeys(query)
    Handler.key = load_key()
    Handler.include_quarantined = args.include_quarantined
    shared = "published + quarantined (your own tester only)" if args.include_quarantined else "published only"
    keyed = f"API key from {KEY_PATH} accepted" if Handler.key else f"no API key ({KEY_PATH} is missing): sessions only"
    print(f"catalog API on {host}:{args.port}; serving {shared}; {keyed}", flush=True)
    ThreadingHTTPServer((host, args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
