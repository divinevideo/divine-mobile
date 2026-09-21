# Social Sounds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Use superpowers:subagent-driven-development only when parallel agent work is explicitly authorized. Steps use checkbox syntax for tracking.

**Goal:** Let people discover, privately collect/import, and reuse sounds with correct public credit from Discover, their library, and video creation.

**Architecture:** Extend existing sound, video, and API packages through injected Flutter-free interfaces. Use one BLoC-backed browser with browse and draft-selection hosts; keep library persistence, public attribution, action-time permissions, and navigation separate.

**Tech Stack:** Flutter, Dart workspace packages, BLoC/Cubit, existing Riverpod composition, go_router, Nostr audio/video events, Funnelcake REST, Divine sound proxy, existing media import/render and encrypted creator-sync services.

**Spec:** [Social sound discovery and reuse](../specs/2026-09-21-social-sounds-design.md)

## Global constraints

- Discover gains Sounds as its rightmost tab. My Library → Sounds stays a private collection.
- Preserve the rich saved-card visual direction; adapt surfaces through context.vineColors.
- Public sound title and original creator credit must survive every adapter and reuse.
- New Divine audio requires creator opt-in. Verified archive audio uses authoritative policy and respects takedowns/rollout.
- Private import/save is not a public sound publication or remix grant.
- Keep the full imported sound; trim when attaching it to a video.
- Saved/editor-carried permission is revalidated at use and publication.
- Do not send private library metadata to public discovery services.
- New UI state uses BLoC/Cubit. Repositories and blocs do not depend on Flutter UI types.
- Reuse existing packages, protocols, provider normalization, persistence, and media tools.
- No unrestricted link download or automatic third-party saved-library synchronization.
- No source/permission/metric invented from a missing value.
- Preserve drafts, account isolation, encrypted sync, and original-audio volume.
- No new app/backend implementation is authorized merely by writing this plan.

## Delivery slices and dependency order

This is a coordinated program with independently shippable slices, not one enormous
mobile PR. Each implementation slice starts from fresh origin/main. Dependent tasks
inside a slice ship together. A later slice starts after its prerequisites merge;
never stack a PR onto another feature branch.

| Slice | Tasks | User-visible result | Prerequisites |
| --- | --- | --- | --- |
| A: import and organization | 2–3 | Add sound in library, private collections, durable files | None; does not require discovery or archive rollout |
| B: identity, permission, actions | 1, 4 | Correct credit; Save means save; Use enters creation | Existing archive-policy work lands, or equivalent owner-coordinated integration |
| C: discovery | 5–7 | Rightmost Sounds tab, search, Following, classics, recent and honest trending | B; server ranking contract below for weekly trending |
| D: create and publish | 8–9 | Same picker in creation and publish; audible final render; optional nudge | B/C |
| E: verified external links | 10 | Supported provider links enter the private library with provenance | A/B; verified resolver capability |

File import in A already supports audio exported by other apps. E covers additional
link entry, not account-library synchronization. The full product framework is not
complete until all agreed core slices A–D are delivered.

## Evidence checked before writing

Mobile baseline: 3c1056651a56ee9a836cd76cbd65c2c1610bd801.

- Existing library UI/persistence: mobile/lib/widgets/library/sounds_tab.dart,
  saved_sound_card.dart, saved_sound_details_editor.dart;
  mobile/lib/blocs/saved_sounds/; mobile/lib/models/saved_sound.dart;
  mobile/lib/services/saved_sounds_service.dart.
- Existing import and cleanup: mobile/lib/services/local_audio_import_service.dart,
  local_audio_cleanup_service.dart, mobile/lib/utils/draft_audio_path_resolver.dart.
- Current picker: mobile/lib/widgets/video_editor/audio_editor/.
- Current public identity: mobile/packages/models/lib/src/audio_event.dart,
  mobile/lib/models/audio_share_attribution.dart,
  mobile/lib/widgets/video_feed_item/audio_attribution_credit.dart,
  mobile/lib/services/video_publish/video_audio_publisher.dart.
