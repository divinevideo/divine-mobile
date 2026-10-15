# Group-signed Nostr events

Date: 2026-10-16. Status: product direction confirmed: one-admin publishing, Keycast-backed recovery by default, and an explicit advanced mode without Keycast. App integration is not implemented.

## Outcome and evidence

A group controls one Nostr identity. For most content, **any one authorized admin
may publish**, including in a three-admin group. Other admins need not be online.
Keycast backs up each admin's group-signing material by default so ordinary users
can recover without managing shares. Groups can explicitly choose advanced
self-management with no Keycast signing, storage or recovery dependency.
The initial hosted path is custodial: Keycast holds the full group key and signs
for authorized admins; it does not provide independent threshold custody.
Higher quorums are an optional group capability, not the default content workflow.
Every mode produces the ordinary NIP-01 event ID and 64-byte BIP-340 signature.
Existing clients and relays need no threshold awareness. Relay events are the
source of truth; Funnelcake can index them but is never required to reconstruct a list.

The throwaway [spike](../../../tools/group_signing_spike/README.md) ran real
ZF FROST DKG and signing through flutter_rust_bridge on macOS ARM64. Seven tests
cover 2-of-2, all three 2-of-3 subsets, 3-of-3, insufficient signing quorum and
incomplete DKG, plus rejection of threshold one by the tested FROST API.
Verification uses independent Bitcoin Core secp256k1, bip340 0.3.0, and the actual Divine `nostr_sdk` Event class (`isValid` and `isSigned`).
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

For opt-in threshold custody, recommend a small direct Rust/FRB bridge exposing
opaque participant, key-share and single-use signing handles. Rust keeps long-lived shares and nonce
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

**Confirmed product policy:** one of the authorized admins can publish ordinary
content. “1-of-3” here describes one human approval among three admins; it does
not require a distributed cryptographic ceremony for each edit.

Confirmed default: Keycast-backed recovery for each admin's group-signing
material. Proposed initial signing path: a hosted group key kept server-side only,
with separately authenticated, revocable signing authorizations. If a later
Keycast-assisted threshold path uses admin-held shares, those shares must also
have a recoverable backup. Mobile owns editing and the single-admin
publish action; Keycast checks authorization and signs as the group.
Keycast already models teams, team-owned stored keys, policies and authorizations
and can issue NIP-46 access to a team's stored key. These are reusable primitives,
not evidence that the required mobile group flow or complete revocation semantics
already work. Verify binding to the current admin identity and revocation of
existing connections before implementing the group adapter. Do not share one
bunker connection secret between admins.

This gives a stable group pubkey while the service changes authorized admins,
without distributing the group private key. Public content remains ordinary relay
events. The service is a signing dependency; it is not the only source of list
state. Keycast-backed recovery is the default custody choice; no-Keycast groups
are an explicit advanced option. Backup copies do not count as additional admins
or increase the required number of human approvals.

The alternatives are:

| Custody | Ordinary-content approval | Consequence |
| --- | --- | --- |
| Keycast-assisted group (default) | One authorized admin | Hosted signing with the full group key server-side only and per-admin access recovery. Service-recoverable material is custodial. |
| Full group key on every admin device | Any one key holder | Works without a signing service; removing an admin cannot revoke their retained key without rotation. |
| Independent FROST shares | An actual t-of-n signing quorum | Keep for groups choosing threshold custody; the tested implementation requires t >= 2. |
| FROST with an automatic Keycast co-signer | One human admin plus the service | Potentially preserves one-admin UX with threshold custody; a separate design, not literal 1-of-n FROST. |

The tested `frosty` 4 API rejects threshold one, and frost-core 2.2.0 also returns
`InvalidMinSigners` for it. Do not patch out that validation. With degree-zero
Shamir sharing, threshold one would give every participant the complete signing
secret; it would not provide the independence obtained with t >= 2.

