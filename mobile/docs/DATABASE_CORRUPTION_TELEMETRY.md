# Local database corruption: what is reported, and how often

Status: Current
Validated against: `mobile/lib/services/database_corruption_service.dart`,
`mobile/lib/services/database_encryption_bootstrap.dart`,
`mobile/lib/services/crash_reporting_service.dart` and the Crashlytics
BigQuery export on 2026-09-14.

Runtime SQLite corruption is recovered automatically (#6108, #6897): the
first statement that fails with `SQLITE_CORRUPT` / `SQLITE_NOTADB` flips
`DatabaseCorruptionService.isCorrupted`, the user is asked to restart, and
the next launch salvages the local-only tables into a fresh database. That
means a corrupt database is a **state the app handles**, not a defect — so
Crashlytics should carry exactly one report per incident, and the rate of
those reports is the number to watch. This page names the reports, gives
the query that turns them into a weekly rate, and records the baseline that
rate was measured at, so a later week can be compared against something
(#7507).

## The three deliberate reports

Each is filed once per incident, with a stable blame frame, so it groups into
one Crashlytics issue whose message names the variant.

| Reason (Crashlytics subtitle) | Exception | Filed by | Means |
|---|---|---|---|
| `DB startup recovery` | `DatabaseRecoveryEvent: <how>` | `DatabaseEncryptionBootstrap._reportRecovery` | The bootstrap recovered the database before opening it. `<how>` is `salvaged local-only data into a fresh DB`, or `backed up + recreated (<reason>)` with `missing`, `key loss`, or `corrupt and unsalvageable (key still valid)`. **This is the recovery counter.** |
| `Runtime database corruption` | `DatabaseCorruptionEvent: SqliteException(<code>): …` | `DatabaseCorruptionService.report` | A statement failed mid-session. Recovery is scheduled; the same install normally shows a `DB startup recovery` a restart later. The message carries the result code and the failing SQL, never its bound parameters. |
| `DatabaseEncryptionBootstrap.resolveCipherKey failed` | whatever the bootstrap threw | `app_bootstrap.recordDatabaseBootstrapFailure` | The bootstrap itself could not settle the database. Only part of these are corruption: `DatabaseUnreadableError`, `DatabaseHotJournalRecoveryError` and a raw `SqliteException` are; `DatabaseCipherStorageUnavailableException` (keystore locked) and `DatabaseCipherUnavailableError` (build misconfiguration) are not. |

Everything else that mentions a corruption result code is an **echo**: the
same dead file, seen from whichever query ran next. Before this was gated,
one incident produced tens of uncaught-zone reports per session (`Error
thrown runZonedGuarded`), one group per bloc that wrapped the failure in
`Reportable`, and one per service that caught its own query
(`DmReactionRetryService`, `NotificationRefreshCoordinator`,
`OutgoingDmRetryService`, the drafts loader). `CrashReportingService` now
asks `DatabaseCorruptionService.echoesReportedCorruption` before forwarding
any non-fatal, so on a build that carries that gate the echo rows below
should read zero. If they do not, the gate has a hole — look at the reason
column of the surviving rows to find which sink bypasses the reporter.

Two bootstrap outcomes do **not** file a `DatabaseRecoveryEvent`, and both
still count in the rate through the bootstrap-failure row:

- The bootstrap's repair-and-retry (`shouldRepairLocalDatabaseCacheAfterBootstrapError`
  → back up and recreate → retry) recovers without a recovery event; its
  incident is the bootstrap failure recorded just before the repair.
- `DatabaseUnreadableError` fails closed and offers a manual reset, so there
  is no automatic recovery to count.

## Reading the rate

The Crashlytics BigQuery export (`openvine-co.firebase_crashlytics`) is the
authoritative source: the console groups by issue, and the issue ids of the
echo groups change with every release because they key on the statement
text, while the export lets one query classify by message. Run it with an
account authorized for the Crashlytics export; the tables are partitioned by
`event_timestamp`, so always bound the interval.

```sql
-- Weekly corruption signals per install, one row per week and signal.
-- Swap co_openvine_app_IOS for co_openvine_app_ANDROID for the other store.
WITH e AS (
  SELECT
    DATE_TRUNC(DATE(event_timestamp), WEEK(MONDAY)) AS week,
    installation_uuid,
    exceptions[SAFE_OFFSET(0)].exception_message AS msg
  FROM `openvine-co.firebase_crashlytics.co_openvine_app_IOS`
  WHERE event_timestamp >= TIMESTAMP('2026-08-17')
    AND error_type = 'NON_FATAL'
),
c AS (
  SELECT week, installation_uuid,
    CASE
      WHEN msg LIKE 'DatabaseRecoveryEvent:%'
        THEN 'A recovery'
      WHEN msg LIKE 'DatabaseCorruptionEvent:%'
        OR msg LIKE '%Error thrown Runtime database corruption%'
        THEN 'B runtime detection'
      WHEN msg LIKE '%Error thrown DatabaseEncryptionBootstrap.resolveCipherKey failed%'
        THEN 'C bootstrap failure'
      WHEN REGEXP_CONTAINS(msg, r'SqliteException\((26|11|267|523|779|1035|1291|1547)\)')
        THEN CONCAT('D echo: ', REGEXP_EXTRACT(msg, r'Error thrown ([^.]{0,60})'))
    END AS signal
  FROM e
)
SELECT week, signal,
  COUNT(*) AS events,
  COUNT(DISTINCT installation_uuid) AS installs
FROM c WHERE signal IS NOT NULL
GROUP BY week, signal ORDER BY week, signal;
```

The result codes in the regex are `SQLITE_CORRUPT` (11) and `SQLITE_NOTADB`
(26) with their extended forms; the low byte carries the primary code, which
is also how `indicatesDatabaseCorruption` classifies in `db_client`. The
`B` branch matches both the current `DatabaseCorruptionEvent` wrapper and the
raw `SqliteException` that builds before it filed under the same reason.

Absolute counts follow the install base, so compare the **share of weekly
active installs**. The analytics export gives the denominator:

```sql
SELECT platform,
  DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week,
  COUNT(DISTINCT user_pseudo_id) AS weekly_active
FROM `openvine-co.analytics_<property_id>.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20260817' AND '20260913'
  AND platform IN ('IOS', 'ANDROID')
GROUP BY platform, week ORDER BY platform, week;
```

Two populations, two caveats. Crashlytics counts installs and is on for every
release build; analytics counts pseudonymous users and can be switched off in
Settings since 1.0.22 (#8795), so the denominator undercounts from then on
and the share reads slightly high. And the Crashlytics `process_state` column
is not usable for these events: it reads `BACKGROUND` on sessions whose
breadcrumbs show the user navigating the feed, so it says nothing about
background launches. Custom keys are likewise the session's final values,
not the values at the time of the event.

Without BigQuery, the console's trend chart on the `DB startup recovery`
issue (`DatabaseEncryptionBootstrap._reportRecovery`) shows events and users
per day; it just cannot be normalised or split by variant without opening
each one.

## Baseline (measured 2026-09-14)

Weeks start on Monday. Installs are distinct `installation_uuid`; the share
divides recovery installs by that week's weekly-active count. The echo column
sums every non-deliberate signal and is what the reporter gate removes on
builds that carry it; builds from 1.0.22 already dropped the bloc-observer
share, but most sessions in these weeks were still on 1.0.20.

**iOS**

| Week | Recoveries (installs) | Runtime detections (installs) | Bootstrap failures (installs) | Echo events | Weekly active | Recovery share |
|---|---|---|---|---|---|---|
| 2026-08-17 | 36 | 14 | 16 | 609 | 15 161 | 0.24 % |
| 2026-08-24 | 56 | 24 | 13 | 969 | 15 217 | 0.37 % |
| 2026-08-31 | 39 | 11 | 9 | 544 | 9 851 | 0.40 % |
| 2026-09-07 | 28 | 13 | 17 | 360 | 8 350 | 0.34 % |

**Android**

| Week | Recoveries (installs) | Runtime detections (installs) | Bootstrap failures (installs) | Echo events | Weekly active | Recovery share |
|---|---|---|---|---|---|---|
| 2026-08-17 | 31 | 2 | 3 | 153 | 9 936 | 0.31 % |
| 2026-08-24 | 41 | 9 | 4 | 327 | 7 459 | 0.55 % |
| 2026-08-31 | 31 | 3 | 3 | 341 | 5 172 | 0.60 % |
| 2026-09-07 | 20 | 4 | 2 | 224 | 4 114 | 0.49 % |

Over the same four weeks the iOS recoveries split 125 salvaged, 25 recreated
because the salvage failed under a still-valid key, and 12 recreated because
the stored key was missing; the missing-key row is a keystore question, not
a corruption one, and belongs in its own issue if it grows.

So the baseline is **roughly 0.3–0.6 % of weekly-active installs running a
startup recovery in any given week**, higher on Android than iOS, with
runtime detections at roughly a third of the recovery count on iOS and a
tenth on Android — most corruption is caught by the startup probe, not
mid-session. A week that doubles its platform's share, or a build whose first
full week lands above 1 %, is worth an issue before anything else changes.

The four days the issue was filed on (2026-08-12 to 2026-08-15) sat on a
much smaller install base and read 12 users; the shares above are the
comparable number, not that count.
