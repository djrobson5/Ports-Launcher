#!/usr/bin/env bash
# Rebuilds this fork's `main` as upstream/main plus exactly one "fork overlay"
# commit. Run from a checkout of `main` whose `origin` is the fork. Used by
# .github/workflows/sync-upstream.yml.
#
# The overlay is rebuilt from scratch on every upstream move, so it can never
# conflict:
#   - FORK_PATHS are copied verbatim from the current `main`;
#   - fork/ports.json entries are applied to upstream's ports.json
#     (apply-fork-catalog.py replaces same-named entries, appends new ones);
#   - upstream repo URLs in src/ and the updater scripts are rewritten to the
#     fork (ports.json URLs are left alone).
# The overlay commit carries an `Upstream: <sha>` trailer naming its base.
# Commits on top of the overlay may only touch FORK_PATHS; anything else makes
# the job fail rather than silently dropping it.
#
# DRY_RUN=1 builds the new main locally and shows it without pushing.
# PYTHON overrides the interpreter (default python3).
set -euo pipefail

UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/Nyaldee/Ports-Launcher.git}"
UPSTREAM_REPO=Nyaldee/Ports-Launcher
FORK_REPO=djrobson5/Ports-Launcher
FORK_PATHS=(FORK.md CLAUDE.md .github/workflows/sync-upstream.yml .github/scripts fork)
PYTHON="${PYTHON:-python3}"
DRY_RUN="${DRY_RUN:-0}"

if [ -n "$(git status --porcelain --untracked-files=all)" ]; then
  echo "::error::Working tree is not clean (untracked or modified files would end up in the overlay). Run from a clean checkout of main."
  exit 1
fi

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"
git fetch upstream main
git fetch origin main

old_head=$(git rev-parse HEAD)
remote_main=$(git rev-parse origin/main)
up=$(git rev-parse upstream/main)

last_overlay=$(git log -1 --format=%H --grep='^Upstream: ' "$old_head" || true)
last_base=""
if [ -n "$last_overlay" ]; then
  last_base=$(git log -1 --format='%(trailers:key=Upstream,valueonly)' "$last_overlay" | tr -d '[:space:]')

  excludes=()
  for p in "${FORK_PATHS[@]}"; do excludes+=(":(exclude)$p"); done
  stray=$(git log --format='%h %s' "$last_overlay..$old_head" -- . "${excludes[@]}")
  if [ -n "$stray" ]; then
    echo "::error::main only holds the fork overlay, but these commits on top of it change files outside FORK_PATHS (${FORK_PATHS[*]}):"
    echo "$stray"
    echo "::error::Move code changes to a feature branch, or catalog changes into fork/, then rerun."
    exit 1
  fi
fi

if [ "$last_overlay" = "$old_head" ] && [ "$last_base" = "$up" ]; then
  echo "Already up to date with upstream."
  exit 0
fi

echo "Rebuilding main as upstream $(git rev-parse --short "$up") + fork overlay."
git checkout -q --no-track -B main "$up"
git checkout "$old_head" -- "${FORK_PATHS[@]}"

catalog_log=$("$PYTHON" .github/scripts/apply-fork-catalog.py ports.json fork/ports.json)
echo "$catalog_log"

mapfile -t url_files < <(git grep -l "$UPSTREAM_REPO" -- src ports_launcher_updater.sh ports_launcher_updater.bat)
if [ "${#url_files[@]}" -eq 0 ]; then
  echo "::error::No '$UPSTREAM_REPO' references found in src/ or the updater scripts; upstream moved its repo URLs. Update .github/scripts/sync-upstream.sh."
  exit 1
fi
# -b keeps CRLF files (the .bat) intact under Git for Windows; no-op on Linux.
sed -b -i "s#$UPSTREAM_REPO#$FORK_REPO#g" "${url_files[@]}"

git add -A
git commit -q --author="djrobson5 <djrobson5@gmail.com>" -F - <<EOF
Fork overlay on upstream $(git rev-parse --short "$up")

- Fork files: ${FORK_PATHS[*]}
- Catalog entries from fork/ports.json: $(echo "$catalog_log" | paste -sd ';' - | sed 's/;/; /g')
- Repo URLs $UPSTREAM_REPO -> $FORK_REPO in: ${url_files[*]}

Upstream: $up
EOF

if [ "$DRY_RUN" = "1" ]; then
  git log --oneline -2
  git diff --stat "$up" HEAD
  echo "DRY_RUN=1: not pushing."
  exit 0
fi

if [ -z "$last_overlay" ]; then
  backup="backup/main-before-overlay-$(date -u +%Y-%m-%d-%H%M)"
  push_args=(--atomic --force-with-lease="main:$remote_main" origin
    "$remote_main:refs/heads/$backup" "HEAD:refs/heads/main")
else
  backup=""
  push_args=(--force-with-lease="main:$remote_main" origin HEAD:main)
fi
if ! git push "${push_args[@]}"; then
  echo "::error::Push failed. If the message mentions 'workflows' permission, add a SYNC_TOKEN secret (see FORK.md)."
  exit 1
fi
echo "Rebuilt main as upstream $(git rev-parse --short "$up") + overlay $(git rev-parse --short HEAD)${backup:+; previous main saved as $backup}."
