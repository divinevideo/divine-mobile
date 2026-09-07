# Collaborator Full Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship end-to-end collaborator invitations: creators invite, recipients accept or ignore, Funnelcake confirms only valid collaborations, and confirmed collaborator videos appear in collaborator/profile/feed reads.

**Architecture:** Keep the creator-authored video event as the source of the pending collaborator set. Add a collaborator-authored public acceptance event and make Funnelcake the authoritative current-state read model for pending, confirmed, and invalid collaborator edges. Mobile uses encrypted NIP-17 DMs for invite delivery and UX, but public feed/profile semantics come only from Funnelcake-confirmed edges.

**Tech Stack:** Flutter/Dart, Drift, BLoC/Cubit, `dm_repository`, `nostr_client`, Funnelcake Rust API, ClickHouse migrations/read models, Nostr NIP-01 addressable events, NIP-17 private DMs, NIP-53 collaborator proof semantics as optional future embedded proof.

---

## Mobile-Side Status (2026-05-17)

The mobile-side chunks of this plan have shipped under coordination epic
`#4201` (week of 2026-05-09 → 2026-05-17). Authoritative state derives from
the Funnelcake read model once it ships; until then, mobile uses the
in-process pipeline described below.

**Shipped on mobile:**

- **Kind choice + constant** (`KIND_COLLAB_RESPONSE = 34238`): `mobile/lib/constants/collaboration_event_kinds.dart`.
- **Acceptance publish path** (Chunk 4 Task 10): `mobile/lib/services/collaborator_response_service.dart` — landed via `#3373` / `#4045`.
- **Invite parser + local state store** (Chunk 3 Tasks 7–9): `collaborator_invite_parser.dart`, `collaborator_invite_state_store.dart`.
- **Invite card + conversation wiring** (Chunk 4 Task 11): `collaborator_invite_card.dart`, `collaborator_invite_actions_cubit.dart`; updated for video preview by `#4378`.
- **Message-request preview** (Chunk 4 Task 12): `request_preview_page.dart` / `request_preview_view.dart`.
- **Post-publish invite delivery + retry** (Chunk 5 Tasks 13–14): `video_publish_service.dart`, `share_video_menu.dart`.
- **Funnelcake confirmed-collab client** (Chunk 6 Task 15): `mobile/packages/funnelcake_api_client/lib/src/funnelcake_api_client.dart` (`getCollabVideos` → `/api/users/{pubkey}/collabs`).
- **Profile collabs BLoC + grid** (Chunk 6 Task 16): `profile_collab_videos_bloc.dart`, `profile_collabs_grid.dart`.
- **Raw `p`-tag feed expansion neutralized** (Chunk 6 Task 17 partial): `mobile/lib/services/video_event_service.dart` no-ops the legacy expansion path with a comment pointing back to this plan.
- **Read consumer for acceptance** (closeout of `#4192` via `#4256`): new `mobile/packages/collaborator_repository` provides `CollaboratorConfirmationRepository` + `CollaboratorVisibility` + `VideoCollaboratorStatusCubit`. Pending vs confirmed render correctly on the inviter's own video and the recipient's own avatar.
- **Self-acceptance publish path closed** (`#3559` / `#3566`): sender-side Accept/Ignore is removed; cubit asserts + early-returns when `currentUser == creator`. Mobile-side audit for `#3664` closed on 2026-04-29.
- **p-tag construction centralized** (`#3704` via `#4326`, `#4383`): single helper for the 4-element collaborator p-tag.
- **Profile enrichment race fixed** (`#3705` via `#4261`): targeted reconciliation prevents the duplicate-video flash on collab accept via Connect.

**Funnelcake-side gates (still required for full plan completion):**

- Chunk 1 Tasks 1–3 — `video_collaborators_current_data` + `video_feed_edges_current_data` read models.
- Chunk 2 Tasks 4–6 — confirmed-only `/api/users/{pubkey}/collabs`, feed-edge-based following feed, Gorse feedback exclusion.
- `#3664` — backend filter against self-acceptance events + historical row cleanup.

Until the Funnelcake gates close, third-party viewers of any video still see all tagged collaborators including pending ones, and the following feed does not include videos from videos the user follows via a collaborator edge. Both gaps are documented in `mobile/packages/collaborator_repository/lib/src/collaborator_confirmation_repository.dart` and `mobile/lib/services/video_event_service.dart`.

---

## Scope Check

This is a two-repo feature. Execute it as two focused PRs, in this order:

1. `divine-funnelcake`: protocol kind allowlist, acceptance ingestion, current collaborator read models, profile/feed queries.
2. `divine-mobile`: accept/ignore UI, public acceptance publishing, invite-state UX, and migration to confirmed read paths.

Do not merge the mobile confirmed-read switch until the Funnelcake read model and API are deployed or safely feature-gated.

