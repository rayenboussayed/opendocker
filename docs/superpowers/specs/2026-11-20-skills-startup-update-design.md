# Startup skill refresh and local snapshot — design

Date: 2026-11-20

## Goal

On every container start, update all lock-tracked global skills and record the result as a signed
**local** git commit in the `opencode-global-skills` volume. No remote push.

## Context

- Global skill files: `~/.config/opencode/skills` (`opencode-config` volume).
- Canonical store and global lock: `~/.agents/skills` and `~/.agents/.skill-lock.json`
  (`opencode-global-skills` volume).
- The entrypoint already fixes volume ownership and configures git identity plus SSH signing for the
  `opencode` user before launching the server.

## Design

- Implement in `entrypoint.sh`, non-root branch, after signing setup and before `exec "$@"`.
- `refresh_skills_snapshot()`:
  1. `npx -y skills update -g -y` (non-interactive, lock-tracked global skills only).
  2. Ensure `~/.agents` exists; `git init -q` once if `.git` is absent.
  3. `git add -A`; if anything is staged, commit with a UTC timestamped message:
     `skills: auto-update YYYY-MM-DDTHH:MM:SSZ`.
  4. Log a clear `[entrypoint]` line on commit; warn on any failure.
- Commits use the already-configured global git identity and SSH signing.

## Error handling

- Every step is failure-tolerant: a failed update, init, add or commit logs a warning and startup
  continues. The entrypoint runs under `set -Eeuo pipefail`, so failures are caught explicitly.
- No secrets are printed. Only `~/.agents` is staged; no remote operations.

## Documentation

- Short note in the "Agent skills" section of `AGENTS.md`.

## Verification

- `bash -n entrypoint.sh`.
- On a start where skills change, logs show `[entrypoint] committed skills snapshot: ...`.
- `git -C ~/.agents log --show-signature -1` shows a signed commit (run inside the container).
