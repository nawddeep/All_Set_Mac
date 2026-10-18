"""Invited people's accounts for the wallpaper server: sign in, sessions, and
the command you run to invite, reset, disable and list them. Also the access
keys the app's key screen asks for.

    /usr/bin/python3 scripts/cloud/accounts.py invite friend@example.com
    /usr/bin/python3 scripts/cloud/accounts.py reset friend@example.com
    /usr/bin/python3 scripts/cloud/accounts.py disable friend@example.com
    /usr/bin/python3 scripts/cloud/accounts.py enable friend@example.com
    /usr/bin/python3 scripts/cloud/accounts.py list

    /usr/bin/python3 scripts/cloud/accounts.py key create "Name"   # a new key, shown once
    /usr/bin/python3 scripts/cloud/accounts.py key revoke "Name"   # that key and every device using it stop
    /usr/bin/python3 scripts/cloud/accounts.py key delete "Name"   # forgotten, so the name can have a new one
    /usr/bin/python3 scripts/cloud/accounts.py key list

Run on the server (it talks to Postgres the way catalog_service.py does; on
the single-Mac server, `scripts/cloud/server.sh key ...` sets DATABASE_URL). An
invite prints a temporary password once; send it to them. Their first sign-in
must set a new one. Passwords are stored as salted PBKDF2 hashes; sessions as SHA-256
hashes of random tokens, so a leaked table can't sign anyone in. Access keys
and their tokens are stored as SHA-256 hashes too.

Tests: /usr/bin/python3 -m unittest scripts/cloud/test_accounts.py
"""
import argparse
import datetime
import hashlib
import hmac
import json
import os
import re
import secrets
import sys

SESSION_DAYS = 30
MIN_PASSWORD = 10
EMAIL = re.compile(r"^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$")
# Checked on a sign-in for an unknown email too, so the time taken doesn't say who exists.
_DUMMY = None


class AccountError(Exception):
    """A request that can't be done; the message is safe to show the person."""


def normalise(email):
    email = (email or "").strip().lower()
    if not EMAIL.match(email) or len(email) > 254:
        raise AccountError("That doesn't look like an email address.")
    return email


HASH_ROUNDS = 600_000


def hash_password(password):
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, HASH_ROUNDS)
    return f"pbkdf2$sha256${HASH_ROUNDS}$" + salt.hex() + "$" + digest.hex()


def verify_password(password, stored):
    try:
        _, method, rounds, salt, digest = stored.split("$")
        if method != "sha256":
            return False
        expected = bytes.fromhex(digest)
        actual = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), int(rounds))
    except (ValueError, TypeError):
        return False
    return hmac.compare_digest(actual, expected)


def temporary_password():
    # 16 characters from an unambiguous set, grouped so it's easy to type once.
    alphabet = "abcdefghjkmnpqrstuvwxyz23456789"
    raw = "".join(secrets.choice(alphabet) for _ in range(16))
    return "-".join(raw[i:i + 4] for i in range(0, 16, 4))


def token_hash(token):
    return hashlib.sha256(token.encode()).hexdigest()


def rows(sql_text, run, variables=None):
    return json.loads(run(f"select coalesce(json_agg(t), '[]') from ({sql_text}) t", variables) or "[]")


