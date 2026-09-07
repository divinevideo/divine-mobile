# Live labeler subscription (#8255) — design

**Problem.** `ModerationLabelService.subscribeToLabeler` performs a one-shot paged
history load and never opens a live subscription. `_subscriptions` is declared but
never assigned. A kind-1985 label published *after* a client loads a labeler never
reaches the running client until an app restart. This is the complement of #8214
(a *failed* load latched as done); here a *successful* load is treated as final.

## Approved design decisions

1. **One subscription per labeler.** Reuse the existing per-pubkey `_subscriptions`
   map. The whole service is keyed per-pubkey (load generation, `_loadingLabelers`,
   `_unloadLabeler`, follow-list churn), so per-labeler subscriptions are the
   surgical fit. Practical count stays well under the relay's `max_subscriptions:
   100`. A single combined `authors:[...]` filter was rejected: it would force
   re-architecting the per-pubkey model and replay every labeler's stored window on
   each follow-list change.

2. **Tail-only live subscription; keep the paged backfill.** A no-`since`
   subscription would re-request the full stored window and undo #8817's paging
   (which exists precisely to avoid OOM/timeout on large histories). So the paged
   backfill (`_loadLabelerHistory`) stays as-is and latches "loaded"; the live
   subscription opens with `since` = the newest applied label's `created_at`
   (fallback: now) and carries only new labels.

3. **Auto-reconnect above the SDK**, mirroring `DmRepository`'s gift-wrap
   subscription: store the per-pubkey `StreamSubscription`; on `onError`
   (relay `CLOSED` → `RelaySubscriptionRefusedException`) or `onDone`, cancel and
   re-open the tail via a cancellable `Timer`, guarded by `_disposed` and the
   existing per-pubkey load generation so an unload / account switch / dispose kills
   pending reconnects. The reconnect re-opens with an updated `since` (newest seen).

4. **Keep #8214's relay-ready retry.** It recovers an *incomplete backfill* (timed
   out / no relays), a different failure mode than a dropped tail: the tail only
   carries new labels and cannot backfill unfetched history. Complementary, so it
   stays; the boundary is documented in code.

## Mandatory: per-event dedup (AC #2)

`_processLabelEvent` appends unconditionally, so a reconnect that replays the tail
window (and the small backfill/tail overlap) would create duplicate label rows.
Track `_appliedLabelEventIds: Map<pubkey, Set<eventId>>`:
- `_processLabelEvent` skips an event id already applied for its labeler.
- `_removeLabelsForLabeler(pubkey)` also clears that labeler's id-set, so the
  backfill's existing remove-then-reprocess still re-applies, and the
  backfill/tail overlap dedups.

## Acceptance criteria (from #8255)

- A labeler's kind-1985 events published *after* subscription reach the label maps
  without an app restart.
- The same event arriving twice does not produce duplicate label rows.
- `_subscriptions` holds real subscriptions; `_unloadLabeler` and `dispose()`
  tear them down.
- Behaviour survives a relay reconnect (verified, not assumed).
- No regression to #8214: an incomplete initial load still must not latch loaded.

## Test plan (TDD)

Extend `test/services/moderation_label_service_test.dart` (mocktail harness). Stub
`nostrClient.subscribe(...)` to return a controllable `StreamController<Event>`:
- live label after load lands in the maps (no restart);
- duplicate event id → single row (dedup);
- `_unloadLabeler` / account switch / `dispose` cancels the subscription and stops
  a pending reconnect;
- stream `onDone`/`onError` triggers a reconnect that re-opens the tail;
- incomplete backfill still does not latch (unchanged #8214 contract);
- each new test mutation-checked (break the guard, watch it go red).
