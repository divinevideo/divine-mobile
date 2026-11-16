# App cache index audit

This audit covers `db_client`'s encrypted event/profile database and
`cache_sync`'s JSON snapshot database. Query plans and timings below use
synthetic data, not a production account database. Timings are local diagnostic
measurements, not device-wide latency guarantees.

## Verified-event startup seed: add a partial index

The seed selects `id, sig` where `signature_verified = 1`, ordered by
`created_at DESC`, limited to 50,000. Since schema v33, older cached events are
correctly unverified. The general creation-time index has to visit unchecked
event rows until it finds enough matches, potentially reading the whole
cache even when returning no results.

With 187,049 synthetic encrypted events and no verified matches, the real
Drift schema took 6,507 ms. A partial index on `(created_at DESC) WHERE
signature_verified = 1` reduced that query to below 1 ms. `EXPLAIN QUERY PLAN`
changed from `idx_event_created_at` to the partial index. Schema v35 ships this
index without changing verification flags or clearing events.

## Snapshot eviction: another useful index

`CacheDaoImpl.evictOldest` selects `cache_key, length(payload)` in `cached_at`
order. Version 1 has only the key primary index, so it reads payloads and
builds a temporary sort. A candidate index is:

```sql
CREATE INDEX idx_cache_entries_eviction
ON cache_entries (cached_at, cache_key, length(payload));
```

On 6,000 synthetic 8 KiB payloads (about 48 MB), selection fell from 22.5 ms to
2.0 ms. The candidate covered the selection and removed the temporary sort;
its bytecode no longer read payload columns from the table. It stores lengths,
not duplicate JSON payloads. It adds work and storage on every snapshot write.
A separate `cache_sync` versioned migration should validate real eviction
workloads before shipping it. Eviction still materializes all entry metadata;
this index alone does not make that operation bounded.

## Existing coverage and queries an ordinary index cannot fix

| Operation | Current coverage / conclusion |
| --- | --- |
| Event expiry | `idx_event_expire_at` supports both NULL and timestamp branches. |
| Orphan video-metrics cleanup | The metrics and event primary-key indexes support the membership check. |
| Author/kind feeds and replaceable-event lookup | Existing composite indexes cover their equality prefixes and recency. |
| Profile and snapshot key lookup | Their primary-key indexes already cover exact lookup. |
| Notification timeline | Existing owner/timestamp index matches the account-scoped timeline. |
| Profile row cap | Sorts a bounded 5,000-row cache after cleanup; lower priority than the full event scan. |
| Cached profile substring search | `instr` and normalized-field expressions do not become substring seeks with a plain name index. |
| Cached video text search | `content LIKE '%query%'` scans candidate event content despite the kind/recency index. A plain content index cannot seek arbitrary substrings. |
| Snapshot prefix deletion | `LIKE ? || '%'` and LIKE's collation prevent an ordinary key index from solving the scan. Changing the bound pattern/collation needs semantic tests. |

## Search sequencing matters independently of indexes

At the audited revision, video search awaited local substring search before
starting REST, then awaited REST before starting relay search. People search
also waited for cached profiles before its REST phase. Slow local work can
therefore delay a healthy remote response and other readers sharing the event
connection. Starting independent sources concurrently and merging progressive
results is a separate search-flow fix; adding more B-tree indexes cannot replace
that coordination.

## Startup log boundaries

`StartupTiming` records fixed stage labels, elapsed milliseconds and success /
failure, never operation values or exception contents. `databaseRuntime` loads
the cipher runtime, `databaseKey` resolves the key, `databaseMigration` classifies
and migrates the file's encryption format, and `databaseProbe` includes the
reactive Drift open (schema migrations and startup cleanup). `databaseOpen`
measures the separate device-lifetime connection's first lazy open, once even
when queries arrive together. `accountRestore`, `accountCleanup` and
`legacyRowClaim` separate authentication restoration from its storage gates.
