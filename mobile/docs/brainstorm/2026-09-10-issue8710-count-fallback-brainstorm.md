# Brainstorm: A failed count must not turn into a 5,000-event download (#8710)

Date: 2026-09-10

Evidence base: `tasks/findings_8710.md` (local). All six load-bearing hypotheses there hold at 1.0,
backed by code at both ends, two executed scratch reproductions, and a live observation in #8992.

## Problem Statement

`NostrClient.countEvents` can fail to get a NIP-45 COUNT answer from any relay. When that happens it re-sends the caller's
limitless filter as a REQ. It then downloads up to 5,000 full events, writes them into the local event
database, and returns their number as an exact count. "No answer" is not rare. It covers:

- every COUNT sent into a relay pool that dropped its idle socket and has not been redialled (COUNT is the only read path that never redials);
- every 5-second timeout;
- every CLOSED from a struggling backend.

The repositories then cache that number for the session. The sound detail screen always shows it, and so do feed
items that have no REST seed, both as fact.

## Constraints

- **Layering and failure contract.** The flow is UI → BLoC → Repository → Client. Choosing a fallback between sources
  belongs in the repository (`.claude/rules/architecture.md`). The client throws a typed exception and never
  returns a value that also means "it failed". A repository rethrows a typed exception or returns a
  documented sentinel. BLoC state carries status and values, never errors (`.claude/rules/error_handling.md`).
