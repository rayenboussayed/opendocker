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

## Network

- Internet access is available.
- Only OpenCode's own port is published. Servers you start (dev servers, databases) are not reachable from the
  user's browser unless the user publishes their port; say so when it matters.
