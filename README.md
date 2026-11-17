# opencode-debian

[OpenCode](https://opencode.ai) 2 in an isolated container built on
[`platformatic/node-caged`](https://hub.docker.com/r/platformatic/node-caged) (Debian 13 trixie). The agent gets
root inside the container through `sudo`, plus Node.js, Python and common tools. It replaces
[nimbleflux/opencode-docker](https://github.com/nimbleflux/opencode-docker), and existing sessions carry over.

```bash
cp .env.example .env              # set OPENCODE_PASSWORD
make run
```

Open http://localhost:4000 and sign in with your `OPENCODE_PASSWORD`. If you don't set one, OpenCode generates a new
password at every start; find it with `docker compose logs opencode | grep "server password"`.

## Commands

| Command | What it does |
|---|---|
| `make run` | Starts OpenCode and the MCP stack in the foreground, building the image only if it doesn't exist yet. Ctrl+C removes the container and keeps the image, so the next start is fast. |
| `make run-clean` | Builds fresh (latest base image, no cache), starts OpenCode, and on Ctrl+C removes the container and the image. |
| `make build` | Builds fresh without starting. |
| `make down` | Removes the OpenCode and MCP containers. |
| `make clean` | Removes the OpenCode and MCP containers and the image. |
| `make test` | Builds and runs the test suite. |
| `make docker` | Optional, Linux only: installs or updates Docker Engine with Docker's official script. On Debian/Ubuntu it first removes conflicting distro packages, as Docker's docs require. |

Every command keeps the volumes, so your sessions, settings and workspace are never deleted. If you aren't in the
`docker` group, the Makefile uses `sudo` automatically. You can also use plain `docker compose` commands.

## What's inside

| | Comes from |
|---|---|
| Node.js 26 + npm | the base image, `platformatic/node-caged:slim` |
| OpenCode 2 | `npm install -g @opencode/cli@latest` |
| Python 3.13 + pip + venv | Debian (`apt`) |
| git, git-lfs, gh, ssh, sudo, jq, yq, ripgrep, fd, sqlite3, make, htop, … | Debian (`apt`) |

That's the whole install: one `apt-get install` line and one `npm install` line.

### About node-caged

node-caged is Node.js built with V8 pointer compression, which roughly halves the memory of JavaScript objects.
- **What it helps:** the Node processes the agent starts, such as MCP servers, dev servers and test runners.
- **What it doesn't:** OpenCode itself, which is a native binary.
- **Limits:** each Node process's heap is capped at 4 GB. N-API native addons work, but addons built on the older NAN
  API (e.g. `better-sqlite3`) can crash and need rebuilding with the included `rebuild-nan-addons`.
- **Harmless warning:** npm prints `Unknown env config "nodedir"`. It comes from the base image, which sets it so
  rebuilt addons use the right headers.

AGENTS.md tells the agent all of this.

## Configuration

Everything goes in `.env`, and everything is optional.

| Setting | Purpose |
|---|---|

| `OPENCODE_PASSWORD` | Password for the web UI and API (username `opencode`) |
| `OPENCODE_PORT` | Host port (default 4000) |
| `GIT_USER_NAME`, `GIT_USER_EMAIL` | Git identity; if unset, read from the host's `~/.gitconfig` |
| `GIT_SIGNING_KEY` | Sign commits and tags: a key file in `~/.ssh` (e.g. `id_ed25519.pub`), `agent`, or a public key; if unset, read from the host's `~/.gitconfig` |
| `SSH_PRIVATE_KEY` | Private key contents, as an alternative to mounting `~/.ssh` |
| `SSH_AUTH_SOCK` | `/ssh-agent` when mounting your ssh-agent |
| `GH_TOKEN` | `gh` and HTTPS git for github.com |
| `NODE_TAG` | Build: base image tag; `slim` (default) is the newest Node, or e.g. `26-slim`, `26.13.1-slim` |
| `OPENCODE_VERSION` | Build: `latest` (default) or e.g. `2.3.0` |
| `NPM_PACKAGES`, `PIP_PACKAGES` | Build: extra global tools, e.g. `typescript pnpm@9` / `ruff` |
| `PACKAGES` | Build: replaces the default Debian package list in the Dockerfile |

Versions are resolved when the image is built, so `make run-clean` (or `make build`) always picks up the latest
releases.

To use the OpenCode terminal client against the container's server:

```bash
docker compose exec -u opencode opencode opencode --server http://127.0.0.1:4000
```

## Supported platforms

| Platform | Status |
|---|---|
| Linux (Debian/Ubuntu, amd64 + arm64) | Primary. Built and tested on amd64 |
| macOS (Intel & Apple Silicon) with Docker Desktop | Works; all images are multi-arch (arm64 native) |
| Windows with Docker Desktop | Works; WSL2 backend recommended. The Makefile needs GNU make (`winget install GnuWin32.Make`) — or use the compose commands below, which are the portable path |

Portable commands (any OS):

```bash
docker compose -f docker-compose.yml -f docker-compose.mcp.yml build
docker compose -f docker-compose.yml -f docker-compose.mcp.yml up
```

Cross-platform notes:

- **Line endings are pinned to LF** via `.gitattributes` — a CRLF checkout on Windows would break the
  `entrypoint.sh` shebang. If you ever cloned with `core.autocrlf=true`, run `git add --renormalize .`.
- **Home directory detection.** `~/.ssh` and `~/.gitconfig` are mounted using `HOME` on Linux/macOS and
  fall back to `USERPROFILE` on Windows. Set `HOST_HOME` in `.env` to override explicitly.
- **Git paths in `~/.gitconfig`.** Git Bash on Windows uses `~/.ssh/...`, which resolves inside the container.
  A `C:\Users\…\.ssh\….pub` signingkey path can't exist in a Linux container — commits will still work, just
  unsigned (a warning is printed). Use `GIT_SIGNING_KEY=key::ssh-ed25519 AAAA…` to sign with any host layout.
- **Docker Desktop file sharing.** No extra setup needed for your home directory or the project folder (both are
  shared by default). The build context excludes `.env` and `.git` via `.dockerignore`.
- **`make` on Windows.** Not required if you use the compose commands above; `make run`, `make down`, etc. are the
  POSIX-shell convenience wrapper.

## Root access and isolation

The agent runs as the user `opencode` and can use `sudo` without a password. The compose file keeps that root inside
the container:

- **Minimal kernel privileges.** All capabilities are dropped and only the 8 that sudo, apt and the startup script
  need are added back. Even with sudo, the agent can't mount filesystems, create namespaces, chroot, open raw sockets,
  create device nodes, change kernel settings or read the kernel log.
- **No host access.** No Docker socket and no host directories; only named volumes are mounted.
- **Localhost only.** The port is published on `127.0.0.1`.
- **Resource limits.** 4,096 processes and 8 GB of memory.
- Docker's default seccomp and AppArmor profiles stay on. `no-new-privileges` is not set, because it would disable
  sudo.

What this doesn't cover:
- **Network:** the container can reach the internet, your local network, and host services listening on all
  interfaces.
- **Kernel:** containers share the host kernel, so a kernel bug could allow an escape.
- **Secrets:** the agent can use any keys or tokens you pass in.

For stronger isolation, run Docker rootless or with `"userns-remap": "default"`, so container root becomes an
unprivileged host user. Alternatively, add `runtime: runsc` to use [gVisor](https://gvisor.dev).

## Universal config

`opencode.json` in the repo root is mounted read-only over the image's system config, `/etc/opencode/opencode.json`.
The system config is machine-wide and outranks the global and project configs, so it applies to every project and
can't be loosened by them. It allows every tool action (`permissions`: `action: *`, `resource: *`, `effect: allow`),
and keeps the `instructions` entry that loads `AGENTS.md`. Edit it and restart the container to change it — no rebuild
needed. The same `opencode.json` is baked into the image as `/etc/opencode/opencode.json`, so the behavior doesn't
depend on the mount.

## MCP servers

An MCP stack ships in `docker-compose.mcp.yml` and is part of the default flow: `make run` (and every plain `docker
compose` command via two `-f` files) starts it alongside OpenCode. It runs MCP tool servers for the agent, published on
`127.0.0.1` for this machine and reachable by the agent over the compose network:

```bash
make run
# or by hand:
docker compose -f docker-compose.yml -f docker-compose.mcp.yml up
```

| Server | Container endpoint | Host endpoint | Backed by |
|---|---|---|---|
| Docker MCP Gateway | `http://mcp-gateway:8080/mcp` | `http://127.0.0.1:8200/mcp` | `docker/mcp-gateway` + 9 `mcp/*` images (Docker-built, cosign-verified by the gateway) |

The gateway serves 76 tools: Playwright (23, driving a real Chromium), Wikipedia (22), npm-sentinel (19), plus
`sequentialthinking`, `fetch`, `time`, `duckduckgo`, `markitdown`, `next-devtools-mcp`. No authentication — the endpoint is only on
loopback and the internal compose network; don't publish it any wider without adding auth (or a proxy) back.

OpenCode is already wired to the container endpoint in `opencode.json` (`mcp.servers.docker-gateway`). When the stack
is down it shows as disconnected — harmless. Host-side clients use the loopback URL with no token:

The first start pulls the `mcp/*` images (a few GB); subsequent starts reuse them. Docker's MCP Gateway signature-verifies them against Docker's keyring.

```bash
curl -s http://127.0.0.1:8200/mcp -X POST \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

Security notes:
- Ports publish on `127.0.0.1` only; the agent talks to `mcp-gateway` on the internal compose network. Host port defaults to 8200; override with `MCP_GATEWAY_PORT` in `.env` if needed.
- The gateway mounts `/var/run/docker.sock` because it *is* the control plane spawning the `mcp/*` containers. The agent container never sees the socket.
- `duckduckgo`, `wikipedia-mcp` and `next-devtools-mcp` are community-maintained (unofficial); the rest come from the original authors (Microsoft, Google, modelcontextprotocol). Browser MCPs can see and do anything the browser can — treat their output as untrusted input.

## AGENTS.md

`AGENTS.md` (repo root) is installed as `/etc/opencode/AGENTS.md` and loaded through OpenCode's system config,
`/etc/opencode/opencode.json`. It tells the agent:
- that it has sudo, and which limits not to work around
- what persists and what's lost on rebuild
- which tools exist
- to leave git signing and SSH settings alone

It's loaded alongside your own `~/.config/opencode/AGENTS.md` and project `AGENTS.md` files. Edit it and rebuild to
change it.

## SSH and commit signing

Uncomment one option in `docker-compose.yml`:

- **Mount your keys:** `~/.ssh:/home/opencode/.ssh-host:ro`. They're copied into `~/.ssh` with the permissions ssh
  requires.
- **Forward your ssh-agent:** the socket mount, plus `SSH_AUTH_SOCK=/ssh-agent` in `.env`. No key files enter the
  container.
- **Paste a key:** set `SSH_PRIVATE_KEY` in `.env`.

Git identity and signing are inferred from the host: `~/.gitconfig` is mounted read-only at
`/home/opencode/.gitconfig-host`, and the entrypoint reads `user.name`, `user.email` and `user.signingkey` from it
when the corresponding `.env` values are unset (explicit `.env` values win). The host's `~/.ssh` is mounted
read-only and copied into the container's `~/.ssh` with fixed ownership/permissions; the entrypoint then symlinks
`$HOST_HOME/.ssh` (the host's original absolute path, with `HOST_HOME=${HOME}` set by compose) to that `~/.ssh`, so
the `signingkey` path in the host config resolves verbatim inside the container — absolute paths and `~` both work on
any uid, no path rewriting. A host like this one (name/email plus `gpg.format = ssh` and
`signingkey = ~/.ssh/….pub`) gets fully working commits signed with the same key — no `.env` entries needed. If your
host has no `~/.gitconfig`, create one (`touch ~/.gitconfig`) or remove the mount in `docker-compose.yml`, otherwise
the Docker daemon creates an empty directory at the source path.

GitHub, GitLab and Bitbucket host keys are pre-trusted. With `GIT_SIGNING_KEY` set, commits and tags are signed; add
the same public key to GitHub as a **signing key** to see them marked "Verified".

## Moving from nimbleflux/opencode-docker (OpenCode 1)

The compose project is named `opencode-docker`, like the original's, so it opens the same volumes. If your checkout
folder had a different name, set `COMPOSE_PROJECT_NAME` to it. Back up, stop the old stack, start this one:

```bash
docker run --rm -v opencode-docker_opencode-data:/d -v "$PWD":/b debian tar czf /b/opencode-data-backup.tgz -C /d .
(cd ../opencode-docker && docker compose down)
make run
```

The original runs OpenCode 1; this image runs OpenCode 2, which imports V1 data on first start. Tested on
OpenCode 1.19.5 data:
- Sessions in git and non-git folders, with their full conversations, carry over.
- Provider credentials carry over.

The import isn't reversible, so keep the backup. V2's intentional breaking changes are:
- **Server API.** Integrations calling the V1 API need updating, including the original Helm chart's `/health`
  probes. Use `/api/info`, which answers 401 without the password.
- **Server command.** The server is started with `opencode serve`; `opencode web` no longer exists.
  `OPENCODE_SERVER_USERNAME` is gone, and the username is always `opencode`.
- **Plugins.** V1 plugins don't run in V2.
- **Language servers.** V2 doesn't run them.

See OpenCode's [migration guide](https://opencode.ai/docs/migrate-v1).

## Tests

```bash
BUILD=1 tests/run-tests.sh
V1_IMAGE=ghcr.io/nimbleflux/opencode-docker:latest tests/run-tests.sh    # also test session migration
```

Only Docker is needed. Every container runs with the compose file's restricted capabilities. The suite covers:
- Node (with pointer compression), Python and the bundled tools
- sudo and apt
- installs as the agent user
- the server, password and healthcheck
- each SSH option against a real SSH git server
- signed commits and tags
- the isolation checks on the shipped compose file
- AGENTS.md reaching the model, using a mock LLM server
- optionally, migration from an OpenCode 1 image

## Known limitations

- Built and tested on amd64; arm64 images are published for the base image and all `mcp/*` servers, so Apple Silicon should work but is untested.
- Debian's `gh` is version 2.46, which is older; `yq` is the jq-syntax tool (kislyuk/yq), not mikefarah/yq.
- Packages the agent installs with `sudo apt-get` disappear when the container is recreated; add them to `PACKAGES`.
- `docker compose exec` opens a root shell; add `-u opencode` to act as the agent.
