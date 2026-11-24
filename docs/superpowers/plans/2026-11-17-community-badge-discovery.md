# Community Badge Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Lists-inspired public badge gallery explaining badges and connecting people to individual follows and community videos.

**Architecture:** BadgeRepository owns public discovery, signature/deletion/policy filtering and indexed previews. ExploreBadgesCubit owns pagination, preview scheduling and request generations. Widgets render adaptive cards and dispatch existing native routes.

**Tech Stack:** Flutter 3.47.9, Dart, BLoC, existing NIP-58/NIP-09 and Funnelcake client, divine_ui.

**Spec:** docs/superpowers/specs/2026-11-17-community-badge-discovery-design.md

## Global Constraints

- 300 definition events; full issuer+d-tag identity, valid signatures and issuer-signed deletions; recent first.
- Reveal 24 cards then 24 more; three faces maximum; four concurrent preview reads, once per coordinate per generation.
- Signed-out discovery; hidden issuers/people excluded; incomplete read is an error.
- Explain how badges work and link to https://badges.divine.video; localize new copy in all locales.
- Adaptive colors, existing typography/components, 16dp gutters/corners/gap, 177:120 art, one column for narrow/large text.
- No backend, protocol, LiveKit, deployment, release or merge work.

## Review Focus

- Identical identifiers from different issuers stay distinct; repository collision and gallery route tests.
- Forged deletions and old deletions cannot erase newer legitimate definitions; signed deletion tests.
- Late refresh/preview completions after replacement or close cannot expose stale people; deferred-future cubit tests.
- Preview outages and absent artwork leave useful cards; gallery fallback test.
- Narrow layouts and large text in both themes retain readable actions; widget layout tests.

---

### Task 1: Public discovery and previews

**Files:** mobile/packages/badge_repository/lib/src/badge_repository.dart; new mobile/packages/badge_repository/test/src/badge_discovery_test.dart.
**Interfaces:** Produce Future<List<Nip58BadgeDefinition>> loadPublicDefinitions() and Future<List<String>> loadHolderPreview(BadgeCoordinate coordinate), using existing NostrClient and FunnelcakeApiClient.

- [ ] Write failing tests for non-official issuers, coordinate collisions/revisions, invalid signatures, authorized deletions, bounded primary-relay reads, incomplete reads, preview filtering and limits.
- [ ] Run pinned Flutter test in mobile/packages/badge_repository; confirm missing behavior failures.
- [ ] Implement bounded reads and repository-owned verification/dedup/filter/sort. Batch relevant deletions; enforce author/timestamp boundaries.
- [ ] Run package tests, expect PASS, commit.

### Task 2: Gallery state

**Files:** mobile/lib/blocs/badges/explore_badges_cubit.dart, explore_badges_state.dart; mobile/test/blocs/badges/explore_badges_cubit_test.dart.
**Interfaces:** Consume Task 1; produce visibleDefinitions, previews, hasMore; showMore() and loadPreview(String coordinate). Page recreates state on account/policy changes.

- [ ] Write failing tests for public discovery, 24-card increments, retained refresh, superseded requests/close, bounded previews and generation deduplication.
- [ ] Run cubit tests; confirm old official-only behavior fails.
- [ ] Implement immutable state and guarded preview queue; preview failure is nonblocking.
- [ ] Run cubit tests, expect PASS, commit.

### Task 3: Gallery and people journey

**Files:** mobile/lib/screens/explore/tabs/explore_badges_tab.dart; new mobile/lib/widgets/badges/badge_community_card.dart; mobile/lib/screens/badges/badge_detail_screen.dart; corresponding widget tests; mobile/lib/l10n/app_*.arb and generated output.
**Interfaces:** Task 2 actions/state, existing image/avatar/profile components, native badge routes and URL launcher, existing follow controls.

- [ ] Write failing widgets for explanation/website, full coordinate routing, native creation/dashboard, skeleton/error/empty, failed preview/art, light/dark large-text layouts. Retain individual follow/public subscription tests.
- [ ] Run focused widgets; verify failures against rows.
- [ ] Implement lazy responsive cards, issuer identity and preview faces. Request previews only for built cards. Add approved explainer/link and native actions. Rename community subscription and people section, add helper; preserve membership/follow semantics and public-list notice.
- [ ] Translate new copy everywhere; generate l10n with pinned SDK. Run affected widgets, cubit, package and localization tests; expect PASS.
- [ ] Run full analyze, localization scanner, relevant guards, runtime reload if available; commit.

### Task 4: Review and publish

**Files:** Branch and PR metadata.
**Interfaces:** Whole-branch diff, spec, plan and validation evidence.

- [ ] Fetch/rebase fresh origin/main. Repeat affected validation if source changed.
- [ ] Obtain fresh independent whole-diff review; fix verified blockers with regression tests.
- [ ] Push own branch; open Conventional Commit PR targeting main and request mapped team once. Include real screenshots if available, otherwise name limitation.
- [ ] Inspect finished relevant CI, publish/verify current-SHA independent conclusion; hand back PR URL, checks and remaining merge owner. Do not merge.