For three admins plus one Keycast share, a 2-of-4 setup could let any admin sign
with an automatic service contribution, while two admins could sign with the
service offline. Whether that additional infrastructure is useful is a custody
choice; it must not add a second human prompt to routine content.

For a **single pubkey**, a fixed FROST threshold cannot become 1 for posts and 2
for admin changes just by changing event tags or UI. Event-specific approval
counts are service policy unless a separate cryptographic construction enforces
them. No higher quorum for any particular action is assumed in this prototype.

Keep a signer interface for hosted and threshold modes. Shared event/protocol
logic belongs in a package, with Page/View → BLoC → repository → signing/transport
clients and constructor injection. Introduce the native threshold package only
for the opt-in FROST path; the hosted path should reuse ordinary NIP-46 signing.
Keycast's current full-key `SigningSession` is suitable for a hosted group key;
threshold participation would need a separate path. Standard NIP-46 does not
supply DKG/partial-signature RPCs.

**Decisions settled:** ordinary content needs one admin; each admin gets
Keycast-backed recovery by default; a group may opt out of Keycast entirely.
Do not ask users to configure shares, backup encryption or quorum infrastructure
during the normal flow. Offer advanced self-management during group creation,
with a plain explanation that the group handles its own keys and recovery.
Switching to no-Keycast later does not erase previously recoverable server copies;
exclusive device custody would require a new key rather than a setting toggle.

## Ceremony transport and approval

This section applies only to opt-in FROST groups. The recommended hosted mode
has no all-admin DKG or multi-round publish ceremony.

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

In threshold mode, each participating signer approves the event once, showing
exact author, kind, target list, additions/removals and complete resulting event before nonce commitment. Fix the
event bytes and signer set; use two FROST signing rounds. Changing timestamp,
content, tags, message, signer set or derivation means a fresh session and fresh
nonces. Never generate new partials from an old approval after a crash/retry.

## Shares, recovery and nonce lifecycle

**Keycast-assisted mode (default).** Preserve recoverable, encrypted signing
material for every admin. For hosted-only admins, the backed-up group key and
recoverable authorization relationship provide access after account recovery;
a cached bunker token alone is not the backup. For admins with device-held group
keys or FROST shares, back up that actual key/share package as well. A team roster
or one central key is not a substitute for backing up distinct participant shares.

Use Keycast's established encrypted key custody and authenticated account-recovery
boundary. Bind each backup to tenant, group identity, admin identity, participant
identifier where applicable, roster/key version and crypto/tweak version. Restore
the same authorized participant and group pubkey; reissue credentials after current
authorization checks instead of reviving an old session. A restored copy is the
same participant, never another quorum vote. Mark enrollment/recovery as backed up
only after durable storage has been acknowledged; expose a failed backup as an
actionable retry rather than falsely claiming the admin is protected. Verify
restore, not merely upload success, before enrolling real persistent groups.

Keycast's existing stored-key API handles complete Nostr keys. A versioned,
per-admin FROST-share backup/restore API still needs implementation; do not feed
share bytes into that existing secret-key parser or claim it already supports
share recovery. Mobile holds admin authorization in its existing secure storage.
No extra backup password should be required in the normal account-recovery flow.

A server-recoverable backup changes custody: if Keycast can recover a threshold
of shares, it can technically sign as the group. Encryption at rest does not
remove that authority. Describe that honestly in advanced custody information;
ordinary users can still choose the recoverable default. Do not describe its
threshold as protection against Keycast itself.

**No-Keycast mode (advanced).** No key/share upload, hosted signing, backup or
recovery request goes to Keycast. Setup includes an explicit local/offline backup
and restore check and a clear statement that Divine cannot recover lost material.
Allow ordinary one-admin signing with a shared full group key, or t >= 2 FROST
with independent shares. Full-key holders cannot be revoked cryptographically
without rotating the group identity. No-Keycast mode must operate against relays
even when Keycast is unavailable; opting out is a functional mode, not just hiding
the backup screen.

