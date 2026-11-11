# Private Evidence for DM Abuse Reports

Status: Decided for #8508 and #7340. The mobile side of the first
implementation (private reports and the unverified excerpt) shipped with the
fix for #7340, without the support record: see below.

## Decision

Divine should treat a DM report as a private moderation action, not as a
public NIP-56 report.

The first implementation should let the reporter deliberately include the
selected received message as a private, unverified excerpt. The excerpt must
travel only inside the existing NIP-17 moderation DM, be displayed to
moderators separately from reporter-written details, and be usable only for
human review. It must not trigger automatic enforcement.

Divine should not disclose a NIP-44 conversation key. That would expose the
whole bilateral conversation rather than the one message the reporter chose.

Cryptographically verifiable evidence for one message remains a possible
second phase. It must not be included in the first implementation until the
Keycast and moderation owners approve the custody, access, retention, and
enforcement model described below.

Merging this document records the product and technical decision. The code
changes may land separately, but private evidence must not ship while the same
DM report still publishes a public kind-1984 event.

## Why

The current report sheet already has a private transport: it sends a NIP-17
gift-wrapped message to Divine Moderation. The missing pieces are the selected
message content and a clear statement of how trustworthy that content is.

A received NIP-17 message has two relevant layers:

- The inner rumor contains the message text but is unsigned. A reporter can
  fabricate equivalent plaintext, so a forwarded excerpt is an allegation,
  not cryptographic proof.
- The kind-13 seal is signed by the sender and commits to the encrypted rumor.
  It is the authenticity anchor, but the app currently discards it after
  successful decryption.

This distinction should survive all the way to the moderator UI. Presenting a
reporter-supplied excerpt as verified evidence would create more trust than the
protocol provides.

## Required privacy change

DM reports must not publish kind-1984 events. A public NIP-56 report identifies
the reporter through its signature and identifies the DM counterparty through
its required `p` tag. A message report also exposes a stable rumor ID in an
`e` tag, and reporter-written details are placed in the public event body.

For DM reports:

- Send the private moderation DM.
- Create the existing private support record if that remains part of the
  moderation workflow.
  As implemented, a DM report files no support ticket at all: a ticket can be
  mirrored into a public GitHub issue (`docs/DIAGNOSTIC_DATA_POLICY.md`),
  which would break the promise that the report stays private.
- Do not create or publish a kind-1984 event.
- Do not copy the selected message excerpt into the support record unless its
  access and retention policy is explicitly approved for private DM evidence.

This resolves the product question in #7340. Its implementation can land
before the evidence feature and should not wait for cryptographic proof.

## First implementation: private unverified excerpt

When a user reports a received message, the report sheet should offer an
explicit choice to include that one message. The consent copy must say that
the selected message will be shared privately with Divine's moderation team
and will not be posted publicly.

The report payload should keep these fields distinct:

- Report metadata: reason, report type, reporter, reported account, message ID.
- Reporter details: optional text written by the reporter.
- Evidence excerpt: the selected message text, marked `unverified`.

The evidence excerpt must be threaded into the moderation-DM payload through a
dedicated value. It must never reuse the `details` or `additionalContext`
arguments used to build the public report or support-ticket projections. That
type and data-flow separation is the primary safety boundary.

All DM-report entry points must use the same submission flow. In particular,
the inbox conversation action currently calls `ContentReportingService`
directly and sends no moderation DM; it must route through the report sheet and
`ReportSubmissionCubit` instead.

Moderators must see a visible label such as "Unverified message excerpt
provided by the reporter." This evidence can inform human investigation, but
must not by itself produce an automated account or content action.

## Rejected design: conversation-key disclosure

NIP-44 derives a shared conversation key for a pair of accounts. Disclosing
that key would allow decryption beyond the selected message, including other
messages in both directions. It is disproportionate and is not an acceptable
evidence mechanism.

## Possible second phase: verifiable one-message disclosure

NIP-44 v2 derives 76 bytes of per-message material from the conversation key
and the encrypted payload's nonce. Subject to cryptographic review, disclosing
that material together with the signed kind-13 seal may let a moderator:

1. verify the seal's Schnorr signature;
2. authenticate and decrypt that seal's ciphertext; and
3. inspect the one rumor committed to by that seal without receiving the
   conversation key or keys for other messages.

