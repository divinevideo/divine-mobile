# Search & result-surface filtering: the blocked-author contract

This document is the canonical reference for **how blocked-author
filtering is applied across search and result surfaces** in the mobile
app. It is the implementation answer to the parent search epic's
acceptance criterion *"Search result filtering rules are documented and
validated on all relevant result surfaces"* (#3801, #3805) and pins the
contract that the search BLoCs, repositories, and result widgets rely on.

It complements [`PEOPLE_SEARCH.md`](PEOPLE_SEARCH.md) (which covers the
people-search data-source / degradation strategy) and the moderation
docs ([`MODERATION_SYSTEM_ARCHITECTURE.md`](MODERATION_SYSTEM_ARCHITECTURE.md),
[`CONTENT_MODERATION_POLICY.md`](CONTENT_MODERATION_POLICY.md)). This
file does not re-explain the moderation engine; it documents *where* its
decision is enforced on search/result paths.

If you add a new search surface or a new way to render
author-attributed content, apply the predicate below and add it to the
table — then update this file.

## The single block predicate

There is one decision function for "should this author's content be
hidden from this viewer":

- **`ContentBlocklistRepository.shouldFilterFromFeeds(pubkey)`**
  (`mobile/packages/content_blocklist_repository/`) — true when the
  viewer blocked the author (kind-30000 `d=block`), the author blocked
  the viewer, or either muted the other (kind-10000). It composes with
  the content-policy engine (`ContentPolicyEngine.evaluate → Block`).
- The repository-layer injection wrapper is
  **`createBlockedAuthorFilter(ref)`**
  (`mobile/lib/providers/moderation_providers.dart`), which returns a
  `bool Function(String pubkey)` predicate backed by the same engine +
  blocklist state. It is injected into each search repository as a
  nullable `blockFilter` constructor parameter.

Both read the same live blocklist state, so filtering is consistent
across every surface that consults either one. There is exactly **one**
`ProfileRepository` construction in the app (in `repository_providers`),
always wired with the filter — so no search surface can bypass it by
holding an unfiltered instance.

## Two enforcement layers

| Layer | Mechanism | Applies to |
|---|---|---|
| **Repository (data)** | injected `blockFilter` / `createBlockedAuthorFilter`, applied while results are still raw events, before model mapping | all *search* methods (people, videos, lists) and the hashtag REST feed |
| **Render chokepoint** | `VideoEventService.shouldHideVideo(video)` (`mobile/lib/services/video_event_service.dart`) — consults `shouldFilterFromFeeds` + the Divine-hosted-only preference | detail / by-id surfaces that resolve a video directly and bypass the reception-time filter (video detail, sound detail, curated/liked grids, notifications) |

The render chokepoint exists because detail/by-id surfaces fetch a
single resolved video and skip the reception-time feed filter, so the
blocklist check lives at the shared `shouldHideVideo` chokepoint rather
than being duplicated at each call site.

WebSocket-streamed surfaces additionally re-filter on arrival because
streamed events are not pre-filtered by a repository search call — e.g.
`HashtagFeedScreen._applyFeedFilters`, which also re-runs when
`blocklistVersionProvider` changes so a newly blocked author disappears
immediately (see #4782).

## Per-surface coverage

| Surface | Where filtered | Test |
|---|---|---|
| **People search** | `ProfileRepository.searchUsersLocally` / `searchUsersFromApi` / `searchUsers` / `searchUsersProgressive` each apply `blockFilter` | `packages/profile_repository/test/src/profile_repository_test.dart` (block-filter group) |
| **Mention autocomplete, new-message (DM) search** | inherit filtering — both call the filtered `ProfileRepository` (`searchUsersFromApi` / `searchUsers`) | covered transitively by the people-search block tests |
| **Video search** | `VideosRepository.searchVideosLocally` / `searchVideosOnRelays` / `searchVideosViaApi` each apply `blockFilter` via `_transformVideoStats`; composed `searchVideos` delegates only to those three | `packages/videos_repository/test/src/videos_repository_test.dart` |
| **Hashtag search → hashtag feed** | hashtag *search* returns hashtag strings (no author content). The hashtag *feed* (`VideosRepository.getHashtagFeedVideos → FunnelcakeApiClient.getVideosByHashtagPage`) filters at the repository layer; `HashtagFeedScreen._applyFeedFilters` re-filters WebSocket updates and the pages the screen holds and reacts to `blocklistVersionProvider` | `test/screens/hashtag_feed_blocklist_filter_test.dart` |
| **List search (curated lists)** | `CuratedListRepository.searchAllLists` filters blocked owners (local + relay) | `packages/curated_list_repository/test/src/curated_list_repository_test.dart` |
| **List search (people lists)** | `PeopleListsRepository.searchPublicLists` filters blocked owners and excludes the app block list (`d=block`) itself | `packages/people_lists_repository/test/people_lists_repository_impl_test.dart` |
| **Detail / by-id render surfaces** | `shouldHideVideo` chokepoint — video detail, sound detail, curated/liked grid providers, notifications | `test/unit/services/video_event_service_search_test.dart` (#948 group) |

## Known exceptions (out of this contract's search/result scope)

These are tracked separately and are **not** part of the search/result
filtering surface this contract covers — listed here so the contract is
honest about its boundary:

- **Authoring people pickers** — `UserPickerSheet`'s follow list loads
  via the unfiltered `ProfileRepository.getCachedProfile` (a raw cache
  accessor, not a search method), so a blocked-but-followed user can
  appear when *choosing collaborators / people-list members*. This is an
  authoring surface, not a discovery/result surface. Tracked by #5164.
- **Curated / liked grid reactivity** — these grids filter at fetch time
  via `shouldHideVideo` but do not yet re-filter an already-loaded grid
  on a broad blocklist change (no `blocklistVersionProvider` watch in
  `list_providers`). The fullscreen sibling was fixed (#5041 → #5105);
  the grid case is tracked by #5104.

## When you change filtering

If you change `shouldFilterFromFeeds`, `createBlockedAuthorFilter`,
`shouldHideVideo`, or any repository `searchXxx` method's filtering,
update this table and the corresponding test in the same change.
