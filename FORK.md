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

- If upstream rewrites its history (the job fails with "shares no history"),
  the fork's `main` has to be rebuilt on the new upstream tip. Fork-local
  commits are the ones after the last upstream commit:

  ```sh
  git fetch upstream
  git rebase --onto upstream/main <last-upstream-commit-on-main> main
  # resolve conflicts (keep upstream's lines, swap Nyaldee -> djrobson5)
  git push --force-with-lease origin main
  ```

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
