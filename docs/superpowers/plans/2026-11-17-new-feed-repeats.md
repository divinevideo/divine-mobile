# New feed repeats implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Keep watched videos visible in New, in publication order.

**Architecture:** Change only the New path in VideosRepository. Cache, API and
relay results share the same policy. Other feed filtering remains unchanged.

**Tech Stack:** Dart, Flutter test, mocktail.

**Spec:** docs/superpowers/specs/2026-11-17-new-feed-repeats-design.md

## Global constraints

- Preserve moderation, deduplication, hydration and cursor semantics.
- Leave PR #11152 untouched.
- No production settings or deployment changes.
- Implement the product choice; do not claim a diagnosis of any individual
  report.

## Review focus

- All-watched API pages must retain both videos and continuation metadata.
- Cached results must survive watching every video without an automatic refetch.
- Refresh and session revalidation must retain watched recent posts.
- New must load even when seen history cannot initialize.
- Relay fallback must retain watched posts in chronological order.

## Task 1: Return watched videos through every New path

**Files:** Modify mobile/packages/videos_repository/lib/src/videos_repository.dart
and mobile/packages/videos_repository/test/src/videos_repository_seen_filtering_test.dart.

**Interfaces:** Preserve getNewVideos({int limit, int? until, String? cursor,
bool skipCache, bool revalidate}) -> Future<HomeFeedResult>.

- [x] Run the existing seen-filter suite as a baseline.
- [x] Update New's existing tests to require watched rows in order, one API read
  for a complete watched-only page, and unchanged cache and cursor metadata.
  Add refresh/revalidation and unavailable-seen-lookup cases.
- [x] Run that suite and confirm the new assertions fail on existing code.
- [x] Remove New's lookup initialization, cached-page filtering, result
  filtering, API per-page filtering and seen-only fetch budget. Keep the API
  loop for content-filtered or deduplicated pages and preserve its cursors.
- [x] Run the updated suite, the full package with coverage, and flutter analyze
  lib test integration_test from mobile. Expect no failures or analyzer issues.
- [ ] Commit, rebase onto fresh origin/main, obtain a fresh-context whole-diff
  review, push, open a PR targeting main, request reviewers once, and inspect CI.
