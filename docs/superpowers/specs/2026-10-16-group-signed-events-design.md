# Group-signed Nostr events

Date: 2026-10-16. Status: proposed design; custody decision and written-spec approval pending.

## Outcome and evidence

A group controls one Nostr identity. A threshold of its members approves an exact
event, producing the ordinary NIP-01 event ID and 64-byte BIP-340 signature.
Existing clients and relays need no threshold awareness. Relay events are the
source of truth; Funnelcake can index them but is never required to reconstruct a list.

The throwaway [spike](../../../tools/group_signing_spike/README.md) ran real
ZF FROST DKG and signing through flutter_rust_bridge on macOS ARM64. Six tests
cover 2-of-2, all three 2-of-3 subsets, 3-of-3, insufficient signing quorum and
incomplete DKG. Verification uses independent Bitcoin Core secp256k1, bip340
0.3.0, and the actual Divine `nostr_sdk` Event class (`isValid` and `isSigned`).
Fresh approvals have distinct public nonce commitments and immutable message bytes.
Changed messages/content fail validation. The probe guards against signing twice
with an approval and destroys its nonce even on failure.

These are simulated participants in one process, with an identical round-one
transcript and private in-memory round-two delivery. This does **not** establish
secure network DKG, crash safety, mobile platform builds, or physical-device
operation. A local stock strfry test relay rejected a damaged signature, accepted
the threshold event and returned it for Divine SDK verification. An in-app prototype and another client's visible rendering remain
acceptance gates. Do not ship the probe as a key-management implementation.

## Library choice

| Candidate | Verified finding | Decision |
| --- | --- | --- |
| ZF `frost-secp256k1-tr` | BIP-340-compatible suite; dealerless DKG and signing; ordinary `frost-secp256k1` is incompatible. | Recommended crypto engine. |
| Dart `frosty` | Existing FRB wrapper; release 4.0.0 with its pinned native source resolves frost-secp256k1-tr 2.2.0 and passes this probe. | Use for throwaway evidence only. |
| `frosty` 5.0.0 | Requires Dart 3.13 and coinlib 6 / pointycastle 4, conflicting with mobile's locked bip340 0.3.0 / pointycastle 3.9.1. | Do not force dependency overrides or unrelated app upgrades. |
| ACINQ / Mantra | Mantra imports ChillDKG/FROST but uses a nested experimental source-build chain. Its Android build explicitly warns the stock ACINQ artifact has no ChillDKG natives. | Viable reference; not an off-the-shelf Flutter dependency. |
| secp256k1-zkp | Inspected upstream tree exposes MuSig2, with no FROST/DKG module found. MuSig2 alone does not supply t-of-n dealerless DKG. | Do not assume an experimental fork is a supported release. |
| Pure Dart | `pqthreshold` exists, but its documented FROST profile is Ed25519; no compatible pure-Dart implementation was established. | Does not meet BIP-340 requirement. |

Recommend a small direct Rust/FRB bridge for the app, exposing opaque participant,
key-share and single-use signing handles. Rust keeps long-lived shares and nonce
material; Dart receives public protocol objects and final events. Pin exact Rust
and bridge versions and review the Taproot suite's audit coverage separately:
the ZF site's listed NCC audit did not include frost-secp256k1-tr. The probe
validates version 2.2.0 through the existing wrapper; newer 3.0.0 is available but
has **not** been validated here. Do not silently upgrade or change tweak semantics.

The upstream wrapper exposes shares as Dart key objects and serializable nonces;
its API permits repeated use unless the caller prevents it. It is evidence of
binding feasibility, not the desired production secret boundary. No custom curve
or threshold arithmetic should be implemented in Dart.

## Ownership between mobile and Keycast

Recommended first prototype: three independent device participants, threshold two.
Mobile owns proposal review, participant identity binding, local share storage and
signing approval. A reusable crypto/protocol package owns deterministic event
serialization, ceremony/signing validation and the native crypto client. The app
flow is Page/View → BLoC → repository → transport/native clients, with constructor
injection and no Flutter types in repositories or protocol models.

