# Agent environment

You are working in a ready-to-use Debian development environment with Node.js, Python, git/GitHub tooling and preconfigured MCP servers. This file is machine-wide guidance; follow it unless the user says otherwise.

Git transport uses SSH; GitHub operations use `gh`. Both are preconfigured — read this file before touching either.

## Additional services

`make run` starts five containers: OpenCode (agent and web UI on port 4000), the Docker MCP gateway (host port
`MCP_GATEWAY_PORT`, default 8200), **n8n** (workflow editor on port 5678), its **Postgres** database, and a private
**SearXNG** search backend. OpenCode, the gateway and n8n publish on `127.0.0.1`; Postgres and SearXNG are reachable
only over the internal compose network. OpenCode and the gateway share `docker-compose.opencode.yml` (with
`opencode` depending on `mcp-gateway`), while n8n, Postgres and SearXNG live in `docker-compose.n8n.yml`. The code
files are intentionally comment-light — put "why" notes in the repo's `README.md`, in its design-decisions section,
not back into the code.

The `opencode` service passes an explicit `environment:` allowlist and never `env_file: .env`; n8n/Postgres/SearXNG
secrets must never enter the agent container. OpenCode is limited to 4,096 processes / 8 GB memory, the gateway to
4 GB, n8n to 2 GB, and Postgres/SearXNG to 1 GB; all services drop capabilities and set `no-new-privileges: true`.

The Dockerfile copies `AGENTS.md` and `opencode.json` to `/etc/opencode/`, chmods that directory to 755 so the
`opencode` user can read it, and `opencode.json` loads `/etc/opencode/AGENTS.md`; keep those paths in sync if either file
moves. The gateway generates its small config files at startup from inline Compose commands (`tool-name-prefix`
avoids tool-name collisions; `n8n.api_url` points at the local n8n). Run `opencode mcp list` from `~/workspace`, not
the home directory, or no project config is discovered.

- n8n stores workflows, credentials and execution history in Postgres. `N8N_ENCRYPTION_KEY` in `.env`
  encrypts stored credentials — back it up and never rotate it casually.
- n8n reaches the OpenCode server at `http://opencode:4000` with HTTP Basic auth (user `opencode`,
  password `OPENCODE_PASSWORD`). The community node is pinned by checksum in `docker-compose.n8n.yml`.
- SearXNG is at `http://searxng:8080`. JSON results require the `search.formats` override in
  `searxng-settings.yml`. It backs n8n Assistant web search and can be queried directly from an
  n8n HTTP Request node.

## Before you start working

Skills are the encoded best practices for this environment and its projects — use them instead of
falling back on generic knowledge. Do this **before** any implementation, research, or code change,
and think step by step throughout:

1. **Understand the task and the repo.** Read the request, then inspect the project (stack, frameworks,
   `package.json`/manifest, layout, recent commits, existing docs) to learn which technologies and
   domains are involved. Don't guess.
2. **List the skills you'll need.** Map the stack and the task to concrete skill needs — e.g. TypeScript,
   NestJS, Prisma, PostgreSQL/SQL, Playwright/E2E, React, a specific security/compliance topic, or docs
   writing.
3. **Inventory what's already available.** Run `npx skills list -g` and, inside the project,
   `npx skills list`, and review the skills advertised in this session. Note what's missing.
4. **Search for every missing skill.** Use `npx skills find <query> [--owner <owner>]` for each need — do
   all the searches, don't stop at the first hit. Verify candidates: prefer 1K+ installs, reputable
   sources (`anthropics`, `vercel-labs`, `microsoft`), read their `SKILL.md`, and check
   https://skills.sh/audits. Preview with `npx skills use <owner/repo@skill>` before installing.
5. **Install only the skills you'll actually use.** Project-only: from `~/workspace`, run
   `npx skills add <owner/repo@skill> -a opencode -y`. Shared across projects:
   `npx skills add <owner/repo@skill> -g -a opencode -y`. See "Install and update — keep them in
   persisted volumes" for the storage details.
6. **Load and read each installed skill before using it.** Call the `skill` tool with the skill's
   directory name as its `id`, or read its `SKILL.md` directly — supporting files are relative to that
   directory.