- **"A zero is not data"** (`tasks/lessons.md`, #7486 / PR #8405). An unknown count must not render as a
  number, or be treated as one.
- **Coverage gates.** `reposts_repository` and `sounds_repository` are at 100%. `nostr_client` 82,
  `comments_repository` 80, `likes_repository` 62, `nostr_sdk` 20.
- **#8992** (idle sockets dropped and never redialled) is a separate open issue. This fix must not depend
  on it, and it must not blank counts during idle windows (findings H6).
- **Relay contract.** funnelcake ignores `limit` on COUNT (F25), clamps a limitless REQ at 5,000 (F8), and
  CLOSEs a COUNT on a storage error (F26). NIP-45 says nothing about `limit` on COUNT.
- **Logging.** Any new diagnostic follows the Nostr-identifier logging rules: full ids, and `pubkeyForLogs` for pubkeys.
- One focused PR against `main`. No stacking, and no deferred TODOs.

## Prior Art

- **#660** (2025-12-16) introduced COUNT, and the client-side fallback "if the relay doesn't support NIP-45".
  It mapped timeouts to "not supported" from day one (F28).
- **`queryEventsDetailed`** already has what COUNT lacks: a redial-first step (#5202, #8550), one deadline for
  the whole call (#7091), and a "no relay took the request" signal (`noRelaysParticipated`).
- **#8936 / #8947** added the relay diagnostics port and the rate-limited support-export adapter. That is the
  channel for making COUNT failures visible.
- **REST stats.** `FunnelcakeApiClient.getVideoStats` / `getBulkVideoStats` and `VideosRepository.getVideoStats`
  supply the feed seeds (`liveRepostCountSeed`, `liveCommentCountSeed`).
- **Audio-reuse design** (`mobile/docs/plans/2025-01-01-audio-reuse-design.md`). The sound usage count uses NIP-45.
  When the relay is unavailable it asks for a "non-fatal error and retry", not a guess, and it caches
  usage counts with a short TTL.
- **`VideoActionButton(count:, labelWhenZero:)`** already renders zero as the action's label, so an unknown count
  on the feed buttons is visually neutral today.
- **Adjacent issues:** #6238 (`queryEvents` partial results look complete), #8992 (idle drop), #6742
  (bound `fetchEventReposters`).

## Approaches Explored

### Approach A: Bound and label the fallback (the issue's suggested direction)

**Description:** Keep the COUNT→REQ fallback inside `countEvents`, but give each filter a bound: a copy with
`limit: N`, since `Filter.limit` is mutable and `Filter.fromJson` exists. Mark the result
`approximate: true` when the bound is hit, or when the query leg timed out or reached no relay. Forward
the caller's `timeout` to the fallback.

**Layers affected:** Client.

**Pros:**
- The smallest diff: one method and its tests.
- The worst case drops from 5,000 events to N.
- No public API change. It is the direction the issue proposes.

**Cons:**
- It still sends a REQ on every failed COUNT, and failures are routine (idle windows: H3, F29). The waste
  continues at N events per count.
- It still returns a number. Nothing reads `approximate` except one debug log, so the repositories still cache,
  and the screens still show, a capped or cache-only floor as exact. That is the defect class of #7486.
- It leaves the idle trigger (H3) and the queued-COUNT replay (E3) alone, and adds no observability.

**Risks / Unknowns:** It looks finished while the user-visible wrongness remains. Making `approximate`
mean anything needs "5,000+" rendering on every surface, which means per-surface UI plus l10n in 22
locales. That is Approach A's hidden second half.

**Complexity:** Low as scoped. Medium if `approximate` is made visible.

### Approach B: Make COUNT a first-class read, where "no answer" means unknown

**Description:**
1. **Client.** `countEvents` gets the redial-first step queries have. One deadline covers the call, and it runs
   `retryDisconnectedRelays()` first when no relay is connected. A count issued after an idle drop is then
   answered by NIP-45 instead of failing. This removes H3's frequency without waiting on #8992.
2. **Client.** Remove the REQ fallback. When no relay answers, throw a typed failure (the client-layer contract)
   instead of returning a guess.
3. **SDK.** `RelayPool.count()` sends with `queueIfFailed: false`, so a failed COUNT is never replayed later with
   no one waiting (E3). It reports COUNT timeouts and unsent COUNTs through the existing relay diagnostics
   channel, so the frequency shows up in support exports (N9, N15).
4. **Repositories** (reposts, comments, likes, sounds). Translate the typed failure into a documented "unknown"
   result, and never cache it, so the next view asks again.
5. **BLoC.** Accept an unknown count per field and keep the seed. Today one failing count in `Future.wait`
   discards all three. A null sentinel adds no new exceptions to that path.
6. **UI.** Sound detail hides its usage line when the count is unknown, instead of saying "no videos". The feed
   buttons need no change: an unknown already renders as the label, as it does today.

**Layers affected:** Client (`nostr_client`, `nostr_sdk`), Repository ×4, BLoC ×1, UI ×1 screen plus its provider.

**Pros:**
- The expensive query is gone entirely.
- Counts in idle windows become *more* available than today: a real NIP-45 answer after a dial, not a guess.
- No wrong number is ever cached or shown.
- It follows the per-layer failure contract (error_handling.md), keeps source choice in the repository
  (architecture.md), and follows lesson #7486.
- COUNT failures become observable.

**Cons:**
- A wider PR: two SDK packages, four repositories (two of them at 100% coverage), a bloc, a provider, and a screen.
- Repository count APIs go from `Future<int>` to a nullable result, which ripples through tests.
- A user whose relay set has no NIP-45 relay loses relay counts. The feed still shows REST seeds, but sound
  detail shows no count. That is a deliberate behaviour change, and the PR must call it out.
- A COUNT sent into an idle pool now waits for a dial. That is the same trade queries made in #5202 and #8550.

**Risks / Unknowns:**
- RelayManager's snapshot of connected relays can lag an idle drop by up to 5 s (F19), so a pre-flight redial
  can miss. Mitigation: have the SDK tell "no relay took the COUNT" apart from "relays took it and none
  answered", as queries do, and redial once for the former.
- The #6022 like-floor arithmetic has to handle a nullable fetch.

**Complexity:** Medium.

### Approach C: Stop asking the relay, using seed-aware fetches and REST stats

**Description:** `VideoInteractionsBloc` fetches only the counts it has no seed for. Today it fires three COUNTs
per feed item and throws them away when a seed exists (N7). For a seedless video it gets reactions,
comments and reposts from one REST call (`VideosRepository.getVideoStats`, funnelcake
`/api/videos/{id}/stats`), with relay COUNT kept only as the repository's last resort. Sound usage has no
REST endpoint, so it stays on relay COUNT.

**Layers affected:** BLoC, Repository (a new composition point for REST and relay counts). The client is unchanged.

**Pros:**
- It removes most COUNT traffic in the healthy case, not only the failure case.
- It fits #4747's REST-first data-source direction and the intent of #3607.

**Cons:**
- It does not fix `countEvents`. Sounds, non-addressable likes, and every REST-failure path still reach the
  unsafe fallback, so it needs A or B anyway.
- It changes which source a count comes from. REST and relay semantics already diverge (#5751, #6021),
  which invites count/list divergence regressions.
- Repository-to-repository dependencies are forbidden (architecture.md), so it needs a new composition point.

**Risks / Unknowns:** Scope creep well beyond #8710. A REST outage lands back on relay COUNT.

**Complexity:** High.

### Approach D: Classify relays by capability, and fall back only where one lacks NIP-45

**Description:** In `RelayPool.count()`, check each relay's NIP-11 `supported_nips` (`Relay.info`, which is
fetched on connect but never read today: N22). A relay that advertises no NIP-45 gets a bounded,
approximate REQ-based count. A NIP-45 relay that fails yields "unknown". Unknown capability is treated as NIP-45.

**Layers affected:** Client (`nostr_sdk`), on top of B's client and repository changes.

**Pros:**
- It serves the one population #660's fallback was built for: users whose relay set lacks NIP-45 (F34, N14).
- It does so without charging everyone else a REQ on a transient failure.
- It is the first real use of NIP-11 in the codebase.

**Cons:**
- The signal is best-effort. It is null until a fetch that nothing awaits has landed, null on any HTTP
  error (with no retry), and reset on every redial (F42–F44), so the classification flaps.
- It adds SDK complexity for a population nobody can size today (no telemetry: F32).
- It still requires B.

**Risks / Unknowns:** Relays that advertise NIP-45 but disable it, and the other way round.

**Complexity:** Medium–High.

## Recommendation

**Approach B.** It is the only option that removes every confirmed cause:

- **Cost (H1):** no REQ fallback.
- **Conflation (H2):** the typed failure means "unknown", nothing more.
- **Frequency (H3, H6):** COUNT redials the way queries do.
- **Wrong numbers (H4, H5):** an unknown is never cached or shown as a number.
- **Orphan replay (E3):** COUNT is no longer queued.
- **Observability (N9, N15):** COUNT failures reach support exports.

It also follows the repo's own contracts rather than working around them: the per-layer failure
contract, "fallback belongs in the repository", and lesson #7486.

A is the cheapest diff, but it keeps the routine REQ and ships a floor that nothing labels, which is
the defect class the team already paid for once. C is valuable but is a data-source initiative (#4747)
that leaves `countEvents` unfixed. Its "don't fetch counts you already have a seed for" part (N7) should
be its own issue. D is YAGNI until someone shows that custom-relay users need relay counts. It can be
layered onto B later without rework, because B's typed failure is exactly the hook D would use.

**Decision to confirm (product-shaped, OQ6 and OQ8).** B chooses "unavailable" over "capped floor", and sound
detail hides its usage line when the count is unknown. Both follow the #7486 precedent. The remaining
product call is whether any surface should show a placeholder such as "—" instead of hiding it. The plan
assumes hide.

## Open Questions for /plan

- [ ] **Typed failure at the client boundary.** Propagate the SDK's `CountNotSupportedException`, which is misnamed
      because it also fires on timeouts and failed sends? Or introduce a `nostr_client` exception whose
      name says what happened? Prefer the shape that stops the H2 conflation from coming back.
- [ ] **Repository "unknown" shape.** `Future<int?>` with a documented null, or a small result type? The BLoC needs
      each count to fail independently either way.
- [ ] **Redial trigger.** Only the pre-flight `connectedRelays.isEmpty` check (as queries do), or also one
      redial-and-retry when `RelayPool.count()` reports that no relay took the COUNT? The second needs a
      "sent to nobody" signal from the SDK.
- [ ] **Timeout budget.** One deadline covering the redial and the COUNT. Which default? Today 5 s covers the COUNT alone.
- [ ] **Diagnostics.** Which `RelayDiagnosticSite` and level? Should the client also log once when a count is unknown?
- [ ] **Sound detail.** The unknown rendering (hide or placeholder) and its widget test. Hiding has no l10n impact.
- [ ] **Old tests.** Tests that pin the old behaviour must change deliberately: `nostr_client_test.dart:5352-5386`,
      plus any repository test that asserts a client-side count. `CountSource.clientSide` becomes dead code.

## Prerequisites

- [ ] Product/UX: confirm that an unknown count hides the sound-detail usage line (the plan's default).
- Nothing else blocks: no protocol change, new package, or backend change. funnelcake already supports
  NIP-45 and ignores `limit` on COUNT.

## Not in scope (tracked elsewhere)

- #8992: idle sockets dropped and never redialled. B makes COUNT self-sufficient; it does not keep sockets alive.
- #6742: bound `fetchEventReposters`.
- #6238: signal partial results from `queryEvents`.
- N7: blocs fetch counts they already have seeds for. A candidate for its own issue.

## Next Step

`/plan https://github.com/divinevideo/divine-mobile/issues/8710` on Approach B, with `tasks/findings_8710.md`
as the evidence base.