Keycast can coordinate delivery without a share. An optional later participant
adapter can hold **one** share using the same Rust ciphersuite. Its current
`SigningSession` owns a complete `nostr::Keys` and canonicalizes the event author
to that key; it cannot sign as a FROST group unchanged. Implement threshold
sessions separately; keep ordinary NIP-46 signing behavior intact. Standard
NIP-46 has no DKG/partial-signature RPC: any new API must be explicitly versioned,
authenticated application protocol, not represented as an existing standard.

A 2-of-3 group with two device shares and one Keycast share can sign with one
human device plus the service. It cannot sign with zero devices. If the desired
policy is two independent humans on every event, that arrangement does not meet
it. If Keycast holds shares for several people, those are one custody domain;
separate account approvals are service policy, not cryptographic independence.
Hosted full-key approval is a valid simpler option, but must be described as
custodial signing rather than FROST's independent-custody guarantee.

**User decision:** devices only, one Keycast share, or hosted approvals first.
No live Keycast changes or custody enrollment before this is settled.

## Ceremony transport and approval

Start with authenticated, confidential per-recipient delivery over existing
NIP-17 gift wraps. Pin a roster, threshold, participant-ID mapping, protocol
version, relay set and random ceremony ID before generating contributions.
Sort participant identity keys bytewise and derive the mapping once; a reordered
or substituted roster aborts. Bind every envelope to that roster/session/round,
sender and recipient; reject replay, contradictory duplicates and unknown senders.

NIP-17 encryption is **not** ZF's required broadcast agreement. Before round-two
secret contributions, every participant signs and checks the same complete
round-one transcript digest. Abort on disagreement or missing agreement. Authenticate
recipient-specific round-two contributions and confirm every participant reaches
the same final public key. All n participants must complete DKG; signing later
needs only t. Abort/time out cleanly and start a new ceremony rather than recycling
randomness or partially accepted material. This agreement protocol still needs
adversarial transport tests; the local probe does not implement it.

Mantra uses kinds 30310–30316 for ChillDKG and 30320–30325 for signing, carried
inside encrypted messaging. ZF DKG is a different protocol: **do not reuse those
wire kinds with incompatible payloads or claim Mantra session interoperability**.
Use an explicitly versioned encrypted application envelope; final list events
remain ordinary Nostr. Define the envelope with the implementation plan.

MLS/Marmot is attractive once a group already has working encrypted chat, but it
adds membership/epoch synchronization and Welcome handling before this prototype
needs them. A coordinator service can store/relay encrypted envelopes and wake
clients; it must not replace transcript agreement or become indispensable to
reading signed results. Keep the transport behind an interface.

Proposed UX follows Mantra's three deliberate DKG gates: join/fix the roster;
review/send contribution; verify transcript/result and confirm completion.
The initiator's start action covers join, leaving two subsequent prompts; invitees
face three. Show who is missing and what each approval authorizes. No inbound
message alone enrolls a participant or publishes a contribution. Network rounds
and these human approval gates are distinct; do not copy ChillDKG round labels
onto ZF's algorithm.

Each later event gets one approval showing exact author, kind, target list,
additions/removals and complete resulting event before nonce commitment. Fix the
event bytes and signer set; use two FROST signing rounds. Changing timestamp,
content, tags, message, signer set or derivation means a fresh session and fresh
nonces. Never generate new partials from an old approval after a crash/retry.

## Shares, recovery and nonce lifecycle

Provision a fresh threshold identity; existing NIP-46 account keys do not expose
secret material from which mobile can derive a share. Do not reconstruct or export
the group secret. No nsec, share, DKG private contribution, nonce or secret-bearing
exception reaches logs, analytics, crash reports or a clipboard.

