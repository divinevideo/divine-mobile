# Brainstorm: Tell every relay read how complete its answer is (#6238)

Date: 2026-09-10

## Problem Statement

A one-shot relay read can end in seven different ways — every relay sent `EOSE`; the caller's deadline passed; the one-second settle window released the caller on the relays that answered first; a relay sent `CLOSED`; a relay's socket dropped; no relay took the `REQ`; or a relay silently clamped the filter to its maximum and still sent a clean `EOSE`. `queryEvents` returns the same `List<Event>` for all seven, so a caller cannot tell a complete answer from a truncated one, and at the `NostrClient` layer a deadline exit even discards the events that did arrive and returns only locally cached rows. The primitive needs a contract that says how complete an answer is, keeps what arrived, and gives callers a safe way to read everything — without breaking existing callers or undoing the latency work that made reads return promptly.

## Constraints

- Layering: the change lives in the client/data layer (`mobile/packages/nostr_sdk`, `mobile/packages/nostr_client`); repositories consume `NostrClient`; nothing above the repository layer picks sources or decides completeness.
- Source compatibility: `queryEvents` appears at about 60 production call sites and about 740 test sites (53 files, mostly mocktail stubs); `queryEventsDetailed` at 18 production call sites and 322 test sites (38 files, 69 record literals). Changing either signature or record shape is a large, risky migration.
- No production code outside `nostr_client` calls the SDK's `Nostr.queryEvents` / `queryEventsDetailed`, so the SDK layer can evolve freely behind `NostrClient`.
- Latency: #6452 (a relay `CLOSED` settles a pending query) and #6673 (settle window; dropped / auth-gated relays are not waited on) removed measured multi-second stalls. Display reads must keep that prompt behaviour.
- Coverage floors: `nostr_client` 82 %, `nostr_sdk` 20 % (`mobile/scripts/baseline/package_coverage_floors.txt`); floors may only rise.
- Diagnostics: packages report through the injected `RelayDiagnosticsSink` port, not a new logger dependency; no Nostr identifier may be shortened in a log line; pubkeys go through `pubkeyForLogs`.
- Protocol: NIP-01 `EOSE` marks the end of *stored* events, not completeness, and relays may return fewer than `limit`; NIP-11 `max_limit` clamps silently; NIP-67 (draft) adds optional `finish` / `more` / `auth` hints to `EOSE`, but their absence proves nothing. The Divine relay advertises `max_limit: 5000` and sends no NIP-67 hint today.

## Prior Art

