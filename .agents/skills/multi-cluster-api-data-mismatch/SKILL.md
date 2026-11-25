---
name: multi-cluster-api-data-mismatch
description: |
  Debug "API returns data that doesn't exist in database" when multiple Kubernetes
  clusters exist (production, staging, POC). Use when: (1) REST API returns records
  that direct database queries can't find, (2) Data counts match approximately but
  specific records don't overlap, (3) kubectl context points to a different cluster
  than the one serving the public domain, (4) ClickHouse/Postgres queries return
  stale or different data than the API, (5) "completely different datasets" despite
  same table names and schemas. Root cause: querying the wrong cluster's database.
author: Claude Code
version: 1.1.0
date: 2026-11-25
---

# Multi-Cluster API Data Mismatch

## Problem
When investigating why an API returns data that doesn't match direct database queries,
the root cause may be that your kubectl context points to a different cluster (e.g., POC)
than the one actually serving the public API (e.g., production). Both clusters have the
same schemas and similar data volumes, making the mismatch non-obvious.

## Context / Trigger Conditions
- API returns records that direct database queries (`kubectl exec ... clickhouse-client`)
  can't find
- Data counts are similar (e.g., both have ~20k records) but specific records differ
- You're debugging a data pipeline that "should work" but labels/counts never update
- Multiple kubectl contexts exist (production, staging, POC, test)
- The API response header shows `server: nginx` but no ingress exists in the current
  cluster's namespace

## Solution

### Step 1: Verify which cluster serves the domain
```bash
# Check DNS for the public API domain
dig relay.divine.video +short
# → 34.58.27.79

# Check your current cluster's gateway/ingress IP
kubectl get gateway -A  # or kubectl get ingress -A
# → 35.184.10.63  (different IP = different cluster!)
```

### Step 2: Check all available contexts
```bash
kubectl config get-contexts
# Look for production vs staging vs POC contexts
```

### Step 3: Switch to the correct cluster
```bash
kubectl config use-context <production-context-name>
```

### Step 4: Verify the database connection

Compare the serving workload's database environment bindings with the connection
references in its GitOps configuration. For Funnelcake, trace the
`CLICKHOUSE_URL` binding to its configured endpoint and verify the environment
and database name. Use Secret and ExternalSecret references for this comparison.
Inspect endpoint and database metadata through the approved read-only access
path if those details aren't visible in configuration.

## Verification
After switching to the correct cluster:
1. Re-run the same database query — the "missing" records should now appear
2. The latest timestamp in the database should match recent API activity
3. `kubectl get pods -n <namespace>` should show the same pods the API logs reference

## Key Indicators You're On the Wrong Cluster

| Symptom | Explanation |
|---------|-------------|
| API video count ~21k, DB count ~20k | Similar but not identical = different datasets |
| Latest DB record is days old | API is receiving writes on a different cluster |
| No ingress/gateway routes match the public domain | Traffic routes elsewhere |
| Different database cluster or endpoint per environment | Production vs POC/staging architecture |
| API pod logs show only health checks, no real traffic | Real traffic goes to another cluster |

## Example

If the production API returns a video missing from your ClickHouse query, use the
video's full hex event ID from the response as `EVENT_ID`. Set `PRODUCTION_CONTEXT`,
`CLICKHOUSE_NAMESPACE`, and `CLICKHOUSE_POD` to the verified production values:

```bash
kubectl --context "$PRODUCTION_CONTEXT" -n "$CLICKHOUSE_NAMESPACE" exec "$CLICKHOUSE_POD" -- \
  clickhouse-client --param_event_id="$EVENT_ID" \
  --query 'SELECT id, created_at FROM nostr.videos_by_id_data WHERE id = {event_id:FixedString(64)} LIMIT 1'
```

A returned row confirms the video exists in that cluster. Compare the result
with the same lookup in the cluster you originally queried.

## Notes
- Production and POC/staging run separate database instances (such as separate
  in-cluster ClickHouse deployments or managed services like Cloud SQL) — same
  schemas, different data
- The similar-but-not-identical record counts are the most misleading symptom
- Always check `max(created_at)` or `max(indexed_at)` — if it's days old on a
  live service, you're querying the wrong instance