## Protocol Decision

Use a Divine app-specific parameterized replaceable event kind for collaborator responses. Pick the final kind before implementation and define it in both repos as `KIND_COLLAB_RESPONSE`. It must be in the `30000..39999` range so a collaborator can replace their response for the same video address.

Accepted response event shape:

```json
{
  "kind": KIND_COLLAB_RESPONSE,
  "pubkey": "<collaborator_pubkey>",
  "content": "",
  "tags": [
    ["d", "34236:<creator_pubkey>:<video_d_tag>"],
    ["a", "34236:<creator_pubkey>:<video_d_tag>", "<relay_hint>", "root"],
    ["p", "<creator_pubkey>"],
    ["role", "Collaborator"],
    ["status", "accepted"]
  ]
}
```

Rejection is local-only for v1. The collaborator can ignore the invite without publishing anything. A later encrypted decline DM can be added for creator feedback, but it must not be part of public confirmation semantics.

Creator removal always wins. If the latest creator-authored video event no longer has the collaborator role `p` tag, Funnelcake must remove the pending/confirmed edge even if an old acceptance event still exists.

## File Structure

### Funnelcake

- `database/migrations/0001XX_allow_collab_response_kind.up.sql`: seed `KIND_COLLAB_RESPONSE` into `nostr.allowed_kinds`.
- `database/migrations/0001XX_allow_collab_response_kind.down.sql`: remove the seed.
- `database/migrations/0001XX_video_collaborators_current.up.sql`: create and backfill collaborator current-state tables/views.
- `database/migrations/0001XX_video_collaborators_current.down.sql`: drop those tables/views.
- `crates/proto/src/relay_event.rs`: add helper/constant for collaborator response kind if the repo centralizes kind helpers there.
- `crates/clickhouse/src/client.rs`: replace raw `event_tags_flat_data` collab lookup with current-state query methods.
- `crates/clickhouse/src/traits.rs`: add trait methods for confirmed collabs and feed edges if needed.
- `crates/api/src/handlers.rs`: expose confirmed collabs and optional status-filtered collabs.
- `crates/api/src/router.rs`: wire any new route/query parameter.
- `crates/api/src/openapi.rs` or the existing OpenAPI source file: document response semantics.
- `crates/relay/src/relay.rs`: ensure collaborator response kind is not treated as repost or Gorse feedback.

### Mobile

- `mobile/packages/db_client/lib/src/database/tables.dart`: add persisted rumor tag JSON to direct messages.
- `mobile/packages/db_client/lib/src/database/app_database.dart`: add migration/backfill guard for the new direct message column.
- `mobile/packages/db_client/lib/src/database/app_database.g.dart`: generated Drift output.
- `mobile/packages/db_client/lib/src/database/daos/direct_messages_dao.dart`: insert/read the new tag JSON.
- `mobile/packages/models/lib/src/dm_message.dart`: expose decrypted rumor tags to app/UI code.
- `mobile/packages/dm_repository/lib/src/dm_repository.dart`: persist NIP-17 rumor tags and map them to `DmMessage`.
- `mobile/lib/models/collaborator_invite.dart`: typed app model for invite metadata.
- `mobile/lib/services/collaborator_invite_parser.dart`: parse structured invite tags from `DmMessage`.
- `mobile/lib/services/collaborator_invite_state_store.dart`: local pending/accepted/ignored/failed state.
- `mobile/lib/services/collaborator_response_service.dart`: publish collaborator acceptance events.
- `mobile/lib/screens/inbox/conversation/widgets/collaborator_invite_card.dart`: invitation card in conversation detail.
- `mobile/lib/screens/inbox/conversation/widgets/message_bubble.dart`: render invite cards for invite DMs.
- `mobile/lib/blocs/dm/conversation/conversation_bloc.dart`: wire accept/ignore events if the conversation screen owns actions.
- `mobile/lib/screens/inbox/message_requests/request_preview_view.dart`: expose invite action from request previews.
- `mobile/lib/widgets/share_video_menu.dart`: send invites when adding collaborators after publish.
- `mobile/packages/funnelcake_api_client/lib/src/funnelcake_api_client.dart`: consume confirmed collaborator read model/API.
- `mobile/packages/videos_repository/lib/src/videos_repository.dart`: stop treating raw `p` tags as confirmed collaborator videos.
- `mobile/lib/blocs/profile_collab_videos/profile_collab_videos_bloc.dart`: update wording and behavior to confirmed collabs.
- `mobile/lib/services/video_event_service.dart`: remove hot feed expansion based on raw collaborator `p` tags once feed edges are available.

## Chunk 1: Funnelcake Protocol And Storage

### Task 1: Pick and allowlist collaborator response kind

