"""pgsql.py: values reach Postgres as psql variables or COPY data, never as SQL text."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pgsql  # noqa: E402
import pgtest  # noqa: E402

HOSTILE = ["it's", "'); drop table wallpapers; --", "back\\slash", "\\.", "line\nbreak", "tab\there", "naïve ☕", ":'name'", "$$x$$"]


class ArgumentTests(unittest.TestCase):
    def test_names_are_checked_and_values_are_plain_arguments(self):
        self.assertEqual(pgsql.arguments({"id": "a'b"}), ["-v", "id=a'b"])
        self.assertEqual(pgsql.arguments({"rows": [1, "x"]}), ["-v", 'rows=[1,"x"]'])
        self.assertEqual(pgsql.arguments({"flag": True}), ["-v", "flag=true"])
        for bad in ("Id", "1x", "a-b", "a b", "x;drop"):
            with self.assertRaises(ValueError, msg=bad):
                pgsql.arguments({bad: "v"})
        with self.assertRaises(ValueError):
            pgsql.arguments({"none": None})

    def test_rows_are_one_copy_line_each(self):
        script = pgsql.incoming([{"t": value} for value in HOSTILE])
        data = script.splitlines()[2:-1]
        self.assertEqual(len(data), len(HOSTILE))
        self.assertTrue(script.endswith("\\.\n"))
        self.assertNotIn("\\.", data)


@unittest.skipUnless(pgtest.AVAILABLE, "needs a local Postgres")
class DatabaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pg = pgtest.Postgres()

    @classmethod
    def tearDownClass(cls):
        cls.pg.stop()

    def run_sql(self, sql, variables=None):
        return pgsql.run(self.pg.url, sql, variables, psql=pgtest.PSQL)

    def test_variables_arrive_exactly_as_given(self):
        for value in HOSTILE:
            self.assertEqual(self.run_sql("select :'value'", {"value": value}), value)
            self.assertEqual(self.run_sql("select length(:'value')", {"value": value}), str(len(value)))
        self.assertEqual(self.run_sql("select count(*) from (select jsonb_array_elements_text((:'list')::jsonb)) t", {"list": HOSTILE}),
                         str(len(HOSTILE)))
        self.assertEqual(self.pg.sql("select to_regclass('wallpapers') is not null"), "t")

    def test_copied_rows_arrive_exactly_as_given(self):
        out = self.run_sql(pgsql.incoming([{"t": value} for value in HOSTILE]) +
                           "select json_agg(doc->>'t') from incoming;")
        import json
        self.assertEqual(json.loads(out), HOSTILE)
        self.assertEqual(self.pg.sql("select to_regclass('wallpapers') is not null"), "t")

    def test_rows_populate_a_table_by_their_names(self):
        row = {"id": "pgsql-test-1", "title": "'); drop table wallpapers; --", "kind": "video", "category": "abstract",
               "tags": ["a,b", "c\"d"], "status": "quarantined", "provenance": {"source": "test"}}
        try:
            self.run_sql(pgsql.incoming([row]) +
                         "insert into wallpapers (id, title, kind, category, tags, status, provenance) "
                         "select r.id, r.title, r.kind, r.category, r.tags, r.status, r.provenance "
                         "from incoming, jsonb_populate_record(null::wallpapers, incoming.doc) r;")
            self.assertEqual(self.pg.sql("select title from wallpapers where id = 'pgsql-test-1'"), row["title"])
            self.assertEqual(self.pg.sql("select tags[2] from wallpapers where id = 'pgsql-test-1'"), 'c"d')
        finally:
            self.pg.sql("delete from wallpapers where id = 'pgsql-test-1'")

    def test_an_error_is_reported_not_swallowed(self):
        with self.assertRaises(pgsql.DatabaseError):
            self.run_sql("select * from no_such_table")


if __name__ == "__main__":
    unittest.main()


class NoHandQuotingTests(unittest.TestCase):
    """Escaping quotes by hand was how values got into SQL text; it's gone and stays gone."""

    def test_no_script_quotes_sql_values_itself(self):
        import re
        pattern = re.compile(r"""replace\(\s*["']'["']\s*,\s*["']''["']\s*\)|def (lit|quote|quoted)\(""")
        for name in sorted(os.listdir(HERE)):
            if not name.endswith(".py") or name.startswith("test_"):
                continue
            with open(os.path.join(HERE, name)) as handle:
                found = pattern.search(handle.read())
            self.assertIsNone(found, f"{name} quotes SQL by hand: {found and found.group(0)}")