Store a versioned share package encrypted at rest with a device-bound wrapping
key in platform secure storage; bind it to account, group, roster, threshold,
ciphersuite and tweak version. iOS Keychain / Android Keystore can protect the
wrapping key; do not assume they can perform secp256k1 FROST directly. Device
locking and account switching must close opaque native sessions.

Proposed prototype recovery policy: no automatic cloud share backup and no nonce
backup. Display that losing enough devices loses signing capability. Any later
backup must be an explicitly authorized encrypted **share** export, containing
recovery metadata but no pending signing sessions/nonces. Restoring an account's
ordinary Nostr key does not restore this newly provisioned share. A backup clone
is the same participant, not another quorum vote.

Use fresh OS randomness per signer/event/session, no precomputed nonce pool.
Persist the binding and an irreversible consumed/aborted record **before** releasing
a partial signature. Never restore pending nonces from a backup, and invalidate
all pending sessions after restore. Until rollback-resistant recovery is proven,
abort on process death and retry with fresh nonces rather than regenerate old
nonce seeds. Reject duplicate/conflicting proposals and concurrent reuse of a
handle. Memory disposal alone is not a durable nonce ledger.

**User decision:** accept device-loss risk for the closed prototype, or require
an encrypted backup/recovery flow before enrolling persistent groups.

## Membership and identity rotation

First prototype uses a fixed roster. Adding/removing a signer requires a new
ceremony and new public key. Update list coordinates and show the replacement
identity explicitly. Where the old quorum is available, publish a quorum-signed
handover to the new coordinate and confirmation from the new key; clients still
need migration support and old follows/addresses do not automatically move.
If the old quorum is lost, no authentic old-key handover can be fabricated.

Removing someone from chat or a collaborator tag does not revoke their share.
Old members who retain an old threshold can still sign the old identity. Share
refresh/resharing that preserves a public key is a separate research project,
not a promised solution in this prototype. App display names or a database alias
cannot make `(kind, pubkey, d)` stable across pubkey changes.

## Union and the first real use case

Recommend a group-owned **kind 30005 public video curation set**, already supported
in Divine, with one fixed roster and ordinary full-list replaceable writes. Media
starter packs (39092) are the next candidate. Never encode editors in NIP-51 `p`
tags: those mean list members. Use existing non-`p` collaborator metadata where
appropriate. No new kind-30000 writes: Funnelcake issue 867 is still open and
reports that all those sets affect the follow graph.

Union contributions remain ordinary events signed by each contributor: the same
`d`, a validated `a` backlink to the anchor, and an author authorized by the current
anchor's non-`p` contributor tags. A standard multi-author kind/`#d` filter can
retrieve them; take the newest valid event **per author**, with NIP-01 tie breaking,
and verify backlinks/authorization locally. A global `limit:1` would lose inputs.
Apply relay pagination/limits and surface incomplete reads before approving a fold-in.

The owner (or threshold group) approves and republishes the complete union as one
standard list event so unaware clients can read it. Keep contributor attribution
in contributions; the final Schnorr signature alone does not reveal which people
approved. FROST supplies authority for fold-in; it does not make contributors'
individual edits threshold-approved automatically.

A materialized fold-in must not recursively become the owner's independent
contribution: otherwise a removed item can survive forever in the previous merged
anchor. Separate the owner's authored contribution from the derived snapshot in
the eventual union protocol, and define removal/conflict behavior before building
it. The first FROST prototype signs an explicit full snapshot and does not silently
invent union deletion semantics. Funnelcake's eventual union index is disposable:
rebuild from verified relay events without privileged state.

## Prototype gates and decisions

1. Approve custody/recovery choice and this written spec, then review the concrete
   implementation plan. The spike is not authorization to settle those choices.
2. Add `mobile/packages/group_signing` for protocol/native interfaces, with its own
   analysis options and package CI; BLoC and Page/View in the app; an internal flag
   defaulting off, including guarded routes and no startup work when disabled.
3. Test authenticated transcript agreement, tampered/replayed/wrong-roster messages,
   exact-event approval, below-quorum signing, durable nonce consumption, process
   death/retry, lost/offline members and altered bytes after approval.
