# Challenges repository

Pure Dart known-coordinate reads and participant delivery on the verified
`challenge_protocol` convention. This package has no production API DTO, relay
connection, database, signer key storage, global discovery or app UI.

## Read boundary

`ChallengeReadSource` returns immutable raw JSON records and separate source,
completion, revision-coverage and indexing metadata. The repository bounds raw
record count and UTF-8 bytes before parsing. It retains authenticated malformed
latest definitions instead of filtering them out by successful challenge parse.
Malformed JSON and nonobject wire input are never newly retained; legacy
instances of those records are skipped during replay. A malformed current
observation is unavailable, but the next valid complete read can recover.
Retained replay uses the protocol reducer and **current** visibility policy,
including pinned snapshots, duplicate selection and unavailable winners.

Incomplete revision retrieval cannot display cached open rules. Partial event
pages may expose known state only when the adapter explicitly establishes
complete revision retrieval. Only complete indexed observations without pending
dependencies expose `completeEntryCount`; known relay state never does.

Adapters must bound network allocations before constructing observations, and
implement durable union retention without silently evicting newer definitions.
The default replay budget is 512 records, 128 KiB per envelope and 4 MiB total;
exhaustion is unavailable, not a truncated successful response. Reduction is
synchronous CPU work: the app adapter must schedule large replay off its UI
isolate. No responsive-device claim is made here.

## Consent and durable delivery

`prepareEntry` requires exact signed definition and video revisions owned by
the current signer. `currentVideoId` must come from the established successful
video publication pipeline; null means unavailable or scheduled, and cannot
enter a challenge. Review preparation awaits owner-scoped handoff persistence.
Pass the established app's NIP-89 client tag through `clientTags` **before**
consent. Signers receive exact immutable reviewed fields; post-review tag
injection or any other field rewrite is rejected.

New consent/signing/re-entry rechecks the current open active definition,
current video revision, owner and policy across asynchronous boundaries.
`canPublish` is actor/action permission; `isVisible` is current source/media
visibility. They are separate so hidden media cannot prevent an owner from
withdrawing their exact entry.

The store must atomically insert owner-scoped signed work before any relay
publication. Store `signedBody` verbatim and retain it through unknown
acknowledgements, indexing lag, crashes and retry failures. Store contracts
throw on failure; no write result may mean "queued but not durable". Instantiate
one writer per app account session; store insertion must still be atomic.
`pendingActions` and `restoreReview` expose owner-scoped restart recovery.

`submit` serializes duplicate taps. Explicit `retry` loads exact persisted bytes
and never signs. Persisted entry retries may proceed after the exclusive end,
later active rules or later video metadata edits: the signed in-window consent
and pinned video remain unchanged. Current cancellation, unavailable/malformed
current definition, owner change or current policy restriction pauses delivery
without deleting the action. Cancellation returns `deliveryPaused` with the
signed action; unavailable current rules return `readUnavailable`. Neither asks
for replacement consent. This makes no claim about timely relay receipt or
organizer eligibility. New signatures recheck current reviewed rules before and
after signing, before durable insertion. Once insertion completes, the first
publication uses exactly the same persisted-consent gates as a later retry.

Withdrawals target one exact owned verified entry. Closure, cancellation and
hidden video do not prevent withdrawal or retry; owner/action permission still
applies. Withdrawal neither deletes nor republishes a video. Re-entry requires
new explicit consent while open. An identical already-persisted template is
refused as new consent; same-second re-entry must wait for a fresh creation
second rather than inventing a timestamp or wire tag.

Publication targets the reviewed definition's advertised challenge relays plus
configured writable relays, with per-target acceptance/rejection/silence/
unreachable outcomes. Only advertised challenge-relay acceptance or a verified
matching echo marks submitted. API exact-ID indexing is independent, and a
configured-only ACK cannot establish challenge submission. Reconciliation
persists simultaneous indexing and relay evidence independently.

## Verification

Run from this package with the workspace's pinned Flutter 3.47.2:

- `flutter pub get --enforce-lockfile` from the app workspace.
- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze --no-pub`
- `very_good test --coverage --min-coverage 95`

Tests use ephemeral synthetic signers and the merged protocol's pinned replay
fixtures. Package and app working-directory invocations are supported. Fake
store restart tests verify port ordering and exact-byte reuse; they do not prove
SQLite crash durability or end-to-end native delivery.
