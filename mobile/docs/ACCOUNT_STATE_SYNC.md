# Account settings and read-state sync

Account-owned choices must survive a device change. The owning repositories retain local intent before transport, reconcile on startup/foreground/reconnect, and process incoming updates. Transient failures retry with capped backoff while pending work remains. A network failure does not roll a successfully persisted individual choice back.

## Ownership and existing protocols

| State | Owner / transport | Merge behavior |
| --- | --- | --- |
| App/content preferences | AccountStateRepository through AccountPreferenceStore | Timestamp per field; explicit null resets |
| Badge rejection / Undo | BadgeRepository using the shared engine | Timestamp per definition coordinate; Undo wins ties |
| Conversation dismissal / restore | DmRepository using the shared engine | Per participant tuple; through-message boundary |
| DM reads | DmRepository, existing self-addressed encrypted marker | Forward-only cursor per participant tuple |
| Individual/batch notification reads | NotificationRepository, existing authenticated server API | Durable concrete server-ID set and retry queue |
| Notification mark-all | Existing atomic online server API | Requires acknowledgment; never replay all:true later |
| Follows, likes, reposts, bookmarks, lists, profile data and blocks | Existing owning Nostr repositories | Their existing protocol and reconciliation rules |
| Drafts/media recovery | Existing creator-sync and media owners | Existing encrypted creator/media protocols |

The explicit preference registry covers content/display language, subtitle target and original-language choices, audio reuse defaults, hosting/provenance filters, feed shape, category preferences, appearance, stats, notification choices, default account labels, and labeler trust/subscriptions. Labeler subscriptions use separate per-pubkey fields. Account labels remain a deliberate whole-set preference and retain the existing public label publication path; applying a private synced preference does not echo a public event.

Device permissions, credentials, analytics and age-verification consent, protected-minor enforcement, camera/audio hardware, gallery/cache/storage/bandwidth controls, developer/security switches and local files are not copied into account preference snapshots. A reset to system language/appearance follows each device's system setting. No livestream/live-spaces behavior is changed.

## Private account-state wire format

Events are signed kind 30078 with the account as author and one d tag selecting a namespace. Content is NIP-44 encrypted to that same account. The decrypted generic payload is:

```json
{
  "version": 1,
  "entries": {
    "content_language": {"value": "es", "updated_at": 1700000000000},
    "app_locale": {"value": null, "updated_at": 1700000000001}
  }
}
```

Timestamps are milliseconds. Fields merge independently; larger timestamps win. Boolean ties prefer false; other ties compare canonical JSON with sorted map keys. Numeric-maximum fields additionally preserve forward-only numeric state. Missing means never set; null is an explicit reset/tombstone. Never prune resets merely because their display value matches a default: an older device may still publish the previous value.

Namespaces currently used:

- divine/preferences/v1: registry field names from AccountPreferenceRegistry. Category keys are content_filter/<label value>; notification keys are notifications/<model field>; labeler membership keys are trusted_labeler/<full hex pubkey>.
- divine:badge-dismissals: legacy-compatible version 1 payload uses decisions instead of entries and hidden instead of value. Keys are full badge definition coordinates; values are booleans.
- divine/dm-dismissals/v1: keys are sorted, comma-joined full participant pubkeys. A value of null restores; a dismissal value contains through (message timestamp) and known (full message IDs known at the boundary). The receiving DAO applies the exact boundary and restores visibility for newer messages, including previously unseen same-second IDs.

The existing DM-read marker is a separate encrypted kind-30078 rumor inside a self-addressed gift wrap. This change does not replace it with the generic wire format. A second client must implement the matching namespace/schema to consume the corresponding state.

## Durability and lifecycle

The generic repository has independent local-write and network queues. A setter returns only after its account-scoped journal is saved. Slow signers, relay queries and acknowledgments do not hold local edits behind them. The journal contains the local projection, pending intent and retained signed relay sources; private relay payloads remain encrypted. Local SharedPreferences storage uses the same device storage boundary as the existing preference services and contains no signing keys.

Complete relay reads are required before publishing a replacement snapshot. Valid signed source events are retained before consolidation, and sources arriving during encryption/signing/publication cannot be dropped during compaction. Unknown or unreadable schemas are a durable write barrier. The original signature is reused when repairing a relay that lost an acknowledged copy. A source fence immediately before handing a publication to NostrClient blocks a newer schema already received locally. Publication linearizes at that handoff: an already-started transport operation cannot be recalled or made atomic across relays. Sources received afterward remain barriers for subsequent attempts.

AccountPreferenceStore projects typed values into the existing services and notifies Cubits/listenables without echoing writes. Legacy migration imports only explicit, provably owned choices; materialized defaults are not treated as user intent. Shared projection serialization and account-generation checks prevent an outgoing native write completing over an incoming account. Temporary sign-out or switching preserves account journals for retry; explicit local account-data erasure removes only that owner's journals and migration markers.

Read owners retain their own protocols. DM intent includes the cursor map independently of disposable conversation cache rows; stale acknowledgments cannot clear newer local reads. Notification intent persists raw server IDs and group membership so cached group IDs are expanded correctly after restart. A new group member arriving during a local write is not implicitly read. Mark-all remains online because source-event timestamps cannot identify notification arrival order; queueing a later whole-account mark-all would consume new arrivals.

The generic transport uses replaceable snapshots subject to NIP-44 and relay event-size limits. It does not silently drop fields or reset history to fit. These are application-defined schemas on standard NIP-78; do not point unrelated NIP-78 data at these parsers or assume an unsupported client reads them automatically.

See the package tests for real-signature, independent-store convergence and source-barrier races; the app tests for preference projection/account transitions; and the DM/notification tests for durable retry and newer-arrival boundaries.
