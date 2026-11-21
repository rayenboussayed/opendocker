# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**No versioned release has been tagged yet.** Everything is listed under Unreleased. When you cut the first
release, rename that section to `[x.y.z] - YYYY-MM-DD`, tag the commit, and add the version links at the bottom.

## [Unreleased]

### Added

- Rewritten `README.md` for non-technical users: plain-language explanation, per-platform install guides
  (Windows, macOS, Linux), pros and cons, use cases and a troubleshooting section [1504b5e].
- Rewritten `AGENTS.md` as a machine-wide guide for the agent: SSH/git/GitHub workflows, commit and tag signing,
  signature verification, `gh` usage and a FAQ [1504b5e].
- `CHANGELOG.md` (this file).
- OpenCode Console and OpenCode Go documentation: `opencode/<model>` and `opencode-go/<model>` prefixes,
  `OPENCODE_API_KEY` passing through the explicit `environment:` allowlist, saved `/connect` account precedence [0e74b9e].
- Expanded MCP stack: local servers `sequentialthinking`, `playwright`, `fetch`, `time`, `duckduckgo`,
  `markitdown`, `wikipedia-mcp`, `next-devtools-mcp`, `npm-sentinel`, `memory`, `aws-documentation`,
  `github-official`; remote servers proxied by the gateway `context7`, `deepwiki`, `microsoft-learn`;
  roughly 137 gateway tools, about 140 including the direct remotes [0e74b9e] [cddb0a1].
- `gh_grep` (public GitHub code search) and `cloudflare-docs` (direct remote) enabled by default;
  `cloudflare-docs` points at `https://docs.mcp.cloudflare.com/mcp` [0e74b9e].
- `memory` MCP server; its knowledge graph persists in the Docker-managed `claude-memory` volume, shared
  across projects [0e74b9e].
- OAuth-based MCP servers preconfigured but disabled by default (`"disabled": true`): `linear`, `notion`,
  `atlassian`, `sentry`, `figma`, `supabase` (read-only), `neon` (read-only), `vercel`, `cloudflare`, `stripe`,
  `posthog`, `eslint`, `astryx` [0e74b9e].
- Initial `docker-compose.mcp.yml` with the Docker MCP Gateway, wired into the agent via `opencode.json` [91bd0de].
- Universal config `opencode.json` mounted read-only at `/etc/opencode/opencode.json`: machine-wide, outranks
  global and project configs, allows every tool action and loads `AGENTS.md` [2fe292c].
- Docker image built from `platformatic/node-caged:slim` with OpenCode 2 installed from npm;
  Python, FFmpeg, git, git-lfs, GitHub CLI, `jq`, `yq`, ripgrep, `fd`, `sqlite3` and more [2fe292c].
- Host-based git setup: `~/.ssh` and `~/.gitconfig` mounted read-only, public keys staged and private keys loaded
  into an in-container agent, pre-trusted host keys for GitHub/GitLab/Bitbucket, `ssh_config` and
  `ssh_known_hosts` baked into the image [2fe292c].
- Resolve host `~/.gitconfig` signing paths inside the container via a symlinked `$HOST_HOME/.ssh` → `~/.ssh` [bef4b5c].
- Named volumes for sessions, config, workspace and cache; port published on `127.0.0.1` only; resource limits
  (4,096 processes, 8 GB memory) [2fe292c].
- `Makefile` targets: `run`, `run-clean`, `run-opencode-clean`, `run-n8n-clean`, `build`, `down`, `clean` [2fe292c].
- MCP stack included in the default flow: `make run` starts it alongside OpenCode; `make down` and
  `make clean` handle both stacks [98c6ff9].
- Four catalog MCP servers: `grafana`, `dockerhub`, `mcp-code-interpreter` and `n8n`. `memory` was already enabled, so
  the gateway now runs 19 servers and roughly 264 tools.
