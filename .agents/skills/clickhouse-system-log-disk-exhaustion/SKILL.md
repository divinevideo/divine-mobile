---
name: clickhouse-system-log-disk-exhaustion
description: |
  Fix ClickHouse "Code: 243 Cannot reserve 1.00 MiB, not enough space" errors caused by
  system log tables (text_log, trace_log, processors_profile_log, query_log) filling the disk.
  Use when: (1) ClickHouse inserts fail with NOT_ENOUGH_SPACE error, (2) Disk is 100% full
  but application tables are small, (3) system database is 10-100x larger than user databases,
  (4) Sentry shows batch insert/commit failures across multiple tables simultaneously.
  Covers self-hosted ClickHouse (Altinity operator on K8s) system log cleanup and TTL
  configuration.
author: Claude Code
version: 2.0.0
date: 2026-11-25
---

# ClickHouse System Log Disk Exhaustion

## Problem
ClickHouse internal system log tables can fill a replica's disk if generated logs
outpace retention cleanup or obsolete log tables accumulate. This can cause
`NOT_ENOUGH_SPACE` failures across unrelated application tables. Check the actual
log retention configuration for the target deployment.

## Context / Trigger Conditions
- **Error message**: `Code: 243. DB::Exception: Cannot reserve 1.00 MiB, not enough space. (NOT_ENOUGH_SPACE)`
- **Symptoms**: All writes fail simultaneously across multiple tables; reads may still work
- **Sentry pattern**: Multiple batch insert/commit failure issues appearing at the same time
- **Diagnosis query**: `SELECT database, formatReadableSize(sum(total_bytes)) FROM system.tables WHERE total_bytes > 0 GROUP BY database ORDER BY sum(total_bytes) DESC`
  - Compare local disk pressure with the sizes of the system log tables before attributing the failure to them.

## Solution

### Diagnosis
```sql
-- Check database sizes
SELECT database, formatReadableSize(sum(total_bytes)) as size
FROM system.tables WHERE total_bytes > 0
GROUP BY database ORDER BY sum(total_bytes) DESC;

-- Find biggest system tables
SELECT name, formatReadableSize(total_bytes) as size
FROM system.tables
WHERE database = 'system' AND total_bytes > 100000000
ORDER BY total_bytes DESC LIMIT 20;

-- Check disk usage
SELECT name, formatReadableSize(free_space) as free, formatReadableSize(total_space) as total
FROM system.disks WHERE name = 'default';
```

### Cleanup on self-hosted ClickHouse

Run the diagnostic queries on the affected replicas. Before removing logs, confirm
the target cluster, replica, table, data retention requirements, and cleanup
authorization with the platform owner.

If DDL fails because the disk is full, work with the platform owner to restore
disk capacity before issuing further DDL.

System log tables often partition by month. Inspect the affected table's active
partitions before choosing any to remove:

```sql
SELECT partition, formatReadableSize(sum(bytes_on_disk)) AS size
FROM system.parts
WHERE database = 'system' AND table = 'text_log' AND active
GROUP BY partition ORDER BY partition;
```

Prefer dropping only the oldest partitions approved for removal. Use SQL against
the affected replica so ClickHouse manages the table metadata and files.

### Retention

For operator-managed clusters, check the server's log configuration and compare
it with `SHOW CREATE TABLE` on the affected replica. Make persistent retention
changes through the owning GitOps repository.

Funnelcake production's retention is configured in
`divine-iac-coreconfig/k8s/applications/clickhouse-candidate/base/cluster.yaml`.
It sets one day for `text_log` and `trace_log`, three days for `query_log` and
several other logs, and disables `processors_profile_log`.

## Verification
```sql
-- After cleanup, verify disk usage
SELECT formatReadableSize(free_space) FROM system.disks WHERE name = 'default';

-- Check whether system log storage decreased
SELECT database, formatReadableSize(sum(total_bytes)) as size
FROM system.tables WHERE total_bytes > 0 GROUP BY database;

```

Confirm normal application writes have recovered in service metrics or logs.

## References
- ClickHouse system tables documentation: https://clickhouse.com/docs/en/operations/system-tables
- ClickHouse TTL documentation: https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/mergetree#table_engine-mergetree-ttl
