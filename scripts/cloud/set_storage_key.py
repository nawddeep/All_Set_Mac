"""Points a wallpaper's row at a file in storage, the supported way.

    /usr/bin/python3 scripts/cloud/set_storage_key.py <id> <column> <relative path>
    /usr/bin/python3 scripts/cloud/set_storage_key.py 0123abcd playback_key live/0123abcd.mp4

Run on the server, after the file is there (scripts/cloud/push_wallpapers.sh).
<column> is playback_key, still_key or thumbnail_key.

Use this instead of an UPDATE typed into psql. It takes the lock deletes and
purges take (catalog_lock.py), so it can't interleave with them, and it only
references a file that is in its place. A file retired with a deleted wallpaper
is brought back first; a file that is nowhere is refused, so a row is never
left pointing at nothing.

Exits 0 when the key is set, 1 with the reason when it isn't.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import delete_service  # noqa: E402


def main(arguments):
    if len(arguments) != 3:
        sys.exit(__doc__)
    problem = delete_service.reference_asset(*arguments)
    if problem:
        sys.exit(f"not set: {problem}")
    print(f"{arguments[0]}.{arguments[1]} = {arguments[2]}")


if __name__ == "__main__":
    main(sys.argv[1:])
