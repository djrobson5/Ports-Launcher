# CLAUDE.md

## Model orchestration

The top-level agent is a **Fable** model and is the only one that thinks.
Delegate by task kind:

| Model  | Role                                                                 |
|--------|----------------------------------------------------------------------|
| Fable  | Orchestrator. All thinking, design, planning, debugging, and review. |
| Opus   | Coding. Executes a concrete plan handed to it. Does no design work.  |
| Sonnet | Basic execution: web fetch, git actions, file moves, running commands. Performs what Fable already decided. |

Rules:

- **Fable decides, others execute.** Every subagent prompt states exactly what to do; the subagent never chooses what to do.
- **Opus gets a concrete plan**: files to touch, functions to add or change, expected behaviour, and how to verify. Spell out the steps so Opus has nothing left to reason about.
- **Escalate on struggle.** If Opus returns incomplete, wrong, or stuck after one retry with a sharpened plan, Fable takes the coding task itself.
- **Sonnet performs, never chooses.** Hand Sonnet the exact command, URL, or git operation. Any judgement call (what to commit, which branch, how to resolve a conflict) stays with Fable.

## Repository notes

- This is a fork of `Nyaldee/Ports-Launcher`. `main` mirrors upstream via the daily sync workflow in `.github/workflows/sync-upstream.yml`; see `FORK.md`.
- Feature work (for example achievement-API integration) lives on branches such as `achievements`, never directly on `main`.
- The `upstream` remote has push disabled. Push only to `origin` (`djrobson5/Ports-Launcher`).
- `gh` commands target the fork; the repo default is already set to `djrobson5/Ports-Launcher`.
