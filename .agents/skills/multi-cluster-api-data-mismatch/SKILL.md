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
```bash
# Check what database the API actually connects to
kubectl get secret -n <namespace> <db-credentials> -o jsonpath='{.data.DATABASE_URL}' | base64 -d
# Production and non-production clusters connect to separate database instances (in-cluster or managed, e.g., Cloud SQL)
```

### Step 5: Also check for ExternalSecrets when updating secrets
If secrets are managed by ExternalSecrets operator:
```bash
# Check if ExternalSecrets manages the secret
kubectl get externalsecret -n <namespace>

# If yes, update the SOURCE (e.g., GCP Secret Manager), not the k8s secret
gcloud secrets versions add <secret-name> --project=<project> --data-file=-

# Force sync after updating
kubectl annotate externalsecret <name> -n <namespace> force-sync=$(date +%s) --overwrite

# Verify the k8s secret updated
kubectl get secret <name> -n <namespace> -o jsonpath='{.data.<key>}' | base64 -d
```

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
```bash
# You query POC ClickHouse and find 20,371 videos, latest from Feb 26
# But the API at relay.divine.video returns videos from today
# The API returns a video with d_tag that doesn't exist in your ClickHouse

# Fix: switch to production
kubectl config use-context <production-context-name>

# Now query the production ClickHouse service/pod in the production cluster
kubectl exec -n <namespace> <production-clickhouse-pod> -- \
  clickhouse-client --query "SELECT count(), max(created_at) FROM nostr.events"

# Query returns 21,221 videos with latest from minutes ago — matches the API
```

## Notes
- Production and POC/staging run separate database instances (such as separate
  in-cluster ClickHouse deployments or managed services like Cloud SQL) — same
  schemas, different data
- The similar-but-not-identical record counts are the most misleading symptom
- Always check `max(created_at)` or `max(indexed_at)` — if it's days old on a
  live service, you're querying the wrong instance
- When updating k8s secrets in production, check for ExternalSecrets first —
  manual `kubectl create secret` will be immediately overwritten by the operator
  syncing from GCP Secret Manager / AWS Secrets Manager / Vault