For device-held threshold material, provision a fresh identity; an existing NIP-46
account does not expose a private key from which mobile can derive a share. Do
not reconstruct the group secret for backup: preserve each participant's share.
Store a versioned local package encrypted with a device-bound wrapping key in
platform secure storage, bound to account, group, roster and ciphersuite/tweak
version. iOS Keychain / Android Keystore protects the wrapping key; do not assume
it can perform secp256k1 FROST directly. Account switching closes native sessions.
No nsec, share, DKG private contribution, nonce or secret-bearing exception reaches
logs, analytics, crash reports or the clipboard in either mode.

**Nonce state is never backup material.** Backups exclude nonce seeds, pending
signing handles and partial-signature retry state. A restore invalidates every
pending session before signing can resume and generates fresh nonces for a new
session, even when the event being approved is unchanged.

Use fresh OS randomness per signer/event/session, no precomputed nonce pool.
Persist the binding and an irreversible consumed/aborted record **before** releasing
a partial signature. Never restore pending nonces from a backup, and invalidate
all pending sessions after restore. Until rollback-resistant recovery is proven,
abort on process death and retry with fresh nonces rather than regenerate old
nonce seeds. Reject duplicate/conflicting proposals and concurrent reuse of a
handle. Memory disposal alone is not a durable nonce ledger.

## Membership and identity rotation

In hosted mode, admin changes update signing and backup-restore permissions
while retaining the group pubkey. Recovery must not resurrect a removed admin
or an obsolete share version. Revocation must terminate the removed admin's
effective signing access, including previously established sessions.

In threshold mode, the first prototype uses a fixed roster. Adding/removing a
signer requires a new ceremony and new public key. Update list coordinates and
show the replacement identity explicitly. Where the old quorum is available, publish a quorum-signed
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
in Divine, with one-admin approval for normal full-list replaceable writes. Media
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
it. The first group-signing prototype signs an explicit full snapshot and does
not silently invent union deletion semantics. Funnelcake's eventual union index is disposable:
rebuild from verified relay events without privileged state.

## Prototype gates and decisions

1. Preserve the settled choices in implementation: one-admin ordinary publishing,
   Keycast recovery for each admin by default, and an advanced no-Keycast mode.
   Build recovery before enrolling persistent groups. This document describes
   the design; the app and backup/restore integration are not built yet.
2. Add `mobile/packages/group_signing` for shared group/signing interfaces, with
   native crypto only for threshold mode, its own analysis options and package CI;
   BLoC and Page/View in the app; an internal flag defaulting off, including guarded routes and no startup work when disabled.
3. In hosted mode, prove every authorized admin can publish alone, unauthorized
   and revoked admins cannot, and other admins may be offline. Prove a replacement
   device recovers the same group identity; reject cross-account/group and stale
   backup restores; never restore a removed admin or reuse nonce state. In advanced
   no-Keycast mode, prove no Keycast calls occur and restore works from the group's
   own backup with Keycast unavailable. In threshold mode,
   test authenticated transcript agreement, tampered/replayed/wrong-roster messages,
   exact-event approval, below-quorum signing, durable nonce consumption, process
   death/retry, lost/offline members and altered bytes after approval.
4. For threshold mode, run DKG/signing on 2–3 physical devices across supported
   platforms. In both modes, publish a group list to a test relay, read it back by ID and coordinate, verify locally,
   and record another independent Nostr client's visible rendering with client
   version/relay/event IDs. A library verifier is not that UI acceptance test.
5. Require Keycast support only for groups using the default assisted mode.
   Separate full-key storage from versioned per-admin share backup. No Funnelcake
   migration, production enrollment, custom public group protocol, membership
   migration or deployment is implied.

## Sources