class Accounts:
    """Every method takes `run(sql, variables) -> str`: psql's output, with each
    value passed as a psql variable and named in the SQL as `:'name'`, never
    written into the SQL itself."""

    def __init__(self, run, clock=None):
        self.run = run
        self.clock = clock or (lambda: datetime.datetime.now(datetime.timezone.utc))

    def _user(self, email):
        found = rows("select email, password_hash, must_change, disabled from accounts where email = :'email'", self.run,
                     {"email": email})
        return found[0] if found else None

    def invite(self, email):
        email = normalise(email)
        if self._user(email):
            raise AccountError(f"{email} already has an account. Use reset to give them a new temporary password.")
        password = temporary_password()
        self.run("insert into accounts (email, password_hash, must_change) values (:'email', :'hash', true)",
                 {"email": email, "hash": hash_password(password)})
        return password

    def reset(self, email):
        email = normalise(email)
        if not self._user(email):
            raise AccountError(f"No account for {email}.")
        password = temporary_password()
        self.run("update accounts set password_hash = :'hash', must_change = true where email = :'email';\n"
                 "delete from sessions where email = :'email'", {"email": email, "hash": hash_password(password)})
        return password

    def set_disabled(self, email, disabled):
        email = normalise(email)
        if not self._user(email):
            raise AccountError(f"No account for {email}.")
        self.run("update accounts set disabled = (:'disabled')::boolean where email = :'email'",
                 {"email": email, "disabled": bool(disabled)})
        if disabled:
            self.run("delete from sessions where email = :'email'", {"email": email})

    def list(self):
        return rows("select email, must_change, disabled, created_at from accounts order by email", self.run)

    def sign_in(self, email, password):
        """(session token, must_change) for the right password, else None."""
        try:
            email = normalise(email)
        except AccountError:
            verify_password(password or "", _dummy_hash())
            return None
        user = self._user(email)
        if not user:
            verify_password(password or "", _dummy_hash())
            return None
        if not verify_password(password or "", user["password_hash"]) or user["disabled"]:
            return None
        token = secrets.token_urlsafe(32)
        expires = self.clock() + datetime.timedelta(days=SESSION_DAYS)
        self.run("insert into sessions (token_hash, email, expires_at) values (:'token', :'email', (:'expires')::timestamptz)",
                 {"token": token_hash(token), "email": email, "expires": expires.isoformat()})
        return token, bool(user["must_change"])

    def who(self, token):
        """(email, must_change) for a live session of an enabled account, else None."""
        if not token:
            return None
        found = rows("select a.email, a.must_change from sessions s join accounts a on a.email = s.email "
                     "where s.token_hash = :'token' and s.expires_at > now() and not a.disabled",
                     self.run, {"token": token_hash(token)})
        return (found[0]["email"], bool(found[0]["must_change"])) if found else None

    def sign_out(self, token):
        if token:
            self.run("delete from sessions where token_hash = :'token'", {"token": token_hash(token)})

    def change_password(self, token, new_password):
        """Sets a new password for the signed-in account, ends its other sessions, and
        returns a fresh session token for this one."""
        who = self.who(token)
        if not who:
            raise AccountError("Sign in again.")
        if len(new_password or "") < MIN_PASSWORD:
            raise AccountError(f"Use at least {MIN_PASSWORD} characters.")
        email = who[0]
        token = secrets.token_urlsafe(32)
        expires = self.clock() + datetime.timedelta(days=SESSION_DAYS)
        self.run("begin;\n"
                 "update accounts set password_hash = :'hash', must_change = false where email = :'email';\n"
                 "delete from sessions where email = :'email';\n"
                 "insert into sessions (token_hash, email, expires_at) values (:'token', :'email', (:'expires')::timestamptz);\n"
                 "commit",
                 {"email": email, "hash": hash_password(new_password), "token": token_hash(token), "expires": expires.isoformat()})
        return token


TOKEN_DAYS = 90
KEY_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"  # no 0/O or 1/I/L: keys get read out and retyped
KEY_PREFIX = "ALLSET"
NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}$")
# Touched when a key is revoked or deleted. catalog_service.py forgets every
# token it remembers as soon as this changes, so a revoked key stops at once.
ACCESS_CHANGED = os.path.expanduser("~/.allset_access_changed")
# A token's expiry the way the app reads it: ISO 8601, UTC, whole seconds.
EXPIRES_TEXT = """to_char(t.expires_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')"""


def new_key():
    """ALLSET-XXXX-XXXX-XXXX: 12 random characters, about 59 bits."""
    raw = "".join(secrets.choice(KEY_ALPHABET) for _ in range(12))
    return KEY_PREFIX + "-" + "-".join(raw[i:i + 4] for i in range(0, 12, 4))


def canonical_key(key):
    """A key as typed or pasted (any case, spaces, with or without dashes or the
    prefix) in its one stored form, or "" if it can't be a key."""
    raw = re.sub(r"[\s-]", "", str(key or "")).upper()
    if raw.startswith(KEY_PREFIX):
        raw = raw[len(KEY_PREFIX):]
    if len(raw) != 12 or any(c not in KEY_ALPHABET for c in raw):
        return ""
    return KEY_PREFIX + "-" + "-".join(raw[i:i + 4] for i in range(0, 12, 4))


def check_name(name):
    name = (name or "").strip()
    if not NAME.match(name):
        raise AccountError("Use a name of letters, digits, spaces, dots, dashes or underscores (up to 64).")
    return name


def iso(moment):
    return moment.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def access_changed():
    """Tells a running catalog_service.py to check every token again."""
    try:
        with open(ACCESS_CHANGED, "a"):
            pass
        os.utime(ACCESS_CHANGED)
    except OSError as error:
        print(f"Couldn't touch {ACCESS_CHANGED} ({error}): the service notices within a minute.", file=sys.stderr)


