# Profile Pinning Evidence Audit

**Date:** 2026-08-23

**Status:** Pinned-source audit; design signoff and runtime readback outstanding

**Review update:** 2026-09-20. "Current" below means the source revisions listed
under Sources checked, not a fresh audit of each repository's latest head.
Product choices remain proposals pending @Chardot under
[profile pinning #3868](https://github.com/divinevideo/divine-mobile/issues/3868)
and [the profile epic #4342](https://github.com/divinevideo/divine-mobile/issues/4342).

## Why this audit exists

This audit separates four different kinds of statement that had been mixed
together in earlier report drafts:

1. behavior already shipped by a Divine client;
2. behavior required or recommended by a Nostr NIP;
3. behavior verified in the current mobile and relay code;
4. new product or implementation recommendations made by the report.

The consolidated report uses this appendix to distinguish established behavior,
protocol facts, engineering risks, and report recommendations.

## Sources checked

- [NIP-01](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/01.md)
  at nostr-protocol/nips commit
  `656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab`.
- [NIP-51](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/51.md)
  at the same commit.
- [NIP-71](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/71.md)
  at the same commit.
- `divine-mobile` `origin/main` at
  `e358fbfb68ba3f6e8549abddfb2510087fde0ca5`.
- `divine-web` `origin/main` at
  `bdc66278cd385df52a20576a28ee0ac05969e31a`.
- `divine-funnelcake` `origin/main` at
  `7350a0e020208c13cb179742f175f2bea6e42f71`.
- The shared `divine-context` checkout. It was on a non-default branch, so it
  was read but treated as potentially stale and was not modified.

## Established Divine behavior

Divine Web already implements profile video pins. Commit
[`0058e2f5`](https://github.com/divinevideo/divine-web/commit/0058e2f51091501e0cf04fe3018f05fff0460eb9)
(`feat: pinned videos on user profiles (#140)`, authored by Rabble on
2026-03-01) is the cross-client precedent:

- `divine-web/src/hooks/usePinnedVideos.ts` reads and writes kind `10001`.
- Video identities are kind-`34236` `a` coordinates.
- New pins are appended to the stored tag list.
- The web limit is three pins.
- The parser accepts values beginning with `34236:` regardless of whether the
  video author is the pin-list owner. It does not strictly validate the pubkey
  or `d` value.
- Other tags are retained during pin and unpin, but both mutations replace
  `content` with an empty string. That can erase private list items stored there.

Current Divine Web behavior includes one later improvement and two remaining
risks:

- Commit
  [`e74b6b04`](https://github.com/divinevideo/divine-web/commit/e74b6b042eb976600683ee830360cfa27592cfbb)
  added deterministic newest-event selection for each video coordinate.
- Kind-10001 reads still query with `limit: 1` and compare only timestamps, so
  they have the same equal-timestamp winner defect identified for Mobile.
- The owned-profile unpin lookup keys by `d` value alone. Two authors using the
  same `d` value can select the wrong foreign-authored coordinate.

This makes kind `10001` plus kind-`34236` `a` tags an existing Divine
convention. It does not make that combination standard NIP-51 behavior.

The current Funnelcake code policy automatically passes the kind-allowlist gate
for the NIP-01 replaceable range `10000..19999` and addressable range
`30000..39999` unless a NIP-86 `disallowkind` record explicitly blocks the kind.
Signature, timestamp, size, moderation, schema, rate-limit, and write-queue
checks can still reject an event. The kind policy landed in commit
[`7dcb41c6`](https://github.com/divinevideo/divine-funnelcake/commit/7dcb41c6e5e3f112ff699901743fbe5291c7e647)
on 2026-07-29. An older Divine Web issue reporting that kind `10001` was
rejected by `relay.divine.video` predates this policy and is not a description
of the current relay code. Code policy alone does not prove the current
production `disallowed_kinds` state.

That older report is consistent with the seeded relay policy, which limits
how far the Divine Web code precedent can be relied on. Before `7dcb41c6`
the gate was an unconditional allowlist-membership test
(`git show 7dcb41c6^:crates/relay/src/relay.rs`, `is_kind_allowed` returning
`Ok(false)` to `KindNotAllowed`), and the seeded allowlist
(`database/migrations/000015_seed_allowed_kinds.up.sql`) lists kinds `10000`
and `10003` but not `10001`; no later migration adds it. Divine Web shipped
profile video pins in
[`0058e2f5`](https://github.com/divinevideo/divine-web/commit/0058e2f51091501e0cf04fe3018f05fff0460eb9)
on 2026-03-01, before the range auto-allow change dated 2026-07-29. Under that
pre-change code and seeded allowlist, a kind-`10001` write would be rejected.
Source dates do not establish every production deployment or live allowlist
configuration during that interval.

At the pinned Web revision, `LIST_KINDS` in `src/lib/relayRouting.ts:11` is
`[30000, 30001, 30005]`, so kind `10001` gets neither the additional profile
relay routing for those lists nor kind `10000`'s separate primary-relay-only
return (`src/lib/relayRouting.ts:130-143`). Instead it reaches the public preset
fan-out (`src/lib/relayRouting.ts:149-168`), while the default read set is
`wss://relay.divine.video` alone (`src/App.tsx:52-54`). A pin can therefore be
accepted by a public relay the default read path never queries.

The precedent consequently establishes the event shape Divine Web uses. It is
not evidence that a pinned-video list has ever been readable through Divine's
own relay. Finding 24's release readback is what settles that, and it should
run before the shape is treated as proven rather than only before Mobile
ships.

## Primary Nostr findings

### Kind 10001 is standardized for pinned notes, not addressable videos

NIP-51 names kind `10001` **Pinned notes** and expects `e` tags that reference
kind-1 notes. NIP-51's general list mechanism permits list items in tags, but it
does not standardize kind-`34236` `a` tags inside kind `10001`.

The Divine representation must therefore be described as an existing Divine
extension to the kind-10001 list, with the interoperability consequence that a
generic NIP-51 client may ignore the video `a` tags.

### Addressable video coordinates are the correct stable reference

NIP-01 defines an `a` reference as `kind:pubkey:d-tag`. NIP-71 defines kind
`34236` as addressable short-form video. The coordinate remains stable across a
replacement only while the author pubkey and `d` value remain unchanged.

The codec must require an exact 64-character lowercase hexadecimal pubkey.
Mobile must also require a nonempty `d` value, but only one current path
enforces that. `VideoEvent.addressableId` returns null for an empty `d`
(`video_event.dart:1359-1368`), while `getVideosByAddressableIds` does not
reject one: it gates only on `AId.fromString` and `isVideoKind`
(`videos_repository.dart:1511-1512`), so an empty-`d` coordinate is parsed
into a filter and sent to relays, and is discarded only when the response is
mapped (`videos_repository.dart:1552`). The requirement therefore has to be
enforced by the pin coordinate type rather than inherited from the existing
paths. It is a current-mobile compatibility rule rather than explicit NIP-71
normative language. `AId.fromString` rejoins colons in a `d` value but does not
enforce these validity rules.

### NIP-51 recommends chronological storage order

NIP-51 says clients SHOULD append new list items so the stored order remains
chronological. The recommended mobile design instead prepends and displays newest
pin first. That is a deliberate SHOULD-level interoperability deviation, not a
claim about standard NIP-51 behavior. Divine Web currently appends and preserves
stored tag order. The recommended Mobile design would preserve order but render
a different subset and insert at the opposite end. A Web-written or
mixed-client list has no per-item timestamps, so Mobile cannot reconstruct a
globally newest-first chronology.

### Replaceable winners need a complete comparator

For replaceable events such as kind `10001` with equal `created_at`, NIP-01
recommends retaining the lowest lexical event ID using lowercase "should".
Its pinned text distinguishes addressable events and does not explicitly extend
that retention sentence to kind `34236`. Using the same comparator for video
replacements is a proposed Divine policy. The current mobile Nostr client reapplies
`limit: 1` after sorting only by timestamp. A kind-10001 query with `limit: 1`
can therefore discard the expected winner before a repository applies the ID
tie-break.

With the current client, the pin repository must query without `limit: 1` and
select by:

```text
created_at descending, then event ID ascending
```

Alternatively, `_mergeEvents` must first be corrected to apply the same
tie-break before limiting. The comparator must also guard live subscription
updates.

## Current mobile findings

### Verified foundations

- `ProfileFeedCubit` owns the canonical newest-first base sequence in
  `_unfilteredVideos` (`mobile/lib/blocs/profile_feed/profile_feed_cubit.dart:125-132`).
- `VideoEvent.addressableId` produces the full kind-`34236` coordinate.
- `VideoEvent.stableId` is not a global pin identity because it omits the
  author when a `vineId` exists
  (`mobile/packages/models/lib/src/video_event.dart:1085-1088,1359-1375`).
- `VideosRepository.getVideosByAddressableIds` batches 20 coordinates, so 12
  unique pins fit in one relay batch. Funnelcake fallback and hydration can
  still cause additional requests
  (`mobile/packages/videos_repository/lib/src/videos_repository.dart:1469-1582`).
- The current grid prefixes owner-only upload placeholders ahead of published
  videos (`mobile/lib/widgets/profile/profile_videos_grid.dart:277-349`).
- The current fullscreen catch-up merge sorts newest-first; it would destroy
  a future pinned launch order. The earlier target-present branch also returns
  the live list outright, dropping any seed-only items
  (`mobile/lib/widgets/profile/profile_video_feed_view.dart:139-153`).

### Engineering findings relevant to future implementation

1. **Pin overlays and pagination need separate centralized sequences.** Current
   cold-load, cache, REST, Nostr load-more, enrichment, relay, and filter paths
   directly emit the filtered base feed. There is no pin overlay today. If a
   future integration injects pins only into `state.videos`, `_onRelaySnapshot`
   would compare that sequence with the unpinned `filtered` list and overwrite
   it whenever `_sameVideoSequence` detects a difference in length, per-index
   event ID, or engagement counters. Every future video emit and comparison
   needs one centralized base-to-displayed derivation
   (`profile_feed_cubit.dart:204-207,255-258,299-302,536-538,576-579,631-633,648-659,678,746-760`).
   Keep raw base, normally filtered base, and displayed sequences separate.
   Backfill counts should use the normally filtered base. Today's Nostr `until`
   cursor is the minimum `createdAt` in filtered `state.videos`
   (`profile_feed_cubit.dart:512-516`). The proposal changes both axes to
   `min(_unfilteredVideos.map((video) => video.nostrCreatedAt))`: `createdAt`
   may be original `published_at`, whereas `nostrCreatedAt` uses the event's
   timestamp when known (`video_event.dart:1090-1097`). This changes the Nostr
   pagination boundary for every profile, including those without pins. Test
   filtered entries, metadata replacements, and unpinned profiles separately.
2. **A naive orderer can drop valid base-feed entries.** Pin-specific owner and
   visibility validation must apply to resolved pins, not re-filter the existing
   authoritative base sequence. Append that base sequence unchanged, minus
   exact duplicates.
3. **Overlapping copies are not reconciled.** When both inputs contain one
   coordinate, neither the feed nor separately resolved copy should win by input
   position. Different event IDs require the proposed video winner policy by
   `nostrCreatedAt` descending then event ID ascending. Same-event enrichment
   precedence and merging are implementation policy that future engineering
   work must state and test explicitly. Preserve the authoritative base
   sequence position.
4. **Video replacement resolution is nondeterministic.** Mobile's
   `getVideosByAddressableIds` currently lets arrival order choose between
   multiple versions of one coordinate. Under the proposal, it must select the raw winner by
   timestamp/ID before parsing and visibility filtering; otherwise an older
   playable version can incorrectly replace a newer filtered version
   (`videos_repository.dart:1529-1558`). Raw-resolved coordinates must be
   tracked independently from visible results: the current fallback path treats
   absence from the visible map as missing and can reintroduce an older visible
   Funnelcake representation of a canonical-but-filtered event
   (`videos_repository.dart:1561-1570,1613-1629`). Canonicalize across sources
   before visibility filtering, or otherwise prevent fallback for a coordinate
   already resolved canonically.
5. **`restartable()` is not enough.** Cancelling a Bloc handler does not cancel
   its underlying resolver future. A generation guard or `emit.isDone` check
   is required before a stale result mutates pin state.
6. **Grid-to-fullscreen can substitute a different sequence; a missing target
   exposes the fallback bug.** The grid de-duplicates its displayed list, but the
   tap handler substitutes `state.videos` when Cubit state is nonempty. It then
   re-resolves the tapped video with author-scoped `indexOfMatchingVideo`, so
   a changed index alone does not open the wrong video
   (`profile_videos_grid.dart:249-267,315-339,425-430`). The concrete failure is
   a stale rendered tile whose video disappeared from the nonempty Cubit list
   before the tap: lookup returns -1, the displayed-list fallback index is used
   against the substituted seed, and fullscreen clamps it when target identity
   is also absent (`profile_video_feed_view.dart:155-175`). Existing grid tests
   stub an empty Cubit list and do not exercise that substitution
   (`mobile/test/widgets/profile/profile_videos_grid_test.dart:41-48`). Add a
   regression with nonempty Cubit state and a missing tapped target. The
   rendered published sequence should own index, prefetch, and launch seed.
7. **Exact identity must be threaded end to end.** Future work must include
   `FullscreenFeedBloc` and its tests in the addressable-coordinate path.
8. **Publish language overclaims certainty.** A fully settled query covers the
   configured relay fan-out, not every relay. `OK true` means accepted for
   writing, not durable. A lost `OK` can leave the remote outcome unknown.
   Failed mutations may keep local visible order unchanged; they cannot
   guarantee the previous order is still live everywhere.
9. **A snackbar alone is insufficient.** `.claude/rules/accessibility.md` requires
   `SemanticsService.sendAnnouncement` for snackbars and asynchronous visible
   changes.
10. **A new package requires complete CI ownership.** If engineering creates a
    repository package, it also
    requires `analysis_options.yaml`, a package CI workflow, a measured package
    coverage-floor entry, and the package CI/coverage floor checks.
11. **Prefer the whole-package analyzer scope.** Run
    `cd mobile && flutter analyze`, which covers the `mobile` package in one
    pass. Positional directories are supported and are what the repository's
    own pre-push hook uses
    (`scripts/install-hooks.sh:382`, `flutter analyze lib test integration_test`);
    they simply narrow the scope, so prefer the bare form when checking the
    whole package.
12. **Mutation serialization is only process-local.** A future chain can order
    one app process, but two devices or Web and mobile can read the same base and
    publish competing replacements. New events normally need
    `max(now, selectedBase.createdAt + 1,
    lastLocallyIssuedOrAcceptedCreatedAt + 1)` for same-process ordering, because
    the next network-participating read may not return the process's last accepted
    write. The repository must fail or defer safely if that timestamp exceeds
    the relay's accepted future-skew boundary. Cross-device writes still follow
    NIP-01 replaceable-winner behavior.
13. **Filter changes cannot restore a pin omitted during resolution.** The
    current addressable resolver filters block, deletion, transport, expiry,
    and content policy before returning. The existing filter-change handler
    re-filters without refetching. The corrected design must either re-resolve
    missing coordinates when filter policy changes or retain canonical raw
    winners below the Cubit visibility layer.
14. **A nonnull `addressableId` does not prove kind 34236.** The model getter
    hardcodes `34236` for any nonempty addressable `d` value. Pin eligibility
    must also require the source `eventKind` to be the addressable short-video
    kind; a nonnull coordinate alone is insufficient.
15. **Mobile has no sanctioned pin glyph yet.** `DivineIcon` accepts only
    `DivineIconName`, whose current enum has no pin entry, and Mobile has no
    Phosphor dependency or pin asset. Reusing Web's Phosphor `PushPin` visual
    requires adding the selected SVG asset, enum/mapping entry, and mapping
    test; it cannot be requested as though the glyph already exists
    (`mobile/packages/divine_ui/lib/src/icon/divine_icon.dart:9-256`).
16. **Cached events do not establish network participation.** The reachable
    path is Drift: `queryEventsDetailed` reads DAO rows into `cacheResults`,
    then merges them into `events` independently of the `noRelays` result. It
    can therefore return cached events while reporting `noRelays: true`
    (`mobile/packages/nostr_client/lib/src/nostr_client.dart:895-915`,
    `mobile/packages/nostr_client/lib/src/nostr_client.dart:991-1001`). Mutation
    reads must use `relayTypes: RelayType.network`,
    `requireAllRelaysSettled: true`, and refuse both `timedOut` and `noRelays`;
    nonempty events are not enough. The SDK also supports counting cache relays
    as participants, but no production caller registers one at the pinned
    revision, so that is a latent SDK capability, not the running-app
    justification (`mobile/packages/nostr_sdk/lib/relay/relay_pool.dart:2146-2162`).
17. **The base feed can reintroduce a hidden canonical version.** Current
    profile merging keys through helpers based on `stableId` and compares
    `createdAt`, which may come from `published_at`. An older visible copy can
    survive in the base feed even after the canonical pinned version is hidden.
    Suppress every base representation of an active candidate coordinate, not
    only Funnelcake fallback
    (`mobile/packages/videos_repository/lib/src/profile_video_merge.dart:11-35`,
    `mobile/packages/models/lib/src/video_event.dart:1085-1097,1370-1375`).
18. **Signing belongs to the configured signer.** The repository may validate
    and construct the event and orchestrate publication, but `NostrClient` and
    the configured signer own signing. Re-check current-account/owner equality
    immediately before publish and never pass private key material into the
    repository (`nostr_client.dart:470,661-667,765-773`).
19. **Empty and inconclusive mutation reads are different states.** A genuinely
    empty network-participating settled result can start from empty tags and
    content. Timeout, no participating relay, disposal, or incomplete
    settlement must refuse mutation rather than infer an empty list
    (`nostr_client.dart:833-1001`).
20. **Existing identity helpers are unsafe for exact pin coordinates.**
    `stableId` can omit the author, while profile-feed helpers lowercase the
    entire `d` value. Pin identity needs a dedicated type that requires the
    canonical lowercase pubkey and preserves case- and colon-sensitive `d`
    data byte-for-byte
    (`profile_video_merge.dart:11-16`,
    `video_event.dart:1085-1088,1359-1375`). Reuse precedents before writing a
    new parser: `BadgeCoordinate.parse` validates a fixed kind, lowercase hex
    pubkey, and nonempty colon-preserving identifier
    (`mobile/packages/badge_repository/lib/src/badge_coordinate.dart:26-35`).
    Video-specific partial precedents are `CuratedListConverter`'s validator
    (`mobile/packages/curated_list_repository/lib/src/curated_list_converter.dart:243-253`)
    and `DmSharedVideoRef.dTag`
    (`mobile/packages/models/lib/src/dm_shared_video_ref.dart:69-78`). Share the
    appropriate lower-layer contract, not a dependency on badge features.
    Existing timestamp/ID ordering also lives in
    `mobile/packages/creator_sync/lib/src/replaceable_event_order.dart:13-29`
    and `mobile/packages/profile_repository/lib/src/identity_event_selection.dart:12-20`.
    The profile comparator uses publication time rather than raw event time
    (`mobile/packages/videos_repository/lib/src/profile_video_merge.dart:156-172`),
    so preserve that distinction when reusing or extracting common logic.
21. **Separate query and subscription setup creates a lost-update window, and
    current `subscribe()` has no readiness contract.** It returns synchronously
    while SDK relay setup continues asynchronously and exposes no participant
    set. Simply calling subscribe first cannot prove that every query relay was
    covered. Add an awaited combined network snapshot/live primitive that
    attaches buffering before send, reports participating relays, settles the
    initial snapshot across that same set, and then remains live. If an event
    becomes the winner before publication, restart reconciliation rather than
    knowingly signing against a stale base
    (`nostr_client.dart:1193-1294`,
    `mobile/packages/nostr_sdk/lib/relay/relay_pool.dart:1834-1962`).
22. **The last accepted revision is content state, not only a timestamp floor.**
    Funnelcake can acknowledge before storage, so an immediate network read may
    return the prior revision. The repository must retain the complete last
    locally accepted event as a base candidate; otherwise a second mutation can
    use a higher timestamp while still losing the first mutation's tags or
    opaque content (`nostr_client.dart:724-830`; current Funnelcake
    `crates/relay/src/relay.rs:1912-1915,2581-2594,2787`).
23. **Current routing cannot prove fullscreen launch identity.** Profile grid
    routes primarily carry index or event/stable IDs, and current fullscreen
    reconciliation returns `liveVideos` as soon as the target appears
    (`profile_video_feed_view.dart:150`), before the sorted merge at line 152.
    Preserving a future pinned launch sequence must cover both that early return
    and the merge sort. Exact coordinate plus a sequence generation must travel
    in route state; the launch prefix needs an explicit session lifetime
    (`mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart:119-142`,
    `mobile/lib/router/pooled_fullscreen_feed_route.dart:13-69`,
    `mobile/lib/screens/profile_screen_router.dart:566-578`,
    `mobile/lib/widgets/profile/profile_video_feed_view.dart:113-153`).
    There is also an existing author-collision hazard: `indexOfVideoIdentity`
    allows an unscoped stable-ID match when `pubkey` is absent, and returns the
    first event-ID **or** stable-ID match. Both fullscreen resolvers omit
    `pubkey`, while `stableId` can be just `vineId`/`d`. In a multi-author feed,
    an earlier other-author video with the same `d` can win even when the exact
    target event appears later. The grid's `indexOfMatchingVideo` does supply
    pubkey. Thread exact identity through both fullscreen resolvers and add the
    author-collision regression
    (`mobile/lib/utils/video_identity.dart:5-29`,
    `mobile/lib/blocs/fullscreen_feed/fullscreen_feed_bloc.dart:357-361`,
    `mobile/lib/widgets/profile/profile_video_feed_view.dart:167-175`).
24. **Code policy is not a release compatibility check.** The audit did not
    verify production `disallowed_kinds` or every target environment's normal
    read/write path. Before Web's shape is treated as proven compatible, an
    authorized test must verify publish/readback through Web's actual default
    routing; before Mobile release, it must also cover each target environment
    and normal Mobile path. A minority-relay `OK` is insufficient evidence that
    ordinary reads surface the list. No probe was published for this review.
    Old signed test revisions may remain even after an empty replacement.

## Recommended mobile decisions and known divergence

The consolidated report proposes these Mobile product choices, pending
@Chardot's review under #3868/#4342. In particular, 12 is an unvalidated working
cap, not an established requirement; badge geometry, one-grid presentation,
recovery flow, and English copy also await signoff:

- mobile prepends new pins and displays newest pin first;
- mobile caps creator-managed pins at 12;
- mobile manages and displays only owner-authored video coordinates;
- foreign and otherwise unrelated tags remain preserved as unrelated data.

The audit records their consequences: Divine Web currently appends, limits
adding at three, and displays
foreign-authored coordinates. Web will read more than three but refuses another
addition whenever the list already contains at least three video tags. Any Web
convergence is separate cross-repo work, not a hidden prerequisite of this
mobile task.

## Report Recommendations for Edge Cases

### 1. Web-written or mixed-client order

Web preserves stored tag order for the coordinate subset it displays. The
recommended Mobile design would also preserve stored order, but Mobile prepends
while Web appends. Without per-item timestamps, Mobile cannot infer a global pin
chronology for an existing Web-written or mixed-client sequence. Treat stored
order as authoritative and guarantee only that a Mobile Pin action moves that
video to the front.

### 2. Cap counting and imported lists over 12

Open Nostr data can exceed a local creator cap. Count every unique valid
owner-authored stored reference, including unresolved or hidden references.
Display from the first 12 candidates, preserve the complete event, permit
Unpin, and reject new Pin actions while the managed count is at or above 12.
Because invisible rows otherwise create a permanent cap lockout, an owner-only
recovery screen must list every managed coordinate independently of resolution
and allow exact removal without exposing or truncating the raw coordinate. A
resolved-but-hidden entry must use the same neutral placeholder as an unresolved
entry and expose no filtered metadata. Status is two-dimensional: visibility
takes precedence, then active-candidate versus overflow position.
Only visible videos resolved from those first 12 candidates are active displayed
pins and receive the badge, pin-rank semantics, and pinned-first position. A
stored overflow member can appear later through the base feed without the badge
or pinned semantics, while still offering Unpin to remove that stored entry.

### 3. Pin action while the first snapshot loads

Disable Pin until the first cache/relay snapshot establishes current membership
and count. Do not guess or publish from an unknown base.

### 4. Legacy or non-addressable video action

Omit Pin for a legacy/non-addressable video. Eligibility must use the source
event kind plus a nonempty `d` value, not `addressableId != null` alone.

### 5. Explicit actions and uncertain outcomes

Pin and Unpin remain idempotent intents after reconciliation; stale UI must
never turn one into the other. Definite failure may offer Retry, but timeout or
a lost acknowledgement offers Check again. Both actions perform a fresh
network-participating read before any publish, and an already-satisfied intent
finishes as a no-op.

### 6. Fullscreen session order

Freeze the grid's published-video launch snapshot for the fullscreen session.
Append unseen base pages without re-sorting the prefix, update canonical
metadata in place, and defer pin-order revalidation until the next grid or
fullscreen opening. Carry exact coordinate and sequence generation in in-app
route state; keep index-only URL restoration explicitly best-effort.

### 7. Accessible invocation and semantic position

Expose Pin/Unpin as custom semantics actions in addition to long-press. Define
pin rank as rank among visible active pins and grid position as the actual
rendered position, including owner-only upload placeholders. Preserve focus by
exact coordinate and announce a material revalidation reorder once.

## Implementation choices, not product facts

The following may be reasonable, but they must be justified as implementation
choices rather than treated as protocol requirements or established product
facts:

- SharedPreferences as the cache backend;
- caching the complete selected raw event;
- inserting rewritten managed tags at the first managed-tag slot;
- preserving extra fields on surviving managed tags;
- serializing mutations per owner;
- the exact cache backend, schema, expiry, and corruption behavior;
- the exact mutation result enums and internal retry state shape.

The Phosphor `PushPin` glyph has a current Divine Web precedent. Reusing it in
Mobile is a proposal pending @Chardot, not a Nostr requirement or recorded
signoff; implementation still has to add and verify the bundled asset.

## Evidence matrix

| Claim | Evidence | Verdict | Required treatment |
|---|---|---|---|
| Kind `10001` standardizes pinned kind-1 notes with `e` tags | [NIP-51 lines 19-29](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/51.md#L19-L29) | Verified NIP fact | Describe video `a` tags as a Divine extension. |
| NIP-51 recommends append order | [NIP-51 lines 9-13](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/51.md#L9-L13) | Verified SHOULD-level recommendation | Keep the recommended Mobile prepend, but document the deviation. |
| Kind `34236` is addressable short video | [NIP-71 lines 23-32](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/71.md#L23-L32) | Verified NIP fact | Use full `a` coordinates; qualify stability by unchanged author and `d`. |
| Equal-timestamp replaceable winner uses lower event ID | [NIP-01 lines 97-103](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/01.md#L97-L103) | Verified recommendation for replaceable events | Apply to kind 10001; label its use for addressable videos as Divine policy and retain the backend-candidate limitation. |
| Divine Web code uses kind `10001` plus video `a` tags | Divine Web commit [`0058e2f5`](https://github.com/divinevideo/divine-web/commit/0058e2f51091501e0cf04fe3018f05fff0460eb9) | Verified code precedent; runtime readback unverified | Treat reuse as conditional on Web/default-path readback; do not call it standard NIP-51. |
| Replaceable-range kinds automatically pass Funnelcake's kind-allowlist gate | Funnelcake commit [`7dcb41c6`](https://github.com/divinevideo/divine-funnelcake/commit/7dcb41c6e5e3f112ff699901743fbe5291c7e647), `crates/relay/src/relay.rs:2159-2226` | Verified gate policy, not production state or final admission | Qualify explicit disallow and every later admission check. |
| `limit: 1` can hide the expected tie winner | `mobile/packages/nostr_client/lib/src/nostr_client.dart:1865-1912` | Verified current defect | Query without the limit or fix the client comparator first. |
| Cubit updates can drop the pin overlay or corrupt pagination boundaries | `mobile/lib/blocs/profile_feed/profile_feed_cubit.dart:204-207,255-258,299-302,404-460,510-516,536-538,576-579,631-633,648-659,678,727-744`; `mobile/packages/models/lib/src/video_event.dart:1090-1097` | Verified risk for future pin integration | Centralize all emits/comparisons. The proposed cursor changes filtered/`createdAt` to raw/`nostrCreatedAt` for unpinned profiles too; test that separately. |
| Addressable resolution is arrival-order dependent and can reintroduce a filtered winner through fallback | `mobile/packages/videos_repository/lib/src/videos_repository.dart:1529-1629` | Verified current defect | Canonicalize raw candidates across sources before applying visibility once, or separately track raw-resolved coordinates so fallback cannot replace a hidden canonical winner. |
| Grid tap navigation can discard the sequence actually rendered | `mobile/lib/widgets/profile/profile_videos_grid.dart:249-252,315-339,425-430` | Verified current integration risk | Use the rendered published list for index, prefetch, and fullscreen seed, and thread the exact addressable coordinate. |
| Mobile has no sanctioned pin icon | `mobile/packages/divine_ui/lib/src/icon/divine_icon.dart:9-256` and `mobile/assets/icon/` at pinned `origin/main` | Verified current design-system gap | Add the selected Phosphor SVG asset, `DivineIconName` mapping, and mapping test rather than assuming a dependency. |
| Snackbar-only announcement violates repo policy | `.claude/rules/accessibility.md:83-111` | Verified policy conflict | Use `SemanticsService.sendAnnouncement` and test it. |
| `e` identifies an event and `a` identifies an addressable coordinate | [NIP-01 lines 78-82](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/01.md#L78-L82) | Verified NIP fact | Store full kind/pubkey/`d` coordinates for replaceable videos. |
| NIP-51 public items live in tags and private items may live in encrypted `content` | [NIP-51 lines 9-13](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/51.md#L9-L13) | Verified NIP fact | Preserve selected-base unrelated tags and `content` byte-for-byte. |
| `OK true` means accepted by that relay, not durable everywhere | [NIP-01 lines 156-168](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/01.md#L156-L168), `mobile/packages/nostr_client/lib/src/nostr_client.dart:742-761` | Verified protocol/client fact | Gate local progress on `acceptedByAny`; never tell the user it is durably saved. |
| Drift-backed results can contain events with `noRelays: true`; subscribe exposes no readiness/participants | `mobile/packages/nostr_client/lib/src/nostr_client.dart:895-1001,1193-1294`; `mobile/packages/nostr_sdk/lib/relay/relay_pool.dart:1834-1962` | Verified current client limitation | Add an awaited combined snapshot/live primitive over `RelayType.network`; require same-set settlement and refuse timeout/no participants. Cache may add candidates but cannot satisfy the gate. |
| Same-second replacement writes need monotonic time, subject to relay future-skew rejection | [NIP-01 lines 97-103](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/01.md#L97-L103), `mobile/lib/utils/nostr_replacement_timestamp.dart:7-16`, Funnelcake `crates/relay/src/relay.rs:1994-2010` and `crates/relay/src/config.rs:233,271-273` | Verified code constraint, not deployed configuration | The default future allowance is 60 seconds with no past bound in this check; `MAX_CREATED_AT_DRIFT_SECS` can override it. Mobile's `NostrTimestamp.now()` defaults to a 30-second backdate (`mobile/lib/utils/nostr_timestamp.dart:47-56`). Floor against the selected base and last issued/accepted time; fail/defer if the required timestamp exceeds the relay allowance rather than clamping below that floor. |
| Web pin mutations erase opaque `content` | Divine Web `src/hooks/usePinnedVideos.ts:101-108,143-152` at pinned `origin/main` | Verified current Web defect | Do not copy this behavior into mobile; track Web correction separately. |
| Web kind-10001 reads limit before applying the ID tie-break | Divine Web `src/hooks/usePinnedVideos.ts:41-51,73-84,131-141` at pinned `origin/main` | Verified current Web defect | Record cross-client divergence; Web correction is separate scope. |
| Filter changes do not re-resolve omitted pins | `mobile/lib/blocs/profile_feed/profile_feed_cubit.dart:671-678`, `mobile/packages/videos_repository/lib/src/videos_repository.dart:1688-1730` | Verified current integration risk | Re-resolve on filter-policy changes or retain canonical raw winners below visibility filtering. |
| `addressableId` alone does not prove source kind 34236 | `mobile/packages/models/lib/src/video_event.dart:528-531,812,1359-1368` | Verified model limitation | Check `eventKind` and nonempty `d` for pin eligibility. |
| Existing profile identity helpers alter exact coordinate semantics | `mobile/packages/videos_repository/lib/src/profile_video_merge.dart:11-16`; `mobile/packages/models/lib/src/video_event.dart:1085-1088,1359-1375` | Verified current integration risk | Use a dedicated coordinate type; require canonical lowercase pubkey and preserve `d` byte-for-byte. |
| Invisible stored members can permanently consume the cap | Prior design ordering/cap rules plus tile-only ordinary Unpin entry point | Verified prior-draft product deadlock | Require recovery removal independent of video resolution and test 12 unresolved members. |
| A last accepted event may not appear in an immediate read | `mobile/packages/nostr_client/lib/src/nostr_client.dart:724-830`; current Funnelcake enqueue/OK/storage paths | Verified integration constraint | Retain the complete accepted revision as a base candidate, not only its timestamp. |
