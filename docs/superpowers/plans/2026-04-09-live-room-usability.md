# Live Room Usability Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current live room from a technically working shell into a usable product surface with explicit exits, correct session-scoped chat, Divine-style chat identity, and a real media stage.

**Architecture:** Keep the work split by responsibility. Navigation fixes stay in the live screen widgets, chat correctness stays in the room/chat boundary, and stage rendering stays in the media service plus stage widget. Avoid cross-cutting router rewrites or chat/comment-system coupling.

**Tech Stack:** Flutter, flutter_bloc, Riverpod provider wiring, LiveKit client, Nostr repositories, widget tests

---

## Chunk 1: Live Navigation Exits

### Task 1: Add explicit back affordances to live flows

**Files:**
- Modify: `mobile/lib/screens/live/go_live_view.dart`
- Modify: `mobile/lib/screens/live/live_room_view.dart`
- Modify: `mobile/lib/screens/live/live_room_detail_view.dart`
- Test: `mobile/test/screens/live/go_live_page_test.dart`
- Test: `mobile/test/screens/live/live_room_page_test.dart`
- Test: `mobile/test/screens/live/live_room_detail_page_test.dart`

- [ ] **Step 1: Write failing widget coverage**

Add coverage that verifies each live screen exposes an explicit back affordance and that tapping it pops when possible or falls back to the live discovery route.

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run:
`flutter test test/screens/live/go_live_page_test.dart test/screens/live/live_room_page_test.dart test/screens/live/live_room_detail_page_test.dart`

Expected: FAIL because the current app bars do not guarantee an explicit back affordance.

- [ ] **Step 3: Implement the minimal navigation fix**

Add explicit app-bar leading actions for the live screens and use the smallest possible navigation fallback that preserves normal pop behavior.

- [ ] **Step 4: Run the targeted tests to verify they pass**

Run:
`flutter test test/screens/live/go_live_page_test.dart test/screens/live/live_room_page_test.dart test/screens/live/live_room_detail_page_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/live/go_live_view.dart mobile/lib/screens/live/live_room_view.dart mobile/lib/screens/live/live_room_detail_view.dart mobile/test/screens/live/go_live_page_test.dart mobile/test/screens/live/live_room_page_test.dart mobile/test/screens/live/live_room_detail_page_test.dart
git commit -m "fix(live): restore navigation exits in live flows"
```

## Chunk 2: Chat Session Correctness And Identity

### Task 2: Scope chat to the active session and render real participant identity

**Files:**
- Modify: `mobile/lib/screens/live/live_room_page.dart`
- Modify: `mobile/lib/screens/live/widgets/live_chat_panel.dart`
- Create: `mobile/lib/screens/live/widgets/live_chat_message_tile.dart`
- Test: `mobile/test/screens/live/live_room_page_test.dart`
- Create: `mobile/test/screens/live/live_chat_panel_test.dart`

- [ ] **Step 1: Write the failing tests**

Add coverage that verifies:
- live chat starts for the current session even when the room state is already ready on first build
- entering a new session does not keep showing stale chat from a previous session
- chat rows show avatar + display name instead of a raw pubkey-first row

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run:
`flutter test test/screens/live/live_room_page_test.dart test/screens/live/live_chat_panel_test.dart`

Expected: FAIL because chat startup currently depends on a listener race and the chat UI renders raw pubkeys.

- [ ] **Step 3: Implement the minimal fix**

Update the room/chat boundary so the active session address is always pushed into `LiveChatBloc`, then split chat-row rendering into a dedicated widget that reuses cached-profile identity components.

- [ ] **Step 4: Run the targeted tests to verify they pass**

Run:
`flutter test test/screens/live/live_room_page_test.dart test/screens/live/live_chat_panel_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/live/live_room_page.dart mobile/lib/screens/live/widgets/live_chat_panel.dart mobile/lib/screens/live/widgets/live_chat_message_tile.dart mobile/test/screens/live/live_room_page_test.dart mobile/test/screens/live/live_chat_panel_test.dart
git commit -m "fix(live): scope chat to the active session"
```

## Chunk 3: Real Stage Media

### Task 3: Replace the fake stage roster with a real media surface

**Files:**
- Modify: `mobile/lib/services/livekit_room_service.dart`
- Modify: `mobile/lib/screens/live/widgets/live_room_stage.dart`
- Create: `mobile/test/screens/live/live_room_stage_test.dart`
- Test: `mobile/test/services/livekit_room_service_test.dart`

- [ ] **Step 1: Write the failing tests**

Add focused coverage that proves the stage can reflect actual local/remote media state instead of only speaker pubkeys and that the media service exposes enough room state for the stage to render.

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run:
`flutter test test/services/livekit_room_service_test.dart test/screens/live/live_room_stage_test.dart`

Expected: FAIL because the current stage widget is text-only and the media service does not expose participant track state for rendering.

- [ ] **Step 3: Implement the minimal stage/media plumbing**

Extend `LiveKitRoomService` with the smallest room/participant media snapshot needed for UI rendering and update the stage widget to render a real media surface with an empty-state fallback.

- [ ] **Step 4: Run the targeted tests to verify they pass**

Run:
`flutter test test/services/livekit_room_service_test.dart test/screens/live/live_room_stage_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/livekit_room_service.dart mobile/lib/screens/live/widgets/live_room_stage.dart mobile/test/services/livekit_room_service_test.dart mobile/test/screens/live/live_room_stage_test.dart
git commit -m "feat(live): render real stage media"
```

## Chunk 4: Integration Verification

### Task 4: Verify the live room works as one surface

**Files:**
- Reference: `mobile/lib/screens/live/live_room_view.dart`
- Reference: `mobile/lib/screens/live/live_room_page.dart`
- Reference: `mobile/lib/screens/live/widgets/live_chat_panel.dart`
- Reference: `mobile/lib/screens/live/widgets/live_room_stage.dart`

- [ ] **Step 1: Run focused live-room verification**

Run:
`flutter test test/screens/live/live_room_page_test.dart test/screens/live/live_room_detail_page_test.dart test/screens/live/go_live_page_test.dart test/screens/live/live_chat_panel_test.dart test/screens/live/live_room_stage_test.dart test/services/livekit_room_service_test.dart`

Expected: PASS

- [ ] **Step 2: Run focused analyze verification**

Run:
`flutter analyze lib/screens/live lib/services/livekit_room_service.dart test/screens/live test/services/livekit_room_service_test.dart`

Expected: PASS

- [ ] **Step 3: Review the diff**

Run:
`git diff --stat origin/codex/live-spaces-v1...HEAD`

Expected: only live room UI, chat, media service, tests, and these docs changed