- Existing discovery API and archive-policy dependencies are documented in the spec.
  Live trending/recent GET probes returned 200 arrays; no capability beyond shape
  and reachability was verified.
- Draft PR https://github.com/divinevideo/divine-mobile/pull/8467 owns related
  archive compatibility work. Do not take over, push, or duplicate its implementation.
  Brain prior-art document: 451C238E0922CB0607814751A4.
- The current sound proxy reorders each candidate page using total current uses.
  It does not establish global weekly trends or correctly ordered trend pagination.

## Proposed file ownership

All paths below are relative to divine-mobile unless prefixed with a sibling repo.
New paths are proposed implementation files, not claims that the code already exists.

| Owner | Responsibility and paths |
| --- | --- |
| models package | Preserve normalized sound source/creator/license in mobile/packages/models/lib/src/audio_event.dart |
| sounds_repository | Create src/sound_discovery_models.dart, src/sound_discovery_repository.dart and src/sound_discovery_source.dart; export through lib/sounds_repository.dart |
| funnelcake_api_client | Create src/models/sound_stats.dart; extend src/funnelcake_api_client.dart and model exports for existing sound list/search/stats APIs |
| App composition | Create mobile/lib/repositories/sound_discovery_sources.dart; inject existing video, follows, block/content filtering, API and catalog clients through ports |
| Sound browser | Create mobile/lib/blocs/sound_browser/{sound_browser_cubit,sound_browser_state}.dart and mobile/lib/screens/sounds/{sound_browser_page,sound_browser_view}.dart |
| Reusable cards/actions | Create mobile/lib/widgets/sounds/{sound_card,sound_actions}.dart and mobile/lib/services/sound_action_coordinator.dart |
| Library | Existing SavedSoundsBloc/model/service/sync and widgets; create mobile/lib/screens/sounds/import_sound_page.dart plus mobile/lib/blocs/sound_import/ |
| Discover routing | Existing explore_tabs_state.dart, explore_tab_labels.dart, explore_tab_view.dart, explore_view.dart, explore_screen_router.dart and app_router.dart |
| Draft attachment | Existing video editor/provider and metadata form; create mobile/lib/widgets/video_metadata/video_metadata_sound_section.dart |
| External links | Extend verified SoundLibraryApiClient resolver contract; create mobile/lib/screens/sounds/import_sound_link_page.dart only after capability verification |

## Shared contracts

Keep wire DTOs in clients and domain records in sounds_repository. The following
are proposed interfaces to implement, not existing methods. Define/export every type
before consumers are changed.

```dart
enum SoundBrowseSection { trending, following, classics, recent, saved }
enum SoundBrowserIntent { browse, selectForDraft }
enum SoundRankingBasis { weeklyAdoption, currentUses, recent }
enum SoundReuseStatus { allowed, denied, unknown }

// Stable identity is independent of an editor track's instance id.
typedef SoundKey = String;

class SoundBrowseRequest {
  const SoundBrowseRequest({
    required this.section,
    this.query = '',
    this.cursor,
    this.viewerPubkey,
    this.limit = 20,
  });
  final SoundBrowseSection section;
  final String query;
  final String? cursor;
  final String? viewerPubkey;
  final int limit;
}

class SoundDiscoveryItem {
  const SoundDiscoveryItem({
    required this.key,
    required this.audio,
    required this.exampleVideos,
    this.creditedCreatorName,
    this.privateName,
    this.collections = const [],
    this.usesInWindow,
    this.distinctCreatorsInWindow,
    this.windowStart,
    this.windowEnd,
  });
  final SoundKey key;
  final AudioEvent audio;
  final List<VideoEvent> exampleVideos;
  final String? creditedCreatorName;
  final String? privateName;
  final List<String> collections;
  final int? usesInWindow;
  final int? distinctCreatorsInWindow;
  final DateTime? windowStart;
  final DateTime? windowEnd;
}

class SoundDiscoveryPage {
  const SoundDiscoveryPage({
    required this.items,
    required this.rankingBasis,
    this.nextCursor,
  });
  final List<SoundDiscoveryItem> items;
  final SoundRankingBasis rankingBasis;
  final String? nextCursor;
}

abstract interface class SoundDiscoverySource {
  Future<SoundDiscoveryPage> fetch(SoundBrowseRequest request);
}

abstract interface class SoundDiscoveryRepository
    implements SoundDiscoverySource {}

abstract interface class SoundReuseChecker {
  // Implement using the authoritative policy work, not a second grant policy.
  Future<SoundReuseStatus> check(SoundDiscoveryItem item);
}
```

