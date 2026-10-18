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