- `mcp-config.yml` holds non-secret catalog config (`n8n.api_url`), mounted read-only into the gateway.
  `.env.mcp.example` documents the optional Grafana, Docker Hub and n8n secret keys.
- A dedicated DinD daemon (`docker:dind`) for the agent's builds and test containers, with a Docker CLI and
  `buildx`/`compose` plugins copied from `docker:cli`. Ports in `DIND_PORT_START`–`DIND_PORT_END` (default
  31000–31099) are forwarded from `127.0.0.1`; the daemon's ephemeral range is constrained to the same ports so
  `docker run -P` is host-reachable too. A `DinD` section in README and AGENTS.md documents port publishing.
- `DOCKER_CLI_TAG`, `DIND_PORT_START` and `DIND_PORT_END` build/runtime settings in `.env.example`.

### Changed

- `.env` no longer holds MCP credentials: the gateway now mounts `./.env.mcp` directly, which is never passed
  to the OpenCode container; `.env.mcp.example` is the tracked template; `.env.example` restored to the minimal
  application settings [946ab2d].
- MCP stack is mandatory in compose operations (`make run`/`build`/`down`/`clean` and plain compose invocations),
  instead of an opt-in addition [98c6ff9].
- Default web UI port changed from 4001 to 4000; MCP gateway memory limit raised to 4 GB [273ee8c].
- Cross-platform support (Linux, macOS, Windows): LF line endings via `.gitattributes`, `HOME`/`USERPROFILE`
  interpolation with `HOST_HOME` override, Docker Desktop/WSL2 guidance in the docs [9ace648].
- `Makefile` `.PHONY` trimmed to the real targets (`run`, `run-clean`, `run-opencode-clean`, `run-n8n-clean`, `build`,
  `down`, `clean`) [946ab2d].
- `websearch.provider` set to `random` (no credentials; see the `EXA_API_KEY` family of variables) [0e74b9e].
- Deep refactor: the Dockerfile, entrypoint, three compose files, Makefile and `opencode.json` were simplified and
  stripped of inline comments; rationale now lives in the README's "Design decisions & rationale" section. The
  entrypoint gained named functions, the n8n stack uses a YAML anchor for shared hardening, disabled MCP servers are
  one-line stubs and `.dockerignore` uses an `.env*` glob. Healthchecks were added for n8n and wired for SearXNG.
- `docker-compose.yml` and `docker-compose.mcp.yml` were merged into `docker-compose.opencode.yml`; `opencode` gained
  `depends_on: mcp-gateway` so the gateway container exists before OpenCode connects. The gateway URL comes from
  `MCP_GATEWAY_URL` (Compose sets the internal URL; a host CLI exports the loopback URL). Catalog config values come
  from `mcp-config.yml` via `--config`; `.env.mcp` stays secrets-only.
- `astryx` and `eslint` no longer carry the redundant `enable: true` field — they are enabled by default in V2.
- Deep refactor: `entrypoint.sh` gained a `gcfg` helper (10 call sites) and a shared `SSH_HOST_KEYS` array for the four
  host key names; the unreachable `HOST_HOME != "$H"` guard was dropped. `Dockerfile` folds the `/etc/opencode` chmod
  into the existing RUN instead of adding a layer. `Makefile` drops the dead `docker info`/`$(SUDO)` probe.
  `opencode.json` drops the redundant `skill` permission rule. Comment-only lines were removed from `.env.example`,
  `.env.mcp.example` and `mcp-config.yml`; rationale stays in README.
- README: corrected the stale server count (~15 → ~19 servers / 264 tools), removed false "Makefile uses sudo" claims,
  qualified floating version numbers, dropped the redundant skill-rule text, merged the duplicated pinned-n8n-node
  paragraph, and documented the n8n↔gateway trust equivalence and the custom SSH key limitation.
- AGENTS.md: corrected the pip install-path claim, added `POSTHOG_PERSONAL_API_KEY` to the skills-refresh env-unset
  list, and clarified who runs `opencode mcp list` and the startup-log command.