**Files:**
- Create: `database/migrations/0001XX_allow_collab_response_kind.up.sql`
- Create: `database/migrations/0001XX_allow_collab_response_kind.down.sql`
- Modify: `crates/relay/src/discovery.rs`
- Modify: `crates/proto/src/relay_event.rs`

- [ ] **Step 1: Choose the final kind**

Pick one unused addressable kind in `30000..39999` and define it as `KIND_COLLAB_RESPONSE`. Check existing usage:

```bash
cd /Users/rabble/code/divine/divine-funnelcake
rg -n "34235|34236|34237|3192|3000|3999|KIND_" crates database
```

- [ ] **Step 2: Write the allowlist migration**

Add the chosen kind to `nostr.allowed_kinds` with a descriptive name like `Divine collaborator response`.

- [ ] **Step 3: Add discovery/proto constants**

Add the kind to relay discovery if this relay advertises supported custom kinds. Add `is_collaborator_response()` or an equivalent helper beside existing kind helpers in `crates/proto/src/relay_event.rs`.

- [ ] **Step 4: Run focused tests**

Run:

```bash
cd /Users/rabble/code/divine/divine-funnelcake
cargo test -p funnelcake-proto relay_event
cargo test -p funnelcake-relay discovery
```

- [ ] **Step 5: Commit**

```bash
git add database/migrations/0001XX_allow_collab_response_kind.* crates/relay/src/discovery.rs crates/proto/src/relay_event.rs
git commit -m "feat(collabs): allow collaborator response events"
```

### Task 2: Create current collaborator read model

**Files:**
- Create: `database/migrations/0001XX_video_collaborators_current.up.sql`
- Create: `database/migrations/0001XX_video_collaborators_current.down.sql`

- [ ] **Step 1: Write migration tests or a migration smoke script**

Create the smallest available migration test for:

- latest creator video has `["p", collaborator, relay, "Collaborator"]` and no acceptance -> `pending`
- latest creator video has collaborator tag plus valid accepted response -> `confirmed`
- latest creator replacement removes collaborator tag -> no current row
- acceptance exists without latest creator tag -> no current row

If this repo does not have migration tests, create a ClickHouse SQL fixture under the existing test harness and wire it to the closest migration test runner.

- [ ] **Step 2: Create `video_collaborators_current_data`**

Use a current-state table, not a generic tag query:

```sql
CREATE TABLE IF NOT EXISTS nostr.video_collaborators_current_data (
    collaborator_pubkey FixedString(64),
    status Enum8('pending' = 0, 'confirmed' = 1, 'invalid' = 2),
    video_event_id FixedString(64),
    video_kind UInt16,
    video_pubkey FixedString(64),
    video_d_tag String,
    video_address String,
    role LowCardinality(String),
    relay_hint String,
    proof String,
    confirmation_source Enum8('embedded' = 1, 'acceptance' = 2, 'both' = 3),
    acceptance_event_id FixedString(64) DEFAULT '',
    created_at DateTime,
    published_at UInt32,
    indexed_at DateTime
) ENGINE = ReplacingMergeTree(indexed_at)
ORDER BY (collaborator_pubkey, status, published_at, video_pubkey, video_kind, video_d_tag);
```

The implementation must ensure old pending rows do not survive once a collaborator becomes confirmed or is removed. If using append-only inserts, use a separate tombstone/version strategy or a rebuildable current snapshot. Do not rely on `ReplacingMergeTree` alone if mutable fields are part of the sort key.

- [ ] **Step 3: Backfill from `videos_latest_data`**

Explode the latest video tags, selecting only `p` tags where:

- tag value is a full 64-char pubkey
- tag role field equals `Collaborator`
- tag pubkey is not the video author

- [ ] **Step 4: Join accepted response events**

An acceptance confirms only when:

- response event kind is `KIND_COLLAB_RESPONSE`
- response event `pubkey` equals the collaborator pubkey
- response event has `["status", "accepted"]`
- response event has `a` or `d` tag matching the latest video address
- latest creator-authored video still names that collaborator

- [ ] **Step 5: Keep NIP-53 proof optional**

If the creator video includes a non-empty proof field in the collaborator `p` tag, record `proof` and set `invalid` if it fails verification. Do not make embedded proof mandatory for v1 because mobile does not currently expose raw Schnorr signing.

- [ ] **Step 6: Run migration tests**

Run the repo's migration/ClickHouse test command. If there is no single command, run:

```bash
cd /Users/rabble/code/divine/divine-funnelcake
cargo test -p funnelcake-clickhouse
```

- [ ] **Step 7: Commit**

```bash
git add database/migrations/0001XX_video_collaborators_current.* crates/clickhouse
git commit -m "feat(collabs): add current collaborator read model"
```

### Task 3: Add feed edge read model

**Files:**
- Modify: `database/migrations/0001XX_video_collaborators_current.up.sql`
- Modify: `database/migrations/0001XX_video_collaborators_current.down.sql`

