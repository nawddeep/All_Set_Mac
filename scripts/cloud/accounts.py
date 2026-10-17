"""Invited people's accounts for the wallpaper server: sign in, sessions, and
the command you run to invite, reset, disable and list them.

    /usr/bin/python3 scripts/cloud/accounts.py invite friend@example.com
    /usr/bin/python3 scripts/cloud/accounts.py reset friend@example.com
    /usr/bin/python3 scripts/cloud/accounts.py disable friend@example.com
    /usr/bin/python3 scripts/cloud/accounts.py enable friend@example.com
    /usr/bin/python3 scripts/cloud/accounts.py list

Run on the server (it talks to Postgres the way catalog_service.py does). An
invite prints a temporary password once; send it to them. Their first sign-in
must set a new one. Passwords are stored as salted PBKDF2 hashes; sessions as SHA-256
hashes of random tokens, so a leaked table can't sign anyone in.

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


def lit(text):
    """A string as a SQL literal. Only for values that have been checked above."""
    return "'" + str(text).replace("'", "''") + "'"


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


def rows(sql_text, run):
    return json.loads(run(f"select coalesce(json_agg(t), '[]') from ({sql_text}) t") or "[]")


class Accounts:
    """Every method takes `run(sql) -> str`: psql's output for one statement."""

    def __init__(self, run, clock=None):
        self.run = run
        self.clock = clock or (lambda: datetime.datetime.now(datetime.timezone.utc))

    def _user(self, email):
        found = rows(f"select email, password_hash, must_change, disabled from accounts where email = {lit(email)}", self.run)
        return found[0] if found else None

    def invite(self, email):
        email = normalise(email)
        if self._user(email):
            raise AccountError(f"{email} already has an account. Use reset to give them a new temporary password.")
        password = temporary_password()
        self.run(f"insert into accounts (email, password_hash, must_change) values "
                 f"({lit(email)}, {lit(hash_password(password))}, true)")
        return password

    def reset(self, email):
        email = normalise(email)
        if not self._user(email):
            raise AccountError(f"No account for {email}.")
        password = temporary_password()
        self.run(f"update accounts set password_hash = {lit(hash_password(password))}, must_change = true "
                 f"where email = {lit(email)}")
        self.run(f"delete from sessions where email = {lit(email)}")
        return password

    def set_disabled(self, email, disabled):
        email = normalise(email)
        if not self._user(email):
            raise AccountError(f"No account for {email}.")
        self.run(f"update accounts set disabled = {'true' if disabled else 'false'} where email = {lit(email)}")
        if disabled:
            self.run(f"delete from sessions where email = {lit(email)}")

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
        self.run(f"insert into sessions (token_hash, email, expires_at) values "
                 f"({lit(token_hash(token))}, {lit(email)}, {lit(expires.isoformat())})")
        return token, bool(user["must_change"])

    def who(self, token):
        """(email, must_change) for a live session of an enabled account, else None."""
        if not token:
            return None
        found = rows(f"select a.email, a.must_change from sessions s join accounts a on a.email = s.email "
                     f"where s.token_hash = {lit(token_hash(token))} and s.expires_at > now() and not a.disabled",
                     self.run)
        return (found[0]["email"], bool(found[0]["must_change"])) if found else None

    def sign_out(self, token):
        if token:
            self.run(f"delete from sessions where token_hash = {lit(token_hash(token))}")

    def change_password(self, token, new_password):
        """Sets a new password for the signed-in account, ends its other sessions, and
        returns a fresh session token for this one."""
        who = self.who(token)
        if not who:
            raise AccountError("Sign in again.")
        if len(new_password or "") < MIN_PASSWORD:
            raise AccountError(f"Use at least {MIN_PASSWORD} characters.")
        email = who[0]
        self.run(f"update accounts set password_hash = {lit(hash_password(new_password))}, must_change = false "
                 f"where email = {lit(email)}")
        self.run(f"delete from sessions where email = {lit(email)}")
        token = secrets.token_urlsafe(32)
        expires = self.clock() + datetime.timedelta(days=SESSION_DAYS)
        self.run(f"insert into sessions (token_hash, email, expires_at) values "
                 f"({lit(token_hash(token))}, {lit(email)}, {lit(expires.isoformat())})")
        return token


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
    args = parser.parse_args(argv)
    accounts = Accounts(catalog_service.query)
    try:
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
