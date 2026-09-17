# lnav log formats

[lnav](https://lnav.org) format definitions for the two Divine log streams
that carry enough structure to be worth parsing. `brew install lnav`, then:

```bash
cd mobile && mise run lnav_setup     # or, from the repo root: lnav -i scripts/lnav/*.json
```

lnav's value here is not prettier output — it is merging several sources into
one time-ordered view and letting you query them with SQL. Everything below is
a recipe that works once the formats are installed.

## `divine_export_log` — bug-report log exports

Parses `openvine_full_logs_*.txt`, the attachment produced by
`LogCaptureService.getAllLogsAsText()`:

```
[2026-09-02T08:29:26.100000Z] [ERROR] [DmRepository] relay: publish failed | Error: TimeoutException
```

`logger` (the `name:` argument) and `category` (the `LogCategory` enum name,
lowercase, or `GENERAL`) become queryable columns:

```bash
lnav openvine_full_logs_*.txt
```

```sql
;SELECT category, count(*) FROM divine_export_log
 WHERE log_level >= 'warning' GROUP BY category ORDER BY 2 DESC;
```

Full npubs and 64-char hex ids are highlighted; the `nsec`/`ncryptsec` pattern
is a tripwire rather than a routine sight, because exports redact secrets
before write (`_sanitizeString` in `bug_report_service.dart`). Highlighting
works precisely *because* we never truncate ids — a shortened id would not
match, which is the same property that makes them greppable against relay and
funnelcake rows.

The timestamp accepts a trailing `Z` **and** its absence, so exports from
builds shipped before #8520 still parse. The two are not equivalent:

- **With `Z`** the suffix is parsed as a zone (`%z`), so the line is read as
  UTC and converted to your display zone. That conversion is what makes a
  merge against relay or Postgres output line up.
- **Without `Z`** the line carries no zone and is read as a bare wall clock,
  displayed exactly as written. That was the device's local time, so it sits
  off a UTC-aware source by the difference between the reporter's offset and
  yours.

Check the app version before trusting a cross-source timeline on an old
export. One caveat: lnav locks a timestamp format per file, so in a file that
mixed both shapes the non-matching lines fold into the preceding message's
timestamp instead of parsing their own. A real export comes from one build
and does not mix; both shapes were verified to parse correctly on their own.

## `gha_log` — GitHub Actions job logs

Parses `gh run view <id> --log` and `--log-failed`. The `job` column is what
makes this worth doing: every `Tests (shard N/8)` log merges into one
time-ordered view instead of eight files read in sequence.

```bash
gh run view <run-id> --log > /tmp/ci.log && lnav /tmp/ci.log
```

Press `e` / `Shift+E` to jump between errors — the runner's own `##[error]`
and `##[warning]` markers are mapped to lnav levels. Step timings:

```sql
;SELECT step, count(*) AS lines,
        cast((julianday(max(log_time)) - julianday(min(log_time))) * 86400 AS int) AS secs
   FROM gha_log GROUP BY step ORDER BY secs DESC LIMIT 10;
```

Note the ratchet scripts in the `Guards` job emit free-form text with
no `::error` annotations, so their failures stay at `info`. Adding annotations
there would improve the GitHub UI and this view together.

## Merging local_stack against the app

lnav auto-detects Postgres, Redis, nginx and Rust tracing formats, so dumping
each service to its own file gets you a merged timeline for free — the same job
`local_stack/merge_logs.py` does for E2E runs, without the JSONL step:

```bash
cd local_stack
for s in keycast funnelcake-relay funnelcake-api blossom; do
  docker compose logs --no-log-prefix "$s" > "/tmp/$s.log"
done
lnav /tmp/*.log /path/to/openvine_full_logs_*.txt
```

## Known gaps

- **`adb logcat`**: lnav ships a logcat format, but it only matches the default
  `threadtime` output. `local_stack/profile.sh` passes `-v UTC -v year`, which
  falls back to `generic_log` and loses the `tag` / `pid` / `tid` columns. Drop
  those flags if you want the structured view.
- **`LogEntry.toFormattedString()`** — the inline summary posted to Zendesk —
  uses a different shape from the export (`[CATEGORY]` bracketed, `(name)` in
  parentheses). Not covered here; the `.txt` attachment is the larger artifact.
- **The console format** `[HH:MM:SS.mmm] [CAT] msg` carries no date and no
  level, so there is little for lnav to extract. Read it live instead.
- **Test output**: we use VGV's human-readable reporter, not
  `--reporter json`, so there is no structure to parse.