4. Run DKG/signing on 2–3 physical devices across supported platforms. Publish a
   group list to a test relay, read it back by ID and coordinate, verify locally,
   and record another independent Nostr client's visible rendering with client
   version/relay/event IDs. A library verifier is not that UI acceptance test.
5. Keep server support optional; no Funnelcake migration, production enrollment,
   custom public group protocol, membership migration or deployment is implied.

## Sources

- Local source snapshots: Divine mobile base `d8c01c405c`; Keycast `9927597e8455ec835c11d98fd1ef23900b397188`; Mantra `99f48d176974cf064a292fa6dae7ae18712dda4c`.
- Divine: `mobile/packages/nostr_sdk/lib/event.dart`; `mobile/lib/services/curated_list_service.dart` (`canCollaborate` has no external callers found); `mobile/packages/curated_list_repository/lib/src/curated_list_converter.dart`; `mobile/packages/people_lists_repository`; `mobile/lib/features/feature_flags`; `docs/ARCHITECTURE.md`.
- Keycast: `core/src/signing_session.rs`, `api/src/handlers/http_rpc_handler.rs`, `Cargo.toml`. No FROST dependency found in its lockfile.
- Mantra: `docs/README.md`, `shared-key-ceremony.md`, `shared-key-derivation.md`, `frost-batch-signing.md`, `marmot-membership.md`, `subgroups.md`, `project-feature.md`, `curated-to-mantra.md`; `ChillDkgRitualManager.kt`, `FrostSigningManager.kt`, `composeApp/build.gradle.kts`. Removed `CuratedSchemaEvent.kt`, `CuratedEntryEvent.kt`, `CuratedSchema.kt` inspected via `git show 776455ec^:<path>` under `composeApp/src/commonMain/kotlin/press/mantra/compose/nostr/curated/`.
- [ZF suite and audit scope](https://frost.zfnd.org/), [BIP-340 suite choice](https://frost.zfnd.org/tutorial.html), [DKG channel requirements](https://frost.zfnd.org/tutorial/dkg.html), [3.0.0 API](https://docs.rs/frost-secp256k1-tr/3.0.0/frost_secp256k1_tr/).
- [Frosty 4 source](https://github.com/peercoin/frosty/tree/0457225a54dd36dcfff86268206f16cc42f59a07), [Frosty package](https://pub.dev/packages/frosty), [pure-Dart Ed25519 profile](https://github.com/turkananation/pqthreshold/blob/main/doc/FROST_PROFILE.md), [ACINQ](https://github.com/ACINQ/bitcoin-kmp), [secp256k1-zkp](https://github.com/BlockstreamResearch/secp256k1-zkp).
- Draft proposals checked open/unmerged: [2235: collaborative pointer / latest editor](https://github.com/nostr-protocol/nips/pull/2235), [1228: encrypted event-owned key](https://github.com/nostr-protocol/nips/pull/1228), [1192: owner-bearing d-tag](https://github.com/nostr-protocol/nips/pull/1192), [1015: trusted signing service](https://github.com/nostr-protocol/nips/pull/1015), [2354: reader-specific trust directories](https://github.com/nostr-protocol/nips/pull/2354). None supplies the required independent threshold authorization by itself.
- [NIP-51 list semantics](https://github.com/nostr-protocol/nips/blob/master/51.md), [merged calendar request/approve precedent](https://github.com/nostr-protocol/nips/pull/1970), [NIP-52](https://github.com/nostr-protocol/nips/blob/master/52.md), [NIP-72 moderator approval](https://github.com/nostr-protocol/nips/blob/master/72.md), [NIP-29 relay groups](https://github.com/nostr-protocol/nips/blob/master/29.md), [Funnelcake 867](https://github.com/divinevideo/divine-funnelcake/issues/867). Relay-enforced permissions and approval wrapper events are distinct from threshold authority on the target event.

Brain search returned no relevant prior decision; no company-memory claim is used.