- Local source snapshots: Divine mobile base `d8c01c405c`; Keycast `9927597e8455ec835c11d98fd1ef23900b397188`; Mantra `99f48d176974cf064a292fa6dae7ae18712dda4c`.
- Divine: `mobile/packages/nostr_sdk/lib/event.dart`; `mobile/lib/services/curated_list_service.dart` (`canCollaborate` has no external callers found); `mobile/packages/curated_list_repository/lib/src/curated_list_converter.dart`; `mobile/packages/people_lists_repository`; `mobile/lib/features/feature_flags`; `docs/ARCHITECTURE.md`.
- Keycast: `core/src/signing_session.rs`, `core/src/types/team.rs`, `core/src/types/authorization.rs`, `core/src/repositories/team.rs`, `api/src/api/http/teams.rs` (`add_key` parses complete keys, not shares), `core/src/custom_permissions/allowed_kinds.rs`, `api/src/handlers/http_rpc_handler.rs`, `Cargo.toml`. No FROST dependency found in its lockfile.
- Mantra: `docs/README.md`, `shared-key-ceremony.md`, `shared-key-derivation.md`, `frost-batch-signing.md`, `marmot-membership.md`, `subgroups.md`, `project-feature.md`, `curated-to-mantra.md`; `ChillDkgRitualManager.kt`, `FrostSigningManager.kt`, `composeApp/build.gradle.kts`. Removed `CuratedSchemaEvent.kt`, `CuratedEntryEvent.kt`, `CuratedSchema.kt` inspected via `git show 776455ec^:<path>` under `composeApp/src/commonMain/kotlin/press/mantra/compose/nostr/curated/`.
- [Tested threshold validation](https://github.com/ZcashFoundation/frost/blob/3ffc19d8f473d5bc4e07ed41bc884bdb42d6c29f/frost-core/src/keys.rs), `frosty` 4 `lib/src/dkg/part1.dart`.
- [ZF suite and audit scope](https://frost.zfnd.org/), [BIP-340 suite choice](https://frost.zfnd.org/tutorial.html), [DKG channel requirements](https://frost.zfnd.org/tutorial/dkg.html), [3.0.0 API](https://docs.rs/frost-secp256k1-tr/3.0.0/frost_secp256k1_tr/).
- [Frosty 4 source](https://github.com/peercoin/frosty/tree/0457225a54dd36dcfff86268206f16cc42f59a07), [Frosty package](https://pub.dev/packages/frosty), [pure-Dart Ed25519 profile](https://github.com/turkananation/pqthreshold/blob/main/doc/FROST_PROFILE.md), [ACINQ](https://github.com/ACINQ/bitcoin-kmp), [secp256k1-zkp](https://github.com/BlockstreamResearch/secp256k1-zkp).
- Draft proposals checked open/unmerged: [2235: collaborative pointer / latest editor](https://github.com/nostr-protocol/nips/pull/2235), [1228: encrypted event-owned key](https://github.com/nostr-protocol/nips/pull/1228), [1192: owner-bearing d-tag](https://github.com/nostr-protocol/nips/pull/1192), [1015: trusted signing service](https://github.com/nostr-protocol/nips/pull/1015), [2354: reader-specific trust directories](https://github.com/nostr-protocol/nips/pull/2354). None supplies the required independent threshold authorization by itself.
- [NIP-51 list semantics](https://github.com/nostr-protocol/nips/blob/master/51.md), [merged calendar request/approve precedent](https://github.com/nostr-protocol/nips/pull/1970), [NIP-52](https://github.com/nostr-protocol/nips/blob/master/52.md), [NIP-72 moderator approval](https://github.com/nostr-protocol/nips/blob/master/72.md), [NIP-29 relay groups](https://github.com/nostr-protocol/nips/blob/master/29.md), [Funnelcake 867](https://github.com/divinevideo/divine-funnelcake/issues/867). Relay-enforced permissions and approval wrapper events are distinct from threshold authority on the target event.

Brain search returned no relevant prior decision; no company-memory claim is used.
