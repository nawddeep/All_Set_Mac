"""The one lock every writer of the wallpaper catalog takes.

Anything that deletes a row, or sets or changes a row's storage keys
(playback_key, still_key, thumbnail_key), does it in a transaction that
first runs

    select pg_advisory_xact_lock(ASSET_LOCK);

so "does another row use this file?" and "delete this row" can't interleave
with another writer's change. The lock is released when the transaction ends.

Work that decides from the catalog and then acts on files (the purge of
retired files) holds the same lock, session-wide, across both
(delete_service.AssetLock).

Second rule: a writer only points a key at a file that is in its place in
storage, checked while it holds the lock. set_storage_key.py does both, and is
the supported way to set a key.

A writer that skips a rule (an UPDATE typed into psql) is covered for a while,
not for ever: deleted files are retired before they are destroyed, and a
retired file that any row references is put back. Once a retired file has been
purged, a reference written to it points at nothing.
"""

# Arbitrary, fixed: the same number in every script and on every machine.
ASSET_LOCK = 4_711_061_026
