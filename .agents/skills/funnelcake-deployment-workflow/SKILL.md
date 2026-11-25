---
name: funnelcake-deployment-workflow
description: |
  Point agents to divine-funnelcake's authoritative deployment and ClickHouse migration
  runbooks instead of using stale manual Docker build or ClickHouse Cloud instructions.
  Use when: (1) Deploying funnelcake to staging, POC, or production, (2) Running or
  debugging ClickHouse migrations for funnelcake, (3) Investigating ImagePullBackOff or
  sync issues on funnelcake workloads.
author: Claude Code
version: 3.0.0
date: 2026-11-25
---

# Funnelcake Deployment Workflow

## Source of Truth

`divine-mobile` does not maintain a copy of Funnelcake's deployment or migration procedure.
Read the authoritative documentation in the `divine-funnelcake` repository before acting:

- `docs/DEPLOYMENT.md` — CI image build pipeline, staging/POC delivery, and the
  production promotion workflow (`.github/workflows/deploy-production.yml` mirrors
  CI-built images from staging to production and opens a GitOps PR in
  `divine-iac-coreconfig`). Manual local `docker buildx` pushes and direct overlay edits
  are not supported and cause image drift.
- `docs/runbooks/production-deploy.md` — current production deploy runbook, ArgoCD
  sync ordering (schema before application services), and post-deploy verification.
- `database/README.md` — first-party `funnelcake-migrate` usage, environment variables,
  and migration ledger (`nostr.funnelcake_schema_migrations`).
- `docs/migration-best-practices.md` — multi-replica ClickHouse migration patterns
  (including why per-statement `SETTINGS` clauses are required instead of standalone `SET`).

## Key Current Facts (as of 2026-11-24)

- **Production ClickHouse is self-hosted.** Production moved from ClickHouse Cloud to a
  self-hosted `Replicated` ClickHouse cluster on Kubernetes on 2026-11-24.
- **Migrations use `funnelcake-migrate` over HTTP (port 8123).** Schema migrations run as
  an ArgoCD sync hook using `funnelcake-migrate` with HTTP(S) `CLICKHOUSE_URL` (port 8123)
  and `FUNNELCAKE_MIGRATIONS_TARGET=replicated`.
- **Retired paths (do not use):**
  - Manual `kubectl apply` of `golang-migrate` / `database/entrypoint.sh` migration Jobs.
  - ClickHouse Cloud native-TLS mode (`CLICKHOUSE_URL` forcing port 9440) and the legacy
    `schema_migrations` table.
  - Manual local `docker buildx` builds or `sed` edits directly against deployment overlays.
