# Move diagnostic sanitization off the main isolate (#7080) — design

**Problem.** `BugReportService.sanitizeSensitiveData` runs synchronously on the main
isolate over up to `BugReportConfig.maxLogEntries` (5000) log entries, sanitizing
messages, errors, and stack traces. #6909 bounded typed fields, but the log corpus is
app-generated and the largest uncapped sanitization workload, so submitting a report
can still stall the UI.

**Serializability (verified).** `LogEntry` is an immutable data class containing
`String`/`DateTime`/enum fields (`error`/`stackTrace` are Strings). `BugReportData`
also carries dynamic diagnostic maps, so the real-`compute` test sends the current
production shapes—nested device data, populated logs, and error counts—across the
boundary rather than assuming every future dynamic value is sendable. Established
codebase pattern: `compute(_topLevelFn, arg)` —
`signer_factory._verifyEventSignature`, `seed_data_preload_service._decodeBundle`.

## Approved design (mirrors `signer_factory`)

1. **Move** the report-sanitize graph to top-level pure functions:
   `sanitizeBugReportData(BugReportData) -> BugReportData` plus the map/list/
   device-info/error-count helpers it needs, all bottoming out in the existing
   top-level `sanitizeDiagnosticText`. Redaction logic is relocated verbatim (single
   implementation, no duplication); no logging inside the isolate entrypoint.
2. **Keep** the sync instance `sanitizeSensitiveData(data)` as a one-line delegate to
   `sanitizeBugReportData`, preserving behavior/idempotency and the existing ~15 sync
   redaction tests (the deterministic oracle). Keep instance `_sanitizeString` for the
   log-export callback path.
3. **Add** an injectable seam, exactly like `signer_factory._verifyOffMain`:
   `_sanitizeOffMain` field defaulting to `(d) => compute(sanitizeBugReportData, d)`,
   settable via a constructor param so tests can force isolate-spawn failure.
4. **Fallback (privacy-critical).** The production collection path becomes:
   ```dart
   try { return await _sanitizeOffMain(reportData); }
   on Object { return sanitizeBugReportData(reportData); } // inline
   ```
   If the worker isolate cannot spawn, sanitize inline rather than transmit
   unsanitized diagnostics. Sanitization must never be skipped — this serves the AC
   "keep public-support payloads sanitized before public projections."
5. **Build the bounded Zendesk log summary through `compute` too.** Its
   defense-in-depth sanitizer runs over each formatted entry before truncation, so
   leaving summary construction in `BugReportCubit` would retain a pathological
   main-isolate scan for one oversized entry. Await an async summary seam before
   submission and use the same privacy-preserving inline fallback if its worker cannot
   start.

On Flutter web, `compute` runs on the current event loop rather than a separate
isolate. The off-main performance benefit therefore applies to the native builds; the
same API preserves behavior on web.

## Tests (TDD)

- Behavior/idempotency/redaction: the existing sync `sanitizeSensitiveData` tests
  (now exercising the moved top-level fn via the delegate) must stay green.
- The seam's job: inject a throwing `_sanitizeOffMain`, assert the report still comes
  back fully sanitized (the inline fallback). Mutation-checkable.
- Real-`compute` happy-path tests proving the populated report and summary
  serialization shapes end-to-end.
- The Cubit awaits asynchronous summary construction before submission.
- `flutter analyze` + the bug-report/privacy tests.

## Files

`mobile/lib/services/bug_report_service.dart` (extract + delegate + seam + fallback),
`mobile/lib/services/bug_report_log_summary.dart` and
`mobile/lib/blocs/bug_report/bug_report_cubit.dart` (off-main summary), plus their
focused tests.
