# Follow hashtags from Home

## Intent and delivery scope

Make it easy for communities to form around a hashtag: follow it once, return to its videos from Home, and see which hashtags you follow. A user following #LNIC should be able to select #LNIC alongside For You, Following, and their subscribed lists.

The user approved this first slice after discussing the larger feature. This delivery covers hashtag following, dedicated Home feeds, and managing followed hashtags. Mixing hashtag videos into Following, recommendation signals for For You, notification preferences and delivery, and a composer shortcut remain separate product work. This slice must not imply those behaviors already exist.

## Current implementation

- `mobile/lib/screens/feed/feed_mode_switch.dart` already renders subscribed curated lists in the Home source picker.
- `mobile/lib/blocs/video_feed/video_feed_state.dart` models those lists as typed Home sources.
- `mobile/lib/blocs/video_feed/video_feed_bloc.dart` observes subscribed-list changes and handles source switching.
- `mobile/lib/screens/hashtag_feed_screen.dart` displays a hashtag grid using repository results and relay updates. A relay subscription here is a request for videos, not a saved user follow.
- `mobile/packages/videos_repository/lib/src/videos_repository.dart` owns hashtag fetches, filtering, and trending/classic composition. Its existing combined hashtag method returns a first-page result without a pagination cursor; Home integration must not pretend it supports unbounded pagination.

These are local code observations. Brain search also located historical discussion of device-local hashtag subscriptions, document C1D49B663E80615958E0D49885; that history is not evidence of current shipped functionality.

## User experience

### Following

The standalone hashtag page shows a Follow / Following action. Following saves the hashtag and makes it immediately available in Home. Tapping Following unfollows it. Show pending state and prevent repeated taps while saving. On a failed write, retain the previously confirmed state and show a localized retryable error.

Anonymous users can view hashtags. Following requires the existing sign-in flow; no anonymous subscription bucket is created. Returning from sign-in must not silently follow a tag without a new explicit action.

### Home source picker

Preserve For You, Following, New, Classics, and existing subscribed-list options. Add followed hashtags with their leading #, sorted alphabetically, followed by a Manage hashtags action. Use the existing scrolling selection surface so a long follow list remains accessible. List labels and hashtag labels retain their distinct presentation.

Selecting a hashtag changes the actual Home feed source and displays its name in the header. Preserve the source through the existing Home source persistence mechanism. Keep the feed's video playback, refresh, filtering, and source-switch cancellation behavior. No duplicate video event appears within the feed.

Unfollowing the currently selected hashtag falls back to For You and persists that fallback. Removing any other hashtag leaves the active source unchanged. Switching accounts must never restore a hashtag source from the previous account.

### Manage hashtags

Open a full-screen Page/View screen from the Home picker. Show the account's followed hashtags in alphabetical order, with an explicit Unfollow action on each row. Tapping the hashtag opens its existing hashtag page. Include a localized empty state explaining that hashtags can be followed from a hashtag page. Use adaptive theme tokens and shared Divine components in light and dark modes.

Existing list subscription controls continue to manage lists; this slice does not consolidate or redesign them. The Home picker remains the common place to access both.

## Storage and state

Add a Flutter-independent hashtag subscription repository under `mobile/packages/`, with an injected persistence interface and replaying immutable subscription snapshots. The app supplies the persistence adapter. The repository owns normalization, membership, serialization of writes, and confirmed state. UI and feed blocs depend on the repository rather than writing preferences directly.

Store follows locally under an account-qualified key using the full public key. Keep display spelling separately from canonical membership: trim whitespace, strip one optional leading #, reject blank values and values containing whitespace or another #, and compare case-insensitively. Preserve non-Latin characters. Following #LNIC and #lnic produces one subscription. Do not silently rewrite every Unicode spelling into an ASCII approximation.

Writes are idempotent and serialized, so overlapping follows cannot overwrite one another. Emit confirmed state after successful persistence. Loading malformed storage yields a surfaced recoverable error rather than overwriting the malformed value with an empty list. Scope repository lifetime to the authenticated account and dispose subscriptions on account changes.

Device-local persistence is an explicit first-version limitation: it survives app restarts, but does not synchronize to another device or another Nostr client. No new Nostr event format is introduced. Cross-device synchronization should be designed against the existing list protocols separately.

## Feed integration

Extend the typed Home source with a hashtag value and an unambiguous persisted representation. Extend the Home bloc's source handling, equality, caching, stale-response protection, and repository subscription lifecycle. Include the canonical hashtag and account identity wherever they affect cache ownership. Preserve other sources' persisted values.

Use `VideosRepository` for data access, including fallback and moderation. Reuse existing hashtag query methods and filtering rather than introducing REST calls or legacy service dependencies in the bloc. The repository must own a paged hashtag result with explicit exhaustion/cursor semantics if existing lower-level APIs support it. Otherwise mark the existing combined result exhausted and retain manual refresh; never repeatedly append the same first page. Preserve trending/classic composition consistently within the selected implementation.

On refresh failure, retain previously loaded videos and expose retry. Distinguish an empty successful result from a failed fetch. Blocked and muted content must remain filtered on both initial load and refresh. A completed request for a previously selected hashtag must not replace the current source's feed.

Update exhaustive source switches, analytics attribution through the existing contract workflow, and cache keys deliberately. Never repurpose an existing source tag to report hashtag views as list views.

## Verification and acceptance

- Repository tests cover normalization, Unicode tags, duplicate follows, unfollow, restart persistence, failed writes, overlapping writes, malformed reads, account separation, and disposal.
- Bloc tests cover selecting a hashtag, loading/failure/empty states, refresh, pagination or explicit exhaustion, stale results after a source switch, selected-tag removal, and account changes.
- Widget tests cover Follow / Following / pending/error behavior, Home picker entries, management navigation and removal, accessible labels, and long lists.
- Existing list-source and Home source persistence tests continue to pass.
- Run affected package and app tests, `flutter analyze`, localization checks, generated-file checks where touched, and relevant repository guards before publishing.
- Verify the complete flow manually: open #LNIC, follow, return Home, select #LNIC, restart, remove it in Manage hashtags, and confirm fallback to For You. Repeat account isolation and light/dark appearance checks.

## Delivery

Use the existing isolated Paseo worktree on `feature/hashtag-subscriptions`, currently at `origin/main`, for this single task. Review this written design, then prepare the implementation plan required by the brainstorming workflow. Product implementation begins after that plan is reviewed and its execution method is selected. Publish a focused PR targeting main after local validation; request the mapped reviewers and inspect required CI before declaring implementation complete.
