# Live labeler subscription (#8255) — design

**Problem.** `ModerationLabelService.subscribeToLabeler` performs a one-shot paged
history load and never opens a live subscription. `_subscriptions` is declared but
never assigned. A kind-1985 label published *after* a client loads a labeler never
reaches the running client until an app restart. This is the complement of #8214
(a *failed* load latched as done); here a *successful* load is treated as final.

## Approved design decisions

1. **One shared subscription for all loaded trusted labelers.** Explicitly selected
   labelers and followed accounts are multiplexed into one `authors:[...]` filter.
   The followed-labeler product setting applies to the entire follow list, which can
   exceed a relay's per-connection subscription limit; one REQ keeps relay work
   constant without silently weakening that setting. Per-labeler state remains
   independent for history loading, moderation rows, watermarks, and unloads. A
   follow-list change cancels the old listener before replacing the stable REQ id,
   and bulk changes are coalesced into one replacement.

2. **Tail-only live subscription; keep the paged backfill.** A no-`since`
   subscription would re-request the full stored window and undo #8817's paging
   (which exists precisely to avoid OOM/timeout on large histories). So the paged
   backfill (`_loadLabelerHistory`) stays as-is and latches "loaded"; the live
   subscription opens from the oldest per-labeler watermark. Each author still has
   its own watermark and a five-minute replay tolerance, so distinct events that
   arrive slightly out of timestamp order still apply while older replay is ignored.

3. **Auto-reconnect above the SDK**, mirroring `DmRepository`'s gift-wrap
   subscription: store the shared `StreamSubscription`; on `onError`
   (relay `CLOSED` → `RelaySubscriptionRefusedException`) or `onDone`, cancel and
   re-open the tail via one cancellable `Timer`, guarded by `_disposed` and the tail
   generation so replacement / account switch / dispose kills stale callbacks. The
   reconnect delay backs off from two seconds to one minute, resets after delivery
   or EOSE, and logs both the drop and planned retry.

4. **Keep #8214's relay-ready retry.** It recovers an *incomplete backfill* (timed
   out / no relays), a different failure mode than a dropped tail: the tail only
   carries new labels and cannot backfill unfetched history. Complementary, so it
   stays; the boundary is documented in code.

## Mandatory: per-event dedup (AC #2)

`_processLabelEvent` appends unconditionally, so a reconnect that replays the tail
window (and the small backfill/tail overlap) would create duplicate label rows.
Track event ids within a bounded window around each labeler's current watermark:
- `_processLabelEvent` skips an event id already applied for its labeler.
- advancing a labeler's watermark discards ids older than the five-minute replay
  tolerance, bounding retained dedup state without treating cross-relay delivery
  order as timestamp order;
- `_removeLabelsForLabeler(pubkey)` also clears that labeler's id-set, so the
  backfill's existing remove-then-reprocess still re-applies, and the
  backfill/tail overlap dedups.

## Acceptance criteria (from #8255)

- A labeler's kind-1985 events published *after* subscription reach the label maps
  without an app restart.
- The same event arriving twice does not produce duplicate label rows.
- the shared subscription carries all loaded trusted authors; author-set changes and
  `dispose()` tear down the previous listener.
- Behaviour survives a relay reconnect (verified, not assumed).
- No regression to #8214: an incomplete initial load still must not latch loaded.

## Test plan (TDD)

Extend `test/services/moderation_label_service_test.dart` (mocktail harness). Stub
`nostrClient.subscribe(...)` to return a controllable `StreamController<Event>`:
- live label after load lands in the maps (no restart);
- duplicate event id → single row (dedup);
- all followed labelers use one REQ, author-set changes replace it, and old
  per-author replay is ignored;
- `_unloadLabeler` / account switch / `dispose` cancels the subscription and stops
  a pending reconnect;
- stream `onDone`/`onError` triggers a reconnect that re-opens the tail;
- incomplete backfill still does not latch (unchanged #8214 contract);
- each new test mutation-checked (break the guard, watch it go red).