These snippets import AudioEvent and VideoEvent from models. Domain implementations
must add value equality and immutable collection handling following package style.

Identity rules:
- Published audio: original full event id from attributionEventId, not timeline id.
- Original video audio: full logical video coordinate, not its changing revision id.
- Provider sound: provider id plus provider's stable sound id.
- Local import: unique persistent import id, not filename or display label.
- Private names never overwrite AudioEvent.title or public creator/source metadata.
- Promotion from original video audio to a published audio reference needs an explicit
  alias/merge in saved-library identity; never merge distinct works merely by title.
  Do not invent a new on-relay identifier or automatically rewrite signed events.

Browse mode actions are Save and Use. Selection mode returns AudioEvent to its host;
the host attaches it. A return value is not permission to publish without a fresh check.
Use the same canonical key for saved status, counts, and the sound page.

## Task 1: Integrate authoritative eligibility and stable public credit

**Files:** Existing audio_event.dart, audio_reuse_consent_resolver.dart,
sounds_providers.dart, audio_attribution_credit.dart, audio_attribution_row.dart,
metadata_sounds_section.dart, sound_detail_screen.dart,
video_metadata_audio_sharing_section.dart, video_audio_publisher.dart.
**Tests:** Existing test/services/audio_reuse_consent_resolver_test.dart,
test/widgets/audio_attribution_row_test.dart, test/widgets/metadata_sounds_section_test.dart,
test/services/video_publish/video_audio_publisher_test.dart; models audio-event tests.
**Consumes:** Current backend audio-reuse policy and coordinated archive PR.
**Produces:** SoundReuseChecker adapter, canonical public source identity and credit.

- [ ] Re-read the current archive PR state and backend policy without modifying the
  other author's branch. If not merged, A may proceed while B waits for coordination.
- [ ] Reproduce fallback attribution with synthetic cases: publisher B using creator
  A's sound; an unrelated inspired-by C; bundled/catalog sound with supplied artist;
  missing referenced event; private imported name differing from public title.
- [ ] Add failing tests asserting source creator A remains credited, inspired-by C
  never becomes audio authorship, and unknown credit remains unknown.
- [ ] Add the policy matrix: ordinary opt-in/off; verified archive on/off rollout;
  active takedown; stale/missing/malformed policy; owner; account switch; retry.
  Reuse the canonical implementation and its existing test fixtures once merged.
- [ ] Preserve creator/source/license fields in bundled and catalog conversions.
  Separate source-video context, publisher, and credited creator in shared display.
  Preserve an existing source reference at publication.
- [ ] Make the public name optional for owned audio by deriving the neutral fallback
  before validity checks; keep imported attribution requirements separate.
- [ ] Test canonical identity through a timeline instance suffix, source-video edit,
  save/reopen, and reuse publication. No duplicate sound page or uncredited republication.
- [ ] Run affected model/service/widget tests and analyze; commit this slice with
  only task files staged.

A minimum pure-model regression belongs in the existing audio-event suite:
```dart
test('bundled conversion keeps creator credit distinct from its publisher', () {
  final audio = AudioEvent.fromBundledSound(
    VineSound(
      id: 'synthetic-loop',
      title: 'Short loop',
      artist: 'Example artist',
      assetPath: 'assets/sounds/example.mp3',
      duration: const Duration(seconds: 6),
    ),
  );
  expect(audio.creatorName, 'Example artist');
  expect(audio.title, 'Short loop');
});
```
Confirm the current VineSound constructor when implementing; retain its supplied
source/license fields as additional assertions.

