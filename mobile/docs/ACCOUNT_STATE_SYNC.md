# Account settings and read-state sync

Account-owned choices must survive a device change. The owning repositories retain local intent before transport, reconcile on startup/foreground/reconnect, and process incoming updates. Relay/query and storage failures retry with capped backoff while pending work remains. Signer failures are deliberately nonretryable: the signer SDK exposes no reliable typed distinction between refusal and a transient RPC failure. To avoid repeated authorization prompts, durable pending edits wait for another foreground, reconnect, incoming source, local edit, or explicit sync trigger. Error messages are not parsed to guess refusal. A network failure does not roll a successfully persisted individual choice back.

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

The generic repository has independent local-write and network queues. Closing drains local persistence and startup migration before owner erasure; it does not wait for network acknowledgments. A setter returns only after its account-scoped journal is saved. Slow signers, relay queries and acknowledgments do not hold local edits behind them. The journal contains the local projection, pending intent and retained signed relay sources; private relay payloads remain encrypted. Preferences and badge adapters retain their existing small SharedPreferences journals. The growing DM dismissal journal uses an injected DriftAccountStateStorage adapter: fields, signed sources and pending metadata are separate owner/namespace-scoped records, reconciled transactionally with only changed records written. The engine retains all merging and source-barrier logic. Readable legacy preference journals migrate before retirement; unreadable sources stay preserved for recovery. No journal contains signing keys.

Complete relay reads are required before publishing a replacement snapshot. Valid signed source events are retained before consolidation, and sources arriving during encryption/signing/publication cannot be dropped during compaction. Unknown or unreadable schemas are a durable write barrier. The original signature is reused when repairing a relay that lost an acknowledged copy. A source fence immediately before handing a publication to NostrClient blocks a newer schema already received locally. Publication linearizes at that handoff: an already-started transport operation cannot be recalled or made atomic across relays. Sources received afterward remain barriers for subsequent attempts.

AccountPreferenceStore projects typed values into the existing services and notifies Cubits/listenables without echoing writes. Legacy migration imports only explicit, provably owned choices; materialized defaults are not treated as user intent. Shared projection serialization and account-generation checks prevent an outgoing native write completing over an incoming account. Temporary sign-out or switching preserves account journals for retry; explicit local account-data erasure removes only that owner's journals and migration markers.

Read owners retain their own protocols. DM intent includes the cursor map and captured same-second message IDs independently of disposable conversation cache rows; stale acknowledgments cannot clear newer local reads. Local reads and synced dismissal boundaries preserve previously unknown same-second incoming IDs as unread. The existing v1 DM read marker carries timestamps only: a receiving device without a matching local or dismissal ID boundary retains timestamp precision and treats messages at or before that cursor as read. This change preserves that wire contract rather than claiming exact remote message-ID precision. Notification intent uses Drift notification_reads and notification_read_members: concrete raw server IDs, pending flags and exact cached group membership are durable and account scoped. Readable legacy preference journals migrate transactionally before removal; malformed JSON or shape stays untouched with a safe diagnostic. Pending IDs are never pruned. Acknowledged overlays survive replica lag only while their raw IDs remain in current cached membership; snapshot replacement and startup cache hydration prune evicted overlays. Mark-all acknowledges only its captured known IDs and never creates an outbox all:true request. DM read-journal corruption likewise preserves the original source in quarantine before a new write, and never crashes listening. A new group member arriving during a local write is not implicitly read. Mark-all remains online because source-event timestamps cannot identify notification arrival order; queueing a later whole-account mark-all would consume new arrivals.

The DM dismissal adapter opts into per-field replaceable snapshots. A field uses d = namespace + "/field/" + a random 256-bit lowercase hexadecimal address, saved before encryption/signing. Addresses are not derived from public participant keys: such derivations allow dictionary discovery of conversation peers. Devices learn field/address mappings only from authenticated decrypted payloads. Concurrent initial addresses converge on the lexicographically smallest full address, independently of the winning field value; old addresses remain valid signed merge inputs. Its version-1 payload contains exactly that one entry. The engine still reads legacy base-namespace snapshots, merges all fields and retains null tombstones and exact full known-ID boundaries. Because Nostr has no d-tag prefix filter, this mode queries/subscribes to the account's kind-30078 events, ignores other namespaces, and requires exactly one decrypted entry before learning its opaque address. A complete read and all retained signed-source/schema barriers are required before any shard publication. Only changed or missing shards publish; each accepted shard is durably saved before advancing, and partial failures leave remaining intent pending. One engine/signer/subscription owns the collection. Preference and badge namespaces keep their original single-snapshot wire formats.

Each individual field still obeys the 65535-byte NIP-44 UTF-8 plaintext ceiling and relay event-size limits. An oversized field emits a safe explicit diagnostic, throws AccountStateException, retains all pending intent, and never truncates known IDs or reset history. It needs a later edit or explicit trigger; no automatic signer prompt loop runs. It does not silently drop fields or reset history to fit. These are application-defined schemas on standard NIP-78; do not point unrelated NIP-78 data at these parsers or assume an unsupported client reads them automatically.

See the package tests for real-signature, independent-store convergence and source-barrier races; the app tests for preference projection/account transitions; and the DM/notification tests for durable retry and newer-arrival boundaries.