- [ ] **Step 1: Add failing feed-edge fixture**

Test that a video produces:

- one `author` edge for the creator
- one `collaborator` edge for each confirmed collaborator
- no collaborator edge for pending or invalid collaborators

- [ ] **Step 2: Create `video_feed_edges_current_data`**

Add:

```sql
CREATE TABLE IF NOT EXISTS nostr.video_feed_edges_current_data (
    actor_pubkey FixedString(64),
    edge_type Enum8('author' = 1, 'collaborator' = 2),
    video_event_id FixedString(64),
    video_address String,
    published_at UInt32,
    created_at DateTime
) ENGINE = ReplacingMergeTree(created_at)
ORDER BY (actor_pubkey, published_at, video_event_id);
```

- [ ] **Step 3: Populate author and collaborator edges**

Author videos and confirmed collaborator videos become the same feed primitive. The feed query should fetch followed pubkeys once, read edge rows once, dedupe `video_event_id`, and then join to video stats.

- [ ] **Step 4: Run migration/feed tests**

Run the same ClickHouse test command from Task 2.

- [ ] **Step 5: Commit**

```bash
git add database/migrations/0001XX_video_collaborators_current.*
git commit -m "feat(collabs): add collaborator feed edges"
```

## Chunk 2: Funnelcake API And Query Paths

### Task 4: Replace profile collab query with confirmed read model

**Files:**
- Modify: `crates/clickhouse/src/client.rs`
- Modify: `crates/clickhouse/src/traits.rs`
- Modify: `crates/api/src/handlers.rs`
- Modify: `crates/api/src/router.rs`
- Modify: `crates/api/src/openapi.rs`

- [ ] **Step 1: Write failing API/client tests**

Cover:

- `/api/users/{pubkey}/collabs` returns confirmed collabs only by default
- pending collaborator role tags are excluded
- removed collaborators are excluded after video replacement
- `?status=pending` or `?status=all` works if implemented

- [ ] **Step 2: Replace `event_tags_flat_data` lookup**

Update the current raw p-tag path in `crates/clickhouse/src/client.rs` to query `video_collaborators_current_data` with `status = 'confirmed'`.

- [ ] **Step 3: Preserve pagination order**

Order by `published_at DESC` and use the existing page size/offset or cursor shape expected by the current endpoint. Do not introduce an ad hoc join against `event_tags_flat_data`.

- [ ] **Step 4: Update handler docs**

Document that "collabs" means confirmed collaborator relationships, not arbitrary mentions.

- [ ] **Step 5: Run focused tests**

```bash
cd /Users/rabble/code/divine/divine-funnelcake
cargo test -p funnelcake-clickhouse get_videos_by_collaborator
cargo test -p funnelcake-api collab
```

- [ ] **Step 6: Commit**

```bash
git add crates/clickhouse/src/client.rs crates/clickhouse/src/traits.rs crates/api/src/handlers.rs crates/api/src/router.rs crates/api/src/openapi.rs
git commit -m "feat(collabs): serve confirmed collaborator videos"
```

### Task 5: Use feed edges for following feeds

**Files:**
- Modify: `crates/clickhouse/src/client.rs`
- Modify: `crates/clickhouse/src/traits.rs`
- Modify: `crates/api/src/handlers.rs`

- [ ] **Step 1: Write failing feed tests**

Create a feed test with one followed creator and one followed collaborator. Expect a confirmed collaborator video to appear once, and a pending collaborator video not to appear.

- [ ] **Step 2: Replace author-or-collaborator branching**

Change feed lookup to query `video_feed_edges_current_data` by `actor_pubkey IN followed_pubkeys`, dedupe video IDs, then hydrate via existing video stats/latest-video paths.

- [ ] **Step 3: Check query shape**

Run `EXPLAIN` or the repo's query logging test for the hot feed query. Confirm the first key is `actor_pubkey` and the query does not scan `event_tags_flat_data`.

- [ ] **Step 4: Run focused feed tests**

```bash
cd /Users/rabble/code/divine/divine-funnelcake
cargo test -p funnelcake-clickhouse feed
cargo test -p funnelcake-api feed
```

- [ ] **Step 5: Commit**

```bash
git add crates/clickhouse/src/client.rs crates/clickhouse/src/traits.rs crates/api/src/handlers.rs
git commit -m "feat(feed): include confirmed collaborator edges"
```

### Task 6: Keep collaborator acceptance out of repost/Gorse semantics

**Files:**
- Modify: `crates/relay/src/relay.rs`
- Modify: `database/migrations/000003_create_engagement_metrics.up.sql` only if the new kind would otherwise be counted by a broad query

- [ ] **Step 1: Write failing relay feedback test**

Add a relay test that publishes `KIND_COLLAB_RESPONSE` and asserts no Gorse `repost` feedback is emitted.