## Task 2: Import directly into My Library

**Modify:** sounds_tab.dart, local_audio_import_service.dart,
local_audio_cleanup_service.dart, SavedSoundsBloc/Service only as needed.
**Create:** import_sound_page.dart and sound_import_cubit.dart/state.dart.
**Tests:** Existing sounds_tab_test.dart, local_audio_import_service_test.dart,
saved_sounds_bloc_test.dart; create sound_import_cubit_test.dart and import_sound_page_test.dart.
**Consumes:** LocalAudioImportService.importAudioFile and SavedSoundsBloc.saveSound.
**Produces:** Durable private imported AudioEvent/SavedSound without a draft.

- [ ] Add a widget regression that Add sound is present in empty/populated release
  UI and opens import directly, never AudioSelectionBottomSheet or timing.
- [ ] Add lifecycle tests for cancellation, unreadable/unsupported file, decoder
  failure, failed durable save, double submit, account change, restart, and draft
  deletion. A failed operation reports retryable failure without false Saved state.
- [ ] Implement file selection → library-owned copy → preview/name → durable save.
  Reuse the existing supported formats. Probe actual decodability; extension alone
  is not validation. Keep the entire source regardless of video duration.
- [ ] Dispose preview on navigation. Clean a canceled/failed unsaved import only
  after checking no saved record/draft owns it. Never delete the picked source file.
- [ ] Keep private naming separate from public attribution and avoid automatically
  launching the label editor after every ordinary Save.
- [ ] Preserve existing encrypted-sync wiring and truthful missing-media state.
  Update copy that incorrectly claims all saved metadata is device-only.
- [ ] Run import, library, cleanup, and BLoC tests; analyze and commit.

Core call sequence (inside the injected app import coordinator, not a widget):
```dart
final audio = await importService.importAudioFile(
  sourcePath: selectedPath,
  displayName: selectedName,
);
final result = await savedSoundsBloc.saveSound(audio);
// Emit success only after this future succeeds in the initiating account.
```
Capture initiating account identity before selection. If the account changes,
cancel the operation and clean only its unreferenced copy. Do not look up a new
account's bloc after the asynchronous copy.

## Task 3: Collections and recognizable saved entries

**Modify:** SavedSound model/serialization, SavedSoundsState/Event/Bloc,
saved_sound_details_editor.dart, saved_sound_card.dart, sounds_tab.dart and sync tests.
**Tests:** saved_sound_test.dart, saved_sounds_service_test.dart,
saved_sounds_bloc_test.dart, saved_sounds_local_store_test.dart and library widget tests.
**Consumes:** Existing saved record and encrypted sync envelope.
**Produces:** Private collections included in saved display/search.

- [ ] Add optional collections: List<String> to SavedSound with an empty default.
  Trim surrounding whitespace, preserve ordinary internal spaces, deduplicate names
  case-insensitively, and retain the first display casing.
- [ ] Test reading old records unchanged; serialize/restore collections through
  encrypted sync; verify public publisher input contains no collection or nickname.
- [ ] Provide Add to collection after save and Organize under More. Creating a
  collection assigns its first item; do not introduce empty-collection storage.
- [ ] Keep existing hashtags intact and searchable. Search private name, collections,
  title, creator, and saved source context consistently in Library and picker.
- [ ] Make original sound title/creator distinct from source-video caption and private
  name. Move edit/remove into More; leave room for Use from Task 4.
- [ ] Run model, BLoC, service, sync, and widget tests; analyze and commit.

Example assertion added to the existing saved-record round-trip test:
```dart
expect(restored.collections, ['Next video', 'Funny voices']);
expect(restored.audio.title, original.audio.title);
expect(restored.audio.creatorName, original.audio.creatorName);
```
Use that test's original/restored records, with collections added before serialization.
No production data or creator identifiers belong in fixtures.

## Task 4: Separate Save, Preview, and Use sound

