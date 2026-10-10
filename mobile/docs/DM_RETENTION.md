# DM retention

How long a direct message survives, and where. Written because the answer
differs per store, the stores disagree, and until #7850 nobody had written it
down.

**This file records what the code does today. It is not a policy ruling.** The
retention decision for the server-side moderation DM log is open and belongs to
Trust & Safety; see [The open decision](#the-open-decision).

## The short version

| Store | Owner | Holds | Lifetime |
|---|---|---|---|
| `direct_messages`, `conversations` (Drift) | the device | decrypted rumors | until the user removes the thread, or the account is switched or signed out |
| `removed_conversations` (Drift) | the device | tombstones | the account's lifetime; cleared only on a full data delete |
| `removed_message_ids` (Drift) | the device | ids of messages and reactions removed with a conversation | the account's lifetime; cleared only on a full data delete |
| `processed_gift_wraps` (Drift) | the device | wrap-id dedup ledger | unbounded — see [Client tables](#client-tables) |
| relay (`kind:1059` gift wraps) | funnelcake | the encrypted wraps | at the relay's discretion; **destroyed on a NIP-62 vanish** |
| `dm_log` (D1, `divine-moderation-service`) | Divine | a plaintext copy of every moderation DM | indefinite — nothing deletes it |

The last two rows are the ones that matter, and they point in opposite
directions: the user's copy is the destructible one and ours is not.

## Why the user's copy is fragile — and why that is the protocol working

None of this is a Divine bug. NIP-59 says both parts outright:

- *"Relays may choose not to store gift wrapped events due to them not being
  publicly useful."* Storage of a `kind:1059` is optional.
- *"Since signing keys are random, relays SHOULD delete `kind:1059` events whose
  p-tag matches the signer of NIP-09 deletions or **NIP-62 vanish requests**."*

Funnelcake implements exactly that: its vanish cascade selects gift wraps by
recipient `p` tag and hard-deletes them. So when a user exercises the
account-deletion flow this app ships, **every gift wrap addressed to them is
destroyed**, an enforcement notice among them.

The local copy is no safer. An account switch or sign-out clears the DM tables
for the departing account, and a reinstall takes the whole database. Recovery
after any of those is by re-reading wraps from relays — and after a vanish there
is nothing left to re-read.

NIP-17 lists *"Fully Recoverable: Messages can be fully recoverable by any
client with the user's private key"* among its benefits. That is the property
that does not hold here, and it is why "the user still has their copy" is not a
safe assumption to build on.

Divine does **not** set a NIP-40 `expiration` tag on enforcement notices, so
the intent is clearly that the user keeps them. There is simply no mechanism
that delivers it.

## Client tables

Every DM table on the device, and what bounds it. Only one is bounded by code.

| Table | Bounded | By what |
|---|---|---|
| `direct_messages` | no | user removal or account teardown only. A NIP-09 "delete for everyone" is a **soft** delete: the row and its content stay so gift-wrap dedup keeps working |
| `conversations` | no | same |
| `removed_conversations` | no | deliberately. The tombstone must outlive relay replay, so it is kept for the account's lifetime and cleared only when the user deletes their data |
| `removed_message_ids` | no | deliberately. A rumor id is exact evidence that a message is gone for good, so a later NIP-09 retraction naming it can be settled and a replay of it is not stored again. Kept for the account's lifetime and cleared only when the user deletes their data. Ids and a timestamp only, no content |
| `outgoing_dms` | partly | deleted on successful send or user cancel; a permanently failed row is marked `failed` and kept for manual retry; a delivery the sender stopped for a member of a stored group message is kept as `cancelled` (the record behind "Not sent to everyone") until the message is retracted, the conversation is removed or the account is cleared. The exception is a one-to-one row addressed to its own sender, which is deleted when a retry reaches it and at the next sign-in (#8363) |
| `dm_message_reactions` | no | removed with their conversation; NIP-09 and own-supersede are soft deletes |
| `pending_gift_wraps` | **yes** | attempts cap plus `deleteExhausted`, run at the top of every retry pass |
| `processed_gift_wraps` | no | history drains read the ledger to avoid re-decrypting terminal outcomes; pruning entries makes old reactions, deletions, unsupported kinds, and tombstone-suppressed wraps eligible for decryption again |

`processed_gift_wraps` is the odd one out: its sibling `pending_gift_wraps` is
bounded, while the history drain continues to consult processed rows on later
passes. The table stores outcomes that may have no message row (reactions,
deletions, unsupported kinds, and messages suppressed by a removal tombstone),
so those rows remain part of the dedup ledger while history can be replayed.
Its long-term growth should be measured before changing that policy.

## The server copy

`dm_log` lives in `divine-moderation-service` (`migrations/003-dm-support.sql`).
It is **not** on the device and is not the mobile DM list — the issue that
prompted this file conflated the two.

Three facts about it, each verifiable from that repo:

1. **Nothing deletes it.** Every `DELETE FROM dm_log` in the repo is in a test.
   There is no TTL, no scheduled sweep (the worker's two cron triggers run the
   creator-delete pipeline and the relay poller), and no lifecycle rule.
2. **`content` is the message itself.** The same string that is gift-wrapped is
   stored, so the row is a byte-identical server-side plaintext copy of an
   end-to-end-encrypted message. No `UPDATE` ever rewrites it.
3. **The vanish cascade does not reach it.** It is ClickHouse-side and names no
   D1 table; the moderation service has no vanish, erasure, or NIP-62 handling
   at all.

Its own design doc says it was meant to be neither of those things:

> - **D1 `dm_log` table** as operational index for the admin dashboard
> - **Relay** as source of truth for message content

The index now outlives the source of truth it indexes, and holds in the clear
what the source of truth only ever held encrypted. Nothing chose that; it is
what happens when one store is given a lifetime and the other is not.

## The open decision

Whether Divine should retain moderation DM records indefinitely is a Trust &
Safety call, not an engineering one, and it has not been made. Retaining
enforcement records through an erasure request is a normal and defensible
posture — but it has to be decided, not inherited.

`divine-moderation-service/docs/trust-safety-report.md` carries a
**Data Storage & Retention** table giving a lifetime for every store the
service writes. `dm_log` is absent from it. Adding a row there is the last step
of #7850 and needs the decision first.

Until then, treat the client behaviour as the contract: the app protects the
user's copy of a moderation notice from deletion, and cannot protect it from a
relay that no longer serves the wrap.

## Related

- `mobile/docs/RETIRED_MODERATION_KEYS.md` — the rotation register. A key
  rotation forks the conversation id, so retired-key rows are a disjoint set.
- #7850 — this retention question.
- #8304 — what a user is entitled to be told about an enforcement action.
- #8391 / #8400 — the removal guard that stops the user destroying their copy.
