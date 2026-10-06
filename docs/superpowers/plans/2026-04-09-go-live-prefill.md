# Go Live Prefill Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prefill the livestream `Go live` form from the host's cached profile and show the host avatar as the default cover preview.

**Architecture:** Keep the change local to the live host flow. Resolve the cached profile in `GoLivePage`, derive initial form defaults there, pass them into `GoLiveCubit`, and let `GoLiveView` seed its controllers from state once while rendering a lightweight cover preview from the same image URL.

**Tech Stack:** Flutter, flutter_bloc, Riverpod provider wiring, existing profile repository, widget tests

---

## Chunk 1: Prefill State Wiring

### Task 1: Capture the desired prefill behavior in tests

**Files:**
- Modify: `mobile/test/screens/live/go_live_page_test.dart`
- Reference: `mobile/lib/screens/live/go_live_page.dart`
- Reference: `mobile/lib/screens/live/go_live_view.dart`

- [ ] **Step 1: Write the failing tests**

Add widget coverage that verifies:
- a cached profile prefills title, summary, and cover image URL
- the form shows a visible avatar/cover preview
- no cached profile keeps the form blank

- [ ] **Step 2: Run the targeted test to verify it fails**

Run: `flutter test test/screens/live/go_live_page_test.dart`
Expected: FAIL because the page currently renders blank controllers and no preview.

- [ ] **Step 3: Write the minimal implementation**

Update the page, cubit, state, and view so:
- `GoLivePage` loads the cached profile for the current host
- it derives initial defaults from `bestDisplayName` and `picture`
- `GoLiveCubit` starts from those values
- `GoLiveView` seeds its controllers once from bloc state and renders the cover preview

- [ ] **Step 4: Run the targeted test to verify it passes**

Run: `flutter test test/screens/live/go_live_page_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/blocs/go_live/go_live_cubit.dart mobile/lib/blocs/go_live/go_live_state.dart mobile/lib/screens/live/go_live_page.dart mobile/lib/screens/live/go_live_view.dart mobile/test/screens/live/go_live_page_test.dart docs/superpowers/specs/2026-04-09-go-live-prefill-design.md docs/superpowers/plans/2026-04-09-go-live-prefill.md
git commit -m "feat(live): prefill go live setup from host profile"
```

## Chunk 2: Focused Verification

### Task 2: Verify the prefill UX and live host flow stay healthy

**Files:**
- Reference: `mobile/lib/screens/live/go_live_page.dart`
- Reference: `mobile/lib/screens/live/go_live_view.dart`
- Reference: `mobile/test/screens/live/go_live_page_test.dart`

- [ ] **Step 1: Run focused widget verification**

Run: `flutter test test/screens/live/go_live_page_test.dart test/screens/live/live_room_page_test.dart`
Expected: PASS

- [ ] **Step 2: Run focused analyze verification**

Run: `flutter analyze lib/blocs/go_live lib/screens/live test/screens/live/go_live_page_test.dart test/screens/live/live_room_page_test.dart`
Expected: PASS

- [ ] **Step 3: Review the diff**

Run: `git diff --stat`
Expected: only live host UI/state/docs coverage changed
