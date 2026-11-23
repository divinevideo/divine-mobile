# Video-first badges implementation plan

**Goal:** Use the Lists thumbnail layout to put playable clips ahead of badge
controls in discovery and detail.

**Spec:** `docs/superpowers/specs/2026-11-22-badge-video-first-design.md`.

**Architecture:** Keep repository discovery and filtering intact. Reuse the
Lists video fan as one accessible target for its leading exact event, with
badge identity opening detail for the complete video grid. Keep detail's existing video pager.

**Tech stack:** Flutter 3.47.9, BLoC, existing Riverpod visibility providers,
`divine_ui`, `material_ui`.

## Constraints and review focus

- Start from mobile PR #11159's fetched head, preserving reviewer commits.
- Keep exact event/author playback, moderation and vanish filtering, and all
  existing owner/report/subscription actions.
- No new localization keys, arbitrary waits or per-card discovery API requests.
- Check relay-only cards, all-hidden clips, large text, both themes and partial
  holder reconciliation failure. Do not count a 404 timing as endpoint latency.

## Tasks

1. Add widget regressions for a full-size relay card without Videos CTA, the
   shared thumbnail fan with exact clip activation, inline videos preceding
   compact controls, and preserved video previews after a late holder failure.
   Run the affected tests and observe the expected failures.
2. Update `mobile/lib/screens/explore/tabs/explore_badges_tab.dart` to reuse
   `DivineListMedia.videos` without changing the shared Lists renderer,
   retain artwork fallback and remove the separate Videos button. Keep the
   existing visibility provider and bounded holder-preview reads.
3. Update `mobile/lib/screens/badges/badge_detail_screen.dart` to render videos
   first, compact the follow control, remove Videos CTA, and preserve an
   available preview through incomplete reconciliation. Keep retry evidence.
4. Run focused app/widget tests, full Flutter analysis and local goldens. Check
   relevant guards. Obtain fresh independent review, push the focused update to
   #11159 and inspect all CI checks and its refreshed web preview.

Staging endpoint verification runs separately under the explicitly authorized
one-hour operations session; it grants no merge or production deployment.
