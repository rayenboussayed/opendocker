# opencode-debian

**OpenCode 2 in one command.** An AI coding agent with real tools — git, GitHub, browsers, docs — running in a box on your computer.

*New here? Read [What is this?](#what-is-this) then [Set it up in 3 steps](#set-it-up-in-3-steps).*
*Want to know why it's built this way? See [Design decisions & rationale](#design-decisions--rationale).*

**Contents**

- [What is this?](#what-is-this)
- [Why you'll love it](#why-youll-love-it) · [What to know first](#what-to-know-first) · [Use cases](#use-cases)
- [Install the tools you need](#install-the-tools-you-need) (Windows · macOS · Linux)
- [Set it up in 3 steps](#set-it-up-in-3-steps) · [Your first 10 minutes](#your-first-10-minutes)
- [Commands](#commands) · [Configuration](#configuration) · [What's inside](#whats-inside)
- [Your projects: how they get in](#your-projects-how-they-get-in) · [Is it safe?](#is-it-safe)
- [Design decisions & rationale](#design-decisions--rationale)
- [MCP servers](#mcp-servers) · [n8n, PostgreSQL, and SearXNG](#n8n-postgresql-and-searxng)
- [Universal config](#universal-config) · [AGENTS.md](#agentsmd)
- [SSH and commit signing](#ssh-and-commit-signing) · [Every platform](#every-platform)
- [Moving from nimbleflux/opencode-docker](#moving-from-nimblefluxopencode-docker-opencode-1)
- [Troubleshooting](#troubleshooting) · [Known limitations](#known-limitations) · [Learn more](#learn-more)

## What is this?

[OpenCode](https://opencode.ai) is an open-source AI coding agent. You describe what you want in plain language;
the agent reads your code, edits files, runs commands and answers questions. It's used by 22M+ developers every
month, works with 200+ models (including free ones), and runs in your desktop app, your terminal, your phone — or in
your browser, next to your code.

The catch: an agent that can run commands on your machine can also do real damage. This repo boxes OpenCode in a
[Docker](https://www.docker.com/what-docker/) container with its tools and an isolated workspace, so it can work
freely while your system stays yours. See [Is it safe?](#is-it-safe) for the honest limits.

It replaces [nimbleflux/opencode-docker](https://github.com/nimbleflux/opencode-docker) and carries your existing
sessions over — see [Moving from OpenCode 1](#moving-from-nimblefluxopencode-docker-opencode-1).

## Why you'll love it

- **One command.** `make run` starts the whole stack — see [Commands](#commands).
- **Batteries included.** Node.js, Python, FFmpeg, git, GitHub CLI and roughly 140 MCP tools — see [What's inside](#whats-inside) and [MCP servers](#mcp-servers).
- **Your models, your choice.** Free models, OpenCode Console/Go, or your own keys — see [Configuration](#configuration).
- **Yours and private.** Sessions persist in volumes and every published port binds to `127.0.0.1` — see [Your projects](#your-projects-how-they-get-in) and [Is it safe?](#is-it-safe).

Git works out of the box too: SSH keys and signed commits are covered in [SSH and commit signing](#ssh-and-commit-signing).

## What to know first

- **It needs Docker** (a free tool) and about 10 minutes of setup.
- **The first start downloads a few GB** of images. After that, starts are fast.
- **Docker Desktop is free** for personal use, education and small businesses (fewer than 250 employees AND
  under $10M annual revenue). Larger companies pay for Docker Desktop — or use Docker Engine on Linux, which is free.
  [Check the terms](https://www.docker.com/pricing/).
- **It is not a perfect security sandbox.** The container shares the host kernel, can reach the internet and your
  local network, and can use any keys or tokens you pass in. See [Is it safe?](#is-it-safe).
- **It runs on Linux, macOS and Windows** — see [Every platform](#every-platform).
- **Runtime installs disappear on recreate.** Add Debian packages to `PACKAGES`, npm tools to `NPM_PACKAGES` and Python tools to `PIP_PACKAGES` in `.env`, then rebuild.

## Use cases

- **Clear the boring backlog.** "Update all dependencies and fix the fallout", "make the tests pass", "migrate this to ES modules" — review the diff after, approve with confidence.
- **Learn any codebase in minutes.** "Explain how authentication works here", "where would I add rate limiting?", "what does this file do?"
- **Review pull requests.** Point it at a branch; it reads the diff, runs the tests, and summarizes risks.
- **Research without leaving your editor.** AWS, Cloudflare and Microsoft docs, GitHub code search, and npm analysis are one question away.
- **Prototype fast.** "Build me a small tool that…" and iterate with the agent until it's right.
- **Keep CI green.** It can read logs, fix the failure and push the fix.
- **One consistent setup for the team.** Everyone runs the same image with the same tools, signing and instructions.
- **Not a programmer?** Describe the outcome you want; the agent writes the code, runs it and shows you the result.

## Install the tools you need

You need three things: **Git** (to get the code), **Docker** (the box), and optionally **Make** (for `make run` instead of long commands).

### Windows 10/11

1. **Docker Desktop** (recommended: with the WSL2 backend)
   ```powershell
   winget install -e --id Docker.DockerDesktop
   ```
   …or install it from the [Microsoft Store](https://docs.docker.com/desktop/setup/install/windows-install/). The
   installer takes care of WSL2. Then start Docker Desktop once and accept the terms.
   If WSL2 complains, open PowerShell as admin and run `wsl --install`, then reboot.
2. **Git** — download [Git for Windows](https://git-scm.com/downloads) and accept the defaults (it also gives you
   Git Bash, which the `chmod` command below needs). Or try `winget install -e --id Git.Git`.
   Git is optional — you can [download the ZIP](#set-it-up-in-3-steps) instead — but recommended.
3. **Make** (optional) — `winget install -e --id GnuWin32.Make`, then make sure its install folder is on your `PATH`
   (search "environment variables" → Path → add `C:\Program Files (x86)\GnuWin32\bin`).
   **Simplest path on Windows: skip Make and use the compose commands shown below instead.**
4. Open **Git Bash** for every command in this file.

### macOS

1. **Docker Desktop**
   ```bash
   brew install --cask docker-desktop
   ```
   …or download the .dmg from [docker.com](https://docs.docker.com/desktop/setup/install/mac-install/) (Apple Silicon
   or Intel). Start Docker Desktop once and accept the terms. [OrbStack](https://orbstack.dev/) is a lighter alternative.
   Don't have Homebrew? [Install it](https://brew.sh/) first.
2. **Git** and **Make** — both come with the Xcode command line tools:
   ```bash
   xcode-select --install
   ```

### Linux (Debian/Ubuntu)

1. **Docker Engine** (free; Docker Desktop is not required on Linux). Easiest, for a personal machine:
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   ```
   For the more careful apt-repository route, follow
   [Docker's Debian/Ubuntu instructions](https://docs.docker.com/engine/install/debian/) — it boils down to:
   ```bash
   sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```
   Then either use `sudo` for docker (the Makefile does this automatically) or let your user run docker without it:
   ```bash
   sudo usermod -aG docker $USER
   ```
   Log out and back in afterwards. Check it works: `sudo systemctl status docker` and `docker run hello-world`.
   On Fedora/RHEL see [Docker's install docs](https://docs.docker.com/engine/install/).
2. **Git** and **Make**:
   ```bash
   sudo apt install git make
   ```

### Verify

```bash
docker --version        # e.g. Docker version 27/28/…
docker compose version  # e.g. Docker Compose version v2.x
git --version
make --version          # optional if you'll use the compose commands
```

Docker Desktop users: make sure Docker Desktop is running before continuing. Give it at least 4 GB of RAM in
Settings (8 GB recommended).

## Set it up in 3 steps

**Step 1 — get the code.** With git:

```bash
git clone https://github.com/rayenboussayed/opendocker.git
cd opendocker
```

No git? On the repo page, click the green **Code** button → **Download ZIP**, unzip it, and open a terminal in the `opendocker` folder.

**Step 2 — configure (one time only).**

```bash
cp .env.example .env              # your settings; set a password and the n8n/SearXNG secrets
cp .env.mcp.example .env.mcp      # optional extras for the MCP tool servers
chmod 600 .env .env.mcp           # keep both private (skip on Windows/unsupported)
```

Open `.env` in any editor. Set `OPENCODE_PASSWORD` to something you'll remember, and fill in `N8N_ENCRYPTION_KEY`,
`N8N_POSTGRES_PASSWORD` and `SEARXNG_SECRET` (each has a generation hint in the template). Leave the rest as-is. If you
only run the OpenCode + MCP subset (`make run-opencode-clean`), these secrets can stay blank.

**Step 3 — start.**

```bash
make run
```

Or, without `make` (this is the command `make run` wraps):

```bash
docker compose -f docker-compose.yml -f docker-compose.mcp.yml -f docker-compose.n8n.yml up
```

The first run downloads a few GB and can take a few minutes. When you see the server start, open
**http://localhost:4000**.

**What just happened?** Five containers started:

- **OpenCode** — the agent and its web UI, on http://localhost:4000.
- **The MCP gateway** — starts and manages ~15 tool servers for the agent (browsers, docs, GitHub…).
- **n8n** — the workflow editor, on http://localhost:5678.
- **PostgreSQL** — n8n's database (workflows, credentials, executions). Internal only.
- **SearXNG** — a private web-search backend for n8n. Internal only.

Sign in with username `opencode` and your password. If you didn't set one, OpenCode generates a new random password
every start; find it with:

```bash
docker compose logs opencode | grep "server password"
```

To stop, press **Ctrl+C** in the terminal where it runs. Your sessions and files are kept.

## Your first 10 minutes

1. **Sign in** at http://localhost:4000 (username `opencode`).
2. **Open the folder you want to work on** — see [Your projects: how they get in](#your-projects-how-they-get-in).
3. **Pick a model** — the page asks, or open `/models`. Free models work out of the box. Bring your own subscription
   or API key if you prefer (see [Configuration](#configuration)).
4. **Type what you want**, in plain language:
   - "Look around and explain this project to me."
   - "Find the bug in `src/auth.js` — the login is flaky."
   - "Add tests for the parser and make them pass."
   - "What changed on this branch versus main, and is it safe to merge?"
5. **Review what it did** — diffs, terminal output, and the plan it followed. Nothing is pushed or merged without you asking (and even then, it asks first when it should).

Sessions are saved automatically. Come back tomorrow, it remembers where you left off.

**Git and GitHub just work:** your SSH keys are used for cloning/pushing, and commits and tags are signed with your
SSH key. See [SSH and commit signing](#ssh-and-commit-signing).

## Your projects: how they get in

The agent works in a folder called `~/workspace` **inside its own volume** — think of it as a folder in the box, not
on your laptop. Three ways to give it your code:

1. **Clone it inside** (no setup): in the web UI's terminal, `git clone git@github.com:you/your-project.git` — it lands
   in `~/workspace` and persists across restarts.
2. **Mount your folder** (work directly on your real files — changes appear instantly on your laptop): open
   `docker-compose.yml` and add a line under `opencode:`'s `volumes:`:
   ```yaml
   - /path/to/your/project:/home/opencode/workspace
   ```
   then `make run`. The agent will see the folder and edit it in place — review the diffs as you normally would.
3. **Copy files in**: `docker compose exec opencode bash` then `mkdir -p ~/workspace/my-project` and copy files with
   `docker cp` from outside, or download them inside the app.

## Commands

`make run` is the normal choice: it starts all five containers. The `*-clean` variants rebuild the image first and
can start a smaller set.

| Target | Services started | Without `make` |
|---|---|---|
| `make run` | all five | `docker compose $COMPOSE up` |
| `make run-clean` | all five, fresh image | build, then `… up` |
| `make run-opencode-clean` | OpenCode + MCP gateway, fresh image | `… up opencode mcp-gateway` |
| `make run-n8n-clean` | those plus n8n + SearXNG; Postgres follows via `depends_on`, fresh image | `… up opencode mcp-gateway n8n searxng` |
| `make build` | build only | `… build --pull --no-cache` |
| `make down` | stops all five | `… down --remove-orphans` |
| `make clean` | stops all five, removes local images | `… down --rmi local --remove-orphans` |

Here `$COMPOSE` is `-f docker-compose.yml -f docker-compose.mcp.yml -f docker-compose.n8n.yml`. Data lives in named
volumes, so none of these delete your sessions or workspace. Ctrl+C stops a foreground run; the Makefile's `trap`
runs the cleanup target on exit, even on failure. If you aren't in the `docker` group, the Makefile uses `sudo`.

## Configuration

Application settings go in `.env`; everything is optional. MCP gateway credentials go in their own file, `.env.mcp`,
which is ignored and is never passed to OpenCode.

| Setting | Purpose |
|---|---|
| `OPENCODE_PASSWORD` | Password for the web UI and API (username `opencode`) |
| `N8N_ENCRYPTION_KEY` | Encrypts n8n credentials in Postgres. Generate once (`openssl rand -hex 32`) and back it up |
| `N8N_TIMEZONE` | Timezone for n8n's Schedule node (default `Europe/Paris`) |
| `N8N_POSTGRES_USER`, `N8N_POSTGRES_PASSWORD`, `N8N_POSTGRES_DB` | n8n's Postgres credentials |
| `SEARXNG_SECRET` | Secret for the private SearXNG instance (`openssl rand -hex 32`) |
| `OPENCODE_API_KEY` | Optional: OpenCode Console pay-as-you-go and OpenCode Go key; models appear as `opencode/<model>` or `opencode-go/<model>` |
| `GIT_USER_NAME`, `GIT_USER_EMAIL` | Git identity; if unset, read from your `~/.gitconfig` |
| `GIT_SIGNING_KEY` | Sign commits and tags: a key in `~/.ssh` (e.g. `id_ed25519.pub`), `agent`, or a public key; if unset, read from your `~/.gitconfig` |
| `SSH_PRIVATE_KEY` | Private key contents; piped into the in-container ssh-agent at start — no private-key file is created |
| `HOST_HOME` | Home directory on the host, used to resolve signing-key paths (default: `HOME`, then `USERPROFILE`) |
| `GH_TOKEN` | `gh` and HTTPS git for github.com |
| `EXA_API_KEY` / `FIRECRAWL_API_KEY` / `PARALLEL_API_KEY` / `TAVILY_API_KEY` / `TINYFISH_API_KEY` | Optional: OpenCode's built-in web search provider |
| `POSTHOG_PERSONAL_API_KEY` | Optional: PostHog MCP server (disabled by default) |
| `MCP_GATEWAY_PORT` | Host port for the MCP gateway (default `8200`; internal port is fixed at `8080`) |
| `NODE_TAG` | Build: base image tag (default `slim`) |
| `SKILLS_REF` | Build: git ref for the baked-in `find-skills` skill (default `main`) |
| `NPM_PACKAGES`, `PIP_PACKAGES` | Build: extra global tools |
| `PACKAGES` | Build: replaces the default Debian package list |

After editing `.env`, recreate the container (`make run`, or `docker compose … down` + `up`) — `.env` is read only at start.

Versions are resolved when the image is built, so `make run-clean` (or `make build`) always picks up the latest releases.

### OpenCode Console and OpenCode Go

`.env` is also the supported place for the OpenCode Console API key:

```dotenv
OPENCODE_API_KEY=oc_sk_...
```

Compose injects `.env` values through an explicit `environment:` allowlist — it never uses `env_file: .env`, so n8n
and SearXNG secrets stay out of the agent container. Both built-in integrations read `OPENCODE_API_KEY`. No
`opencode.json`, Dockerfile or MCP credential entry is required, and the key does not belong in `.env.mcp`.

Recreate the container after changing the key, then open `/models` and select:

- `opencode/<model>` for pay-as-you-go Console models;
- `opencode-go/<model>` for the Go subscription ($10/month).

If both `OPENCODE_API_KEY` and a saved `/connect` account exist for the same integration, the saved account takes
precedence. For shared or CI machines, prefer a Console service-account key over a personal key; service-account keys
are created by workspace owners/admins. Keep the key out of `opencode.json`, the Dockerfile, Compose arguments and git.

To use the OpenCode terminal client against the container's server:

```bash
docker compose exec -u opencode opencode opencode --server http://127.0.0.1:4000
```

This works when `OPENCODE_PASSWORD` is fixed in `.env`; with the default generated password, pass it explicitly with
`docker compose exec -e OPENCODE_PASSWORD=… -u opencode opencode …`.

## What's inside

| | Comes from |
|---|---|
| Node.js 26 + npm | the base image, `platformatic/node-caged:slim` |
| OpenCode 2 | `npm install -g @opencode/cli@latest` |
| Python 3.13 + pip + venv | Debian (`apt`) |
| FFmpeg 7.1 + `ffprobe`/`ffplay` | Debian (`apt`) |
| git, git-lfs, gh, ssh, jq, yq, ripgrep, fd, sqlite3, make, htop, … | Debian (`apt`) |

That's the whole install: one `apt-get install` line, npm/pip upgraded to latest, and one npm install for OpenCode.

### About node-caged

node-caged is Node.js built with V8 pointer compression, which roughly halves the memory of JavaScript objects.
- **What it helps:** the Node processes the agent starts, such as MCP servers, dev servers and test runners.
- **What it doesn't:** OpenCode itself, which is a native binary.
- **Limits:** each Node process's heap is capped at 4 GB. N-API native addons work; addons built on the older NAN API
  (e.g. `better-sqlite3`) can crash and need rebuilding against the image's Node headers.
- **Harmless warning:** npm prints `Unknown env config "nodedir"`. It comes from the base image, which sets it so
  rebuilt addons use the right headers.

## Every platform

| Platform | Status |
|---|---|
| Linux (Debian/Ubuntu, amd64 + arm64) | Primary. Built and tested on amd64 |
| macOS (Intel & Apple Silicon) with Docker Desktop | Works; all images are multi-arch (arm64 native) |
| Windows with Docker Desktop | Works; WSL2 backend recommended. Use the compose commands or install GNU make (`winget install -e --id GnuWin32.Make`) |

Cross-platform notes:

- **Line endings are pinned to LF** via `.gitattributes` — a CRLF checkout on Windows would break the
  `entrypoint.sh` shebang. If you ever cloned with `core.autocrlf=true`, run `git add --renormalize .`.
- **Home directory detection.** `~/.ssh` and `~/.gitconfig` are mounted using `HOME` on Linux/macOS and
  fall back to `USERPROFILE` on Windows. Set `HOST_HOME` in `.env` to override explicitly.
- **Git paths in `~/.gitconfig`.** Git Bash on Windows uses `~/.ssh/...`, which resolves inside the container.
  A `C:\Users\…\.ssh\….pub` signingkey path can't exist in a Linux container — commits will still work, just
  unsigned (a warning is printed). Use `GIT_SIGNING_KEY=key::ssh-ed25519 AAAA…` to sign with any host layout.
- **Docker Desktop file sharing.** No extra setup needed for your home directory or the project folder (both are
  shared by default). The build context excludes `.env`, `.env.mcp` and `.git` via `.dockerignore`.
- **Default shell.** Use Git Bash or WSL2 on Windows; the examples assume a POSIX shell.

## Is it safe?

Short version: **reasonable precautions, not a fortress.** The agent runs as the unprivileged `opencode` user with no
sudo and no system package manager at runtime. Read the details in
[Design decisions & rationale](#design-decisions--rationale).

- **Minimal kernel privileges.** Capabilities are dropped to the few needed for the root-to-agent transition, and
  `no-new-privileges: true` is set on every service.
- **No Docker socket in the agent.** The MCP gateway owns the socket as its control plane; it is unauthenticated and
  reachable from this machine and from sibling containers, so treat gateway access as host-level access.
- **SSH keys stay host-owned.** No private key is copied into the container's writable filesystem; the in-container
  agent loads them from a read-only mount. On Linux the mounted keys remain readable by the same UID — use a
  dedicated deploy key if that matters.
- **Loopback only.** Published ports bind to `127.0.0.1`; Postgres and SearXNG have no host port.
- **Resource limits.** OpenCode: 4,096 processes and 8 GB of memory; smaller limits on the other services.
- **Minimal secret exposure.** Only agent-specific variables pass into the agent container. Keep `.env` and
  `.env.mcp` at mode `600` — container isolation is only part of the story.
- **Package install scripts are allowed.** npm 12's script blocking is disabled at build and runtime, and pip runs
  source build backends. Third-party install code executes during the image build (no secrets in the build context)
  and at runtime as the non-root `opencode` user. The automatic skills refresh is a notable case — see below.

What this doesn't cover:

- **Network:** the container can reach the internet, your local network, and host services listening on all interfaces.
- **Kernel:** containers share the host kernel, so a kernel bug could allow an escape.
- **Secrets:** the agent can use any keys or tokens you pass in.
- **Supply chain:** the background `npx skills update -g -y` executes third-party code on every start. It runs
  without `GH_TOKEN`, `OPENCODE_API_KEY` or `OPENCODE_PASSWORD`, but keeps the SSH agent so it can sign its local
  snapshot commit.

For stronger isolation, run Docker rootless or with `"userns-remap": "default"`. Alternatively, add `runtime: runsc`
to use [gVisor](https://gvisor.dev).

If you pass the agent credentials, treat what it can do with them as what you can do — it will generally act only
when you ask, but it can, for example, create branches and PRs on repositories its GitHub token can reach.

## Design decisions & rationale

This is where the "why" notes live. The code files are intentionally comment-light; update this section when behavior
changes.

- **Privilege drop.** The entrypoint starts as root only to fix volume ownership, stage public SSH files and seed the
  base skill, then re-execs itself with `setpriv --reuid=1000 --regid=1000`. The restored capabilities exist for that
  `chown`/`setpriv` transition alone; the long-lived agent retains none of them. `no-new-privileges: true` blocks
  setuid escalation. *(Dockerfile, entrypoint.sh, docker-compose.yml)*

- **SSH keys.** Private keys are read from the read-only `~/.ssh-host` mount straight into an in-container `ssh-agent`
  at a fixed socket. A key supplied via `SSH_PRIVATE_KEY` is piped in on stdin and the variable is unset immediately —
  no private-key file is created. Only public files are staged into writable `~/.ssh`; the filename allowlist is
  deliberate. `$HOST_HOME/.ssh` is linked to `~/.ssh` so a host `signingkey` path resolves verbatim, and the link is
  skipped when `HOST_HOME` is the container home to avoid a self-referential symlink. *(entrypoint.sh, docker-compose.yml)*

- **Git identity and signing.** Explicit `.env` values win; the host `~/.gitconfig` is only a fallback. `allowed_signers`
  is generated locally so `git verify-commit` works. See [SSH and commit signing](#ssh-and-commit-signing).

- **Environment allowlist.** `opencode` lists every variable explicitly instead of using `env_file: .env`, which would
  hand n8n/Postgres/SearXNG secrets to all processes in the container. `SSH_AUTH_SOCK` is declared in Compose as well
  as exported by the entrypoint because `docker compose exec` reads the container's environment, not the entrypoint's
  exports. *(docker-compose.yml)*

- **Install scripts.** npm 12 blocks install scripts by default, so the build passes `--dangerously-allow-all-scripts`
  and sets `NPM_CONFIG_DANGEROUSLY_ALLOW_ALL_SCRIPTS=true`; Debian's pip needs `--ignore-installed`. `.dockerignore`
  excludes `.git` and `.env*` so no secrets enter the build context. *(Dockerfile, .dockerignore)*

- **MCP gateway.** Catalog-first: the gateway runs what the catalog covers; `opencode.json` lists only gaps and OAuth
  servers. The gateway owns the Docker socket as its control plane, is published on loopback via `MCP_GATEWAY_PORT`
  (host `8200` → container `8080`), and the agent never sees the socket. `cloudflare-docs` bypasses the catalog because
  its SSE endpoint returns 410. *(docker-compose.mcp.yml, opencode.json)*

- **Pinned n8n node.** `n8n-nodes-opencode-v2@0.1.1` is pinned by name, version and npm checksum; the older `ssccio`
  node targets the removed V1 API. The checksum is why no global `N8N_UNVERIFIED_PACKAGES_ENABLED` flag is needed.

- **n8n storage and search.** Postgres stores workflows and credentials; `PGDATA` is pinned because `postgres:18`
  changed its default data directory. Required secrets use `${VAR:?…}` guards so a missing `.env` fails fast. The
  SearXNG settings add the `json` format because the stock image serves only HTML. Healthchecks make n8n wait for
  Postgres and SearXNG. *(docker-compose.n8n.yml, searxng-settings.yml)*

- **Skills refresh.** A pristine `find-skills` skill is baked into the image and seeded only when missing, so local
  edits survive. `npx skills update -g -y` runs in the background so the server starts immediately, logs to
  `skills-update.log`, and commits a signed local snapshot in `~/.agents` as a rollback trail. It never pushes.

- **Persistence.** Named volumes hold sessions, config, workspace, cache and global skills. `claude-memory` is shared
  across projects and survives `make clean`. See [How do I back up my sessions?](#troubleshooting).

- **node-caged.** Pointer compression halves JavaScript object memory; the trade-off is a 4 GB per-process heap cap and
  the NAN addon caveat in [About node-caged](#about-node-caged).

## MCP servers

An MCP stack ships in `docker-compose.mcp.yml` and is part of the default flow: `make run` starts it alongside OpenCode.
It runs MCP tool servers for the agent, published on `127.0.0.1` for this machine and reachable by the agent over the
compose network:

```bash
# already done for you by `make run`; shown here for reference
docker compose -f docker-compose.yml -f docker-compose.mcp.yml -f docker-compose.n8n.yml up
```

`.env.mcp` is the MCP-only credential file. It is ignored, must remain chmod 600, and contains the Docker MCP catalog
names directly. It is mounted only into the gateway and is not passed to OpenCode. `.env` is not used for gateway
catalog secrets.

| `.env.mcp` key | Purpose |
|---|---|
| `github.personal_access_token` | GitHub Official MCP server |
| `context7.api_key` | Optional; raises Context7 rate limits |

Missing optional keys only produce gateway warnings; GitHub Official will not work without a token. Use a fine-grained,
least-privilege GitHub token: the agent can create branches, pull requests and repository contents without another
confirmation prompt.

| Entry | Where it runs | Backed by | Active by default |
|---|---|---|---|
| Docker MCP Gateway | `http://mcp-gateway:8080/mcp` (container), `http://127.0.0.1:8200/mcp` (host) | `docker/mcp-gateway` + catalog servers | yes |
| `gh_grep` | direct remote | Grep/grep.app public GitHub code search | yes |
| `cloudflare-docs` | direct remote | `https://docs.mcp.cloudflare.com/mcp` | yes |
| `astryx`, Linear, Notion, Atlassian, Sentry, Figma, Supabase, Neon, Vercel, Cloudflare API, Stripe, PostHog, ESLint | direct remote/local | see `opencode.json` | no, `"disabled": true` |

The gateway proxies local stdio servers as containers and three remote documentation services:

- Local: `sequentialthinking`, `playwright`, `fetch`, `time`, `duckduckgo`, `markitdown`, `wikipedia-mcp`, `next-devtools-mcp`, `npm-sentinel`, `memory`, `aws-documentation`, `github-official`.
- Remote: `context7`, `deepwiki`, `microsoft-learn`.

That is 137 tools through the gateway; including the enabled direct servers (`gh_grep` and `cloudflare-docs`) OpenCode
sees about 140. The exact list can change with upstream catalogs and server versions.

`cloudflare-docs` is configured directly because Docker's catalog entry still points to the retired
`https://docs.mcp.cloudflare.com/sse` endpoint, which returns HTTP 410 Gone. The direct endpoint above initializes
successfully without authentication.

`memory` persists its knowledge graph in the Docker-managed `claude-memory` volume. It is deliberately outside the
`opencode-*` volumes, is shared across projects, and is **not** removed by `make clean`.

OpenCode is already wired to these servers in `opencode.json`. When the gateway is down it shows as disconnected —
harmless. The first start pulls the missing local images (a few GB); subsequent starts reuse them. Docker's MCP Gateway
pins catalog images to digests and signature-verifies Docker MCP images against Docker's keyring. The official GitHub
image is GitHub-built from GHCR and does not publish an equivalent Docker signature; the remote documentation servers are
proxied and are not image-verified by the gateway.

To enable a disabled server, remove or set `"disabled": false` in `opencode.json` and restart OpenCode. For OAuth
servers, run the OpenCode sign-in flow (`/mcps`, or `opencode mcp auth <name>`). If the browser cannot reach the
in-container callback, copy the callback URL into the sign-in prompt instead of reloading it. Supabase and Neon are
configured read-only; keep those flags when enabling them.

Security notes:
- Ports publish on `127.0.0.1` only (no LAN exposure); the agent talks to `mcp-gateway` on the internal compose network.
  The host port defaults to 8200 (`MCP_GATEWAY_PORT` in `.env`); the internal 8080 is fixed. Because the gateway has no
  authentication and holds the Docker socket, any process on this machine or in this compose project can reach it —
  treat that as host-level access.
- The gateway mounts `/var/run/docker.sock` because it *is* the control plane spawning the MCP containers. The agent container never sees the socket.
- `duckduckgo`, `wikipedia-mcp` and `next-devtools-mcp` are community-maintained (unofficial); the GitHub Official image is GitHub-maintained. Browser MCPs can see and do anything the browser can — treat their output as untrusted input.
- `websearch.provider` is `random`, but random selection does not provide credentials. Set one of `EXA_API_KEY`, `FIRECRAWL_API_KEY`, `PARALLEL_API_KEY`, `TAVILY_API_KEY` or `TINYFISH_API_KEY` in `.env`, or connect a provider in `/connect`.
- Public documentation/code endpoints enabled by default send your queries there: Grep/grep.app, Cloudflare Docs and, through the gateway, Context7, DeepWiki and Microsoft Learn.

Host-side clients can use the loopback gateway URL with no token:

```bash
curl -s http://127.0.0.1:8200/mcp -X POST \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## n8n, PostgreSQL, and SearXNG

`docker-compose.n8n.yml` adds a second, self-contained stack to the same compose project. It is part
of `make run` / `make down` and uses the same internal network as OpenCode. Only n8n's editor is
published on the host (`127.0.0.1:5678`); Postgres and SearXNG have no host ports.

### One-time setup

1. Open **http://localhost:5678** and create the owner account.
2. **Credentials → New → OpenCode V2 API**:
   - **Server URL**: `http://opencode:4000` (internal compose address — long agent replies can be cut
     by a public reverse proxy)
   - **Username**: `opencode` (fixed by OpenCode)
   - **Password**: the `OPENCODE_PASSWORD` value from `.env`
   - **Test** calls `GET /api/info`; it should pass.
3. Try it: **Chat Trigger → OpenCode V2** (Chat / Send Message), leave Working Directory at `/tmp`
   (avoids slow prompt hooks from project plugins), map `{{ $json.chatInput }}` and
   `{{ $json.sessionId }}`, and return `{{ $json.reply }}`. Start with the Read Only permission preset.

The community node is `n8n-nodes-opencode-v2@0.1.1`, pinned in the compose file by name, version and
npm checksum. The original `ssccio/n8n-nodes-opencode` targets the OpenCode **V1** API (`/session`,
Bearer auth), which no longer exists in OpenCode 2, so it is deliberately not installed. n8n logs a
warning about a future change to `N8N_UNVERIFIED_PACKAGES_ENABLED`; the pinned checksum is why this
package installs without enabling that flag globally.

### Storage and search

- n8n uses **Postgres** for workflows, credentials and execution history; the `.n8n` volume keeps the
  encryption key. Back up both. `N8N_ENCRYPTION_KEY` must stay the same across rebuilds.
- **SearXNG** listens at `http://searxng:8080`. `searxng-settings.yml` enables the `json` format
  (the stock image only serves HTML, so `format=json` would otherwise return 403). It is the web
  search backend for n8n Assistant, and is available immediately from any workflow:

  ```bash
  docker compose exec n8n wget -qO- \
    'http://searxng:8080/search?q=opencode&format=json' | jq '.results | length'
  ```

  n8n Assistant itself stays off until you add a sandbox and a model key (see
  [Set up n8n Assistant](https://docs.n8n.io/deploy/host-n8n/configure-n8n/set-up-n8n-assistant.md)).
  The sandbox stack is intentionally not part of this lean setup.

### Going the other direction

To let the OpenCode agent call n8n workflows as tools, create an n8n **MCP Server Trigger** workflow
with Bearer auth, then add a remote MCP entry to `opencode.json`:

```json
{
  "mcp": {
    "n8n": {
      "type": "remote",
      "url": "http://n8n:5678/mcp/<path>",
      "headers": { "authorization": "Bearer <token>" }
    }
  }
}
```

Restart OpenCode after editing the config.

## Universal config

`opencode.json` in the repo root is mounted read-only over the image's system config, `/etc/opencode/opencode.json`.
The system config is machine-wide and outranks the global and project configs, so it applies to every project and
can't be loosened by them. It allows every tool action (`action: *`, `effect: allow`) plus an explicit `skill` rule,
and keeps the `instructions` entry that loads `AGENTS.md`. The broad rule also overrides the default prompts for
`.env` files; the `skill` rule is kept as an explicit statement of intent. Edit it and restart the container — no
rebuild needed. The same `opencode.json` is baked into the image as `/etc/opencode/opencode.json`, so the behavior doesn't
depend on the mount.

## AGENTS.md

`AGENTS.md` (repo root) is installed as `/etc/opencode/AGENTS.md` and loaded through OpenCode's system config. It is
a machine-wide guide for the agent — it teaches the agent how to work in its environment, including:

- how SSH keys are provided and used, and which hosts are trusted
- how git identity and commit/tag signing work, and how to verify signatures ("Verified" on GitHub)
- how to use the GitHub CLI (`gh`), and why `gh auth login` doesn't persist
- what persists across rebuilds, which tools exist, and which MCP servers are available
- what to ask you before doing (pushes, force-pushes, deleting things, changing config)
- step-by-step diagnostics for the common failures ("Permission denied", "No principal matched", unsigned commits…)

It's loaded alongside your own `~/.config/opencode/AGENTS.md` and project `AGENTS.md` files. Edit it and rebuild the
image to change it (`make run-clean`).

## SSH and commit signing

SSH keys stay on the host. The entrypoint starts an `ssh-agent` inside the container and loads host keys directly from
the read-only mount; a key supplied via `SSH_PRIVATE_KEY` is piped into the agent on stdin, so no private-key file is
created. Only public keys, `known_hosts`, `allowed_signers` and SSH config remain in the writable `~/.ssh`. On Linux
the mounted host keys are still readable by the same UID, so a compromised agent could read them — use a dedicated
deploy key for sensitive repositories. Git and ssh use `SSH_AUTH_SOCK` automatically; no agent forwarding is needed.

Git identity and signing are inferred from the host: the entrypoint reads `user.name`, `user.email` and
`user.signingkey` from your `~/.gitconfig` (mounted read-only) when the corresponding `.env` values are unset.
Public keys are staged into the container's `~/.ssh`, and `$HOST_HOME/.ssh` is symlinked to it, so the `signingkey`
path in your host config resolves verbatim inside the container — absolute paths and `~` both work. A host with
`gpg.format = ssh` and `signingkey = ~/.ssh/….pub` gets commits signed with the same key through the agent — no
`.env` entries needed. If your host has no `~/.gitconfig`, create one (`touch ~/.gitconfig`) or remove the mount in
`docker-compose.yml`, otherwise the Docker daemon creates an empty directory at the source path.

GitHub, GitLab and Bitbucket host keys are pre-trusted. With `GIT_SIGNING_KEY` set, commits and tags are signed; add
the same public key to GitHub as a **signing key** to see them marked "Verified".

## Moving from nimbleflux/opencode-docker (OpenCode 1)

The compose project is named `opencode-docker`, like the original's, so it opens the same volumes. If your checkout
folder had a different name, set `COMPOSE_PROJECT_NAME` to it.

Back up first, stop the old stack, start this one:

```bash
docker run --rm -v opencode-docker_opencode-data:/d -v "$PWD":/b debian tar czf /b/opencode-data-backup.tgz -C /d .
(cd ../opencode-docker && docker compose down)
make run
```

OpenCode 1 data is imported on first start. The import isn't reversible, so keep the backup. V2's breaking changes:

- **Server API.** The V1 API is gone; use `/api/info` (answers 401 without the password) instead of `/health`.
- **Server command.** `opencode serve` replaces `opencode web`; `OPENCODE_SERVER_USERNAME` is gone (always `opencode`).
- **Plugins.** V1 plugins don't run in V2.
- **Language servers.** V2 doesn't run them.

See OpenCode's [migration guide](https://opencode.ai/docs/migrate-v1).

## Troubleshooting

**The page won't open / "connection refused".**
Is Docker running? Is the container up? `docker compose -f docker-compose.yml -f docker-compose.mcp.yml -f docker-compose.n8n.yml ps` — look for
`opencode`. If the terminal where `make run` runs shows errors, read them; they're usually the missing password or a
port clash.

**"Port 4000 is already in use."**
The web UI port is fixed at 4000; free that port or change the mapping in `docker-compose.yml`, then recreate
(`make run`).

**I forgot my password.**
Unset `OPENCODE_PASSWORD` in `.env`, recreate, and read the new one from the logs:
`docker compose logs opencode | grep "server password"`.

**`make: command not found` (Windows).**
Use the compose commands shown in [Set it up](#set-it-up-in-3-steps), or install GNU make with
`winget install -e --id GnuWin32.Make` (and add its `bin` folder to your `PATH`).

**The first start is very slow.**
Normal. It's downloading several GB of images. Subsequent starts take seconds. Go make coffee.

**I edited `.env` and nothing changed.**
`.env` is read only when the containers are created. Stop and start:
`docker compose -f docker-compose.yml -f docker-compose.mcp.yml -f docker-compose.n8n.yml down` then `make run`.

**The agent can't see my project.**
By default it lives in its own volume. See [Your projects: how they get in](#your-projects-how-they-get-in).

**`git push` says "Permission denied (publickey)".**
SSH keys are loaded into the container's ssh-agent at start — restart the environment (`make run`) so new keys are
picked up, and use an SSH remote (`git@github.com:you/repo.git`). Inside the container, `ssh-add -l` shows which keys
the agent holds. Still stuck? See AGENTS.md.

**Commits show "Unverified" on GitHub.**
Upload your SSH key to GitHub as a **Signing Key** (not an authentication key): Settings → SSH and GPG keys → New SSH
key → type "Signing Key". The commit email must match an email on your GitHub account.

**How do I back up my sessions and settings?**
```bash
docker run --rm -v opencode-docker_opencode-data:/d -v "$PWD":/b debian tar czf /b/opencode-data-backup.tgz -C /d .
```

**How do I start completely over?**
Sessions and workspace live in Docker volumes and survive `make clean`. To erase everything, recreate the volumes:
`docker compose -f docker-compose.yml -f docker-compose.mcp.yml -f docker-compose.n8n.yml down -v` — **warning: this
deletes your sessions and workspace.** Back up first.

**Still stuck?** Open an issue at [github.com/rayenboussayed/opendocker/issues](https://github.com/rayenboussayed/opendocker/issues).

## Known limitations

- Built and tested on amd64; arm64 images exist for the base image and all `mcp/*` servers, so Apple Silicon should
  work but is untested.
- Debian's `gh` is 2.46, which is older; `yq` is the jq-syntax tool (kislyuk/yq), not mikefarah/yq.
- There is no `sudo` or `apt` at runtime; packages you need must be added to `PACKAGES` and the image rebuilt.
- `docker compose exec` opens a root shell; add `-u opencode` to act as the agent.
- First start pulls a few GB of images.

## Learn more

- [OpenCode docs](https://opencode.ai/docs/) — agents, models, MCP, skills, plugins
- [Changelog](CHANGELOG.md) — what changed and when
- [OpenCode Console](https://opencode.ai/console) — pay-as-you-go models and service accounts
- [OpenCode Go](https://opencode.ai/console/go) — $10/month subscription
- [Migration from OpenCode 1](https://opencode.ai/docs/migrate-v1)
- [this repo](https://github.com/rayenboussayed/opendocker) — source, issues, latest changes
- [`platformatic/node-caged`](https://hub.docker.com/r/platformatic/node-caged) — the base image
- [`nimbleflux/opencode-docker`](https://github.com/nimbleflux/opencode-docker) — the OpenCode 1 setup this replaces