- [ ] **Step 2: Keep feedback mapping strict**

Ensure only kind `6` and `16` produce repost feedback. `KIND_COLLAB_RESPONSE` must not increase repost counts or Gorse repost feedback.

- [ ] **Step 3: Run tests**

```bash
cd /Users/rabble/code/divine/divine-funnelcake
cargo test -p funnelcake-relay gorse
```

- [ ] **Step 4: Commit**

```bash
git add crates/relay/src/relay.rs database/migrations/000003_create_engagement_metrics.up.sql
git commit -m "test(collabs): keep acceptances out of repost feedback"
```

## Chunk 3: Mobile DM Metadata And Invite Parsing

### Task 7: Persist decrypted NIP-17 rumor tags

**Files:**
- Modify: `mobile/packages/db_client/lib/src/database/tables.dart`
- Modify: `mobile/packages/db_client/lib/src/database/app_database.dart`
- Modify: `mobile/packages/db_client/lib/src/database/daos/direct_messages_dao.dart`
- Modify: `mobile/packages/db_client/lib/src/database/app_database.g.dart`
- Modify: `mobile/packages/models/lib/src/dm_message.dart`
- Modify: `mobile/packages/dm_repository/lib/src/dm_repository.dart`
- Test: `mobile/packages/db_client/test/src/database/daos/direct_messages_dao_test.dart`
- Test: `mobile/packages/dm_repository/test/src/dm_repository_test.dart`

- [ ] **Step 1: Write failing DAO test**

Add a direct message insert/read test that passes:

```dart
tagsJson: jsonEncode([
  ['divine', 'collab-invite'],
  ['a', '34236:creator:dtag', 'wss://relay.divine.video', 'root'],
])
```

Expect the saved `DirectMessageRow.tagsJson` to round-trip.

- [ ] **Step 2: Add Drift column**

Add nullable `tagsJson` text to `DirectMessages` in `tables.dart`.

- [ ] **Step 3: Add migration guard**

In `app_database.dart`, add `_addColumnIfMissing('direct_messages', 'tags_json', 'TEXT')` in the existing direct message migration path.

- [ ] **Step 4: Update DAO insert**

Add `String? tagsJson` to `insertMessage` and map it to the new companion field.

- [ ] **Step 5: Expose tags in model**

Add `List<List<String>> tags = const []` to `DmMessage`, with Equatable props. Parse from stored JSON when mapping rows to models.

- [ ] **Step 6: Persist rumor tags on ingest**

In `_handleGiftWrapEvent`, store `jsonEncode(rumorEvent.tags)` when inserting the message.

- [ ] **Step 7: Generate Drift output**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 8: Run focused tests**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile/packages/db_client
flutter test --no-pub test/src/database/daos/direct_messages_dao_test.dart --plain-name "tags"

cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile/packages/dm_repository
flutter test --no-pub test/src/dm_repository_test.dart --plain-name "tags"
```

- [ ] **Step 9: Commit**

```bash
git add mobile/packages/db_client mobile/packages/models/lib/src/dm_message.dart mobile/packages/dm_repository/lib/src/dm_repository.dart mobile/packages/dm_repository/test/src/dm_repository_test.dart
git commit -m "feat(dm): persist decrypted rumor tags"
```

### Task 8: Add collaborator invite parser

**Files:**
- Create: `mobile/lib/models/collaborator_invite.dart`
- Create: `mobile/lib/services/collaborator_invite_parser.dart`
- Create: `mobile/test/services/collaborator_invite_parser_test.dart`

- [ ] **Step 1: Write parser tests**

Cover:

- valid invite requires `["divine", "collab-invite"]`
- valid invite requires matching `a` tag with video kind/pubkey/d-tag
- creator comes from the creator `p` tag or the `a` tag pubkey
- role defaults to `Collaborator` only when absent, but rejects non-collaborator roles when present
- invalid malformed addresses return `null`

- [ ] **Step 2: Implement model**

Create a small immutable model:

```dart
class CollaboratorInvite {
  const CollaboratorInvite({
    required this.messageId,
    required this.videoAddress,
    required this.videoKind,
    required this.creatorPubkey,
    required this.videoDTag,
    required this.role,
    this.relayHint,
    this.title,
    this.thumbnailUrl,
  });
}
```

- [ ] **Step 3: Implement parser**

Parse only structured tags from `DmMessage.tags`. Do not parse the fallback plaintext body.

- [ ] **Step 4: Run tests**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile
flutter test --no-pub test/services/collaborator_invite_parser_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/models/collaborator_invite.dart mobile/lib/services/collaborator_invite_parser.dart mobile/test/services/collaborator_invite_parser_test.dart
git commit -m "feat(collabs): parse collaborator invite messages"
```

### Task 9: Add local invite state store