**Create:** sound_action_coordinator.dart and shared sound_actions.dart.
**Modify:** sound_detail_screen.dart, saved_sound_card.dart, sounds_tab.dart,
feed/metadata sound rows, app_router.dart and recorder handoff.
**Tests:** sound_detail_screen_test.dart, saved_sound_card_test.dart,
sounds_tab_test.dart and new sound_action_coordinator_test.dart.
**Consumes:** Task 1 identity/eligibility and existing selected-sound/draft routing.
**Produces:** Predictable browse actions and source-preserving creation handoff.

- [ ] Add failing regressions: Save persists without navigation; Use enters creation
  with the chosen source and never just saves; a saved card can Use; a denied/unknown
  policy does not attach media; retry rechecks rather than reuses the old answer.
- [ ] Keep existing drafts intact when starting a new creation. Preserve normal
  camera/upload choices and do not force lip-sync or discard recorded clips.
- [ ] Render one-tap Save/Saved state backed by durable library state. Failed saves
  return to unsaved with retry; preview does not change selection or saved state.
- [ ] Give eligible original audio the same feed sound affordance as shared audio.
  Credit remains visible when unavailable; permission state explains why Use is absent.
- [ ] Make the sound page show source credit and paginated example videos, preserving
  scroll position when returning from an example.
- [ ] Verify pause/resume ownership across feed → sound → preview → camera/back.
- [ ] Run routing, sound detail, library, and attribution widget tests; analyze; commit.

Browse-host contract:
```dart
await coordinator.startCreation(item);
```
Define Future<void> startCreation(SoundDiscoveryItem item) on
SoundActionCoordinator. For this independently shippable slice, adapt the existing
sound-detail/library data into SoundDiscoveryItem and use the current recorder route.
Do not depend on the future browser UI. Task 6 introduces the draft-selection host.
The coordinator injects SoundReuseChecker, media preparation and navigation ports;
repositories never receive BuildContext.

## Task 5: Verify and connect discovery data

**Create:** Shared contracts/files above; typed sound DTO/client tests and repository tests.
**Modify:** sounds_repository exports/composition and funnelcake_api_client model exports.
**Consumes:** Existing list/search/stats/catalog APIs and injected filtered video sources.
**Produces:** SoundDiscoveryRepository backed by SoundDiscoverySource.

- [ ] Write HTTP fixture tests for current bare-array list responses, search, pagination,
  nullable source/creator/duration, malformed rows, timeouts, and error retry.
  HTTP 200 without expected fields is a contract failure, not an empty success.
- [ ] Implement direct Funnelcake methods in funnelcake_api_client, then inject them.
  Wire the existing catalog client instead of embedding provider credentials in mobile.
- [ ] Hydrate public sound metadata from its authoritative audio event when list stats
  contain only publisher author_name. Never map author_name to creatorName blindly.
  Retain visible browse entries when optional counts fail, with unknown counts.
- [ ] Define bounded pages of 20 results; batch hydration and eligibility work;
  paginate without one sound/video HTTP query per row.
- [ ] Build Following from the existing recent followed-video source, grouping public
  uses by canonical sound key. Carry example videos from the same filtered source.
  Deduplicate logical video revisions and repeated creator identities; exclude
  blocked/muted/filtered content. Cache by viewer and reset on follow/account changes.
- [ ] Consume up to three source pages per load to find usable sounds, retaining the
  source cursor so Load more continues. Label the result Recent uses by people you
  follow; do not claim an exhaustive friend count from this bounded scan.
- [ ] Build Classics from existing classic-video retrieval plus authoritative archive
  policy. Do not rely solely on the display-only isOriginalVine getter.
- [ ] When a new filter/query supersedes a request, discard its late result; retain
  independent scroll/cursor state per section; one provider error cannot erase Saved.
- [ ] Run HTTP/repository tests, dependency-cycle guard, analyze, and commit.

