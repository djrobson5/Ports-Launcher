# About this fork

This is a fork of [Nyaldee/Ports-Launcher](https://github.com/Nyaldee/Ports-Launcher),
kept in sync with upstream so it can serve as a base for experimental features
(notably achievement-API integration across ports) that may never land upstream.

## How syncing works

- `main` is always `upstream/main` plus exactly one **fork overlay** commit.
  The overlay commit ends with an `Upstream: <sha>` trailer naming its base.
- `.github/workflows/sync-upstream.yml` runs daily (and on demand from the
  Actions tab). Whenever upstream moves, including when it force-pushes a
  squashed `main`, the job rebuilds the overlay from scratch on the new
  upstream tip and force-pushes `main`. Nothing is replayed, so nothing can
  conflict.
- Rebuilding `main` re-creates the workflow file, which the default
  `GITHUB_TOKEN` may not push. The job therefore uses the `SYNC_TOKEN` secret:
  a fine-grained PAT scoped to this repo with **Contents: read and write** and
  **Workflows: read and write**.
- Run the job locally (builds the new `main` without pushing) from a checkout
  of `main`. The checkout must be clean (no untracked files such as `target/`),
  since upstream has no `.gitignore`; a fresh clone is simplest:

  ```sh
  DRY_RUN=1 PYTHON=python bash .github/scripts/sync-upstream.sh
  ```

## Divergences from upstream

The overlay contains:

- The fork's own files, copied verbatim from the current `main`: `FORK.md`,
  `CLAUDE.md`, `.github/workflows/sync-upstream.yml`, `.github/scripts/` and
  `fork/`.
- Catalog entries from `fork/ports.json`, applied to upstream's `ports.json`:
  an upstream entry with the same `name` (or `-name`) is replaced, otherwise
  the entry is added before the schema entry. Currently: Lost Odyssey.
- Repo URLs in `src/` and the two updater scripts rewritten from
  `Nyaldee/Ports-Launcher` to `djrobson5/Ports-Launcher`, so a binary built
  from this fork serves this fork's `ports.json` and self-updates from here.
  The `extra/` URLs inside `ports.json` intentionally still point upstream.

Only those fork paths may be changed directly on `main`. Commit edits to them
on top of the overlay and the next run folds them into a fresh overlay; a
commit on `main` touching anything else makes the job fail. To add or change
a catalog entry, edit `fork/ports.json`, not `ports.json`.

## Local setup

```sh
git clone https://github.com/djrobson5/Ports-Launcher.git
cd Ports-Launcher
git remote add upstream https://github.com/Nyaldee/Ports-Launcher.git
git remote set-url --push upstream no_push   # never push to upstream by accident
```

## Feature work

Keep `main` as upstream plus the overlay. Do code changes on branches (for
example `achievements`). After `main` is rebuilt, move a branch onto the new
overlay:

```sh
git fetch origin
git rebase --onto origin/main $(git log -1 --format=%H --grep='^Upstream: ' <branch>) <branch>
```
