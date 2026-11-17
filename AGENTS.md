# Container environment

You are running inside an isolated Docker container (Debian stable), not directly on the user's computer.

## Access

- You run as the user `opencode` and have passwordless root through `sudo`, e.g. `sudo apt-get install -y <package>`.
- Root is confined to this container. There is no Docker socket, the host's files are not visible except for the
  mounted volumes, and kernel privileges are restricted (no mounting, no raw sockets or packet capture, no device
  access, no namespaces or chroot). Don't try to work around these limits; tell the user if a task needs them.

## What persists

- Kept across restarts and rebuilds: `~/workspace` (keep all projects here), `~/.config/opencode`,
  `~/.local/share/opencode` and `~/.cache`.
- Lost when the container is recreated: everything else, including packages installed with `sudo apt-get`, global
  `npm`/`pip` installs and changes outside the paths above. If a project permanently needs a system
  package, tell the user to add it to `PACKAGES` in their `.env` and rebuild the image.

## Tools

- Available: Node.js with npm/npx, Python with pip and venv, git, git-lfs, gh, jq, yq, ripgrep (`rg`), fd, sqlite3,
  curl, make. Compilers are not installed; use `sudo apt-get install -y build-essential` when something needs building.
- `yq` is the jq-syntax YAML tool: queries use jq syntax and output JSON unless you add `-y`.
- Node.js is built with pointer compression: about half the memory, but each process's heap is limited to 4 GB.
  N-API native addons work; addons using the older NAN API (e.g. `better-sqlite3`) can crash. Prefer an N-API
  alternative, or rebuild them with `rebuild-nan-addons` after installing `build-essential`.
- Prefer project-local dependencies (`package.json`, a virtualenv) over global installs.
- `npm install -g` and `pip install` work without sudo and install into `~/.local`. Don't use sudo for them.

## Git

- The git identity, SSH keys or SSH agent, and commit signing are set up by the container at startup. Don't change
  `user.name`, `user.email`, `user.signingkey`, `commit.gpgsign` or `~/.ssh` unless the user asks.
- Don't push, force-push or rewrite published history unless the user asks.
- `gh` is authenticated only when the user provides a `GH_TOKEN`.

## SSH

SSH is preconfigured. Use it; don't reconfigure it unless the user asks.

- **Where the keys come from:** the host's `~/.ssh` is mounted read-only at `~/.ssh-host` and copied into `~/.ssh`
  at startup, with fixed ownership (1000:1000) and permissions (private keys 600, `.pub`/`known_hosts` 644). Directories
  and `authorized_keys` / `environment` are not copied. The copy is refreshed on every container start, so host-side
  key changes only show up after a restart.
- **Path compatibility:** the entrypoint also symlinks `$HOST_HOME/.ssh` (the host's original home path, set by
  compose) to `~/.ssh`, so the `signingkey` path in the host's `~/.gitconfig` — absolute or `~/.ssh/...` — resolves
  to the same keys inside this container.
- **Pre-trusted hosts:** github.com, gitlab.com and bitbucket.org host keys live in `/etc/ssh/ssh_known_hosts`.
  `ssh -T git@github.com` and `git clone`/`git push` over SSH work without prompts. Any other host is untrusted;
  tell the user if a new host needs to be trusted rather than bypassing host key checking.
- **Identity and signing:** `user.name` and `user.email` come from the host's `~/.gitconfig` (mounted at
  `~/.gitconfig-host`); explicit `GIT_USER_NAME` / `GIT_USER_EMAIL` in `.env` win. Commit and tag signing use
  `gpg.format=ssh` with `user.signingkey` from `.env` (`GIT_SIGNING_KEY`) or from the host config. `~/.config/git/allowed_signers`
  is rebuilt at startup from the key in use. To sign via the agent instead of a key file, set `GIT_SIGNING_KEY=agent`
  (uses the first key the agent offers).
- **ssh-agent:** if the user forwards an agent (socket mounted at `/ssh-agent`, `SSH_AUTH_SOCK=/ssh-agent` in `.env`),
  ssh and git use it for transport. If the socket can't be used by uid 1000 directly, the entrypoint relays it through
  `socat` and points `SSH_AUTH_SOCK` at the relay.
- **One-shot keys:** `SSH_PRIVATE_KEY` in `.env` installs a pasted private key as `~/.ssh/id_ed25519` (or `id_rsa` /
  `id_ecdsa`, guessed from the key type); its `.pub` is derived automatically.
- **Hygiene:** private keys live in `~/.ssh` only as far as this container goes. Don't `cat`, copy or print key
  contents, and don't `ssh-copy-id` or distribute them anywhere. If a task seems to need a different key or host,
  ask the user.
- **Testing SSH:** `ssh -T git@github.com` (authentication), `git log --show-signature` (an SSH-signed commit),
  `ssh-add -l` (an agent's keys). Diagnosis before acting: `ssh -vvv -T git@github.com` if something fails.

## MCP

An MCP tool server is (optionally) available on the compose network, configured as a remote server in the system
config:

- `docker-gateway` at `http://mcp-gateway:8080/mcp` — 57 tools: Playwright, Wikipedia, `sequentialthinking`, `fetch`,
  `time`, `duckduckgo`, `markitdown`, `next-devtools-mcp`.

No authentication; reachable only on loopback and in the Docker network. It connects when the MCP stack is running;
if it shows as disconnected, ask the user to start it (`make run`, or `docker compose -f docker-compose.yml -f
docker-compose.mcp.yml up -d mcp-gateway`) rather than editing the configuration.

## Network

- Internet access is available.
- Only OpenCode's own port is published. Servers you start (dev servers, databases) are not reachable from the
  user's browser unless the user publishes their port; say so when it matters.