This would intentionally turn a deniable private message into a durable proof
artifact at the recipient's request. That artifact may be retained, copied, or
legally compelled. Product and moderation owners must approve that consequence
before implementation.

This is not currently a mobile-only change. Local-key accounts can derive the
per-message material on-device, but Keycast, Amber, and NIP-46 accounts decrypt
through remote signer interfaces. The mobile client does not receive their
private key or conversation key. A complete design therefore needs one of:

- a narrowly scoped signer operation that returns disclosure material for one
  supplied, authenticated seal payload; or
- an equivalent evidence envelope produced during the original decryption.

Any new Keycast operation requires platform ownership and must:

- never return the account private key or conversation key;
- bind the result to exactly one ciphertext and nonce;
- require normal account authorization;
- validate that the caller is the addressed recipient;
- be rate-limited and audited without logging private content or key material;
- define retry and failure behavior without silently falling back to
  unverified evidence; and
- have independent cryptographic review.

The signed seal or evidence envelope should be retained when the message is
successfully decrypted. Re-fetching a gift wrap by its stored ID may be a
recovery path, but relay retention and availability are not a durable evidence
guarantee.

## Ownership decisions required for the second phase

Before verifiable disclosure is designed or implemented, the responsible
owners must record answers to these questions:

- Product: should a recipient be able to waive NIP-17 deniability for one
  received message?
- Moderation: what actions may verified and unverified evidence support?
- Platform/Keycast: can a one-ciphertext disclosure operation be exposed
  without creating a broader key-export capability?
- Privacy/legal: who may access the evidence, how long is it retained, how is
  it deleted, and how are access and export audited?
- Protocol: should the payload remain a documented Divine extension or be
  proposed as interoperable Nostr behavior?

Until those answers are approved, the product should ship only the private,
clearly unverified excerpt.

## Implementation boundaries

### Mobile

- Route every DM-report entry point through the report sheet and
  `ReportSubmissionCubit`.
- Suppress kind-1984 creation and publication for DM reports.
- Add explicit, localized consent for sharing the selected message privately.
- Carry evidence in a dedicated payload that cannot enter public or support
  projections accidentally.
- Surface the existing rumor-size refusal in the report sheet. `maxDmRumorBytes`
  (`mobile/packages/dm_repository/lib/src/dm_message_size.dart`) already refuses
  an oversized rumor before it is enqueued and returns
  `NIP17SendResult.tooLong`, so the work is rendering that failure on the report
  path rather than adding a second check. The 40,000-byte bound comes from
  NIP-44 v2's `u16` length prefix under the double encryption NIP-17 performs;
  NIP-17 itself specifies no message-size ceiling.

### Moderation service

- Extend the moderation-DM contract to parse evidence independently from
  reporter details.
- Display evidence provenance and verification state in the admin Messages UI.
- Prevent unverified evidence from entering automated enforcement.
- Pin the coordinated tag/payload ordering in the existing contract tests.

### Storage and signer services

No storage or signer change is required for the first implementation.

The verifiable second phase requires a retention policy and a Drift migration
if mobile stores the signed seal. It may also require coordinated Keycast,
Amber, and NIP-46 capability work; unsupported signer types must fail closed
rather than presenting unverified evidence as verified.

## Verification

The implementation is not complete without tests proving:

- A DM report never creates or publishes a kind-1984 event.
- The selected message and reporter details never reach kind-1984 content or
  tags, even if a future caller enables public reporting accidentally.
- Evidence does not enter the support-ticket projection without an explicitly
  approved evidence policy.
- All three current DM-report entry points reach the same private submission
  flow and moderation DM.
- The moderator receives the selected received message, reason, target, and
  provenance as distinct fields.
- Unverified evidence cannot trigger automated enforcement.
- Oversized evidence follows the documented `maxDmRumorBytes` behavior at the
  40,000-byte rumor ceiling.
- Consent copy exists in every locale and is rendered through `context.l10n`.

If the verifiable second phase is approved, add cross-implementation fixtures
proving that one disclosed payload authenticates and decrypts exactly one
genuine seal, rejects tampering, cannot decrypt a different message, and works
or fails explicitly for every supported signer type.

## Deliberately out of scope

- Image, video, or arbitrary file attachments.
- Disclosure of a conversation key, account private key, or remote-signer
  credential.
- Automatic enforcement based only on reporter-provided plaintext.
- A new public event kind or a new relay.
- Reporter-to-moderator follow-up communication.
