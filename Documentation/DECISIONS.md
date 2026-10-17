# Decisions (production-readiness run)

One entry per non-obvious choice: date · finding · choice · why · how to reverse.

- 2026-10-17 · all · Uncommitted work from earlier sessions committed as one snapshot (`5e7f5ee`) before any change · owner's choice, gives a clean baseline · it is an ordinary commit; revert or cherry-pick around it.
- 2026-10-17 · #1 · Lid Plane removed entirely (c5192d2): 20 tests went with it (456 → 436) · GPL-3.0 code would force the whole app to be GPL · `git revert c5192d2`, then license the app GPL-3.0.
- 2026-10-17 · process · The Dock app is rebuilt and relaunched (30 s stay-up check) after each task that changes the app's UI or runtime, and at least once per phase otherwise · `build-app.sh` takes ~3.5 min; doing it after doc/test/server-only tasks adds nothing.
