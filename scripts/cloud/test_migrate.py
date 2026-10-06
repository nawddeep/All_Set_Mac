"""Schema migrations against a throwaway Postgres.

    /usr/bin/python3 -m unittest scripts/cloud/test_migrate.py
"""
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import migrate  # noqa: E402
import pgtest  # noqa: E402


@unittest.skipUnless(pgtest.AVAILABLE, "needs a local Postgres")
class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.pg = pgtest.Postgres(migrated=False)
        self.steps = tempfile.mkdtemp(prefix="allset-migrations-test-")

    def tearDown(self):
        self.pg.stop()
        shutil.rmtree(self.steps, ignore_errors=True)

    def step(self, name, body):
        with open(os.path.join(self.steps, name), "w") as handle:
            handle.write(body)

    def apply(self, directory=None):
        return migrate.apply(self.pg.url, psql=pgtest.PSQL, directory=directory)

    def test_a_fresh_database_gets_every_step_once(self):
        first = self.apply()
        self.assertEqual(first, migrate.steps())
        self.assertIn("0001_initial.sql", first)
        self.assertEqual(self.pg.sql("select count(*) from wallpapers"), "0")
        self.assertEqual(self.apply(), [])
        self.assertEqual(migrate.pending(self.pg.url, psql=pgtest.PSQL), [])

    def test_a_database_from_before_migrations_is_adopted_with_its_rows(self):
        """The server's database was made by loading the schema directly."""
        with open(os.path.join(migrate.MIGRATIONS, "0001_initial.sql")) as handle:
            self.pg.sql(handle.read())
        self.pg.sql("insert into wallpapers (id, title, kind, category) values ('kept', 't', 'video', 'abstract')")
        self.assertEqual(self.pg.sql("select to_regclass('schema_migrations') is null"), "t")

        self.assertEqual(self.apply(), migrate.steps())
        self.assertEqual(self.pg.sql("select id from wallpapers"), "kept")
        self.assertEqual(self.apply(), [])

    def test_steps_apply_in_name_order_and_only_the_new_ones(self):
        self.step("0001_a.sql", "create table things (id int primary key);")
        self.assertEqual(self.apply(self.steps), ["0001_a.sql"])
        self.step("0003_c.sql", "insert into things select id + 10 from things;")
        self.step("0002_b.sql", "insert into things values (1);")
        self.assertEqual(self.apply(self.steps), ["0002_b.sql", "0003_c.sql"])
        self.assertEqual(self.pg.sql("select string_agg(id::text, ',' order by id) from things"), "1,11")

    def test_a_step_that_fails_changes_nothing_and_stops_the_run(self):
        self.step("0001_a.sql", "create table things (id int primary key);")
        self.step("0002_broken.sql", "insert into things values (1); insert into nowhere values (2);")
        self.step("0003_c.sql", "insert into things values (3);")
        with self.assertRaises(migrate.MigrationError) as failure:
            self.apply(self.steps)
        self.assertIn("0002_broken.sql", str(failure.exception))
        # The first half of the broken step was rolled back, and the next never ran.
        self.assertEqual(self.pg.sql("select count(*) from things"), "0")
        self.assertEqual(migrate.pending(self.pg.url, psql=pgtest.PSQL, directory=self.steps),
                         ["0002_broken.sql", "0003_c.sql"])

        self.step("0002_broken.sql", "insert into things values (1);")
        self.assertEqual(self.apply(self.steps), ["0002_broken.sql", "0003_c.sql"])
        self.assertEqual(self.pg.sql("select count(*) from things"), "2")


if __name__ == "__main__":
    unittest.main()
