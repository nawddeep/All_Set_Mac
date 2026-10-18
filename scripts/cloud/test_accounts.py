"""Accounts for the wallpaper server, against a throwaway Postgres.

    /usr/bin/python3 -m unittest scripts/cloud/test_accounts.py
"""
import datetime
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import accounts  # noqa: E402
import pgtest  # noqa: E402


class PasswordTests(unittest.TestCase):
    def test_a_password_is_stored_as_a_hash_and_checked(self):
        stored = accounts.hash_password("correct horse battery")
        self.assertNotIn("correct horse", stored)
        self.assertTrue(accounts.verify_password("correct horse battery", stored))
        self.assertFalse(accounts.verify_password("correct horse", stored))
        self.assertFalse(accounts.verify_password("", "not-a-hash"))

    def test_each_hash_has_its_own_salt(self):
        self.assertNotEqual(accounts.hash_password("same"), accounts.hash_password("same"))

    def test_temporary_passwords_are_readable_and_distinct(self):
        first, second = accounts.temporary_password(), accounts.temporary_password()
        self.assertRegex(first, r"^[a-z2-9]{4}(-[a-z2-9]{4}){3}$")
        self.assertNotEqual(first, second)

    def test_emails_are_checked_and_lowercased(self):
        self.assertEqual(accounts.normalise("  Friend@Example.COM "), "friend@example.com")
        for bad in ("", "no-at-sign", "a@b", "x@y.z", "o'brien@example.com"):
            with self.assertRaises(accounts.AccountError, msg=bad):
                accounts.normalise(bad)

    def test_no_value_is_written_into_sql(self):
        """Every value reaches psql as a variable: the SQL text names it, never holds it."""
        seen = []
        fake = accounts.Accounts(lambda sql, variables=None: seen.append((sql, variables)) or "[]")
        hostile = "x'); drop table accounts; --@example.com"
        with self.assertRaises(accounts.AccountError):
            fake.reset(hostile)
        fake.sign_out("token' or 1=1 --")
        for sql, variables in seen:
            self.assertNotIn("drop table", sql)
            self.assertNotIn("or 1=1", sql)
        self.assertTrue(any(variables for _, variables in seen))


@unittest.skipUnless(pgtest.AVAILABLE, "needs a local Postgres")
class AccountFlowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import catalog_service
        cls.pg = pgtest.Postgres()
        catalog_service.DATABASE_URL = cls.pg.url
        catalog_service.PSQL = pgtest.PSQL
        cls.now = datetime.datetime.now(datetime.timezone.utc)
        cls.accounts = accounts.Accounts(catalog_service.query, clock=lambda: cls.now)

    @classmethod
    def tearDownClass(cls):
        cls.pg.stop()

    def test_invite_then_first_sign_in_must_change_the_password(self):
        temporary = self.accounts.invite("new.person@example.com")
        self.assertIsNone(self.accounts.sign_in("new.person@example.com", "wrong-password"))
        session, must_change = self.accounts.sign_in("new.person@example.com", temporary)
        self.assertTrue(must_change)
        self.assertEqual(self.accounts.who(session), ("new.person@example.com", True))
        session = self.accounts.change_password(session, "my-own-password")
        self.assertEqual(self.accounts.who(session), ("new.person@example.com", False))
        self.assertIsNone(self.accounts.sign_in("new.person@example.com", temporary))

    def test_an_invite_is_only_once_and_reset_replaces_the_password(self):
        self.accounts.invite("twice@example.com")
        with self.assertRaises(accounts.AccountError):
            self.accounts.invite("twice@example.com")
        old = self.accounts.reset("twice@example.com")
        self.assertIsNotNone(self.accounts.sign_in("twice@example.com", old))
        new = self.accounts.reset("twice@example.com")
        self.assertIsNone(self.accounts.sign_in("twice@example.com", old))
        self.assertIsNotNone(self.accounts.sign_in("twice@example.com", new))

    def test_a_session_ends_after_its_time(self):
        password = self.accounts.invite("old.session@example.com")
        session, _ = self.accounts.sign_in("old.session@example.com", password)
        self.assertIsNotNone(self.accounts.who(session))
        # Expiry is judged by the database's clock, so age the session there.
        self.accounts.run("update sessions set expires_at = now() - interval '1 minute' where token_hash = :'token'",
                          {"token": accounts.token_hash(session)})
        self.assertIsNone(self.accounts.who(session))

    def test_signing_out_ends_the_session(self):
        password = self.accounts.invite("leaves@example.com")
        session, _ = self.accounts.sign_in("leaves@example.com", password)
        self.accounts.sign_out(session)
        self.assertIsNone(self.accounts.who(session))

    def test_unknown_accounts_and_missing_things_are_plain_errors(self):
        with self.assertRaises(accounts.AccountError):
            self.accounts.reset("nobody@example.com")
        with self.assertRaises(accounts.AccountError):
            self.accounts.set_disabled("nobody@example.com", True)
        self.assertIsNone(self.accounts.who(""))


