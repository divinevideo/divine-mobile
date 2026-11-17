# New feed repeats

Approved by the maintainer in the active session on November 17, 2026.

New must show eligible videos newest first by original publication time,
including watched videos and the viewer's own videos. Returning to New,
refreshing it, or reading its cached first page must not remove a video because
it was watched. Preserve content filtering, deduplication, source selection,
hydration, and cursor pagination.

## Approaches

- Keep New unseen-only with an own-author exception: helps creators find their
  uploads but still makes other recent videos disappear after watching.
- Bypass seen filtering only during refresh: leaves inconsistent results on
  cached reads and later pages.
- Remove seen filtering from New entirely (chosen): preserves a predictable
  chronological feed and allows repeats, as requested by the maintainer.

Other feeds retain seen filtering. Keeping the viewer's own watched videos in
those feeds is separate work in PR #11152, owned by another agent. This change
does not inject uploads into unrelated candidate pools or bypass moderation.

The original report's cause remains unconfirmed. Latest TestFlight is the
working assumption, not verified installation evidence. This implements an
explicit product choice without claiming reporter-specific diagnosis.

## Verification

Regression tests cover API and relay results, watched-only API pages, cached
reads after watching, manual refresh, revalidation, and an unavailable seen
lookup. Existing repository tests protect pagination and content filtering.
Run the complete videos_repository suite with coverage and application analysis.
No backend, settings, release, or deployment changes are in scope.