**Files:**
- Create: `mobile/lib/services/collaborator_invite_state_store.dart`
- Create: `mobile/test/services/collaborator_invite_state_store_test.dart`

- [ ] **Step 1: Write state-store tests**

Use keys composed of `videoAddress`, `creatorPubkey`, and current user's collaborator pubkey. Cover `pending`, `accepting`, `accepted`, `ignored`, and `failed`.

- [ ] **Step 2: Implement with `SharedPreferences`**

Use JSON in a single key namespace, for example `collaborator_invite_states_v1`. Keep this local UX state only; it is not authoritative collaboration truth.

- [ ] **Step 3: Run tests**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile
flutter test --no-pub test/services/collaborator_invite_state_store_test.dart
```

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/services/collaborator_invite_state_store.dart mobile/test/services/collaborator_invite_state_store_test.dart
git commit -m "feat(collabs): store local invite response state"
```

## Chunk 4: Mobile Acceptance Publishing

### Task 10: Publish public collaborator acceptance events

**Files:**
- Create: `mobile/lib/services/collaborator_response_service.dart`
- Create: `mobile/test/services/collaborator_response_service_test.dart`
- Modify: `mobile/lib/providers/app_providers.dart`

- [ ] **Step 1: Write failing service tests**

Mock `AuthService` and `NostrService`. Expect acceptance to call event signing with:

```dart
kind: KIND_COLLAB_RESPONSE,
content: '',
tags: [
  ['d', invite.videoAddress],
  ['a', invite.videoAddress, invite.relayHint ?? 'wss://relay.divine.video', 'root'],
  ['p', invite.creatorPubkey],
  ['role', invite.role],
  ['status', 'accepted'],
]
```

- [ ] **Step 2: Implement constants**

Add the chosen kind constant in an existing constants location, or create `mobile/lib/constants/collaboration_event_kinds.dart`.

- [ ] **Step 3: Implement service**

Use existing app signing/publishing patterns from `mobile/lib/services/view_event_publisher.dart`. Return a typed success/failure object containing the event ID or error.

- [ ] **Step 4: Wire provider**

Register the service in `app_providers.dart` using constructor injection. Avoid hidden singletons.

