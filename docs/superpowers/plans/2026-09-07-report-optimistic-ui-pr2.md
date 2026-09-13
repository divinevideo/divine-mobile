# Offline reporting implementation and verification (#8053)

The durability and UI work are combined in PR #8822 targeting main. The final
behavior is described in [the design record](../specs/2026-09-07-report-durable-optimistic-design.md).

## Implementation

1. Save the complete report intent in one schema-14 `pending_reports` row,
   redacting before persistence and deferring signing until delivery.
2. Confirm after that write. Keep local persistence errors retryable in the form,
   coalesce repeated taps, and remove screen-owned network work.
3. Retry relay, ticket, and moderation destinations independently on startup,
   reconnect, foreground resume, and a bounded backoff timer. Keep failed work
   queued and bound attempts so a stalled channel does not block other reports.
4. Replay moderation intent through `DmRepository.enqueueSend` with a stable
   report id and timestamp, followed by NIP-17-only recovery of the same rumor.
5. Scope every delivery to the report owner, guard support identity changes
   across awaits, and include reports in account-data cleanup.
6. Translate the saved-report confirmation and remove obsolete delivery-warning
   strings across locales.

## Regression checks

- Offline acceptance does not invoke a signer or network request.
- Reopened storage retains all three redacted delivery intents.
- A local write failure never produces an accepted result.
- Repeated taps and process-restarted DM handoffs do not duplicate a rumor.
- Channel success retires independently; reconnect and timers retry pending work.
- Backed-off rows and a hung destination do not starve newer reports.
- Switching accounts during token refresh cannot file under the new identity.
- Fresh, migrated, and legacy-repaired databases have the same schema.
- Existing DM repository behavior, reporting widgets, inbox reporting,
  localization consistency, and app static analysis remain green.

Run affected app tests, database migration/DAO tests, the full DM repository
suite, code generation, localization checks, and repository ratchets before
publishing. Re-request human review after the updated PR checks pass.