- `queryEventsDetailed` in both layers, `requireAllRelaysSettled` (#6966) and `noRelaysParticipated` / `sentTo` (#7594): the opt-in completeness signal; default mode still reports settle-window, `CLOSED` and dropped-socket exits as `timedOut: false`, and nothing sees a relay cap.
- Caller-side fixes that use the opt-in flags: #8260 (mute list), #8267 (contact list), #8275 (people lists), #8220 (DM inbox), #8219 (video repair latch), #8254 (labeler latch), #8217 (DM history drain), #6966 (bookmarks).
- `moderation_label_service.dart` (#8817): an `until` pager that re-requests the inclusive boundary and de-duplicates by id (so `created_at` ties are not skipped) and detects a relay that ignores `until`.
- `community_content_label_repository.dart`: returns `List<Event>?` — `null` for a failed read, empty for a genuine empty answer.
- `dm_repository` history drain: a page only counts once it is authoritative.
- Evidence behind this brainstorm (investigation of #6238): a host test driving a real `RelayPool` with scripted relays; on-device probes against production reads through a local fault-injecting proxy; live measurements (a capped replay of 5000 events takes 10–15 s; 200 video events take ~22 s; a large replay delays other `REQ`s on the same connection, so a small read that answers in 0.3 s alone went unanswered for 15 s behind one).

## Approaches Explored

All four share the same machinery underneath: the settlement layer records *why* a query ended; the `NostrClient` deadline keeps what the inner query collected; `possiblyCapped` compares per-relay event counts with `min(limit, relay max_limit)`; an `until` pager generalises #8817; one diagnostics line per non-complete exit. They differ in how callers receive that information.

### Approach A: Additive typed read API

**Description:** Add a new read in both layers — `readEvents(...)` returning a `QueryResult` that carries the events that arrived, an enum saying how the read ended (`complete`, `settledEarly`, `relayClosed`, `socketDropped`, `deadline`, `noRelay`), `possiblyCapped`, and `isComplete`; plus `readAll(filter, …)`, an `until` pager built on it. `queryEvents` and `queryEventsDetailed` become thin wrappers over the same implementation with their behaviour pinned by tests. Callers move to the new API one follow-up PR at a time, most destructive first.

**Layers affected:** Client (`nostr_sdk`, `nostr_client`); repositories only when they migrate.

**Pros:**
- No churn now: every existing call site and test stub keeps compiling and behaving as pinned.
- Explicit and exhaustive: a caller cannot read the events without the value that says how complete they are.
- Enumeration is first-class (`readAll`), which is the only answer to a relay cap.
- Each caller migration decides what partial data means for that caller, in a reviewable diff.

**Cons:**
- Two read APIs coexist until migration finishes.
- The wrappers need characterisation tests so their pinned behaviour cannot drift.

**Risks / Unknowns:**
- Whether the deadline fix should also reach the wrappers (a behaviour change for existing callers) — see open questions.
- Cap detection needs each relay's `max_limit`; relays that do not publish NIP-11 leave it heuristic.

**Complexity:** Medium

### Approach B: Evolve `queryEventsDetailed` in place

**Description:** Grow the existing record with `endedBy` and `possiblyCapped`, fix the deadline loss there, and leave `queryEvents` as the lossy wrapper.

**Layers affected:** Client; every current `queryEventsDetailed` caller and test.

**Pros:**
- One detailed API instead of two.

**Cons:**
- 18 call sites and 69 record literals across 38 test files change together.
- Callers that destructure the record today see a changed type in the same PR as the semantic change.
- Pagination is bolted on beside a record that was never shaped for it.

**Risks / Unknowns:**
- A large diff touching many unrelated packages makes a behaviour change hard to review.

**Complexity:** Medium

### Approach C: Metadata carried on the returned list

**Description:** Keep `queryEvents`' signature and return a `List<Event>` subclass that carries completeness, read through an extension getter.

**Layers affected:** Client.

**Pros:**
- Zero churn; any caller can opt in with one getter.

**Cons:**
- The contract is invisible: `where`, `map` and `toList` return plain lists and silently drop the metadata.
- Mocks return plain lists, so every stubbed read reports "unknown".
- Nothing forces a caller to look.

**Risks / Unknowns:**
- The failure mode this issue is about — a caller acting on a list without knowing how complete it is — stays the default.

**Complexity:** Low, but fragile

### Approach D: Fail-closed by default

**Description:** `queryEvents` throws an `IncompleteQuery` (carrying the partial events) on any non-complete exit; display callers pass `allowPartial: true` to keep today's behaviour.

**Layers affected:** Client; about 60 call sites.

**Pros:**
- Safe by default for new code.

**Cons:**
- About 45 display call sites must add the flag; any one missed turns a prompt, harmless display read into an error.
- Exceptions become control flow for an expected outcome.
- A capped read ends in a clean `EOSE`, so it still never throws — pagination is needed anyway.

**Risks / Unknowns:**
- Regresses the latency work unless every display path is found.

**Complexity:** High

## Recommendation

**Approach A.** It is the only option that is both explicit and churn-free. It keeps the #6452 / #6673 latency behaviour for display reads, makes the completeness value impossible to ignore for callers that adopt it, and gives enumeration a correct path through the relay cap and `created_at` ties by generalising the pager #8817 already proved. It also realises the audit's suggestion (#8258) of a read that cannot be used without handling the inconclusive case, while leaving each caller's migration — the part that needs product judgment about partial data — to its own reviewable PR.

## Open Questions for /plan

- [ ] Does the `NostrClient` deadline fix (return the events that arrived, not cache rows only) also reach `queryEventsDetailed` and plain `queryEvents`, or only the new `readEvents`?
- [ ] How does the deadline plumb through: an absolute deadline passed to the SDK, or a collector the client owns?
- [ ] How is `possiblyCapped` decided: per-relay counts against `min(limit, max_limit)` with `max_limit` from NIP-11 (fetched once per relay), a configured default, or only when a `limit` is set?
- [ ] When does `readAll` stop: an empty complete page, a short complete page, or a NIP-67 `finish` hint when a relay sends one? Default page size (smaller pages shorten the head-of-line delay a large replay causes)?
- [ ] Parse NIP-67 `EOSE` hints now or later?
- [ ] Telemetry: a new `RelayDiagnosticSite` value or `requestSettlement`; level and volume bounding.
- [ ] Exact names and where `QueryResult` / the end-reason enum live (SDK, client, or both).
- [ ] Order of caller migrations and which verified destructive callers go first.

## Prerequisites

- [ ] None blocking. Optional: a relay-side issue (draft for review) proposing NIP-67 hints and concurrent `REQ` handling per connection.

## Next Step

`/plan 6238`
