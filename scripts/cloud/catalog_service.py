"""Read-only wallpaper API for a tester: the catalog list and file downloads.

  GET /catalog     -> JSON list of {id, title, kind, category, tags, duration,
                      width, height, size_bytes}. No paths, no provenance.
                      The whole list, or one page with ?limit=N (1-500) and
                      ?offset=M: the body is the same list, and the headers
                      X-Total-Count and X-Next-Offset say how to go on.
  GET /file/<id>   -> that wallpaper's playback file. Supports `Range: bytes=`
                      so an interrupted download can resume.

  POST /login      -> body {"email", "password"}; returns {"token", "must_change"}
                      for an invited person (accounts.py). Wrong details: 401.
  GET /me          -> {"email"} for the signed-in person: 200 when the session is good,
                      401 when it isn't, 403 while a temporary password is still in use.
                      Caddy asks this before serving any wallpaper file (see Caddyfile.example).
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
Never forward the port to the internet.

Usage (on the server):
    /usr/bin/python3 scripts/cloud/catalog_service.py [--port 8082] [--host ADDRESS] [--include-quarantined]
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
from accounts import AccountError  # noqa: E402

# The most rows one page of /catalog may ask for, and requests served at once.
MAX_PAGE = 500
MAX_CONCURRENT = 8
MAX_BODY = 4096
# Wrong passwords for one email: LOGIN_LIMIT in LOGIN_WINDOW seconds, then a wait.
LOGIN_LIMIT = 10
LOGIN_WINDOW = 15 * 60

STORAGE = os.path.expanduser("~/AllSetStorage/wallpapers")
KEY_PATH = os.path.expanduser("~/.allset_catalog_token")
# Who /me says is asking when the request carries the API key.
KEY_HOLDER = "api-key"
# The one library folder a receiving Mac's catalog names.
LIBRARY_ROOT = "server"
PSQL = "/opt/homebrew/bin/psql" if os.path.exists("/opt/homebrew/bin/psql") else "psql"
DATABASE_URL = "postgres://allset@localhost/allset"
COLUMNS = "id, title, kind, category, tags, duration, width, height, size_bytes"
ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
DATABASE_TIMEOUT = 20
TAILSCALE_NET = ipaddress.ip_network("100.64.0.0/10")


class DatabaseError(Exception):
    pass


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


def query(sql):
    try:
        result = subprocess.run([PSQL, DATABASE_URL, "-At", "-v", "ON_ERROR_STOP=1", "-c", sql],
                                capture_output=True, text=True, timeout=DATABASE_TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise DatabaseError(str(error))
    if result.returncode != 0:
        raise DatabaseError(result.stderr.strip() or f"psql exited {result.returncode}")
    return result.stdout.strip()


def allowed_statuses(include_quarantined):
    return ("published", "quarantined") if include_quarantined else ("published",)


def status_clause(include_quarantined):
    return "status in (%s)" % ", ".join(f"'{s}'" for s in allowed_statuses(include_quarantined))


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
    key = ""  # the permanent API key, set in main()

    # Requests served at once, across every connection.
    slots = threading.BoundedSemaphore(MAX_CONCURRENT)

    # Failed sign-ins per email, in the last LOGIN_WINDOW seconds: the same
    # answer to a wrong password, and a wait once there are too many.
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

    def _session(self):
        """(email, must_change) for the bearer token, or None."""
        header = self.headers.get("Authorization", "")
        token = header[len("Bearer "):] if header.startswith("Bearer ") else ""
        if self.key and hmac.compare_digest(token.encode(), self.key.encode()):
            return KEY_HOLDER, False
        return self.accounts.who(token)

    def _body(self):
        """The JSON object sent with a POST, or None if it isn't one."""
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return None
        if not 0 < length <= MAX_BODY:
            return None
        try:
            data = json.loads(self.rfile.read(length))
        except ValueError:
            return None
        return data if isinstance(data, dict) else None

    def do_GET(self):
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

    def _route_get(self, url):
        if url.path == "/me":
            who = self._session()
            if not who:
                return self._json(401, {"error": "sign in"})
            if who[1]:
                return self._json(403, {"error": "set a new password first"})
            return self._json(200, {"email": who[0], "must_change": False})
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
            self.failures.setdefault(email, []).append(time.time())

    def _catalog(self, parameters):
        """The whole list, or with ?limit= (and ?offset=) one page of it. The
        body is the same list either way; a page also says how many rows there
        are in all (X-Total-Count) and where the next page starts (X-Next-Offset,
        absent on the last one). A page can hold fewer than `limit` items: rows
        whose file isn't on this server are left out after the page is cut."""
        where = status_clause(self.include_quarantined)
        paging, headers = "", {}
        if "limit" in parameters or "offset" in parameters:
            try:
                limit = int(parameters.get("limit", [str(MAX_PAGE)])[0])
                offset = int(parameters.get("offset", ["0"])[0])
            except ValueError:
                return self._json(400, {"error": "limit and offset must be whole numbers"})
            if not 1 <= limit <= MAX_PAGE or offset < 0:
                return self._json(400, {"error": f"limit must be 1 to {MAX_PAGE}, offset 0 or more"})
            total = int(query(f"select count(*) from wallpapers where {where}") or 0)
            paging = f" limit {limit} offset {offset}"
            headers["X-Total-Count"] = str(total)
            if offset + limit < total:
                headers["X-Next-Offset"] = str(offset + limit)
        rows = query(f"select coalesce(json_agg(t), '[]') from (select {COLUMNS}, playback_key from wallpapers "
                     f"where {where} order by category, title, id{paging}) t")
        # only list wallpapers whose file is actually on this server
        return self._json(200, [{k: v for k, v in r.items() if k != "playback_key"}
                                for r in json.loads(rows)
                                if os.path.isfile(os.path.join(STORAGE, r["playback_key"] or "-"))], headers)

    def _library(self):
        """Every wallpaper /catalog lists, shaped like the app's catalog.json
        (WallpaperLibraryCatalog): each file is named by where it is in the
        storage folder, which is where the app keeps its copy and asks for it."""
        rows = query("select coalesce(json_agg(t), '[]') from (select id, title, kind, category, tags, "
                     "playback_key, still_key, thumbnail_key, duration, width, height, fps, size_bytes, "
                     "status, content_rating, added_at from wallpapers "
                     f"where {status_clause(self.include_quarantined)} order by category, title, id) t")
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
        key = query(f"select playback_key from wallpapers where id = '{item_id}' "
                    f"and {status_clause(self.include_quarantined)}")
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
    Handler.key = load_key()
    Handler.include_quarantined = args.include_quarantined
    shared = "published + quarantined (your own tester only)" if args.include_quarantined else "published only"
    keyed = f"API key from {KEY_PATH} accepted" if Handler.key else f"no API key ({KEY_PATH} is missing): sessions only"
    print(f"catalog API on {host}:{args.port}; serving {shared}; {keyed}", flush=True)
    ThreadingHTTPServer((host, args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
