#!/usr/bin/env bash
# Fails if the repository tracks something it shouldn't: build output, local
# settings or secrets (*.env), Finder litter, or a file big enough to bloat
# every clone. Run by CI on every push; run it before committing a large change.
#
#   scripts/check-repo-hygiene.sh
set -euo pipefail
cd "$(dirname "$0")/.."

MAX_KB=5120  # 5 MB: the largest file this project needs is about 2 MB
problems=0

report() {
  echo "::error::$1"
  problems=1
}

# The index, not HEAD: a staged removal counts as removed.
tracked=$(git ls-files)

built=$(echo "$tracked" | grep -E '^(\.build|\.build-probe|build|dist|DerivedData)/' | head -5 || true)
[ -n "$built" ] && report "build output is tracked (it belongs in .gitignore): $(echo "$built" | tr '\n' ' ')"

secrets=$(echo "$tracked" | grep -E '(^|/)[^/]*\.env$|\.p12$|\.mobileprovision$' || true)
[ -n "$secrets" ] && report "local settings or credentials are tracked: $(echo "$secrets" | tr '\n' ' ')"

litter=$(echo "$tracked" | grep -E '(^|/)\.DS_Store$' || true)
[ -n "$litter" ] && report ".DS_Store files are tracked: $(echo "$litter" | tr '\n' ' ')"

# Absolute paths into someone's home folder. Placeholders used in tests and
# examples (/Users/me, /Users/someone, /Users/server, /Users/YOU, /Users/USER) are fine.
homes=$(git grep -nE '/Users/[A-Za-z0-9._-]+' -- . ':!*.png' ':!*.jpg' 2>/dev/null \
  | grep -vE '/Users/(me|someone|server|YOU|USER|Shared)\b' | head -5 || true)
[ -n "$homes" ] && report "a personal path is tracked: $(echo "$homes" | tr '\n' ' ')"

# Pictures over 1 MB outside the app's own resources: design exports and screenshots
# belong outside the repository (../AllSet-personal).
while IFS= read -r file; do
  case "$file" in Resources/*|Sources/*) continue ;; esac
  case "$file" in *.png|*.jpg|*.jpeg|*.heic|*.gif) ;; *) continue ;; esac
  [ -f "$file" ] || continue
  size=$(du -k "$file" | cut -f1)
  if [ "$size" -gt 1024 ]; then report "$file is a ${size} KB picture outside Resources/Sources"; fi
done <<< "$tracked"

while IFS= read -r file; do
  [ -f "$file" ] || continue
  size=$(du -k "$file" | cut -f1)
  if [ "$size" -gt "$MAX_KB" ]; then report "$file is ${size} KB, over the ${MAX_KB} KB limit"; fi
done <<< "$tracked"

if [ "$problems" -eq 0 ]; then
  echo "Repository hygiene: $(echo "$tracked" | wc -l | tr -d ' ') tracked files, nothing out of place."
fi
exit "$problems"