class AccessKeys:
    """Access keys for the app's key screen, one per person so one can be
    revoked alone. A key is exchanged at /api/activate (catalog_service.py) for
    a token that lasts TOKEN_DAYS, one per device; revoking the key ends them
    all. Only SHA-256 hashes of keys and tokens are stored. `run` as for Accounts."""

    def __init__(self, run, clock=None):
        self.run = run
        self.clock = clock or (lambda: datetime.datetime.now(datetime.timezone.utc))

    def _key(self, name):
        found = rows("select name, revoked_at from access_keys where lower(name) = lower(:'name')", self.run,
                     {"name": name})
        return found[0] if found else None

    def _existing(self, name):
        found = self._key(check_name(name))
        if not found:
            raise AccountError(f"No key for {name.strip()}.")
        return found["name"]

    def create(self, name):
        """A new key for `name`, returned once: only its hash is kept."""
        name = check_name(name)
        if self._key(name):
            raise AccountError(f"{name} already has a key. Revoke and delete it to give them a new one.")
        key = new_key()
        self.run("insert into access_keys (name, key_hash) values (:'name', :'hash')",
                 {"name": name, "hash": token_hash(key)})
        return key

    def revoke(self, name):
        """The key and every device's token stop working; the name stays, listed as revoked."""
        name = self._existing(name)
        self.run("begin;\n"
                 "update access_keys set revoked_at = coalesce(revoked_at, now()) where name = :'name';\n"
                 "delete from access_tokens where key_name = :'name';\n"
                 "commit", {"name": name})
        access_changed()
        return name

    def delete(self, name):
        """Forgets the key and its tokens, so the name can be given a new one."""
        name = self._existing(name)
        self.run("delete from access_keys where name = :'name'", {"name": name})
        access_changed()
        return name

    def list(self):
        return rows("select k.name, k.created_at, k.revoked_at, k.last_used_at, "
                    "(select count(*) from access_tokens t where t.key_name = k.name and t.expires_at > now()) as devices "
                    "from access_keys k order by lower(k.name)", self.run)

    def activate(self, key):
        """(token, name, expiresAt) for a key that isn't revoked, else None. Each
        call makes a new token (one per device) and clears expired ones."""
        key = canonical_key(key)
        if not key:
            return None
        found = rows("select name from access_keys where key_hash = :'hash' and revoked_at is null", self.run,
                     {"hash": token_hash(key)})
        if not found:
            return None
        name = found[0]["name"]
        token = secrets.token_urlsafe(32)
        expires = self.clock() + datetime.timedelta(days=TOKEN_DAYS)
        self.run("begin;\n"
                 "insert into access_tokens (token_hash, key_name, expires_at) values (:'token', :'name', (:'expires')::timestamptz);\n"
                 "update access_keys set last_used_at = now() where name = :'name';\n"
                 "delete from access_tokens where expires_at <= now();\n"
                 "commit", {"token": token_hash(token), "name": name, "expires": expires.isoformat()})
        return token, name, iso(expires)

    def who(self, token):
        """(name, expiresAt) for a live token of a key that isn't revoked, else None."""
        if not token:
            return None
        found = rows(f"select t.key_name as name, {EXPIRES_TEXT} as expires_at from access_tokens t "
                     "join access_keys k on k.name = t.key_name "
                     "where t.token_hash = :'token' and t.expires_at > now() and k.revoked_at is null",
                     self.run, {"token": token_hash(token)})
        return (found[0]["name"], found[0]["expires_at"]) if found else None


def key_command(keys, action, name):
    if action == "list":
        for row in keys.list():
            state = "revoked" if row["revoked_at"] else "active"
            used = (row["last_used_at"] or "never")[:16].replace("T", " ")
            print(f"{row['name']}\t{state}\tdevices: {row['devices']}\tlast used: {used}{'' if used == 'never' else ' UTC'}")
        return
    if not name:
        raise AccountError(f"key {action} needs a name.")
    if action == "create":
        key = keys.create(name)
        print(f"Key for {check_name(name)} (shown once; only its hash is kept):\n{key}")
    elif action == "revoke":
        print(f"Revoked {keys.revoke(name)}: the key and every device using it stop working.")
    else:
        print(f"Deleted {keys.delete(name)}.")


def _dummy_hash():
    global _DUMMY
    if _DUMMY is None:
        _DUMMY = hash_password("not-a-real-password")
    return _DUMMY


def main(argv=None):
    import catalog_service  # the same psql connection the server uses

    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("invite", "reset", "disable", "enable"):
        commands.add_parser(name).add_argument("email")
    commands.add_parser("list")
    key = commands.add_parser("key", help="access keys for the app's key screen")
    key.add_argument("action", choices=("create", "revoke", "delete", "list"))
    key.add_argument("name", nargs="?")
    args = parser.parse_args(argv)
    accounts = Accounts(catalog_service.query)
    try:
        if args.command == "key":
            return key_command(AccessKeys(catalog_service.query), args.action, args.name)
        if args.command == "invite":
            password = accounts.invite(args.email)
            print(f"Invited {normalise(args.email)}.\nTemporary password (shown once; they set their own at first sign-in):\n{password}")
        elif args.command == "reset":
            password = accounts.reset(args.email)
            print(f"New temporary password for {normalise(args.email)} (shown once):\n{password}")
        elif args.command in ("disable", "enable"):
            accounts.set_disabled(args.email, args.command == "disable")
            print(f"{args.command}d {normalise(args.email)}.")
        else:
            for row in accounts.list():
                state = "disabled" if row["disabled"] else ("must set password" if row["must_change"] else "active")
                print(f"{row['email']}\t{state}")
    except AccountError as error:
        sys.exit(str(error))
    except catalog_service.DatabaseError as error:
        sys.exit(f"Database: {error}")


if __name__ == "__main__":
    main()