7. **Consume the skills for the whole task.** Follow the loaded skills' instructions for the relevant
   files, commands and decisions, and re-check them whenever the work enters a domain a skill covers.
   Think step by step and verify each result.

## Agentic coding playbook

Goal: orchestrate agents to build software that is simple, minimal, maintainable, readable, writable,
documented, typed, tested (unit / integration / e2e / performance / memory), secure and fast — with no
redundant code or types, using the right best practices and design patterns. These rules are distilled from
large-scale agentic engineering write-ups (minimaxir's agentic iteration, "Rewriting Bun in Rust", and
GitHub's Copilot-runtime-to-Rust migration). They concern *how to drive agents*, not any one language:
do **not** rewrite projects in Rust unless the user explicitly asks.

### Quality bar (non-negotiable)

- Prefer simple, minimal and readable over clever; make the smallest change that satisfies the contract.
- No redundant code or duplicate types: deduplicate, prune dead code, reuse through idiomatic DRY.
- Use a strongly typed compiler and linters as a fast feedback loop; prefer guarantees enforced by the
  type system over style guides and manual review.
- Document decisions in the repo and keep docs in sync with code; follow the project's existing design
  patterns and conventions instead of inventing parallel structures.
- Cover unit, integration, e2e, performance and memory/leak tests where relevant.

### Operate the control loop, don't "assign and wait"

- Work in loops: task → implement → review → apply feedback → repeat. Inspect results, challenge decisions,
  enforce quality gates, and push back when an agent treats an intermediate stopping point as the finish line.
- Own the framing, boundaries, strategy, trade-offs, high-risk review and final merge; agents do the volume.
- State the goal and end state explicitly and completely — vague instructions get read narrowly. Say what
  "done" means, including what must be removed.

### Research first, write second

- Expect ~10x more reading/searching than editing: inspect state, form a hypothesis, make a targeted change,
  repeat. Don't "spew code".
- For large changes, map ownership and seams before editing, then delegate slices.
- De-risk big work: write design decisions into a doc, review that doc adversarially, and trial-run on a
  small representative slice before scaling. Do all searches and verify evidence; think step by step.

### Prompt for constraints, not outcomes

- Replace "make it better/faster" with specific, measurable, pass/fail targets (e.g. ">=1.2x vs baseline",
  "no more than 5% regression").
- Establish a true baseline before changing anything; iterate in small high-impact increments; report
  results against the baseline each pass; stop when gains converge and added code is disproportionate.
- Explicitly forbid gaming the metric — change only the implementation, never the test or benchmark;
  verify via the git diff.
- Escape local optima with deliberate "breakthrough" prompts: don't repeat what failed, forbid giving up
  easily, require a fundamental change rather than hyperparameter tweaks.
- Call out forbidden shortcuts up front (e.g. unsafe code, escape-hatch labels, stubs).

### Adversarial review (separate contexts)

- 1 implementer + 2 or more adversarial reviewers per change. Reviewer sees only the diff, is told to
  assume the code is wrong, and its only job is to find bugs. Implementer doesn't review; reviewer doesn't implement.
- Reviewer checklist: behavioral equivalence, incompatibilities, simplification/idiomatic patterns, avoid
  unnecessary allocation, reuse via traits/interfaces, dead code removed, migration pushed as far as
  reasonable, and tests not weakened/deleted.
- Iterate review → fix → re-review until clean; commit after each fix batch so CI runs concurrently.
- Humans review architecture, design, conventions and risk; agents do exhaustive comparisons; tests and
  static analysis check mechanically enforceable properties.
- If a workaround needs a paragraph-long comment to justify it, the code is wrong — fix the code.

### Protect the oracle (tests)

- E2E tests are the correctness oracle. Strengthen them before a large change. The agent changing the
  implementation must not also rewrite tests, update snapshots, raise baselines, or apply escape-hatch
  labels. Never delete or change E2E tests without explicit consent.
- Keep the contract independent and sensitive guardrails behind separate approval; layer checks with
  different failure modes so one mistake can't ship a regression.
- Run heavy/full suites in CI, not locally during parallel work; minimize CPU use.

### Subagents and parallel sessions

- Use subagents mainly to fan out exploration/review; keep mutation near the coordinating agent to avoid
  conflicts and preserve a coherent strategy.
- Give each parallel worker its own worktree/branch; explicitly forbid destructive/shared git commands
  (stash, reset --hard) and slow commands; only commit specific files.
- Use cheaper models for exploration subagents, the strongest model on the main thread for judgment.
- Gate CPU-heavy builds/tests with a lease (one worker builds at a time); others keep working meanwhile.
- Be explicit about intent — "leave this alone" and "autonomous, but don't touch other branches" must be
  said plainly; agents may use any capability you expose in situations you didn't anticipate.

### Refactor and reduce

- After feature/optimization passes, do a dedicated refactor: reduce source lines via deduplication and
  pruning, split oversized files, keep all tests green and zero performance regressions.
- Target SLoC, not LoC, so comments aren't deleted to game the metric; remove dead code and temporary shims.

### Performance and benchmark integrity

- Never run benchmarks in parallel (they compete for resources); never game/manipulate benchmarks — change
  only the implementation. Use diverse/adversarial/real-world inputs and check output against a known-good
  implementation.
- Never use target-cpu=native or special flags for a fair comparison; keep benchmarks independent
  (disable caching features); always use the project's standard benchmark tool.
- Guard against regressions, including after refactors; iterate until any regression is gone.

### Fix the system, not just the symptom

- When a failure mode appears twice, promote it into standing instructions, a skill, an eval, a protected
  baseline or a harness check; turn session logs into evals.
- Fix the process that produced the bad code rather than hand-fixing each case; keep evolving agent and
  review instructions. Never let a check pass via escape hatches/waivers — investigate and fix the code.
- A compiler checks internal coherence, not contract correctness, ordering, lifecycle, ambient inputs
  (time zone/env/cwd), blocking calls, missed features, library behavior differences or acceptable cost —
  verify these explicitly.

### Developer inner loop

- Optimize build/test/iterate speed up front, including for multiple concurrent worktrees; the agent inner
  loop benefits more, not less, from a fast loop.
- Preserve prompt-cache-friendly context (stable prefixes); use subagents/compaction to keep long sessions
  affordable and on-track, and re-anchor on current state after compaction.

## Workspace & persistence

- Keep projects in `~/workspace` — it persists across restarts and rebuilds, together with `~/.config/opencode`,
  `~/.local/share/opencode` and `~/.cache`.
- Agent skills: global OpenCode skills live in `~/.config/opencode/skills` (`opencode-config` volume), the skills CLI's
  canonical store and global lock in `~/.agents` (`opencode-global-skills` volume), and project skills in
  `<project>/.agents/skills/` with `skills-lock.json` in the project root (`opencode-workspace`). See "Agent skills (skills.sh)" below.
- Everything else — global npm/pip installs and files you create outside the paths above — is lost when the environment
  is recreated.
- There is no `sudo` and no system package manager at runtime: use only preinstalled tools. If a project permanently
  needs a system package, ask the user to add it to `PACKAGES` in their `.env` and rebuild.
- Prefer project-local dependencies (`package.json`, a virtualenv) over global installs.

## Tools

- Available: Node.js with npm/npx, Python with pip and venv, FFmpeg (`ffmpeg`, `ffprobe`, `ffplay`), git, git-lfs, gh,
  jq, yq, ripgrep (`rg`), fd, sqlite3, curl, make, nano/vim.
- You run as the unprivileged `opencode` user (no sudo — see Workspace & persistence).
- No compilers are available by default. If something needs building, ask the user to add a package to `PACKAGES` and rebuild.
- `yq` is the jq-syntax YAML tool: queries use jq syntax and output JSON unless you add `-y`.
- Node.js is built with pointer compression: about half the memory, but each process's heap is limited to 4 GB.
  N-API native addons work; addons using the older NAN API (e.g. `better-sqlite3`) can crash. Prefer an N-API
  alternative, or ask the user to add `build-essential` to `PACKAGES` and rebuild.
- `npm install -g` installs into `~/.local` (via `NPM_CONFIG_PREFIX`); no pip user-site override is set here.

## Agent skills (skills.sh)

Skills are portable `SKILL.md` instruction packages from https://skills.sh. OpenCode discovers them
from `~/.config/opencode/skills` (global) and `<project>/.opencode/skills`, `<project>/.agents/skills`,
`<project>/.claude/skills` (project). A skill's ID is its **directory name**; OpenCode only advertises
skills whose frontmatter has a `description`. Load one with the `skill` tool (`{"id": "..."}`), or read
`SKILL.md` directly — supporting files are relative to that directory.

A `find-skills` base skill is baked into the image and seeded at startup into
`~/.config/opencode/skills/find-skills` — the regular global skills dir, inside the `opencode-config`
volume. The entrypoint restores it if missing, so treat it as image-managed: don't try to
`skills update` or `skills remove` it; upstream changes arrive on rebuild (`SKILLS_REF`).

At every container start the entrypoint starts `npx -y skills update -g -y` in the **background**, so
the server starts immediately; its output goes to `~/.local/share/opencode/skills-update.log`. The
updater stages the `~/.agents` volume and creates a local commit there if anything changed (signed when a signing key
and identity are configured). It runs without `GH_TOKEN`, `OPENCODE_API_KEY`, `OPENCODE_PASSWORD` or
`POSTHOG_PERSONAL_API_KEY`, but keeps the SSH agent for that commit. There is no remote push; the local git history is
the rollback trail for skill updates. Update failures only log a warning to that file.

Use the CLI via `npx skills` (no install needed; the Node version here is new enough). It is
non-interactive when given a query and `-y`. Docs: https://www.skills.sh/docs/cli.

### Read and inspect

- `npx skills list` — project skills; `npx skills list -g` — global skills. Status: `tracked`, `modified`, `untracked`, `missing`. Add `--json` for machine-readable output.
- `ls -R ~/.config/opencode/skills` — global skill files; `cat ~/.config/opencode/skills/<id>/SKILL.md` — read one.
- `npx skills use <owner/repo@skill>` — print a skill's prompt without installing it.

### Find

- `npx skills find <query> [--owner <owner>]` — searches the skills.sh index. With a query it prints
  `owner/repo@skill`, install count and a skills.sh URL. Without a query it opens an interactive picker — avoid that.
- Verify before recommending: prefer 1K+ installs, reputable sources (`vercel-labs`, `anthropics`, `microsoft`),
  check GitHub stars and the `SKILL.md` contents. Security audits: https://skills.sh/audits.
- Telemetry is anonymous; set `DISABLE_TELEMETRY=1` (or `DO_NOT_TRACK=1`) if the user prefers none.

### Install and update — keep them in persisted volumes

Skill storage that survives a recreate:

| Path | Volume | Survives recreate? |
| --- | --- | --- |
| `~/.config/opencode/skills/` (incl. seeded `find-skills`) | `opencode-config` | yes |
| `~/.agents/skills/` + `~/.agents/.skill-lock.json` | `opencode-global-skills` | yes |
| `<project>/.agents/skills/` + `skills-lock.json` | `opencode-workspace` | yes |

- **Project skills (project-only):** run from a project inside `~/workspace`, without `-g`.
  Files go to `<project>/.agents/skills/`, lock to `<project>/skills-lock.json` — both in `opencode-workspace`.
  ```bash
  npx skills add <owner/repo@skill> -a opencode -y
  npx skills check                     # report updates / local changes (exit 1 if any)
  npx skills update -y                 # update all project skills
  ```
- **Global skills (all projects):** `-g` is safe now — the canonical store `~/.agents/skills` and the global
  lock `~/.agents/.skill-lock.json` are inside the `opencode-global-skills` volume, so symlinks, updates and
  removals all survive a recreate.
  ```bash
  npx skills add <owner/repo@skill> -g -a opencode -y
  npx skills check -g
  npx skills update -g -y
  npx skills list -g
  ```
  `--copy` still works if you prefer real files under `~/.config/opencode/skills/` instead of symlinks; it is
  no longer required for persistence.
- `npx skills check -g` is read-only in current releases, but some older versions (e.g. 1.7.4) routed it to
  `update`. Confirm with `npx skills --help` before relying on it as read-only.
- Remove: `npx skills remove -g <name>` (`-y` skips prompts). `--all` only removes lock-tracked skills;
  name untracked ones explicitly.

## Git

### Identity

- `user.name` / `user.email` come from `GIT_USER_NAME` / `GIT_USER_EMAIL` in `.env` if set, otherwise from the host's
  `~/.gitconfig`. If neither is set, commits fail with "Please tell me who you are".
- Never invent or guess an identity. If it is missing, tell the user; the fix is `.env` (`GIT_USER_NAME`, `GIT_USER_EMAIL`)
  or the host's git config.
- New repositories default to branch `main`; `safe.directory=*` is already configured, so "dubious ownership" errors
  should not occur.
- git-lfs is installed and initialized system-wide.

### Remote protocol

- GitHub remotes use SSH (`git@github.com:owner/repo.git`) by default; SSH keys are preconfigured (see next section).
- Avoid `https://github.com/...` remotes unless the user asked: without `GH_TOKEN`, HTTPS fails with an authentication
  error. To switch an existing repo to SSH: `git remote set-url origin git@github.com:owner/repo.git`.
- If `GH_TOKEN` is set, HTTPS to github.com also works via the `gh` credential helper; SSH remains the default.

### Do not change

- Don't touch `user.name`, `user.email`, `user.signingkey`, `commit.gpgsign`, `tag.gpgsign`, `gpg.format` or anything
  in `~/.ssh` unless the user asks.
- Don't push, force-push, delete branches/tags, or rewrite published history unless the user asks.
- If something already pushed needs rewriting (amend, rebase, force-push): ask the user first.

## SSH

SSH is preconfigured. Use it as-is; don't reconfigure it unless the user asks.

### Where the keys come from

- At every start, the entrypoint loads private keys from the host's `~/.ssh` (read-only source at `~/.ssh-host`) into
  an in-container `ssh-agent`. `SSH_PRIVATE_KEY` is piped into the agent on stdin and then unset — no private key is
  written to the container's writable filesystem. The mounted host keys remain readable by the same UID, so a
  compromised agent could read them; use a dedicated deploy key where that matters.
- Only public files (`*.pub`, `known_hosts*`, `allowed_signers`, `config`) are staged into `~/.ssh` with `~/.ssh` at 700
  and public files at 644. `authorized_keys`, `environment` and directories are not copied.
- The agent is refreshed at every start: key changes on the host appear after a restart. Files added to `~/.ssh` here
  are lost when the environment is recreated and never reach the host.
- The host's `~/.ssh/config` is staged too: aliases (e.g. `git@github-work:org/repo.git`) are honored.
- A `$HOST_HOME/.ssh` symlink points at the staged `~/.ssh`, so a `user.signingkey` path from the host's git config —
  absolute, or `~/.ssh/...` — resolves verbatim to the staged public key. The link is skipped when `HOST_HOME` is the
  container home itself, to avoid a self-referential symlink.
- `~/.ssh-host` is read-only: you cannot change the host's keys from here.

### Pre-trusted hosts

- `github.com`, `gitlab.com` and `bitbucket.org` host keys are pre-trusted (all key types, in `/etc/ssh/ssh_known_hosts`).
  SSH to these works without prompts.
- To double-check a fingerprint against an official source, compare with GitHub's page:
  https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
- Any other host is untrusted. Never bypass host key checking (`StrictHostKeyChecking=no` or equivalent). If a task
  needs a new host, tell the user: the fix is on the host (add its host key to the host's `known_hosts`), then restart
  so the refreshed copy is picked up.

### ssh-agent

- An `ssh-agent` is started for you at container start. The host's private keys are loaded into it directly from the
  read-only mount and are never copied into the container's writable filesystem — only public keys, `known_hosts`,
  `allowed_signers` and SSH `config` remain in `~/.ssh`.
- `SSH_AUTH_SOCK` is set automatically. ssh and git use the agent for transport and for SSH signing.
- `ssh-add -l` lists the keys the agent holds. Never read, copy or exfiltrate a private key — the writable `~/.ssh`
  has only public files, and the host keys on the read-only mount are off-limits too. If a needed key isn't loaded,
  ask the user to provide it via `SSH_PRIVATE_KEY` or restart the environment.

### One-shot key install

- `SSH_PRIVATE_KEY` in `.env` is piped into the ssh-agent at every start; only the derived public key is written
  (`id_ed25519.pub` / `id_rsa.pub` / `id_ecdsa.pub`). This is the sanctioned way to add a key via `.env`. Don't paste
  keys anywhere else.

### Hygiene

- Never `cat`, print, copy or exfiltrate private keys. Never `ssh-copy-id`. Never add keys to servers or to the agent
  yourself. Never relax permissions on `~/.ssh`.
- If a task seems to need a different key, a new host, or an added key, ask the user.

### Diagnosing SSH

- `ssh -T git@github.com` — exit code 1 with "Hi <name>! You've successfully authenticated, but GitHub does not provide
  shell access." means **success** (GitHub doesn't offer shell access).
- `git clone`/`git push` hanging or prompting means there is no usable key: check `ssh-add -l` first, then
  `ls -l ~/.ssh` (public files only — private keys live in the agent, not on disk).
- Verbose trace when anything is unclear: `ssh -vvv -T git@github.com`.
- Fingerprint of a public key: `ssh-keygen -lf ~/.ssh/<name>.pub`.
- Effective config: `ssh -G github.com | grep -iE '^(hostname|user|identityfile|port)'` and
  `git config --list --show-origin`.

## GitHub CLI (gh)

- `gh` is preinstalled. It authenticates from the environment, independently of SSH: set `GH_TOKEN` (or `GITHUB_TOKEN`;
  `GH_TOKEN` wins) in `.env`. `.env` is read only when the environment is created, so the change takes effect only
  after the user recreates it (`make run`, or `down`/`up`).
- With `GH_TOKEN` set, git is also configured to authenticate HTTPS to github.com through `gh`
  (`credential.https://github.com.helper=!gh auth git-credential`), so HTTPS remotes work too. SSH remains the default.
- `gh auth status` shows the token source (it will report the environment variable, not a stored login). A token from
  the environment takes precedence over any stored credential.
- Don't rely on `gh auth login`: `~/.config/gh` is not persisted and `make run` recreates the environment, so an
  interactive login evaporates. `GH_TOKEN` in `.env` is the durable path.
- Useful non-interactive commands: `gh repo view`, `gh pr create`, `gh pr list`, `gh pr view`, `gh pr diff`,
  `gh pr checks`, `gh issue list`, `gh api <endpoint>`. `GH_PROMPT_DISABLED=1` disables prompts in scripts.
- GitHub Enterprise Server: `GH_ENTERPRISE_TOKEN` (checked before `GITHUB_ENTERPRISE_TOKEN`) and `GH_HOST`.
- Without `GH_TOKEN`: SSH git still works fully; `gh` and git-over-HTTPS for github.com do not. Tell the user rather
  than creating tokens yourself.
- `gh` can only reach what its token scopes allow. Treat the token as least-privilege; don't ask for broader scopes
  than the task needs.

## Commit & tag signing (SSH signing)

Signing with SSH keys (no GPG) is enabled automatically when a signing key resolves. At start the environment sets
`gpg.format=ssh`, `commit.gpgsign=true`, `tag.gpgsign=true`, and rebuilds `~/.config/git/allowed_signers` from the key
in use (git is pointed at it via `gpg.ssh.allowedSignersFile`). The private half stays only in `ssh-agent`; the public
key file is used for verification.

### Which key signs

In order: `GIT_SIGNING_KEY` from `.env`, otherwise `user.signingkey` from the host's `~/.gitconfig`. Accepted forms:

- a path to a private key (a sibling `<name>.pub` is used for the signers file): `~/.ssh/<name>` or absolute
- a path to a `.pub` file (signs via the agent if the key is in the agent, otherwise via the private key file at the same basename)
- a raw public key (`ssh-ed25519 AAAA…`, `ecdsa-…`, `sk-ssh-…`), optionally prefixed as `key::<pub>`
- the word `agent` — signs with the first key in the in-container ssh-agent

If the public key is in the agent, signing goes through the agent (no passphrase needed); otherwise the private key
file is used.

### Verify your own commits and tags

- `git log --show-signature -1` → expect `Good "git" signature` and a principal line matching your `user.email`.
- `git verify-commit <sha>` / `git verify-tag <tag>`.
- "Good" signature but "No principal matched" or an unreadable `allowed_signers`: the allow-list is rebuilt at every
  start from the key in use. Ask the user to recreate the environment, then check
  `git config --get gpg.ssh.allowedSignersFile`.
- Quick sanity check of what is configured:
  `git config --get gpg.format; git config --get user.signingkey; git config --get commit.gpgsign; git config --get tag.gpgsign`

### "Verified" on GitHub

- Locally-good signatures are not automatically "Verified" on GitHub. For the badge:
  1. the same SSH key must be uploaded to GitHub as a **Signing Key** (Settings → SSH and GPG keys → New SSH key →
     type: Signing Key) — separate from the authentication key;
  2. the committer email must be an email GitHub can match to the account.
- If the badge is missing, the fix is on GitHub's side. Don't change local signing or identity config to force it.
- Signed tags: `git tag -s -a v1.0.0 -m "v1.0.0"` (automatic with `tag.gpgsign=true`), push with
  `git push origin v1.0.0`, verify with `git verify-tag v1.0.0`.

### Failure handling

- If the signing key cannot be resolved, the environment logs a warning and commits stay unsigned. Don't work around
  it: fix `GIT_SIGNING_KEY` / the host config, or tell the user.
- Never use `--no-gpg-sign` or `--no-verify` to make a failing commit pass, unless the user explicitly asks.
- Don't reconfigure signing to make something work; report it instead.

## Cookbook

- Clone: `git clone git@github.com:owner/repo.git`
- Start work: `git switch -c fix/thing` → edit → `git add -p` → `git commit -m "…"` (signing is automatic) →
  `git push -u origin fix/thing`
- Before pushing: `git status`, `git diff`, `git log --show-signature -3`
- Open/inspect a PR: `gh pr create --fill`, `gh pr view`, `gh pr diff`, `gh pr checks`
- Signed release tag: `git tag -s -a v1.2.3 -m "v1.2.3" && git push origin v1.2.3 && git verify-tag v1.2.3`
- Sync: `git fetch --prune`, then rebase or merge per the repo's convention
- Amend only before pushing; after a push, make a new commit
- Presence of a token without printing it: `[ -n "$GH_TOKEN" ] && echo "gh token: set" || echo "gh token: unset"`
- Full picture of effective config: `git config --list --show-origin`

## FAQ

Other common questions (GitHub auth, ports, `.env` changes, commit verification, tags) are answered in the repo's
`README.md` (Troubleshooting) and in the sections above.

**Q: Why is my passphrase-protected key not working?**
A: Non-interactive sessions can't answer a passphrase prompt. The in-container ssh-agent loads keys at startup; a
key that needs a passphrase must be added by the user outside this environment, or provided unprotected via
`SSH_PRIVATE_KEY`. Don't try to decrypt or bypass it.

**Q: Do I need to type a password to push?**
A: With SSH remotes and a key in `ssh-agent`: no. With HTTPS to github.com and `GH_TOKEN` set: no (the credential helper
supplies it). Otherwise git prompts and the push fails non-interactively — fix the remote or the token; don't guess.

**Q: Why are there two keys in `~/.ssh`?**
A: Common host setups keep an authentication key and a signing key. Transport identity and signing identity are
independent: git transport uses the key in `ssh-agent`; commit signing uses `user.signingkey` (from `.env` or the
host config, pointing at the staged public key) or `GIT_SIGNING_KEY=agent`.

**Q: Can I use different GitHub accounts per repo (work vs personal)?**
A: Yes, if the host's `~/.ssh/config` defines aliases (e.g. `github.com-work`) — the config is staged at start. Use the
alias in the remote: `git@github.com-work:org/repo.git`, and scope the signing key with `GIT_SIGNING_KEY`. If no alias
exists, ask the user to add one on the host.

**Q: My skills broke or disappeared after `make run`.**
A: Check that `opencode-global-skills` is mounted at `~/.agents` — that's where the canonical store and global lock
live. Without it, symlinks break; recreate after restoring the mount.

**Q: Something is broken — where do I look first?**
A: In order: `ssh-add -l` → `ssh -T git@github.com` → `ls -l ~/.ssh` (public files) → `git config --list --show-origin` →
`git log --show-signature -1`. If you need the startup log (how the entrypoint resolved identity and signing, plus any
warnings), ask the user to run `docker compose -f docker-compose.opencode.yml logs opencode | grep entrypoint` —
inside the container you have no Docker CLI. For MCP status run `opencode mcp list` yourself from `~/workspace`;
ask the user only if you cannot.

## Ask the user first

- Pushing to repositories you didn't create, merging/closing PRs or issues, publishing releases
- Force-push, rebase of published branches, deleting branches or tags
- Adding trusted SSH hosts, using a key not in `~/.ssh`, generating new keys
- Changing git identity, signing configuration or anything in `.env`
- Making any repository public/private, changing tokens or scopes
- Changing `opencode.json` skills sources or compose volume mounts (skill storage layout)

## Never

- Print, `cat`, copy or exfiltrate private keys or tokens; `ssh-copy-id`; add keys to servers yourself
- Relax permissions on `~/.ssh` (700 / 600 / 644)
- Disable host key checking, or bypass commit/tag signing with `--no-gpg-sign` / `--no-verify` without explicit instruction
- Commit `.env`, `.env.mcp` or any file containing secrets
- Invent an identity, email or signing key

## MCP

MCP servers come from two places: Docker's catalog runs in the gateway, and `opencode.json` lists direct remotes plus
disabled optional servers. The gateway and OpenCode are defined in `docker-compose.opencode.yml`; `opencode` has a plain
`depends_on: mcp-gateway` so the container exists before OpenCode connects. `make run` starts both:

- `mcp-gateway` (config key `docker-gateway`) — roughly 264 catalog tools from 19 servers. The original 15 are
  Playwright, Wikipedia, npm-sentinel, sequentialthinking, fetch, time, duckduckgo, markitdown, next-devtools-mcp, memory,
  AWS documentation, GitHub Official, Context7, DeepWiki and Microsoft Learn; `grafana`, `dockerhub`,
  `mcp-code-interpreter` and `n8n` were added. `memory` was already enabled.
- `gh_grep`, `cloudflare-docs`, `astryx` and `eslint` are enabled direct servers; the rest of `opencode.json` is disabled.

The gateway URL comes from `MCP_GATEWAY_URL`: Compose sets `http://mcp-gateway:8080/mcp` inside the container; a host
OpenCode CLI must start with `MCP_GATEWAY_URL=http://127.0.0.1:8200/mcp` in its environment (the background service
captures it at startup). Non-secret config (`n8n.api_url: http://n8n:5678`, the `tool-name-prefix` flag) is generated
at gateway startup from inline Compose commands; `.env.mcp` holds secrets only and must remain chmod 600. Config
values in `.env.mcp` are silently ignored. The n8n API key has no CLI/env generator — it is created in n8n's Settings
→ n8n API UI.

Tools are hidden by Code Mode: `opencode mcp list` shows connection status, and inside the agent `execute` →
`search({ namespace: "..." })` discovers them. The gateway has no authentication and holds the Docker socket as its
control plane; it is published on loopback and reachable from every container in this project — treat access as
host-level. Spawned MCP containers share the Compose network but do not inherit the Compose services' `cap_drop: ALL`,
so consider them additional network peers. If the gateway shows as disconnected, ask the user to start it (`make run`,
or `docker compose -f docker-compose.opencode.yml up -d mcp-gateway`) rather than editing configuration.

`.env.mcp` is not passed to OpenCode and must not contain application secrets such as `OPENCODE_API_KEY`. GitHub Official
can write to repositories the token can reach, and agent permissions are allow-all, so do not issue broader GitHub
tokens than needed.

## Network

- Internet access is available.
- The web UI is published on a single port (default 4000). Services you start (dev servers, databases) are not
  reachable from elsewhere unless that port is published. If the user wants something reachable, tell them they need
  to publish the port; you cannot do it yourself.