Repository test specification using the proposed request:
```dart
final page = await repository.fetch(
  const SoundBrowseRequest(
    section: SoundBrowseSection.following,
    viewerPubkey:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  ),
);
expect(page.items.map((item) => item.key).toSet().length, page.items.length);
expect(page.items.every((item) => item.exampleVideos.isNotEmpty), isTrue);
```
Construct the repository with a fake followed-video source containing two revisions
of one video and a friend's reuse of another creator's audio. Verify that the reuse
appears once and the credited creator stays the source creator. Anonymous fetch
must produce a typed sign-in-required state before invoking that source.

## Server gate: truthful weekly trending

This is a separately owned service sub-project, required before the complete
Trending experience is released. It must have its own detailed service plan and
query-cost review under that repository's instructions before schema/query edits.
This mobile plan defines the acceptance contract; it does not authorize deployment.

Existing service work can supply Recent and explicitly labeled Most used while
this gate is open. Neither may be labeled Trending this week as a substitute.

**Proposed extension, not a deployed claim:**
GET /api/sounds?sort=trending&window=7d retains the array response and adds
uses_in_window, distinct_creators_in_window, previous_distinct_creators,
window_start, window_end, ranking_basis and a stable snapshot/cursor mechanism.
Agree backward-compatible pagination with the service owner before client rollout;
the existing offset mode stays available for existing callers.

Required ranking fixture:
- A: 100 lifetime uses, 1 distinct creator this week, 1 previous week.
- B: 12 lifetime uses, 8 distinct creators this week, 2 previous week.
- C: 30 videos this week, all by one creator.
- B must rank ahead of A and C. Re-edits/reposts cannot manufacture new adoption.

Proposed deterministic ranking: positive increase in distinct creators over the
previous seven days descending; current seven-day distinct creators descending;
most recent qualifying use descending; canonical sound key ascending.
Keep only sounds with at least two qualifying creators in the current window.
Counts describe public qualifying reuse videos, not private saves or previews.

Each logical video counts once, at its original reuse publication time. Include
current video kinds 34235 and 34236; exclude removed/ineligible sources and respect
existing moderation policy. Do not use a metadata revision timestamp as a new use.
A stable snapshot must prevent duplicates/skips when paging a changing ranking.

Evidence required: synthetic fixture tests, measured query/resource cost on realistic
cardinality, exact semantics for counts/window, source identity/credit hydration,
and deployed response verification without persisting real account data.
If service ranking_basis is absent/unknown, the mobile UI shows a named unavailable
state or explicit Most used alternative; it never relabels total count as weekly.

## Task 6: Shared sound browser and cards

**Create:** sound_browser_cubit.dart/state.dart, sound_browser_page.dart/view.dart,
sound_card.dart; tests under test/blocs/sound_browser and test/screens/sounds.
**Consumes:** Tasks 4–5 repository/actions and saved library state.
**Produces:** Browse host and AudioEvent-returning selection host.

Define Future<AudioEvent?> openSoundBrowserForSelection(BuildContext context)
in sound_browser_page.dart. It opens the same View with selectForDraft intent and
returns null on cancellation. Task 8's host checks that its initiating draft is
still current before applying the returned audio.

- [ ] Write tests for loading, result, empty, failure/retry, sign-in-required,
  unavailable policy, and missing optional credit/count/thumbnail.
- [ ] Add race tests: type two queries with responses reversed; switch section,
  account, or close browser mid-preview; stale result must not overwrite current state.
- [ ] Implement shared vertical rich cards: public title/credit, source context,
  preview, Save/Saved, Use, and example-video navigation. Private context appears
  only in the viewer's Saved section.
- [ ] Search all supported public sources when discovering; search the local saved
  record when in Saved. Expose source/filter scope clearly.
- [ ] In selectForDraft mode, return the source AudioEvent and offset; do not navigate
  to camera or save automatically. In browse mode, use Task 4's coordinator.
- [ ] Keep Saved fast/offline. Show imported missing-media state without dropping the
  record or pretending remote metadata sync restored file bytes.
- [ ] Verify dark/light, large text, accessible action names, loading announcements,
  scroll retention, single audio playback, and media pause on route changes.
- [ ] Run BLoC/widget tests and goldens; analyze; commit.

