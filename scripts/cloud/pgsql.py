"""Running SQL through psql with every value passed as a psql variable.

Values never become part of the SQL text. Each one goes to psql as its own
argument (`-v name=value`) and the SQL refers to it as `:'name'`, which psql
sends as a properly quoted literal; lists and rows go as JSON
(`(:'rows')::jsonb`). The SQL is read from stdin, the only way psql
substitutes variables (`-c` doesn't).

    run(url, "select title from wallpapers where id = :'id'", {"id": item_id})
"""
import json
import os
import re
import subprocess

PSQL = "/opt/homebrew/bin/psql" if os.path.exists("/opt/homebrew/bin/psql") else "psql"
NAME = re.compile(r"[a-z_][a-z0-9_]{0,62}")


class DatabaseError(Exception):
    pass


def value(item):
    """What psql receives for one variable: text as is, everything else as JSON."""
    if item is None:
        raise ValueError("pass NULL in the SQL, not as a variable")
    if isinstance(item, bool):
        return "true" if item else "false"
    if isinstance(item, (int, float)):
        return str(item)
    if isinstance(item, str):
        return item
    return json.dumps(item, separators=(",", ":"))


def arguments(variables):
    """`-v name=value` pairs, the names checked (they are interpolated as names)."""
    args = []
    for name, item in (variables or {}).items():
        if not NAME.fullmatch(name):
            raise ValueError(f"bad variable name {name!r}")
        args += ["-v", f"{name}={value(item)}"]
    return args


def run(url, sql, variables=None, psql=None, timeout=30, lines=False):
    """Runs `sql` (one or more statements) in one psql session. Returns its
    output, trimmed, or a list of output lines with `lines=True`."""
    command = [psql or PSQL, url, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1"] + arguments(variables) + ["-f", "-"]
    try:
        result = subprocess.run(command, input=sql, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise DatabaseError(str(error)) from error
    if result.returncode != 0:
        raise DatabaseError(result.stderr.strip() or f"psql exited {result.returncode}")
    return result.stdout.splitlines() if lines else result.stdout.strip()


def incoming(rows):
    """Script lines that load `rows` (a list of dicts) into a temporary table
    `incoming (doc jsonb)` through COPY: the data follows the command on stdin
    and is never parsed as SQL. Put it at the start of a script given to `run`,
    then read the rows with `doc->>'field'`."""
    lines = ["create temp table incoming (doc jsonb);", "copy incoming (doc) from stdin;"]
    for row in rows:
        # COPY's text format: a backslash is its escape character, so it's doubled.
        # json.dumps writes no raw tab or newline (they become \t and \n), so a
        # row is always one line and can never be the end-of-data marker.
        lines.append(json.dumps(row, separators=(",", ":")).replace("\\", "\\\\"))
    lines.append("\\.")
    return "\n".join(lines) + "\n"