### Removed

- `prepare-mcp-secrets.sh` and the Makefile secrets target; the gateway reads `./.env.mcp` directly [946ab2d].
- MCP bearer token on the gateway (loopback-only, not reachable from the LAN) [ed5290f].
- Chrome DevTools MCP server (Playwright kept as the browser automation path) [51bd358].
- Stale `make test` / `make docker` commands and the nonexistent `tests/` section from the docs [1504b5e].
- `Makefile` targets `run-opencode-clean` and `run-n8n-clean`, plus the service-list variables and the `$(2)` macro
  parameter they alone used. `run-clean` is now the only clean target.

### Fixed

- `.env.example` restored after being dropped by accident in the Makefile change [fe69e48].
- `ssh_known_hosts` regenerated (github/gitlab/bitbucket) [273ee8c].
- `SSH_PRIVATE_KEY` is piped into ssh-agent instead of being staged as a file, and is unset immediately after loading;
  a self-referential `$HOST_HOME/.ssh` symlink is avoided; an empty public key no longer defeats the signing fallback.
- `.env.example` now explains that `N8N_POSTGRES_PASSWORD` must be set; README's `env_file`, service-scope,
  plain-compose and "everything else can stay as-is" claims were corrected, and the nonexistent `rebuild-nan-addons`
  helper was removed from the docs.
- AGENTS.md's stale claims about published ports, the SSH key install path and the unauthenticated gateway were fixed;
  its duplicated FAQ entries and skills tables were consolidated.
- The host OpenCode CLI could not resolve `http://mcp-gateway:8080/mcp` (a Compose-internal hostname); the URL is now
  driven by `MCP_GATEWAY_URL`, and the docs explain how to inspect MCP status and find Code Mode tools.
- `/etc/opencode` was mode 644, so the `opencode` user could not read the system config and OpenCode reported no MCP
  servers; the Dockerfile now chmods it to 755. `gateway-config.json` enables `tool-name-prefix` to resolve the
  `dockerhub`/`duckduckgo` `search` tool collision; all 19 servers and 264 tools now load.
- Stale README claims about `${VAR:?}` guards, config requiring a restart, and tool counts were corrected; bare
  `docker compose` commands in the docs now carry both `-f` flags.
- `HOST_HOME` drift: the `~/.ssh` and `~/.gitconfig` bind mounts now use the same `HOST_HOME`/`HOME`/`USERPROFILE`
  fallback as the container env, so an explicit override resolves host keys from the intended directory.
- File uploads in the web UI returned HTTP 500 because OpenCode writes temp files to `/tmp/opencode`, which the base
  image created as root-owned; the Dockerfile now creates it as `opencode:opencode`. `~/.config/opencode/skills` is
  chowned for the same reason so skill installs are writable by the agent.

### Security

- OpenCode has no sudo or system package manager at runtime; `no-new-privileges: true` is set on every service, and its
  capability set is limited to what the startup drop to the agent user requires [6b3bc43].
- Private SSH keys are loaded from the read-only host mount straight into an in-container `ssh-agent`; a key supplied
  via `SSH_PRIVATE_KEY` is piped in on stdin, so no private-key file is created. Git transport and SSH signing work
  through the agent [6b3bc43].
- OpenCode receives an explicit allowlist of environment variables instead of the whole `.env`, so n8n/Postgres/SearXNG
  secrets never enter the agent container [6b3bc43].
- The automatic skills refresh runs without `GH_TOKEN`, `OPENCODE_API_KEY`, `OPENCODE_PASSWORD` or the PostHog key;
  it keeps the SSH agent only to sign its local snapshot commit. The docs now state plainly that mounted host keys
  remain readable by the same UID and that the unauthenticated MCP gateway holds the Docker socket.
