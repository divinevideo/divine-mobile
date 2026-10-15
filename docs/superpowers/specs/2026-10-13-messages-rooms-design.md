# Messages: Direct and Rooms

## Intent and status

Approved product direction: put Concord community rooms inside Divine's existing
Messages surface, alongside direct messages, using the existing Divine account.
Web uses https://divine.video/chat. Native mobile uses native Flutter screens.
There is no separate chat account, login, or custom callback scheme.

This document records that direction and the implementation contract. It does
not claim the Concord runtime or the UI has shipped. At the inspected mobile
base, 835f9ab418, main has no Concord implementation. A separate local worktree
has started a concord_protocol package; its ownership and repository API must
be coordinated before integration. Do not edit or copy its uncommitted work.

## Navigation

Preserve the existing Inbox's Notifications / Messages selector. Inside
Messages add a compact Direct / Rooms selector; do not add a bottom-navigation
destination or a third item to the Notifications / Messages selector.

- Direct contains the existing one-to-one and group DMs, message requests,
  moderation support entry, search, filters, and compose action.
- Rooms contains joined Concord communities with their channels grouped under
  community headings. Start with the Divine community; do not impose a
  single-community data model.
- The first visit selects Direct. Remember the last selected view per account
  on this device. An explicit room link selects Rooms; an explicit DM entry
  selects Direct, overriding the saved preference for that navigation.
- Preserve each list's scroll position and Direct's search/filter state when
  switching views. Hidden views must not receive taps, accessibility focus,
  or mark conversations as read.
- Account changes clear the previous account's rendered state immediately,
  cancel pending UI operations, and load only the new account's preference.
  An old asynchronous completion cannot restore the previous account's state.

Mobile navigation is Rooms list -> room conversation -> room details. Back from
a room returns to its Rooms list. Room links must resolve from durable room
coordinates and the account repository after a cold start; route extras are
only optional warm-start hints. Secret invite fragments must never enter logs,
analytics, crash reports, or public path/query parameters.

On desktop web, show the Direct / Rooms selector and lists in the conversation
sidebar beside the selected conversation. Narrow web layouts use the same
list-to-conversation flow as mobile. Integrating into the existing Divine web
SPA does not require changing its root asset base or service-worker scope.

## Rooms list and joining

Render room name, community context, a public/private label, unread activity,
mention count, and muted state from repository data. Do not infer permissions
or bridge status from names such as general or announcements.

The unjoined state offers Join the Divine community only when a real configured
invite is available. Joining opens a full-screen preview showing the community,
public access, bridge disclosure where applicable, and an explicit Join action.
An invite can also open this preview directly. Never autojoin on link opening.
Invalid, expired, revoked, offline, and pending membership states have distinct
UI states. A submission is not treated as membership confirmation.

If no deployment/invite is configured, do not invent a room or working Join
button. Keep the feature unavailable through the existing feature-gate system
until the real integration passes its release checks. A repository failure is
an error with Retry, not an empty joined-community list.

Existing protected-account access rules must be applied explicitly to community
entry. A second messaging surface must not bypass the existing account policy.
If no applicable community policy is available, preserve the restrictive gate
until that decision is made.

## Room conversation

Use familiar message history, composer, reply, and reaction interactions, with
the community and channel name visible in the header. Use separate Concord
state and persistence; do not feed community events to the DM decoder or store
them as DM conversations.

The repository supplies effective read/write capabilities. A read-only room
shows that only authorized members can post. Losing permission disables the
composer immediately; send-time authorization is rechecked by the repository.
A pending send is not shown as delivered until the publication criteria are
met. Failed sends remain visibly retryable without publishing duplicates.

Room details expose member information, notification settings, leaving, and
reporting supported by the runtime. Reporting uses the existing safety flow
with the correct Concord context. Do not silently upload decrypted history.
Administrative roles and community management remain web responsibilities in
the first mobile release.

## Privacy and notifications

Bridged public rooms display “Public · Linked to Discord” and explain that
messages are also shared with Discord. Do not use a lock icon or claim those
rooms are end-to-end private. Unknown bridge status is not evidence of privacy.
Non-bridged room copy must still reflect Keycast custody: encryption protects
against relays and outsiders, not Divine acting as the key-custody operator.

Only public Discord channels are eligible. Tickets and every private support
channel remain excluded. Discord remains live and canonical. These UI changes
do not import channels, change the bridge, or authorize production deployment.

