#!/usr/bin/env bash
# Brings this fork's `main` up to date with upstream. Run from a checkout of
# `main` whose `origin` is the fork. Used by .github/workflows/sync-upstream.yml.
#
# - upstream already contained in main: nothing to do.
# - shared history: fast-forward, or merge when fork-local commits exist.
# - no shared history (upstream force-pushed a squashed/rewritten main):
#   replay the fork's own commits onto the new upstream tip, then push the
#   old main to a backup branch and force-push the rebuilt main atomically.
#
# Fork commits are identified by author (FORK_AUTHORS, a `git log --author`
# regex). Any conflict fails the run without pushing anything.
set -euo pipefail

UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/Nyaldee/Ports-Launcher.git}"
FORK_AUTHORS="${FORK_AUTHORS:-djrobson5}"

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"
git fetch upstream main

old_head=$(git rev-parse HEAD)

if git merge-base --is-ancestor upstream/main HEAD; then
  echo "Already up to date with upstream."
  exit 0
fi

if git merge-base HEAD upstream/main >/dev/null 2>&1; then
  if git merge --ff-only upstream/main 2>/dev/null; then
    echo "Fast-forwarded to upstream."
  elif git merge --no-edit upstream/main; then
    echo "Merged upstream (merge commit created)."
  else
    git merge --abort
    echo "::error::Merge conflict with upstream. Resolve locally: git fetch upstream && git merge upstream/main"
    exit 1
  fi
  git push origin HEAD:main
  exit 0
fi

echo "upstream/main shares no history with main; upstream rewrote its history. Rebuilding main on the new upstream tip."

mapfile -t picks < <(git log --reverse --no-merges --format=%H --author="$FORK_AUTHORS" "$old_head")
if [ "${#picks[@]}" -eq 0 ]; then
  echo "::error::No fork commits (author matching '$FORK_AUTHORS') found on main; refusing to rebuild."
  exit 1
fi
echo "Replaying ${#picks[@]} fork commit(s):"
git log --no-walk=unsorted --format='  %h %s' "${picks[@]}"

git checkout -q --no-track -B main upstream/main
if ! git cherry-pick --empty=drop "${picks[@]}"; then
  git cherry-pick --abort || true
  git checkout -q -B main "$old_head"
  echo "::error::Replaying fork commits onto the rewritten upstream conflicted. Rebuild main locally (see FORK.md)."
  exit 1
fi

backup="backup/main-before-upstream-rewrite-$(date -u +%Y-%m-%d-%H%M)"
if ! git push --atomic --force-with-lease="main:$old_head" origin \
    "$old_head:refs/heads/$backup" "HEAD:refs/heads/main"; then
  echo "::error::Push failed. If the message mentions 'workflows' permission, add a SYNC_TOKEN secret (see FORK.md)."
  exit 1
fi
echo "Rebuilt main on upstream $(git rev-parse --short upstream/main); previous main saved as $backup."
