# About this fork

This is a fork of [Nyaldee/Ports-Launcher](https://github.com/Nyaldee/Ports-Launcher),
kept in sync with upstream so it can serve as a base for experimental features
(notably achievement-API integration across ports) that may never land upstream.

## How syncing works

- `.github/workflows/sync-upstream.yml` runs daily (and on demand from the
  Actions tab) and merges `upstream/main` into this fork's `main`.
- If a merge conflict occurs the job fails; resolve it locally:

  ```sh
  git fetch upstream
  git merge upstream/main
  # fix conflicts, commit, then:
  git push origin main
  ```

- Upstream regularly force-pushes a squashed `main`. The job handles that on
  its own: it replays every non-merge commit authored by `djrobson5` onto the
  new upstream tip, saves the old `main` as
  `backup/main-before-upstream-rewrite-<date>`, and force-pushes. Keep
  fork-only changes in commits authored as `djrobson5` so they get replayed;
  merge commits are not replayed. Delete old `backup/*` branches when you no
  longer need them.
- Rebuilding `main` re-creates the commit that adds the workflow file, which
  the default `GITHUB_TOKEN` may not push. The job therefore uses the
  `SYNC_TOKEN` secret: a fine-grained PAT scoped to this repo with
  **Contents: read and write** and **Workflows: read and write**.
- If replaying conflicts, the job fails without pushing. Rebuild by hand:

  ```sh
  git fetch upstream
  git checkout -B main upstream/main
  git cherry-pick $(git log --reverse --no-merges --format=%H --author=djrobson5 origin/main)
  # resolve conflicts (keep upstream's lines, swap Nyaldee -> djrobson5)
  git push --force-with-lease=main:$(git rev-parse origin/main) origin main
  ```

  The sync logic lives in `.github/scripts/sync-upstream.sh`; running it from
  a checkout of `main` does the same thing as the job.

## Divergences from upstream

- The catalog/theme raw URLs, self-update repo, GitHub links and the two
  updater scripts point at `djrobson5/Ports-Launcher` instead of upstream, so
  a binary built from this fork serves this fork's `ports.json`.
- `ports.json` carries fork-only entries (currently Lost Odyssey). When an
  upstream sync conflicts on that file, keep both sides' changes.

## Local setup

```sh
git clone https://github.com/djrobson5/Ports-Launcher.git
cd Ports-Launcher
git remote add upstream https://github.com/Nyaldee/Ports-Launcher.git
git remote set-url --push upstream no_push   # never push to upstream by accident
```

## Feature work

Keep `main` as the synced mirror plus this note and the workflow. Do feature
work on branches (for example `achievements`) and periodically merge or rebase
them onto `main` so they pick up upstream changes.
