# Startup database performance, 17 November 2026

Build 1.0.30+916 spent 174,251 ms in `databaseProbe` before its first frame.
A reopening spent 4,486 ms in that probe and another 5,413 ms opening the
same database for the app. The probe includes Drift schema upgrades and
startup cleanup; the field logs do not time individual SQL statements.

## Reproduction and fix

The opt-in benchmark uses 200,000 synthetic 2 KiB events, matching metrics,
and 5,000 synthetic 8 KiB profiles, in an approximately 970 MB encrypted file.
It creates the historical v34 index layout before exercising the upgrade.
No real account data is used.

| Local database open | Historical v35 code before profile preflight | v36 cache replacement and profile preflight |
| --- | ---: | ---: |
| Upgrade open | 12,121 ms | 36 ms |
| Next open | 1,260 ms | 20 ms |

These are host diagnostic runs, under varying machine load, not device-wide
startup guarantees or proof that all 174 seconds in the field were index
creation. The structural difference is tested independently of wall time:
v36 renames the old event/metrics pair and indexes empty replacements, without
reading or copying the retired payloads. Keeping their existing indexes attached
avoids freeing their large B-trees during startup. Durable tables stay in place.

The profile-cap query was another repeated cost, including when no rows needed
eviction. A covering primary-key overflow check now skips that query when the
cache is already within the cap. The regression test explains the actual
preflight query and verifies it uses a covering index.

Retirement starts after the first frame and startup settling. It deletes at
most 250 old rows per transaction, metrics first, checks foreground/feed-idle
state between batches, and yields between short passes. Cleanup resumes from
remaining rows on later launches. Only empty old tables are dropped. There is
no launch-time VACUUM; freed pages are reusable, so the allocated file size need
not shrink immediately.

## Encryption comparison

Production encryption is unchanged. The same smaller 20,000-event benchmark
was also run with and without a key, using the same SQLite3MultipleCiphers
runtime and schema:

| Synthetic fixture | Upgrade open | Next open | Bulk fixture insertion |
| --- | ---: | ---: | ---: |
| Encrypted, approximately 137 MB | 112 ms | 158 ms | 12,977 ms |
| Unencrypted, approximately 137 MB | 151 ms | 257 ms | 6,007 ms |

Single runs under variable load do not isolate encryption overhead or establish
a speed ratio. They show no consistent open-time benefit from disabling
protection after the avoidable scans are removed. Bulk writes warrant a more
controlled device benchmark before changing the public-cache architecture.

The native database contains more private data than DMs: drafts, pending
uploads/actions, outgoing messages and retained signed personal events also
need protection. SQLite3MultipleCiphers selects encryption per database file,
so a public-cache/durable-data split is a separate storage design. Some other
stores, including the JSON snapshot cache, are already separate. See
[the cipher documentation](https://utelle.github.io/SQLite3MultipleCiphers/)
and [the existing at-rest design](sqlcipher_at_rest_plan.md).

## Other database costs to investigate

The [cache index audit](CACHE_INDEX_AUDIT.md) identifies existing cases:

- Local substring searches can delay network search because independent
  sources are started sequentially. Changing the sequencing is more relevant
  than adding a B-tree index to a substring predicate.
- Snapshot eviction reads payload lengths and sorts entry metadata. Bound the
  work and measure projection costs before adding an index to an existing cache.
- Active event expiry and metrics-orphan sweeps still run on database open.
  Their cost on long-lived or expired caches needs measurement independently
  of the one-time v36 replacement.
- Retention runs at particular lifecycle boundaries, so declared TTLs and caps
  are not evidence that every long-running session stays small.

Do not infer that every large table is disposable. DM history and its dedup
ledger have different retention requirements; drafts, queues and signed retry
intent cannot be reconstructed by clearing an event cache.

## Reproduce

From the mobile directory, using the repository's Flutter 3.47.9:

```sh
flutter test --no-pub packages/db_client/test/benchmarks/event_cache_upgrade_benchmark.dart
flutter test --no-pub packages/db_client/test/benchmarks/event_cache_upgrade_benchmark.dart --dart-define=BASELINE_V35=true
flutter test --no-pub packages/db_client/test/benchmarks/event_cache_upgrade_benchmark.dart --dart-define=CACHE_BENCHMARK_EVENT_COUNT=20000 --dart-define=ENCRYPTED_CACHE=false
```

The recorded historical baseline predates the profile-cap preflight.
`BASELINE_V35=true` selects the old index migration but retains the current
profile DAO, so that command isolates the index-build cost rather than replaying
every operation in the old release byte-for-byte.

The benchmark lives under the test tree for access to native test helpers but
has no `_test.dart` suffix, so ordinary directory test discovery does not run
the large fixture. Invoke it explicitly as shown.

## Verification limits

The pre-existing plaintext-to-encrypted bootstrap migration is unchanged; it
can still copy a plaintext database before Drift opens it. This fix addresses
the encrypted-cache upgrade path observed in TestFlight, not that older path.
Real-device end-to-end startup remains to be validated on the release build.

The repository CI analysis scope is `lib test integration_test tools` on Flutter
3.47.9. An earlier unscoped run on the older locally selected Flutter 3.47.2 also
included the unchanged manual integration script and reported a missing
`allowVideoReuse` argument in `integration_test_manual/upload_publish_real_e2e_test.dart`,
plus existing script/lint configuration notices. Those paths were not changed;
the CI-scope analysis and database-package analysis passed with Flutter 3.47.9.
