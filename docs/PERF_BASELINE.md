# Build / test / dev-loop performance baseline

Captured 2026-07-25 against `origin/main` @ `3152aee7f`. These are the numbers
every later change is measured against. Re-measure with the commands in
[How these were measured](#how-these-were-measured) before claiming a win.

---

## 1. CI (GitHub Actions)

### Job durations

p50/p90 over the 13 most recent successful `Mobile CI` runs (and, for the
non-`Mobile CI` rows, over the most recent successful runs of their own
workflow within the same window). `q_p50` is median queue wait — the gap
between job creation and job start.

| Job | Workflow | n | p50 | p90 | max | q_p50 |
|---|---|---:|---:|---:|---:|---:|
| Tests | Mobile CI | 13 | **599s** | 615s | 619s | 3s |
| Build & Deploy to app.divine.video | Web production deploy | 2 | 225s | 225s | 225s | 4s |
| Build Flutter Web Preview | PR preview build | 18 | 207s | 216s | 222s | 3s |
| Generated Files | Mobile CI | 13 | **198s** | 230s | 233s | 3s |
| Analyze | Mobile CI | 13 | 103s | 119s | 119s | 3s |
| build / build (`divine_ui` VGV) | Divine UI CI | 23 | 100s | 157s | 170s | 3s |
| Android Compile Check | service integration | 1 | 98s | 98s | 98s | 4s |
| Format | Mobile CI | 13 | 52s | 61s | 64s | 3s |
| Deploy PR Preview To Cloudflare | PR preview deploy | 21 | 36s | 41s | 42s | 3s |
| Detect App CI Scope | Mobile CI | 13 | **26s** | 29s | 30s | 3s |
| VGV Tag Gate | Mobile CI | 13 | 9s | 10s | 11s | 3s |
| ensure-linked-issue | PR Issue Link | 4 | 6s | 6s | 6s | 3s |
| mergeability | Mergeability Check | 20 | 4s | 6s | 7s | 3s |
| semantic-pull-request | semantic_pr | 19 | 4s | 6s | 6s | 3s |
| Mobile CI (gate) | Mobile CI | 13 | 3s | 4s | 4s | 3s |

**Queue wait is 3–4s across the board. CI is not queue-bound** — every second
of PR latency is real work.

### Critical path

Every `Mobile CI` job declares `needs: changes`, so the workflow's wall clock is:

```
Detect App CI Scope (26s)  ->  Tests (599s)   =  625s  (10m25s)
```

`Generated Files` (198s), `Analyze` (103s) and `Format` (52s) run in parallel
under that ceiling and do not set PR latency today. They *become* the ceiling
the moment `Tests` drops below them.

### Per-step breakdown (run 30142684388, a representative PR run)

**Detect App CI Scope — 26s total**

| Step | Time |
|---|---:|
| `actions/checkout@v4` (`fetch-depth: 0`) | **23s** |
| Detect whether app CI is required | 0s |

23 seconds of full-history clone to produce a changed-file list, at the head of
the critical path, on every run.

**Tests — 615s total**

| Step | Time |
|---|---:|
| Setup Flutter | 26s |
| `flutter pub get` | 10s |
| `dart pub global activate very_good_cli 1.3.0` | 9s |
| **`very_good test --optimization --concurrency=4`** | **558s** |

13,159 tests, 289 skipped, reported as `09:07` by the test runner.

**Generated Files — 224s total**

| Step | Time |
|---|---:|
| Setup Flutter | 17s |
| `flutter pub get` | 12s |
| **Verify native transport security** | **43s** |
| 22 ratchet / boundary guards (combined) | ~40s |
| **`dart run build_runner build`** | **101s** |
| Verify l10n generated files | 3s |

Of the 43s transport-security step, ~42s is `sudo apt-get update -qq` (28s) plus
`apt-get install libxml2-utils` (14s). `xmllint` is genuinely absent from the
`ubuntu-24.04` image; the actual guard runs in well under a second.

**Analyze — 119s total:** Setup Flutter 27s, `pub get` 12s, `flutter analyze` 71s.

**Format — 46s total:** Setup Flutter 17s, `pub get` 10s, `dart format` 11s.

### Cache behaviour

`subosito/flutter-action@v2` with `cache: true` is the only dependency cache and
it does hit — Setup Flutter costs 17–27s rather than a full SDK download.
`flutter pub get` at 10–12s is a warm pub cache. **No build_runner state is
cached anywhere**, so the 101s codegen verification starts from an empty build
graph on every run.

### Package workflows

`mobile/packages/` has 56 entries, and all 56 now have a package workflow
under `.github/workflows/` carrying `paths:` filters scoped to their own
package plus their own workflow file; since #3347 removed the orphaned
`nostr_apps` package there are no package-CI exceptions left in
`mobile/scripts/baseline/package_ci_exceptions.txt`. The two mobile
web build/deploy workflows are also path-filtered to `mobile/**`. The six
workflows without `paths:` filters are `mobile_ci.yaml`,
`mobile_service_integration_tests.yaml`, `semantic_pr.yaml`, `pr_issue_link.yml`,
`mergeability_check.yml`, and `mobile_pr_preview_deploy.yml` — all of which are
intentionally repo-wide. **There is no path-filter waste to recover here.**

`--coverage` is *not* collected in the `Mobile CI` Tests job. Package workflows
do collect it, and they consume it (`min_coverage` gates), so it is not waste.

---

## 2. Test suite

### Where the 558s goes

Per-test durations were recovered from the CI log by diffing consecutive
reporter timestamps in the `Run Flutter tests` step of run 30142684388.

| Slice | Time | Share |
|---|---:|---:|
| Top 10 tests | 178s | 35.4% |
| Top 25 tests | 192s | 38.3% |
| Top 50 tests | 210s | 41.8% |
| Top 100 tests | 240s | 47.8% |
| Top 200 tests | 281s | 55.9% |
| All 13,158 attributed | 502s | 100% |

The distribution is extremely top-heavy: **the ten slowest tests own a third of
the suite.**

Caveat on attribution: the merged VGV bundle and the 18
`skip_very_good_optimization` files interleave their reporter output, so a
single large gap can be an artifact of a tagged suite's VM startup rather than
a genuinely slow test. Every entry acted on below was re-confirmed by running
its file in isolation.

### Confirmed hot spots

| Test | File | Measured |
|---|---|---:|
| `cleans failed non-resumable transient stop-motion renders` | `test/services/upload_manager_from_draft_test.dart` | **62s** |
| `throws when upload finishes in failed state instead of returning a completed upload` | same file | **62s** |

Both drive `UploadManager` to retry exhaustion. `UploadRetryConfig` defaults to
`maxRetries: 5`, `initialDelay: 2s`, `backoffMultiplier: 2.0`, and
`UploadRetryPolicy` sleeps that backoff in real time: 2+4+8+16+32 = **62s per
test**. Isolated file run before the fix: **3m08s**.

### Structural cost: the merged bundle is single-threaded

CI runs `very_good test --optimization --concurrency=4` on a 4-vCPU runner. The
optimizer collapses every untagged test file into **one** `.test_optimizer.dart`
suite, i.e. one process. The 18 `skip_very_good_optimization` files run as
separate suites alongside it. So for the overwhelming majority of the 558s,
**one of the four available cores is doing the work** and the concurrency
setting has nothing to schedule.

### Existing test-hygiene ratchets (already in place, not regressions)

Counts below are as of the capture commit; the baseline files themselves are
authoritative for current ceilings.

The repo already freezes several of the things a perf audit would normally
flag, so these are *not* available wins:

- `scripts/baseline/future_delayed_test_counts.txt` — 1,119 executable
  `Future.delayed` call sites across 178 files under `test/`, frozen as
  shrink-only per-file numeric ceilings (epic #4337).
- `scripts/baseline/skip_test_ceilings.txt` — skipped-test count, shrink-only.
- `test/vgv_tag_baseline.txt` — 18 `skip_very_good_optimization` files,
  count may not increase.
- `scripts/baseline/test_unit_files.txt` — `test/unit/` frozen per-file.

Total explicit real-time sleep across `test/**` is **21.4s over 105
`Future.delayed(Duration(...))` call sites** — real, but an order of magnitude
smaller than the two 62s backoff waits above.

---

## 3. Dev loop (local)

Apple Silicon dev machine, Flutter 3.44.0 via `mise exec --`, run from `mobile/`.

| Operation | Time |
|---|---:|
| `flutter pub get`, warm workspace | 8.5s |
| `dart format --output=none lib test integration_test` (2708 files) | 44.5s |
| `flutter test <one 7-test service file>`, cold compile | 3m08s (18s after the backoff fix) |
| Full suite, `very_good test --optimization --concurrency=4` | 5m08s – 7m12s |

### Plain `flutter test` vs the optimized run

Plain `flutter test` compiles and spins a fresh isolate **per file**;
`very_good test --optimization` bundles the untagged files into one. Measured
head-to-head on an identical subset — 31 files / 277 tests, selected by
round-robin so it spans directories, same machine, back to back:

| Command | Wall | Tests |
|---|---:|---:|
| `flutter test --concurrency=4` | **60s** | 277 |
| `very_good test --optimization --concurrency=4` | **17s** | 277 |

**3.5x on identical work**, i.e. roughly 1.4s of per-file isolate and compile
overhead that the optimizer amortises away. `flutter test` is what
`CONTRIBUTING.md` currently tells developers to run.

The whole suite was not run to completion unoptimized; a partial run was
abandoned after a 50-minute sample reached 2,151 of ~13,159 tests, but that
sample was CPU-contended and is not a sound basis for a projection, so no
full-suite plain figure is claimed here.

### Full-suite run-to-run stability (local)

The optimized full suite is **not reliably green on this machine**, on
`main` as well as on branches. Across seven runs at
`--test-randomize-ordering-seed 12345`, one `origin/main`-equivalent run
failed on `personalEventCacheServiceProvider keeps queued events through
transient non-auth states` (a known CI-only flake, #6280); other runs failed on
`clips_library_bloc_test.dart` and `video_event_service_deduplication_test.dart`.
Each failing test passes in isolation. Treat a single red local full-suite run
as inconclusive and re-run before attributing it to a diff.

### Repo shape (verified, not assumed)

- `mobile/lib`: 1,400 Dart files
- `mobile/test`: 1,225 `*_test.dart` files, largest buckets `widgets/` (289),
  `services/` (280), `screens/` (185), `blocs/` (114)
- `mobile/packages`: 55 entries, **all** declared `resolution: workspace` under
  a single `workspace:` block in `mobile/pubspec.yaml` — one pub resolve for the
  whole monorepo, not 55. No win available here.

---

## Addendum 2026-09-17: the guard steps became the critical path

`Tests` dropped to ~219s when #6375 sharded it, which made `Generated Files`
the ceiling exactly as [Critical path](#critical-path) predicted. It then grew
every week. Median successful PR run of `Mobile CI`, by ISO week, from every
run between 2026-07-13 and 2026-09-17 (n ≈ 180–590 per week):

| Week | Run wall | Generated Files | Tests (per shard) | Guard steps in the job |
|---|---:|---:|---:|---:|
| 31 (after sharding) | 4.0m | 3.1m | 3.2m | 33 |
| 34 | 5.3m | 4.3m | 4.2m | 48 |
| 36 | 6.7m | 6.2m | 4.3m | 56 |
| 37 (Flutter 3.47.2, #8870) | 9.0m | 8.6m | 5.2m | 66 |
| 38 | 9.7m | 9.0m | 5.1m | 68 |

Queue wait stayed at 0s throughout; runners were unchanged. Inside the job,
setup (~40s) and the build_runner verification (~105s) were flat. The growth
was all guard steps: 45s in week 31, 398s in week 38. Two shapes account for
it:

- **20 Dart-AST detectors at 7–26s each.** Every one is its own `dart run`,
  and on the runner that is ~8s of VM start plus `package:analyzer` JIT before
  the first file is parsed. Measured locally on Apple Silicon: VM start plus
  analyzer JIT 2.9s; parsing every Dart file in the repo once (4,896 files,
  66 MB) 2.5s. The detectors were paying the fixed cost twenty times.
- **`check_async_safety_ceiling.sh` (#8870) at 67–80s.** A full second
  `dart analyze` of lib, test, integration_test and tools.

The 4-shard `Tests` legs grew 142s → 230s over the same window from test
volume alone (1,271 → 1,648 files, 14.7 → 19.8 MB), plus roughly 20% at the
Flutter 3.47.2 upgrade.

### What changed

- `Generated Files` now holds only the build_runner and gen-l10n
  verification (~2.5m expected).
- `Guards` runs every guard script through `mobile/scripts/ci/run_guards.sh`
  from the manifest `mobile/scripts/ci/guards.tsv`, four wide on the 4-vCPU
  runner, and replays each guard's output in manifest order. Locally, all 62
  guards at `--jobs 4`: **85s wall for 315s of summed guard time**.
- `Async Safety` is its own job, because it rewrites `analysis_options.yaml`
  in place while it runs.
- `Tests` runs 8 shards instead of 4. Byte-weighted, the heaviest 8-shard
  bucket carries 55% of the heaviest 4-shard bucket (3.2 MB vs 5.8 MB).

Expected `Mobile CI` wall after the change: bounded by `Web Bundle Size`
(~4.1m, a `flutter build web --release` that #9276 added the same week), with
`Tests`, `Guards` and `Generated Files` each below it. Re-measure with
`report_mobile_ci_run.py` and recalibrate `.github/ci-timing-budgets.json`
once a week of runs has landed.

Runner minutes are not a cost here: the repository is public, every
`runs-on` is a standard label, and the `timing` endpoint reports
`billable.total_ms = 0` on every run sampled. The 60-concurrent-job cap of
the org's plan is the only thing runner minutes spend.

Not done, and worth doing next: the detectors are all syntactic
(`parseString`) libraries that `test/tools/` already imports, so one Dart
entrypoint could parse each file once and hand the unit to every detector —
~200s of summed guard time would become ~15s. And retiring the async-safety
baseline to zero (#9118) retires its job.

## How these were measured

```bash
# CI job durations (p50/p90 across recent successful runs)
gh run list --limit 300 --json databaseId,name,conclusion
gh api /repos/divinevideo/divine-mobile/actions/runs/<id>/jobs \
  --jq '.jobs[] | "\(.name)\t\((.completed_at|fromdate)-(.started_at|fromdate))"'

# Per-step timings for one run
gh api /repos/divinevideo/divine-mobile/actions/runs/<id>/jobs \
  --jq '.jobs[] | select(.name=="Tests") | .steps[]
        | "\(.name)\t\((.completed_at|fromdate)-(.started_at|fromdate))s"'

# Per-test durations (diff consecutive reporter timestamps)
gh run view <id> --log --job=<test-job-id> | grep "Run Flutter tests"

# Local, CI-equivalent
cd mobile
mise exec -- very_good test --optimization --concurrency=4 \
  --exclude-tags integration --test-randomize-ordering-seed random

# Plain vs optimized on an identical subset
git ls-files 'test/**/*_test.dart' | sort | awk 'NR % 40 == 1' > /tmp/mobile-perf-subset.txt
mise exec -- flutter test --concurrency=4 --exclude-tags integration $(cat /tmp/mobile-perf-subset.txt)
mise exec -- very_good test --optimization --concurrency=4 --exclude-tags integration $(cat /tmp/mobile-perf-subset.txt)

# Local, one file
cd mobile && time mise exec -- flutter test <path> --reporter expanded
```