- The gateway runs with `cap_drop: [ALL]`, a 4 GB memory limit and publishes on `127.0.0.1` only; the Docker
  socket is mounted into the gateway (its control plane) and never into the OpenCode container [91bd0de]
  [0e74b9e] [946ab2d].
- The new MCPs are documented with their real capability surface and least-privilege token guidance. Gateway-spawned
  MCP containers get `no-new-privileges` but not the Compose services' `cap_drop: ALL`; `mcp-code-interpreter` runs
  arbitrary Python and `mcp/n8n` can manage workflows. n8n has no supported CLI/env way to generate a default API key,
  so the key remains an explicit, optional user action.
- Gateway catalog servers are pinned to digests and signature-verified by the gateway; the agent container drops all
  capabilities except the five needed for `chown` and the `setpriv` drop to the agent user [2fe292c] [91bd0de].
- Documented two pre-existing trust boundaries surfaced during the adversarial audit: n8n shares the compose network
  with the unauthenticated, Docker-socket-backed gateway (n8n access is effectively host-level), and only the four
  standard SSH key names are auto-loaded into the agent — custom-named keys need an explicit `ssh-add`. Neither
  behavior changed in this refactor.
- `.env.mcp` is gitignored and Docker-ignored, must remain chmod 600, and is never passed to OpenCode [946ab2d].
- DinD is privileged and host-root-equivalent: it lives on an internal `docker-net` that gateway-spawned MCP
  containers cannot join, its unauthenticated `2375` port is never published to the host, and its forwarded port range
  is loopback-bound. `DOCKER_HOST` is stripped from the background skills refresh.
- MCP endpoints are unauthenticated but bind to loopback only; direct remote endpoints enabled by default send
  queries to Grep/grep.app, Cloudflare Docs, Context7, DeepWiki and Microsoft Learn [ed5290f] [0e74b9e].

[unreleased]: https://github.com/rayenboussayed/opendocker/compare/2fe292c...HEAD
[1504b5e]: https://github.com/rayenboussayed/opendocker/commit/1504b5edc5c234d833a9c5cd3de246ee7555c463
[946ab2d]: https://github.com/rayenboussayed/opendocker/commit/946ab2d4043d69b9b1d9510c48d4b207ea921a97
[0e74b9e]: https://github.com/rayenboussayed/opendocker/commit/0e74b9e40fb6b4e06b6e0d5afa8fe9bb7fc5ab48
[273ee8c]: https://github.com/rayenboussayed/opendocker/commit/273ee8c3c5d3319e4d6febaad9a3519c8dfb03e1
[cddb0a1]: https://github.com/rayenboussayed/opendocker/commit/cddb0a188d1eb8a9b4c482b14cf36cb1019296da
[9ace648]: https://github.com/rayenboussayed/opendocker/commit/9ace648f1e3728629b96f1abc6220a8250f582cd
[fe69e48]: https://github.com/rayenboussayed/opendocker/commit/fe69e489cdb0d787a743930784d9322c35441ede
[98c6ff9]: https://github.com/rayenboussayed/opendocker/commit/98c6ff946b4239a4a3fea74caee568bcfd5af73d
[51bd358]: https://github.com/rayenboussayed/opendocker/commit/51bd3581ab80e05eb19fc8db7fd3d73cd1b5ced8
[ed5290f]: https://github.com/rayenboussayed/opendocker/commit/ed5290f67eec200b76a7eee50e5600b4d0ca9dda
[91bd0de]: https://github.com/rayenboussayed/opendocker/commit/91bd0de49aa42fff7fe1a2e90d5b1b25f6a48ee6
[bef4b5c]: https://github.com/rayenboussayed/opendocker/commit/bef4b5c9f7777b961eb786b48b7890974387c0a1
[2fe292c]: https://github.com/rayenboussayed/opendocker/commit/2fe292c6543298a3aa7923f480bbdc897f23b055
[6b3bc43]: https://github.com/rayenboussayed/opendocker/commit/6b3bc4304986168a7ade0cbdb1f971cdcfd372e6