- [ ] **Step 5: Run focused tests**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile
flutter test --no-pub test/services/collaborator_response_service_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/constants/collaboration_event_kinds.dart mobile/lib/services/collaborator_response_service.dart mobile/lib/providers/app_providers.dart mobile/test/services/collaborator_response_service_test.dart
git commit -m "feat(collabs): publish collaborator acceptance"
```

### Task 11: Render invite card in conversations

**Files:**
- Create: `mobile/lib/screens/inbox/conversation/widgets/collaborator_invite_card.dart`
- Modify: `mobile/lib/screens/inbox/conversation/widgets/message_bubble.dart`
- Modify: `mobile/lib/blocs/dm/conversation/conversation_bloc.dart`
- Modify: `mobile/lib/blocs/dm/conversation/conversation_event.dart`
- Modify: `mobile/lib/blocs/dm/conversation/conversation_state.dart`
- Test: `mobile/test/screens/inbox/conversation/collaborator_invite_card_test.dart`
- Test: `mobile/test/blocs/dm/conversation_bloc_test.dart`

- [ ] **Step 1: Write widget test**

Given a `DmMessage` with invite tags, expect a card showing the video title or fallback address, creator identity text, Accept action, and Ignore action. The card must not render for ordinary DMs.

- [ ] **Step 2: Write bloc tests**

Cover:

- accept sets local state to `accepting`
- successful publish sets local state to `accepted`
- failed publish sets local state to `failed`
- ignore sets local state to `ignored` and does not publish

- [ ] **Step 3: Implement card**

Use existing dark-mode components (`DivineButton`, `DivineIconButton`, `VineTheme`) and keep copy direct. Suggested visible strings:

- `Collab invite`
- `Accept`
- `Ignore`
- `Accepted`
- `Try again`

- [ ] **Step 4: Wire message rendering**

In `message_bubble.dart`, parse `DmMessage` through `CollaboratorInviteParser`; render `CollaboratorInviteCard` when parsing succeeds.

- [ ] **Step 5: Wire bloc actions**

Add conversation events for accept/ignore. The bloc calls `CollaboratorResponseService` and `CollaboratorInviteStateStore`.

- [ ] **Step 6: Run focused tests**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile
flutter test --no-pub test/screens/inbox/conversation/collaborator_invite_card_test.dart
flutter test --no-pub test/blocs/dm/conversation_bloc_test.dart --plain-name "collaborator invite"
```

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/screens/inbox/conversation/widgets mobile/lib/blocs/dm/conversation mobile/test/screens/inbox/conversation mobile/test/blocs/dm/conversation_bloc_test.dart
git commit -m "feat(collabs): accept invites from conversations"
```

### Task 12: Handle invite message requests

**Files:**
- Modify: `mobile/lib/screens/inbox/message_requests/request_preview_view.dart`
- Modify: `mobile/lib/screens/inbox/message_requests/message_request_actions_cubit.dart`
- Test: `mobile/test/screens/inbox/message_requests/request_preview_view_test.dart`

- [ ] **Step 1: Write request-preview test**

Given the latest request message is a collaborator invite, expect the preview to show invite actions without requiring the user to first send a regular DM.

- [ ] **Step 2: Reuse parser and card primitives**

Do not duplicate tag parsing in the message-request UI. Reuse `CollaboratorInviteParser` and a small action callback interface if the full card layout does not fit the preview.

- [ ] **Step 3: Preserve request semantics**

Accepting a collaborator invite publishes the public response and may mark the conversation as accepted/read, but it must not require a plaintext reply.

- [ ] **Step 4: Run focused tests**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile
flutter test --no-pub test/screens/inbox/message_requests/request_preview_view_test.dart --plain-name "collaborator invite"
```

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/inbox/message_requests mobile/test/screens/inbox/message_requests/request_preview_view_test.dart
git commit -m "feat(collabs): accept invites from message requests"
```

## Chunk 5: Creator-Side Retry And Post-Publish Adds

### Task 13: Surface invite delivery failures after publish

**Files:**
- Modify: `mobile/lib/services/video_publish/video_publish_service.dart`
- Modify: `mobile/lib/providers/video_publish_provider.dart`
- Modify: `mobile/lib/screens/create_post/create_post_screen.dart` or the current publish result UI owner found by `rg "PublishSuccess|PublishError" mobile/lib`
- Test: `mobile/test/services/video_publish/video_publish_service_test.dart`

- [ ] **Step 1: Write failing publish result test**

Simulate successful video publish with one failed invite. Expect publish success to remain success and expose failed invite pubkeys/errors.

- [ ] **Step 2: Extend publish result shape**

Add non-breaking invite warning fields to the publish success/result model. Avoid turning invite delivery failure into video publish failure.

- [ ] **Step 3: Show retry affordance**

Display a compact warning and retry action in the publish completion UI. The retry calls `CollaboratorInviteService.sendInvite` for the failed collaborator.

- [ ] **Step 4: Run focused tests**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile
flutter test --no-pub test/services/video_publish/video_publish_service_test.dart --plain-name "invite"
```

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/video_publish mobile/lib/providers/video_publish_provider.dart mobile/lib/screens/create_post mobile/test/services/video_publish/video_publish_service_test.dart
git commit -m "feat(collabs): surface invite delivery warnings"
```

### Task 14: Send invites when adding collaborators after publish

**Files:**
- Modify: `mobile/lib/widgets/share_video_menu.dart`
- Test: create or extend `mobile/test/widgets/share_video_menu_collaborators_test.dart`

- [ ] **Step 1: Write failing widget/service test**

Exercise `_addCollaborator` and expect it to both republish the video metadata with the collaborator role tag and send a NIP-17 invite to the new collaborator.

- [ ] **Step 2: Inject invite service**

Thread `CollaboratorInviteService` into the share/edit flow with constructor injection or existing provider access. Avoid creating an untestable singleton.

- [ ] **Step 3: Send invite after successful republish**

Only send the invite after the replacement video event publishes successfully, so the recipient's acceptance has a creator-authored pending tag to confirm.

- [ ] **Step 4: Run focused test/analyzer**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile
flutter test --no-pub test/widgets/share_video_menu_collaborators_test.dart
dart analyze lib/widgets/share_video_menu.dart
```

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/widgets/share_video_menu.dart mobile/test/widgets/share_video_menu_collaborators_test.dart
git commit -m "feat(collabs): invite collaborators added after publish"
```

## Chunk 6: Mobile Confirmed Reads

### Task 15: Update Funnelcake API client for confirmed collabs

**Files:**
- Modify: `mobile/packages/funnelcake_api_client/lib/src/funnelcake_api_client.dart`
- Test: `mobile/packages/funnelcake_api_client/test/funnelcake_api_client_test.dart`

- [ ] **Step 1: Write client tests**

Cover confirmed default endpoint and optional status query if Funnelcake exposes one.

- [ ] **Step 2: Update API docs/comments**

Change comments from "tagged as collaborator" to "confirmed collaborator".

- [ ] **Step 3: Run package tests**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile/packages/funnelcake_api_client
flutter test --no-pub test/funnelcake_api_client_test.dart --plain-name "collab"
```

- [ ] **Step 4: Commit**

```bash
git add mobile/packages/funnelcake_api_client
git commit -m "feat(collabs): read confirmed collab videos from funnelcake"
```

### Task 16: Stop treating raw `p` tags as confirmed profile collabs