Default room notification preference is mentions. Ordinary room activity uses
an unread dot; mention counts are distinct. Messages' aggregate attention count
includes existing DM attention plus eligible unread room mentions, without
counting every community post. Notification preferences, muting, read cursors,
and cross-device read-state semantics must be implemented in the repository;
do not invent new protocol event kinds for UI convenience.

Opening a visible room marks only messages actually presented as read. An
inactive app, a hidden pane, or prefetching must not mark them read. Expired
messages must disappear from timelines, previews, searches, and notifications;
CORD-08 receiver safety is required even while timer controls remain deferred.

## Integration boundary

Keep the existing flow UI -> BLoC/Cubit -> Repository -> Client.

- InboxPage owns dependency wiring. A small messages-navigation Cubit owns
  Direct / Rooms selection and account-scoped preference restoration.
- Extract the existing Direct content without changing its DM behavior.
  Keep ConversationListBloc and DmRepository responsible for direct messages.
- Rooms list, join, and conversation features each use a Page/View split and
  BLoC/Cubit state. Riverpod may bridge existing account-scoped dependencies;
  new feature state does not belong in providers.
- The Concord repository owns joined-community/channel snapshots, membership
  status, effective permissions, message history, publication outcomes, unread
  and mention state, notification preferences, invite validation, expiry, and
  subscription lifecycle. Widgets never decrypt events or calculate authority.
- Use the existing account signer. Session refresh must update signer access;
  logout/account switch disposes subscriptions and plaintext state. Community
  List kind 33302 sync belongs to the Concord implementation.
- Repository state must distinguish initial loading, usable cached data while
  offline, verified empty results, failure, lost access, and pending admission.
  No successful empty fallback when the backend is unavailable.

Agree actual types and method names with the Concord implementation owner
before coding consumers. This document defines required behavior rather than
creating a second speculative protocol API. Dependent runtime and UI changes
must land together in one PR targeting main, or the runtime must land first;
do not open a stacked PR or ship a live Rooms tab backed only by mocks.

## Existing source anchors

- mobile/lib/screens/inbox/inbox_page.dart: account-scoped dependency wiring.
- mobile/lib/screens/inbox/inbox_view.dart: existing Notifications / Messages
  lifecycle and Direct list, including visibility and account-change handling.
- mobile/lib/screens/inbox/widgets/inbox_segmented_toggle.dart: existing outer
  selector, which remains unchanged in meaning.
- mobile/lib/router/routes/messaging_routes.dart: conversation navigation.
- mobile/lib/router/routes/shell.dart: Inbox branch in the existing app shell.
- mobile/lib/blocs/dm/conversation_list/: existing DM conversation state.
- mobile/packages/dm_repository/: existing DM persistence and delivery.

## Acceptance evidence

1. Existing Direct inbox, message requests, support row, filters, composing,
   navigation, and account-switch tests remain green after extraction.
2. Widget/Cubit tests prove selection restoration, explicit-link precedence,
   independent scroll/search state, hidden-pane accessibility and read-state
   isolation, and stale preference completion after account switching.
3. Rooms tests cover loading, offline cached history, verified empty state,
   error/retry, multi-community grouping, mention versus activity indicators,
   and accurate bridge/public labels.
4. Join tests prove preview-before-join, duplicate-submit protection, invalid
   and revoked invites, pending membership, protected-account gating, and
   cancellation on account change.
5. Conversation tests cover permission loss, read-only channels, failed-send
   retry/deduplication, message expiry, unread visibility, and reporting context.
6. Verify cold-start links and back navigation on native iOS and Android;
   verify web refresh, narrow/wide layouts, and existing authenticated session
   reuse at https://divine.video/chat in the owning web implementation.
7. Use real generated TypeScript/Dart interop fixtures and a controlled relay
   to prove that pinned Armada, Divine web, and Divine mobile exchange room
   messages. UI mocks do not count as protocol interoperability evidence.
8. Verify light/dark themes, large text, screen-reader navigation, localized
   copy in every supported locale, affected tests, and flutter analyze.
   Inspect relevant CI results before describing implementation as complete.

## Release boundary

Ship room entry only with functioning Concord dependencies, an explicit
community invite, moderation/reporting coverage, and passing interoperability
tests. POC remains first; production requires the infrastructure plan's Step 7
gate. Voice, pin controls, timer controls, and mobile community administration
remain outside phase one. No separate desktop client is required for this UX.
