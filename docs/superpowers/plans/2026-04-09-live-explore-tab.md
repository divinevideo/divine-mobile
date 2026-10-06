# Live Explore Tab Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make livestream discovery a first-class Explore tab instead of a promo card above the tab strip.

**Architecture:** Keep the change local to `ExploreScreen`: extend the existing tab bookkeeping with a gated `live` entry, remove the promo-card rendering path, and mount the existing embedded live discovery UI inside the `TabBarView`. Preserve the existing standalone live routes for direct navigation and deep links.

**Tech Stack:** Flutter, Riverpod compatibility glue, existing live screens/widgets, Flutter widget tests

---

## Chunk 1: Explore Tab Wiring

### Task 1: Capture the failing Explore behavior in tests

**Files:**
- Modify: `mobile/test/screens/explore_screen_test.dart`
- Reference: `mobile/lib/screens/explore_screen.dart`

- [ ] **Step 1: Write the failing tests**

Add tests that verify:
- when `FeatureFlag.livestreamingBeta` is enabled, Explore shows a `Live` tab label
- the old `LiveExploreEntryCard.entryKey` is absent

- [ ] **Step 2: Run the targeted test to verify it fails**

Run: `flutter test test/screens/explore_screen_test.dart`
Expected: FAIL because Explore still renders the promo card and has no `Live` tab.

- [ ] **Step 3: Write the minimal implementation**

Update `mobile/lib/screens/explore_screen.dart` so:
- `_tabCount` includes the gated live tab
- `_tabNames` includes `live`
- the `TabBar` adds a `Tab(text: 'Live')`
- the `TabBarView` adds the embedded live discovery content
- the promo-card branch is removed

- [ ] **Step 4: Run the targeted test to verify it passes**

Run: `flutter test test/screens/explore_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/explore_screen.dart mobile/test/screens/explore_screen_test.dart docs/superpowers/specs/2026-04-09-live-explore-tab-design.md docs/superpowers/plans/2026-04-09-live-explore-tab.md
git commit -m "feat(live): make livestream a first-class explore tab"
```

## Chunk 2: Verification

### Task 2: Verify the live Explore UX did not regress

**Files:**
- Reference: `mobile/lib/screens/explore_screen.dart`
- Reference: `mobile/lib/screens/live/live_discovery_view.dart`

- [ ] **Step 1: Run focused widget verification**

Run: `flutter test test/screens/explore_screen_test.dart test/screens/live/live_discovery_page_test.dart`
Expected: PASS

- [ ] **Step 2: Run focused analyze verification**

Run: `flutter analyze lib/screens/explore_screen.dart lib/screens/live test/screens/explore_screen_test.dart test/screens/live/live_discovery_page_test.dart`
Expected: PASS

- [ ] **Step 3: Review git diff for unintended churn**

Run: `git diff --stat`
Expected: only Explore/live UI docs and tests changed