**Files:**
- Modify: `mobile/packages/videos_repository/lib/src/videos_repository.dart`
- Modify: `mobile/lib/blocs/profile_collab_videos/profile_collab_videos_bloc.dart`
- Modify: `mobile/lib/widgets/profile/profile_collabs_grid.dart`
- Test: `mobile/packages/videos_repository/test/src/videos_repository_test.dart`
- Test: `mobile/test/blocs/profile_collab_videos/profile_collab_videos_bloc_test.dart`

- [ ] **Step 1: Write repository tests**

Expect `getCollabVideos` to return Funnelcake-confirmed results and not fall back to raw relay `p` tags as if they were confirmed. If a legacy fallback must remain, mark those results as legacy/pending and keep them out of confirmed profile tabs.

- [ ] **Step 2: Update BLoC wording**

Change state comments/copy to confirmed collaborator semantics.

- [ ] **Step 3: Run focused tests**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile/packages/videos_repository
flutter test --no-pub test/src/videos_repository_test.dart --plain-name "collab"

cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile
flutter test --no-pub test/blocs/profile_collab_videos/profile_collab_videos_bloc_test.dart
```

- [ ] **Step 4: Commit**

```bash
git add mobile/packages/videos_repository mobile/lib/blocs/profile_collab_videos mobile/lib/widgets/profile/profile_collabs_grid.dart mobile/test/blocs/profile_collab_videos/profile_collab_videos_bloc_test.dart mobile/test/widgets/profile/profile_collabs_grid_test.dart
git commit -m "feat(collabs): show only confirmed profile collabs"
```

### Task 17: Use collaborator feed edges in feed reads

**Files:**
- Modify: `mobile/lib/services/video_event_service.dart`
- Modify: `mobile/lib/providers/profile_feed_provider.dart`
- Modify: `mobile/packages/videos_repository/lib/src/videos_repository.dart`
- Test: add focused tests in the package or app layer that owns feed fetch behavior.

- [ ] **Step 1: Write feed behavior test**

Followed collaborator gets a confirmed collaborator video from Funnelcake feed edges. Pending collaborator role tags do not expand the feed.

- [ ] **Step 2: Remove hot raw tag expansion**

Remove or feature-gate the feed path that adds collaborator `p` tag filters to hot feed queries. Feed expansion should come from Funnelcake edge rows.

- [ ] **Step 3: Run focused tests**

Run the feed test added in Step 1 and the nearest existing feed/provider tests.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/services/video_event_service.dart mobile/lib/providers/profile_feed_provider.dart mobile/packages/videos_repository
git commit -m "feat(feed): use confirmed collaborator feed edges"
```

## Chunk 7: End-To-End Verification

### Task 18: Full lifecycle smoke test

**Files:**
- Modify docs only if needed: `docs/superpowers/plans/2026-04-25-collab-full-lifecycle.md`
- Optional: `mobile/docs/NOSTR_VIDEO_EVENTS.md`

- [ ] **Step 1: Manual protocol smoke**

Using two test accounts:

1. Creator publishes a video with collaborator role tag.
2. Collaborator receives encrypted invite DM.
3. Collaborator accepts.
4. Funnelcake indexes `KIND_COLLAB_RESPONSE`.
5. `/api/users/{collaborator}/collabs` returns the video after confirmation.
6. Collaborator profile shows the video.
7. Following feed includes the video through collaborator edge.
8. Creator edits the video and removes collaborator.
9. Funnelcake removes the collaborator edge.

- [ ] **Step 2: Run Funnelcake verification**

```bash
cd /Users/rabble/code/divine/divine-funnelcake
cargo test
```

- [ ] **Step 3: Run mobile focused verification**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile
flutter test --no-pub test/services/collaborator_invite_parser_test.dart
flutter test --no-pub test/services/collaborator_invite_state_store_test.dart
flutter test --no-pub test/services/collaborator_response_service_test.dart
flutter test --no-pub test/screens/inbox/conversation/collaborator_invite_card_test.dart
flutter test --no-pub test/blocs/dm/conversation_bloc_test.dart --plain-name "collaborator invite"
dart analyze lib/services/collaborator_response_service.dart lib/services/collaborator_invite_parser.dart lib/screens/inbox/conversation/widgets/collaborator_invite_card.dart
```

- [ ] **Step 4: Run generated-code-sensitive verification**

Because this plan touches Drift generated inputs:

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/collab-invite-repost/mobile
dart run build_runner build --delete-conflicting-outputs
git status --short
```

Commit any intentional generated files.

- [ ] **Step 5: Final commits and PRs**

Open the Funnelcake PR first. After Funnelcake is deployed or behind a feature flag, open/update the mobile PR with the confirmed-read switch.

Use Conventional Commit PR titles:

- `feat(collabs): add confirmed collaborator read model`
- `feat(collabs): accept collaborator invites`
