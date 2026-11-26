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

- [Deployment pipeline](https://github.com/divinevideo/divine-funnelcake/blob/main/docs/DEPLOYMENT.md) covers staging delivery and production promotion. [CI image-push gating](https://github.com/divinevideo/divine-funnelcake/blob/main/docs/operations/ci-push-gating.md) covers opt-in POC images.
- [Production deploy runbook](https://github.com/divinevideo/divine-funnelcake/blob/main/docs/runbooks/production-deploy.md) covers schema-first ArgoCD sync and post-deploy verification.
- [Migrator reference](https://github.com/divinevideo/divine-funnelcake/blob/main/database/README.md) documents supported `funnelcake-migrate` invocations, configuration, and the active migration ledger.
- [Migration best practices](https://github.com/divinevideo/divine-funnelcake/blob/main/docs/migration-best-practices.md) covers multi-replica migrations and per-statement `SETTINGS`.

Use these sources if an older doc refers back here for a manual Job template.

## Key Current Facts (as of 2026-11-24)

- **Production ClickHouse is self-hosted.** Production moved from ClickHouse Cloud to a
  self-hosted `Replicated` ClickHouse cluster on Kubernetes on 2026-11-24.
- **Production migrations use `funnelcake-migrate` over HTTP(S).** The ArgoCD sync hook
  uses the environment's configured `CLICKHOUSE_URL` and
  `FUNNELCAKE_MIGRATIONS_TARGET=replicated`.
- **Single-statement `RENAME TABLE` still required.** Self-hosted `Replicated` databases in
  production also reject multi-table renames in a single query (Code 48). Use one
  rename per statement and review the non-atomic interval for serving tables.
- **Active migration ledger.** Check `nostr.funnelcake_schema_migrations` for migration
  progress. The migrator uses the legacy `schema_migrations` table only for bootstrap.
- **Retired paths (do not use):**
  - Manual `kubectl apply` of `golang-migrate` / `database/entrypoint.sh` migration Jobs.
  - ClickHouse Cloud native-TLS mode (`CLICKHOUSE_URL` forcing port 9440).
  - Manual local `docker buildx` builds or `sed` edits directly against deployment overlays.