## Task 7: Sounds as Discover's rightmost tab

**Modify:** explore_tabs_state.dart, explore_tab_labels.dart, explore_tab_view.dart,
explore_view.dart, explore_screen_router.dart, app_router.dart, route_paths.dart.
**Create:** mobile/lib/screens/explore/tabs/explore_sounds_tab.dart.
**Tests:** explore_tabs_cubit_test.dart, explore_tabs_featured_test.dart,
explore_tab_labels_test.dart, explore_tab_route_test.dart,
explore_tab_navigation_test.dart and explore_tab_tap_navigation_test.dart.
**Consumes:** Shared browse host.
**Produces:** Stable sounds tab and /explore/sounds navigation consistent with routing.

- [ ] Add const exploreSoundsTabName = 'sounds' and append it after optional Apps
  and all other tabs. Preserve stable name/index conversion and featured insertion.
- [ ] Add tab/URL tests for all optional-tab configurations and restoring Sounds
  after asynchronous availability changes.
- [ ] Add the embedded browser View. Treat Sounds as non-video-grid content so shell
  autoplay/feed mode and buffered-video banners do not activate on it.
- [ ] Wire Find sounds from My Library to this tab and Saved from discovery to the
  existing saved-library route. Preserve back behavior and direct-link restoration.
- [ ] Add localized label and analytics through existing contracts; no ad hoc event
  schema, private labels, or raw user identity in new analytics.
- [ ] Run explore routing/state/widget tests; analyze; commit with Task 6 if dependent.

Regression to add alongside existing tab-state fixtures:
```dart
final state = ExploreTabsState(
  classicsAvailable: true,
  forYouAvailable: true,
  appsAvailable: true,
);
expect(state.tabNames.last, exploreSoundsTabName);
expect(state.nameForIndex(state.indexForName(exploreSoundsTabName)), 'sounds');
```
Repeat with the existing featured-tab fixture and optional tabs unavailable.

## Task 8: Connect camera/editor and publishing to the same picker

**Modify:** audio_selection_bottom_sheet.dart, video_editor_audio_chip.dart,
video_editor_screen.dart, video_editor_provider.dart and owning state,
video_metadata_screen.dart, video_metadata_form_fields.dart.
**Create:** video_metadata_sound_section.dart.
**Tests:** Existing audio_selection_bottom_sheet_test.dart and relevant editor/metadata
tests; create video_metadata_sound_section_test.dart and sound attachment integration test.
**Consumes:** Shared selection host, permission and identity contracts.
**Produces:** Consistent attachment and audible final output.

- [ ] Replace duplicated catalog/category/search logic with the shared browser host.
  Preserve source/private display metadata until the host extracts AudioEvent.
- [ ] Test attach, replace, trim, remove, cancel, and switching back to Saved without
  losing private search labels or the current draft.
- [ ] Add publishing Sound row: selected title/credit or Add sound. Selecting routes
  through the editor audio pipeline while preserving caption, cover, collaborator
  choices, warnings, and all other draft state.
- [ ] Invalidate the prior render after an audio change; rerender through existing
  processing states. Disable posting during the required render. Cancel/failure
  keeps a retryable draft rather than uploading mismatched audio/credit.
- [ ] Preserve original/added volume separately; audition against current video;
  apply timing once rather than opening a second trim flow.
- [ ] Recheck permission before use and publish. Preserve explicit public opt-in
  for newly shared own/imported sounds; reuse references original shared sound.
- [ ] Run attachment tests with synthetic audio/video and inspect the rendered audio,
  not only the selected-sound provider. Verify saved draft/reopen yields the same mix.
- [ ] Run editor/metadata/publisher tests; analyze; commit.

## Task 9: Optional sound encouragement

**Modify:** video metadata sound section and draft model/serialization.
**Tests:** metadata sound section and draft round-trip tests.
**Consumes:** Current added-track state and reliable mute/audio-track metadata.
**Produces:** Dismissible per-draft suggestion without changing sound automatically.

