# Move diagnostic sanitization off the main isolate (#7080) — design

**Problem.** `BugReportService.sanitizeSensitiveData` runs synchronously on the main
isolate over up to `BugReportConfig.maxLogEntries` (5000) log entries, sanitizing
messages, errors, and stack traces. #6909 bounded typed fields, but the log corpus is
app-generated and the largest uncapped sanitization workload, so submitting a report
can still stall the UI.

**Serializability (verified).** `BugReportData` and `LogEntry` are immutable data
classes of only `String`/`DateTime`/enum fields (`error`/`stackTrace` are Strings), so
they copy cleanly across a `compute()` boundary. Established codebase pattern:
`compute(_topLevelFn, arg)` — `signer_factory._verifyEventSignature`,
`seed_data_preload_service._decodeBundle`.

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

## Tests (TDD)

- Behavior/idempotency/redaction: the existing sync `sanitizeSensitiveData` tests
  (now exercising the moved top-level fn via the delegate) must stay green.
- The seam's job: inject a throwing `_sanitizeOffMain`, assert the report still comes
  back fully sanitized (the inline fallback). Mutation-checkable.
- One real-`compute` happy-path test proving the serialization shape end-to-end.
- `flutter analyze` + the bug-report/privacy tests.

## Files

`mobile/lib/services/bug_report_service.dart` (extract + delegate + seam + fallback),
`mobile/test/services/bug_report_service_test.dart` (seam/fallback + real-compute).
