# Room engagement implementation plan

> Execute with superpowers:subagent-driven-development. User delegated the participant definition and implementation on 2026-10-29.

**Goal:** Help people find active public chat rooms and see new messages before opening them.

**Design:** Each room shows unread count, latest message and time, and unique contributors and message count in the last 24 hours. Use recent contributors, not online presence or membership. Counts cover retained, verified history; show a lower-bound indicator when the relay history window is full. Unread state is per account, relay and channel on this device, excludes self-authored messages, survives restart, and advances only when the room is foregrounded at the newest messages. Empty/loading/error states distinguish unknown from zero. The Rooms selector carries the aggregate unread count. Preserve catalog order and existing feature/account/minor gates.

**Approaches:** A badge-only change would not solve discovering activity. Online presence needs new protocol/backend work and cannot be derived from message history. Use the existing verified Concord timelines for a complete room summary, with shared repository sessions to avoid duplicate relay subscriptions or concurrent writers to each channel store. The user delegated this choice.

**Architecture:** Add a Flutter-free RoomActivityRepository and summary models in concord_repository. Construct it with channel repositories and account-scoped stores. Application provider supplies one instance for the authenticated signer and relay. A RoomsCubit adapts summary changes for UI. ChatPage reuses the session's channel repository; ChatScreen acknowledges the currently rendered timeline only when visible, resumed, and scrolled to latest. Tests can still inject isolated chat repositories.

- [x] Package: test unread/unique contributors/recent counts/edits/deletion/expiry/dedup/read persistence/loading/errors and resource cleanup; implement source aggregation and read metadata.
- [x] App: share room sessions behind existing gates, wire RoomsCubit, reuse repositories in ChatPage, record reads with route/app/scroll visibility. Test lifecycle and account isolation.
- [x] UI: accessible adaptive room rows, latest preview/time, recent contributor avatars/count, unread and aggregate badges, loading/retry/empty states. Localize new copy and run consistency checks. Cover narrow layouts, large text, light/dark and navigation.
- [x] Validate package tests, affected app tests, localization guards and flutter analyze. Rebase, review complete diff in fresh context, resolve findings, commit/push/open PR targeting main, request mapped reviewers and inspect CI.

No livestream/LiveKit work. No synthetic activity or online claims. No real account identifiers in committed artifacts.

## Verification and review decisions

- Local verification: 257 affected Flutter and localization tests passed; 86 concord_repository tests passed; CI-equivalent `flutter analyze --no-pub lib test integration_test tools` clean; plural-category floor and whitespace checks passed.
- Initial relay EOSE and pending verification must finish before a room is known-empty. Raw response limits count discarded and duplicate wraps and remain conservative across reconnects.
- Read snapshots coalesce only after a rendered frame and request a frame on app resume; covered/background/scrolled-away rooms do not acknowledge new messages.
- Resolve the current signer for each send, bound to the captured authenticated account, so a recovery upgrade does not pin an unavailable signer.
- Stop owned channel writers immediately on teardown, before waiting for read metadata persistence. Keep exact read IDs: a timestamp watermark would mark a late delivery read, while exact IDs keep it unread.
- All ten new labels are translated in every shipped locale; no localization debt was added. Empty copy refers to recent activity, not all-time history.