- [ ] Add a persisted soundSuggestionDismissed flag defaulting false for old drafts.
- [ ] Test no added sound shows Try a sound, dismissal survives back/reopen,
  selection removes the prompt, and speech/captions absence is not a mute signal.
- [ ] Show a compact Add sound prompt for no added sound; emphasize it only when
  audio is explicitly muted/absent. Skip speculative speech recognition work.
- [ ] Reuse the shared browser and keep Publish immediately available when skipped.
- [ ] Test original ambient audio remains unchanged until an explicit user action.
- [ ] Run draft/widget tests; analyze; commit with Task 8 if tightly coupled.

## Task 10: Bring supported sound links into the library

**Modify:** SoundLibraryApiClient only for a verified resolver contract and app link
routing; create import_sound_link_page.dart and resolver tests.
**Consumes:** Existing Divine routes, catalog resolver and durable private-save flow.
**Produces:** Supported link → preview/credit → Save or Use.

- [ ] Verify request/response and enabled providers against the current proxy
  implementation; add scrubbed synthetic contract fixtures before client changes.
  A provider registry entry alone does not prove a resolvable media capability.
- [ ] Accept Divine sound links through existing source identity. Enable each catalog
  URL only after its resolver tests return usable media plus creator/source/license.
- [ ] Test unsupported URLs, redirect targets, inaccessible/private media, missing
  attribution, cancel, and network failure. Offer file import for unsupported links.
- [ ] Do not dereference arbitrary user URLs in mobile or infer reuse from possession.
  Retain provenance separately from private naming.
- [ ] Save using the same durable import/library flow; never auto-publish.
- [ ] Verify cross-platform link entry plus affected repository/widget tests; analyze;
  commit. Native inbound share extensions remain outside this slice.

## Verification and delivery checklist for every implementation slice

Commands run from mobile unless shown from repository root. Test paths above are
relative to mobile; new tests are created as part of their owning task.

```bash
flutter pub get
flutter test test/widgets/library/sounds_tab_test.dart test/widgets/library/saved_sound_card_test.dart test/services/local_audio_import_service_test.dart
flutter analyze lib test integration_test
```

Run only relevant focused suites initially, then broaden when changes justify it.
For workspace packages, run their package-local suites from the owning package using
the repo's current package test workflow. Regenerate code only when inputs changed.

- [ ] Load check-l10n/divine-mobile localization guidance; regenerate localization;
  all added visible text uses l10n and adaptive colors/shared Divine components.
- [ ] Run relevant guards including package boundaries/cycles, logging, and permission
  tests. Never truncate public IDs or log secrets.
- [ ] Golden-check dark/light and large text on the new/changed screens.
- [ ] Device walkthrough on iOS and Android: discover → save → use; import → restart
  → use; following reuse; verified classic; opted-out source; offline policy failure;
  publish-time selection and final playback; account change; missing local file.
- [ ] Performance check: one active preview, bounded page work, batched hydration,
  no per-row policy/count waterfall, no eager playback of every example.
- [ ] Confirm all shipped routes have truthful empty/error states. Do not ship a
  fake Trending filter, a broken Add sound action, or a nonfunctional Use button.
- [ ] Rebase onto fresh origin/main before publishing; stage only task-owned files;
  commit/push and open the slice PR against main with Conventional Commit title.
- [ ] Request mapped reviewers; inspect required CI to completion and resolve
  introduced failures. Policy/publication changes require the applicable human review.
- [ ] Report exact completed slices and unresolved dependency states. Do not call the
  full framework complete just because the library-only slice ships.

## Success measures

Baseline before rollout using the canonical analytics contract and aggregate measures:
time to first successful preview; discovery → save/use; saved/imported → published
video; completion after adding sound; correct-credit/permission failures; playback
and import failures. Segment by entry point, not private labels or sound collections.
Instrument a new metric only through the shared analytics schema.

The decisive acceptance walkthrough is: someone finds a sound they never saved,
recognizes who made it, saves it in one action, returns later, makes a video with it,
and publishes a video whose audible sound and displayed credit match the selection.
