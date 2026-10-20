# videos_repository

Status: Current
Validated against: `pubspec.yaml` and library exports on 2026-03-19.

Purpose: repository for video retrieval, local storage coordination, filtering, and feed-cache behavior.

Used by: the main video feed, profile grids, and related playback surfaces.

Test locally:

```bash
cd mobile/packages/videos_repository
flutter test --coverage
```

## Badge video feeds

A badge pager keeps its author snapshot and `before` bound fixed. It splits
full-length authors into groups of 200 and requests up to 100 server rows at a
time through the API client's body-based by-authors request. Each chunk always
pages by offset under that fixed bound; it does not consume `next_cursor`.
Offsets advance by the server item count, including rows later filtered out.

Chunks merge using each event's own `created_at`, with event ID as a tie-breaker.
Both ordinary Following and badge Following use that event clock. Badge
Following retains the ordinary 25-video page size and recently-seen demotion
within each delivered page; badge discovery grids keep event-time ordering.
Demoting a page does not change the pager's chronological snapshot boundaries.

The index can supply a filtered holder preview. Complete relay reads determine
the accepted holder snapshot, and a late preview cannot replace that result.
Incomplete badge reads are retryable exceptions, not programming errors.
Backend deployment verification, signed-in end-to-end acceptance, and the
existing fluent-language review remain rollout gates for the draft feature.

Following waits for the first complete subscription read in each account/session.
A verified empty subscription list then permits direct-feed first display while
one background read revalidates it. Account changes, sign-out and local edits
invalidate the proof; same-account upgrade/resume notifications do not. A newly
observed subscription triggers a merged-feed refresh; failed revalidation revokes
the shortcut for the next load without discarding the current page. A signed
subscription list arriving after its caller's deadline can trigger a merged-feed
refresh once. Deadlines and incomplete reads during holder loading retain the
existing failure policy: users can retry explicitly, and late holder results do
not automatically replace the feed. The newest signed subscription list wins by
replaceable-event ordering; a missing or older
relay result cannot erase it, and a newer signed empty list can supersede it.
Empty holder results and incomplete reads are never absence proofs.
The cache is in memory and stores no state across app restarts.


Following's badge/direct source selection and fallback live in
`FollowingVideoFeedSession`. The app injects author-reader callbacks and request
ownership; the session owns the committed badge pager and prevents superseded
reads from becoming empty terminal pages. Holder sets are not cached: a
nonempty-holder cache needs an explicit freshness and revocation policy.

The badge detail Videos action opens the dedicated grid inside the mobile app.
Its URL is also routable on web; `/badges` URLs are not registered native app
links on Android or parsed as incoming native deep links.