class KeyFormatTests(unittest.TestCase):
    def test_new_keys_are_readable_and_distinct(self):
        first, second = accounts.new_key(), accounts.new_key()
        self.assertRegex(first, r"^ALLSET(-[A-HJKMNP-Z2-9]{4}){3}$")
        self.assertNotEqual(first, second)

    def test_a_pasted_key_is_tidied_to_its_one_form(self):
        key = accounts.new_key()
        for typed in (key, key.lower(), "  " + key + "\n", key.replace("-", ""), key[len("ALLSET-"):],
                      key.replace("-", " ")):
            self.assertEqual(accounts.canonical_key(typed), key, msg=typed)
        for bad in ("", None, "ALLSET-AAAA-AAAA", "ALLSET-AAAA-AAAA-AAA0", "ALLSET-AAAA-AAAA-AAAAA", "ALLSET-AAAA-AAAA-AAA'"):
            self.assertEqual(accounts.canonical_key(bad), "", msg=bad)

    def test_names_are_checked(self):
        self.assertEqual(accounts.check_name("  AadityaSir "), "AadityaSir")
        for bad in ("", " ", "o'brien", "-dash-first", "x" * 65):
            with self.assertRaises(accounts.AccountError, msg=bad):
                accounts.check_name(bad)

    def test_no_key_value_is_written_into_sql(self):
        seen = []
        fake = accounts.AccessKeys(lambda sql, variables=None: seen.append((sql, variables)) or "[]")
        self.assertIsNone(fake.activate("ALLSET-AAAA-BBBB-CCCC"))
        self.assertIsNone(fake.who("token' or 1=1 --"))
        for sql, variables in seen:
            self.assertNotIn("or 1=1", sql)
            self.assertNotIn("AAAA", sql)
        self.assertTrue(all(variables for _, variables in seen))


@unittest.skipUnless(pgtest.AVAILABLE, "needs a local Postgres")
class AccessKeyFlowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import catalog_service
        cls.pg = pgtest.Postgres()
        catalog_service.DATABASE_URL = cls.pg.url
        catalog_service.PSQL = pgtest.PSQL
        cls.keys = accounts.AccessKeys(catalog_service.query)
        cls.marker = tempfile.mkdtemp(prefix="allset-access-test-")
        cls.real_marker = accounts.ACCESS_CHANGED
        accounts.ACCESS_CHANGED = os.path.join(cls.marker, "changed")

    @classmethod
    def tearDownClass(cls):
        accounts.ACCESS_CHANGED = cls.real_marker
        shutil.rmtree(cls.marker, ignore_errors=True)
        cls.pg.stop()

    def test_a_key_is_stored_only_as_a_hash_and_activates(self):
        key = self.keys.create("navdeep")
        stored = self.keys.run("select key_hash from access_keys where name = 'navdeep'")
        self.assertNotIn(key, stored)
        token, name, expires = self.keys.activate(key.lower().replace("-", " "))
        self.assertEqual(name, "navdeep")
        self.assertRegex(expires, r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")
        self.assertEqual(self.keys.who(token), ("navdeep", expires))
        self.assertNotIn(token, self.keys.run("select string_agg(token_hash, ',') from access_tokens"))
        self.assertIsNone(self.keys.activate("ALLSET-AAAA-AAAA-AAAA"))
        self.assertIsNone(self.keys.who("not-a-token"))
        self.assertIsNone(self.keys.who(""))

    def test_each_device_gets_its_own_token(self):
        key = self.keys.create("two macs")
        first, second = self.keys.activate(key)[0], self.keys.activate(key)[0]
        self.assertNotEqual(first, second)
        self.assertIsNotNone(self.keys.who(first))
        self.assertIsNotNone(self.keys.who(second))
        self.assertEqual([row["devices"] for row in self.keys.list() if row["name"] == "two macs"], [2])

    def test_revoking_ends_the_key_and_its_tokens_and_tells_the_service(self):
        key = self.keys.create("leaver")
        token = self.keys.activate(key)[0]
        before = os.path.getmtime(accounts.ACCESS_CHANGED) if os.path.exists(accounts.ACCESS_CHANGED) else None
        self.assertEqual(self.keys.revoke("LEAVER"), "leaver")
        self.assertNotEqual(os.path.getmtime(accounts.ACCESS_CHANGED), before)
        self.assertIsNone(self.keys.who(token))
        self.assertIsNone(self.keys.activate(key))
        with self.assertRaises(accounts.AccountError):
            self.keys.create("Leaver")  # one key per name, whatever its case, until deleted
        self.keys.delete("leaver")
        self.assertIsNotNone(self.keys.activate(self.keys.create("leaver")))

    def test_a_token_ends_after_its_time(self):
        token = self.keys.activate(self.keys.create("old token"))[0]
        self.keys.run("update access_tokens set expires_at = now() - interval '1 minute' where token_hash = :'token'",
                      {"token": accounts.token_hash(token)})
        self.assertIsNone(self.keys.who(token))

    def test_unknown_names_are_plain_errors(self):
        with self.assertRaises(accounts.AccountError):
            self.keys.revoke("nobody")
        with self.assertRaises(accounts.AccountError):
            self.keys.delete("nobody")
        with self.assertRaises(accounts.AccountError):
            self.keys.create("o'brien")


if __name__ == "__main__":
    unittest.main()
