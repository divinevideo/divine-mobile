# NIP-17 retry semantics: making a retry distinguishable from a repeat

Status: **ruled 2026-11-03. Adopt A′ (SHOULD), hold B behind field evidence,
ship no receiver-side suppression.** See "Recommendation" for the full ruling.
Tracking: [#6522](https://github.com/divinevideo/divine-mobile/issues/6522)
Author's evidence: reproduced end-to-end, see "Evidence" below.

This document records the protocol decision #6522 asks for and the evidence
behind it. It changes no behaviour and no wire format: Divine already does what
A′ asks, and B is specified but not implemented.

---

## The problem in one paragraph

A NIP-17 receiver stores a message under its rumor id. If a sending client
retries delivery by **re-minting** the rumor — building a new kind-14 with a
fresh `created_at`, and therefore a fresh `id` — the receiver has no way to tell
that from the user deliberately sending the same text twice. Both arrive as two
distinct rumors with identical content from the same sender in the same room.
The receiver renders two bubbles for one logical message.

There is no receiver-side repair for this. The two cases are byte-identical in
every field the receiver can inspect, so no heuristic can separate them; it can
only pick which error to make. Divine already made that choice deliberately in
[#7324](https://github.com/divinevideo/divine-mobile/issues/7324): suppressing
the second copy silently destroyed genuine repeated messages ("ok", "?", a
double-tapped send) with no error, no bubble and no recovery. Showing a
duplicate is the *less* harmful failure, and it is the current behaviour.

## Evidence

Reproduced on an iPhone 17 Simulator (iOS 26.5) against a local funnelcake
relay, with a hand-built NIP-59 peer that is not Divine:

- two gift wraps, byte-identical content, rumor `created_at` 30 s apart,
  distinct rumor ids, distinct wraps, distinct ephemeral wrap authors;
- both persisted into one conversation, no dedup gate logged a skip;
- the thread rendered two identical bubbles, and the message-request preamble
  counted them as separate messages ("they've sent 3 messages").

Confirmed against `nostr-protocol/nips` at `400d157` (2026-10-27): `kind 14`
carries only `p`, `e`, `subject` and `q` (`17.md:117-134`), followed by an open
"rest of tags". No NIP defines a per-message correlation or idempotency
identifier, and a search of the open pull requests found none that proposes
one. The nearest prior art is
[nips#2000](https://github.com/nostr-protocol/nips/pull/2000), a stale proposal
for a "Mark as Received" event. That is a delivery receipt a sender could use to
stop retrying, which is a different problem from telling a retry from a repeat.

## What Divine does today

Divine's sender **never re-mints.** Both recovery paths rebuild the rumor from
the stored `rumor_event_json` and republish it verbatim:

- `DmRepository.recoverFullSend` — retries a failed send
- `DmRepository.recoverSelfWrap` — replays the sender's cross-device copy

Both preserve `id` and `created_at`, so a receiver collapses the retry on its
rumor-id primary key. Every retry entry point routes through them — the
background sweep, the red-bubble "resend", the partial-delivery self-wrap
retry, and the inline reel-reply retry — and `outgoing_dm_retry_service.dart`
contains no rumor-building call at all.

Stated precisely: **Divine never re-mints a rumor it has stored.** Two paths do
mint a fresh rumor for the same text, and neither is a retry of a stored one:
`InlineReelReplyCubit.retry` falls back to a fresh `submit` when nothing was
parked (`inline_reel_reply_cubit.dart`), and `sendMessage` skips the
durable enqueue when no `outgoing_dms` DAO is wired. In both cases there is no
stored rumor and no wire copy in flight, so no duplicate can result. This is
now locked by
`dm_retry_rumor_identity_test.dart`; before that test it was protected only by
a doc comment, and a refactor that rebuilt the rumor through `buildRumor`
instead would have silently turned Divine into a source of this defect for
every peer it messages.

Two more paths build a rumor and are not retries of a stored one:

- `DmRepository.enqueueSend(idempotencyKey:, createdAt:)` (#8053) rebuilds the
  rumor on every call from the caller's key and timestamp, so a durable intent
  such as a queued report or a sound request reproduces the same rumor id, and
  the same `batch` value, each time. `dm_enqueue_send_test.dart` pins both
  halves: the same key and timestamp give the same rumor id, a different key
  gives a different one. It is retry-stable by construction rather than by
  replaying a stored row.
- `sendFileMessage` (video DMs) has no queue row and builds the rumor inside
  `sendPrivateMessage`. A second send encrypts the file again under a fresh key
  and nonce (`dm_video_encryption.dart`), so its content and tags differ from
  the first. It is a new message, not a re-mint of the old one.

One hop sits outside this repository. For a Keycast identity the rumor is
wrapped by the `nip17_wrap_batch` RPC, which takes the client's whole rumor,
rejects a wrong id (`verify_id`), fills in an id only when one is missing, and
wraps that rumor as given (`api/src/api/http/nostr_rpc.rs:366-380, 1609-1620`
at keycast `ca0d8a9`). Read from code only: the pass-through is neither
documented nor pinned by a test there, so a change on that side could re-mint
without anything in this repository noticing.

So, as the code stands, Divine does not cause this defect. It can only
receive it.

---

## Proposal A′ (ruled): state the contract

NIP-17 already makes the rumor id the message's identity — it requires the
field:

> `.content` MUST be plain text. Fields `id` and `created_at` are required.

If the id is the identity, then minting a new id *is* creating a new message.
That is already the spec's model; it is simply never said out loud, so
implementers reasonably treat a retry as "send it again" rather than "put the
same event on the wire again."

**Proposed addition to NIP-17, after the Encrypting section:**

> When a client retries delivery of a message it has already attempted to send,
> it SHOULD keep the message's identity: re-wrap the original rumor, or rebuild
> it with the same `created_at`, `tags` and `content`, so that its `id` does not
> change. A new `id` denotes a new message: receivers deduplicate on the rumor
> `id`, and a retry with a new `id` is indistinguishable from the user sending
> the same text twice. Only the seal and the gift wrap are rebuilt, since each
> carries a fresh ephemeral key and a randomized `created_at`. A retry sent
> later keeps the rumor's original `created_at`. Sending the same text again on
> purpose is a new message and needs its own `id`; a client that could send two
> identical rumors in one second has to make them differ.

A′ replaces the wording first proposed here ("MUST re-wrap the original
rumor") in three ways:

- **SHOULD, not MUST.** A re-minted retry shows the receiver a duplicate; it
  does not break the protocol. The neighbouring timestamp rule is also a
  SHOULD (`17.md:59`), and the three libraries read in "What third-party
  clients do" re-mint by default today, so a MUST would make them
  non-conforming on day one.
- **A rebuild with identical fields is allowed.** Divine's `enqueueSend`
  rebuilds its rumor from a caller-supplied key and timestamp rather than
  replaying a stored row, and a library that cannot hand the rumor back can do
  the same. What matters is that the `id` comes out the same, not how.
- **The converse is stated.** Without it, "reuse the id" reads as "a repeat may
  share an id", and same-second identical sends would collapse. Divine's
  `batch` nonce exists for exactly that case (`_sendBatchTagKey`).

**Why this is the right shape**

- It costs nothing. No new tag, no new field, no format negotiation, no
  privacy surface, no migration.
- It makes the ambiguity impossible at the source instead of asking receivers
  to guess after the fact.
- It is compatible with every existing client that already re-wraps; it only
  names behaviour some already have.
- Divine is a conforming reference implementation, so we are asking the
  ecosystem to do what we already do rather than to adopt something we invented.
- It is how the closest protocols settle the same question. The originator fixes
  an identity once and a retry reuses it, as Matrix does with its transaction
  id; on Nostr a resent event is an expected case that relays answer with a
  `duplicate:` OK (`01.md:171`), and NIP-17 edits keep "the same timestamp"
  (`17.md:89`).

**What it does not do**

It does not help against a client that ignores it, and it has no effect until
clients adopt it. Adoption is outside our control. This is why B is specified
and held.

---

## Proposal B (held, specified but NOT implemented): a correlation tag

Held. It is revisited when there is field evidence of a real client re-minting
on retry that adoption of A′ does not fix: either a named, widely used client,
or support logs showing it (see "What third-party clients do" for the
`contentCorrelation` token). Upstream declining A′ is not by itself the
trigger.

**Divine already ships a tag in this exact position, and it is instructive that
it cannot be reused.** `sendMessage` and `sendGroupMessage` both inject
`['batch', <256-bit secure-random hex>]` into the rumor. The
`_sendBatchTagKey` declaration, `_newSendBatchId` call sites, and receive-path
tag parsing show the complete lifecycle. Its own doc comment notes
that it "travels inside the encrypted rumor" and that "other clients ignore
unrecognised rumor tags, so it is inert on the wire" — so the extension point
is proven in production, not hypothetical.

Two properties stop it being the answer, and any correlation design has to
resolve both:

1. **Wrong polarity.** The token is minted once per *invocation*
   (`final sendBatchId = _newSendBatchId();`), and its documented purpose is
   "so two identical sends in the same Unix second produce distinct rumor ids."
   It is a **uniqueness nonce** — its job is to make two sends *differ*. Retry
   correlation needs the opposite: a token **stable across re-mints**. Because
   Divine replays the stored rumor on retry, the existing token has never been
   exercised as a cross-client correlator. `enqueueSend` lets a caller supply
   the key, which makes the value stable per intent, but it is still the
   sender's own token, read back only by the sender's own ingest.
2. **Peer-authored tokens are deliberately refused, with a stated attack.**
   Ingest honours the tag only when `rumor.pubkey == ownerPubkey`, because —
   quoting the code — "accepting a
   peer-authored `'batch'` tag would let a sender suppress the local user's own
   in-flight group persist." Honouring a peer's token is precisely what #6522
   needs, so **any cross-client correlation contract must answer this
   suppression vector before it can ship.** This is the strongest argument for
   preferring A′: a contract that says "reuse your own rumor" grants a peer no
   new power over the receiver's database, whereas any honoured peer-authored
   token does.

   One way to narrow the vector, offered as an untested inference: if the
   receiver only ever matched a token against earlier rows from the *same
   sender pubkey*, a sender could suppress only their own later message, not
   the local user's persist. No existing document evaluates this, and it needs
   the same review as the rest of B before it counts as an answer.

**Wire shape** — a tag inside the kind-14 rumor:

```json
["msgid", "<32 random bytes, hex>"]
```

- Generated once per **logical** message, at compose time.
- A retry re-uses the value. Two different messages MUST NOT share one.
- Random and opaque. It carries no derivation from the sender, the device, the
  session, the content, or any other message. It correlates a retry to its
  original and nothing else.

**Where it must live.** Inside the rumor, never on the seal or the gift wrap.
`59.md` is explicit that the outer layers exist to defeat exactly this kind of
linkage:

> When adding expiration tags to both `seal` and `gift wrap` layers,
> implementations SHOULD use independent random timestamps for each layer.
> Using different `created_at` values increases timing variance and helps
> protect against metadata correlation attacks.

A correlator on the wrap would be a relay-visible link between two events the
protocol works hard to keep unlinkable.

**Receiver semantics.** Claim-once, not existence. A logical message put on the
wire twice yields exactly one counterpart, so a stored row may absorb exactly
one arrival. `DirectMessagesDao.claimCrossProtocolTwin` is the existing
implementation of precisely this shape, including the single-statement
`UPDATE ... WHERE id IN (SELECT ... LIMIT 1)` that stops two concurrent
arrivals claiming the same row. Asking *existence* instead is what let one
stored row swallow every same-text arrival in
[#8211](https://github.com/divinevideo/divine-mobile/issues/8211).

**Costs to weigh before adopting**

- The value is readable by every recipient of a group send, and persists in
  each of their local databases.
- It needs a Drift migration and changes the dedup contract currently pinned by
  `direct_messages_dao_test.dart`.
- It still only helps against clients that adopt it — the same adoption problem
  as A′, but with a permanent format commitment attached.
- Group sends require one byte-identical rumor per send
  ([#8188](https://github.com/divinevideo/divine-mobile/issues/8188)); the tag
  must be identical across recipients or it re-forks the id.

---

## Approaches that are already rejected

Recorded so they are not re-proposed.

| Approach | Why it is rejected |
|---|---|
| Widen the ±5s dedup window | Absorbs legitimate repeated messages and re-creates #7324's silent data loss. It also would not even reach this case: post-[#8169](https://github.com/divinevideo/divine-mobile/issues/8169) a peer's rumor is only matched against a NIP-04 twin (`DmDedupCounterpart.nip04Copy`), so a NIP-17-onto-NIP-17 match is rejected at *any* delta and the window is not what decides here. That holds for a peer's rumors. The sender's own group rumors that carry no `batch` token still use the unconstrained ±5 s match (`dm_repository.dart:4310-4318` at `f3faefaa4a`), which is an echo of the user's own send and not a peer retry. |
| Content-hash dedup | Identical content is not evidence of the same send, and there is no safe time boundary. An unbounded rule permanently discards legitimate repeats. |
| Receiver-side heuristic suppression | Without a wire-level signal, any heuristic that catches a retry also discards a genuine repeat. It can only choose which error to make. |
| Anything keyed on the gift wrap's `created_at` | NIP-17 says clients SHOULD randomize that timestamp up to two days into the past (`17.md:59`), so a conforming client buries it in noise on purpose. Measured at ~45 h from the rumor's own timestamp in our repro, and between 1 and 45 h across six wraps built with `nak`. It is a SHOULD, not a MUST: a client that skips it would make the timestamp informative, which is no basis for a rule. |

## What third-party clients do

Which clients re-mint on retry was answered from source on 2026-11-02, at the
commits below. Nothing was run: each row says what the code does, not what an
app built from it does.

| Project | Commit | Does the built-in retry reuse the rumor? | Where |
|---|---|---|---|
| Amethyst (Quartz) | amethyst `553f761f22`, quartz `5ae28cbea1` | **Yes.** A retry republishes the wraps built on the first send, so the rumor, seal and wrap ids are all unchanged. | `Account.broadcastPrivately`: "Republishing the wraps we already hold is the whole retry". The retry closure is in memory in `ChatDeliveryTracker` and covers a send that failed before reaching the relay pool |
| Coracle and welshman | welshman `7d72fa0a7c`, coracle `d50db6133f` | **Yes.** `retry` republishes the thunk's original options, and the rumor is stamped once, before wrapping. | `thunk.ts:411-414`, `wraps.ts:70-71` |
| nostr-tools | `8ffc6287cd` | No retry layer. The high-level `nip17.wrapEvent` stamps `created_at` from the clock on every call, so retrying by calling it again re-mints. The lower-level `nip59` functions accept an existing rumor. | `nip17.ts:22`, `nip59.ts:21-30` |
| NDK | `4b86acd13f` | No retry layer. `NIP17Protocol.sendMessage` builds the rumor from the clock inside the call and does not return it. `giftWrap` accepts an existing event. | `messages/src/protocols/nip17.ts:28-40` |
| rust-nostr | `4c8099aef6` | No retry layer. `PrivateDirectMessageBuilder::finalize` makes a fresh rumor on every call, even on a clone. `GiftWrapBuilder` wraps an `UnsignedEvent` the caller kept. | `nostr/src/nips/nip17.rs:158-166` |

What this shows:

- Neither app with a built-in retry was found to re-mint on it. Both already do
  what Proposal A′ asks, which is the same position Divine is in.
- Re-minting is the default path in the three libraries. The call an app author
  reaches for first builds the rumor internally and discards it, so retrying
  correctly means dropping to the lower-level wrap function and keeping the
  rumor. A contract that says "keep the rumor's `id`" therefore also needs
  those APIs to hand the rumor back, or to accept the original `created_at`
  so the caller can rebuild it. The sentence in the NIP is necessary but not
  sufficient.
- It does not show that any shipped app re-mints. That depends on the app built
  on a library, and none of those were read.

Still unknown: apps built on nostr-tools, NDK and rust-nostr; 0xchat; whether
Amethyst's retry survives a process restart, since its retry closure is held in
memory; whether Quartz 2.13.0, the version Amethyst pins, matches the commit
read; whether the older welshman that Coracle pins (0.13.0, whose
`publisher.ts` says "The event keeps its id") behaves like the commit read;
and the welshman version Flotilla pins. Damus and Primal were still
kind-4-only on 2026-09-05 and were not read.

Field evidence stays collectable from support logs: each
`Persisted NIP-17 DM` line records a process-local, keyed `contentCorrelation`
token. Equal tokens for the same conversation and sender, seconds apart, are
evidence of a possible re-mint that support can grep from a bug report. The
plaintext, its length, and the temporary key are never logged, and the token
changes after an app restart.

## Recommendation

Ruled 2026-11-03:

- **Adopt A′, as a SHOULD.** It is the contract Divine already follows.
- **Specify B and hold it.** Revisit it on field evidence of a real client
  re-minting that A′ adoption does not fix, as described under Proposal B.
- **Do not ship any receiver-side suppression.** It stays in the rejected
  table.
- **No "possibly resent" disclosure on the receiving side for now.**

A′ is not merely cheaper than B — it is safer. B requires honouring a token
authored by the peer, which is the one thing the current ingest path refuses on
purpose; designing that safely is a larger problem
than the duplicate bubble it would fix. A′ grants the peer no new authority over
the receiver's database at all.

The third-party read adds one requirement to A′. The two apps that retry already
conform, and the libraries make non-conformance the default, so the NIP wording
is worth proposing together with a pointer for library authors: expose the
rumor, or let the caller pass the original `created_at`, from the high-level
send call so a caller can keep the `id` and re-wrap or rebuild it.
