"""Accounts for the wallpaper server, against a throwaway Postgres.

    /usr/bin/python3 -m unittest scripts/cloud/test_accounts.py
"""
import datetime
import os
import sys
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

    def test_sql_text_is_quoted(self):
        self.assertEqual(accounts.lit("it's"), "'it''s'")


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
        self.accounts.run(f"update sessions set expires_at = now() - interval '1 minute' "
                          f"where token_hash = {accounts.lit(accounts.token_hash(session))}")
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


if __name__ == "__main__":
    unittest.main()
