# n8n, PostgreSQL, and SearXNG — design

Date: 2026-11-20

## Goal

Add self-hosted n8n with a Postgres database and a private SearXNG search backend to the existing
OpenCode compose project, and connect n8n to the OpenCode agent running in the same stack.

## Research findings

- The linked `install-with-docker` page is deprecated; n8n recommends its Docker Compose guide.
  That guide's default stack bundles a privileged Docker-in-Docker sandbox runner for n8n Assistant.
  It is development-only, needs 4 GB+ RAM, and is at odds with this repo's security posture. It is
  deliberately excluded.
- `ssccio/n8n-nodes-opencode@1.0.0` (Oct 2025) targets the OpenCode **V1** server API: unprefixed
  `/session`, `/session/:id/message` with `parts`, `/agent`, `/config/providers`, and Bearer auth.
  This repo runs OpenCode 2, whose OpenAPI spec has only `/api/...` routes (`Model.Ref` uses `id`,
  prompt input is `text`), with HTTP Basic auth (user `opencode`). The two open fix PRs are unmerged
  and still V1-shaped. The node cannot work here.
- `n8n-nodes-opencode-v2@0.1.1` (Nov 2026) targets OpenCode ≥ 2.1, uses Basic auth, tests credentials
  with `GET /api/info`, waits via `/api/experimental/session/:id/wait`, keeps persistent sessions,
  has permission presets, and is `usableAsTool`. It is new (0 stars), so pin its tarball checksum.
- n8n ≥ 2.21 can install community packages from env (`N8N_COMMUNITY_PACKAGES_MANAGED_BY_ENV` +
  `N8N_COMMUNITY_PACKAGES`). A pinned `checksum` satisfies the unverified-package requirement.
- SearXNG's stock config only enables HTML results; JSON requires a `search.formats` override in
  `/etc/searxng/settings.yml`. `SEARXNG_SECRET` overrides the placeholder secret key.

## Design

- New `docker-compose.n8n.yml` in the same `opencode-docker` project/network, included in the
  Makefile's `COMPOSE` list so all `make` targets cover it:
  - `postgres:18` with pinned `PGDATA`, healthcheck, `n8n-postgres` volume, no host port.
  - `n8nio/n8n:${N8N_VERSION:-2.48.6}` on `127.0.0.1:${N8N_PORT:-5678}:5678`, `n8n-data` volume,
    explicit env only (no `env_file: .env`, so OpenCode/MCP secrets never reach n8n), and
    `depends_on: postgres: service_healthy`.
  - `ghcr.io/searxng/searxng` with `SEARXNG_SECRET`, read-only `searxng-settings.yml`, a cache
    volume, `/healthz` healthcheck, and no host port.
  - Capabilities dropped to the minimum needed for the images' entrypoints, plus pids/memory limits.
- New `searxng-settings.yml` merged with defaults (`use_default_settings: true`) to enable `json`
  and disable image proxy/limiter.
- `.env.example`: `N8N_PORT`, `N8N_VERSION`, `N8N_ENCRYPTION_KEY`, `N8N_TIMEZONE`,
  `N8N_POSTGRES_USER/PASSWORD/DB`, `SEARXNG_SECRET`, `SEARXNG_VERSION`.
- Docs: README section plus AGENTS.md service inventory.

## Decisions

- Use the v2 community node, pinned by checksum. Do not install the V1-only ssccio node.
- Use Postgres rather than SQLite for n8n storage.
- No Assistant sandbox/SearXNG proxy stack: SearXNG alone is useful for direct HTTP workflows and is
  ready if Assistant is enabled later.
- All ports published on loopback only; Postgres and SearXNG have no host ports.

## Verification

- `docker compose -f docker-compose.yml -f docker-compose.mcp.yml -f docker-compose.n8n.yml config -q`
- `make run`; `curl -sf http://127.0.0.1:5678/healthz`
- `docker compose exec postgres pg_isready -U "$N8N_POSTGRES_USER" -d "$N8N_POSTGRES_DB"`
- `docker compose logs n8n | grep -i opencode` shows the pinned package installed
- `docker compose exec n8n wget -qO- http://searxng:8080/healthz`
- `docker compose exec n8n wget -qO- 'http://searxng:8080/search?q=opencode&format=json'`
- In the n8n UI, test the OpenCode V2 credential and run a two-message chat to confirm session reuse.
