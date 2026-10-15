# Concord chat test and pilot acceptance

Status checked 2026-10-15. This is an acceptance checklist, not a deployment
approval or evidence of a working community. Discord remains canonical.

## Review and implementation state

Backend PR: https://github.com/divinevideo/divine-mobile/pull/10093
Review repair starts from published head
`b9516b117ed3680334b5adeb69e0d66ec5a83076` and includes current main.
The UI and backend are combined in PR #10093. After the backend session
failed, Rabble authorized the UI session to finish integration and validation.
No stacked PR is required.

The Messages UI provides Direct / Rooms behind the disabled-by-default
`concordChat` gate. Its catalog is an explicitly public test community. It
reuses the current Divine account. It does not establish membership or staff
permissions. UI widget tests are not evidence of relay interoperability.

## Review fixes and remaining boundaries

The combined PR now has a receiving lifecycle, verified channel/epoch-bound
wrap ingestion, relay acknowledgements, failure/retry UI and subscription
reconnection. The app stores encrypted wraps and pending delivery state in a
new account/relay/channel-scoped Drift store. Retrying republishes the original
signed wrap. It does not invoke the legacy cipher or ask the signer to sign
again. Verified relay echoes also reconcile delivery after a lost acknowledgement.

Receiver expiry is enforced at ingest, display and periodic local purge. Outer
wraps copy the signed expiration for NIP-40 relays. Delete tombstones do not
expire. Timer controls and authoritative community timer state remain phase 2.

Regression coverage includes rejected/lost acknowledgements, disconnects,
restart replay, deduplication, expiry, interrupted startup, account isolation,
failed initial reads, signer refusal and draft retention. Protocol validation,
subsecond ordering and the browser transport have native and Chrome tests.
These automated tests do not replace physical-device or independent-client
acceptance below.

Remaining boundaries:

- The endpoint still defaults to wss://relay.staging.dvines.org. The dedicated
  POC relay and its TLS/retention/moderation contract still need verification.
- The catalog and keys are explicitly public test material. Real invite
  admission, Community List sync, owner-rooted roster authority and rekeying
  are not implemented by this PR. The incomplete held-key/list path was
  removed using the reviewer's proposed option. `fragmentIndex` now names the
  kind-33302 `d` coordinate accurately; it is not a community id.
- Report/block/mute, thread composition, timer administration and a full
  community lifecycle remain outside this POC. The unsupported local thread
  action was removed from the screen.
- The standalone relay transport remains intentional for the explicitly
  configured POC relay. Shared NIP-44/relay adapters are an architectural
  suggestion, not an interoperability prerequisite. Existing DMs are unchanged.

### Finding the rooms in a review build

Web PR previews build with `FF_CONCORD_CHAT=true`, so signed-in
users can open **Messages → Rooms** immediately and see `#general` and
`#introductions`. No developer mode or settings change is needed. The override
is defined for preview builds in `mobile_pr_preview_build.yml`, without a
PR-number exception. These preview URLs are public: anyone with a link who
signs in can read and post in the same public test rooms, including from
previews of unrelated PRs.
There is no reviewer-only access gate; messages use the signed-in account's real
identity. This is intentional for testing. Normal release builds retain the
off-by-default flag. Protected-account restrictions still apply.

For local reviewer builds, pass `--dart-define=FF_CONCORD_CHAT=true`. The
internal settings override remains available under **App preferences →
Experimental Features** after enabling developer mode, but is not part of
the PR review flow. Each preview URL has separate local preferences.

### Mobile room interaction

The room UI follows a mobile channel-list → full-screen conversation flow.
Messages → Direct / Rooms uses Divine controls; each community groups clear
channel rows. A room keeps its channel and community in the header, uses the
same peer identity and avatar rules as DMs, displays localized timestamps, and
anchors recent messages above the shared multiline composer. The public-test
notice remains visible. Wide screens cap the reading column at 720 logical
pixels. Sending still preserves the draft until durable acceptance.

Design references: [Divine messaging explorations](https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=9437-13416)
and [Discord mobile navigation](https://support.discord.com/hc/en-us/articles/12654190110999-New-Mobile-App-Updates-Layout).
These inform the interaction and styling; this POC does not add Discord's
member, voice, or moderation controls.

Verify small and wide screens, light/dark themes, large text, route back to the
channel list, account restrictions, sender identity, and failed-send draft
preservation. The shared composer must retain its existing DM behavior.

## Review repair and TestFlight boundary

The review repair enforces NIP-44 encoded and decoded payload bounds, preserves
Concord outbox rows during database salvage, keeps the keyboard and new drafts
intact during sends, and clears stale delivery failures after reconciliation.
Reaction counts represent one account per emoji. Delivered ciphertext is stored
per event, with an atomic index update and a 200-wrap local history window;
unsent messages are retained separately from eviction. Existing aggregate
ciphertext records migrate transactionally on restore. Initial relay history
queries carry the same limit. This window is not backwards pagination.

These changes make the public text POC reviewable. They do not connect the app
to the production community. A TestFlight build intended to test Discord and
Trust & Safety must first load the real channel catalog and membership,
understand current community authority and moderation state, and expose room
reporting. Merely changing the relay URL or turning on the POC flag cannot
satisfy that acceptance gate. Publish that build only after those mobile paths
and the production enforcement service pass a staff roundtrip.

The approved Discord scope is **all public channels**, not a two-channel pilot.
Tickets and every private support channel remain excluded. The real channel
inventory and bridge links determine the production catalog; the two synthetic
POC rooms are not that catalog.

## Relay evidence and required contract

The live https://relay.divine.video/ NIP-11 response advertised NIP-59 and
NIP-33, no required authentication, and unrestricted writes. This metadata is
not an exhaustive kind policy or proof of successful storage.

Funnelcake source inspected at `4b2c414af38ce1b3d3f455ad4edcd6020033eb76`:
`database/migrations/000079_allow_gift_wrap_kind.up.sql` admits 1059;
`crates/relay/src/relay.rs` auto-allows 10000–19999 and 30000–39999,
subject to explicit disallow decisions. That predicts support for the durable
kinds below, but the deployed image and live allow/disallow tables were not
verified. Ephemeral kinds remain gated; do not assume 21059 is supported.

| Outer kind | Purpose | Acceptance requirement |
| --- | --- | --- |
| 1059 | Stream/control gift wraps and direct invitations | Publish acknowledgement, author query, live fanout, durable replay; also recipient filters for direct invitations |
| 33301 | Public invite bundle | Empty `d` coordinate, replacement and revocation tombstone |
| 33302 | Self-encrypted Community List | Decimal fragment `d` coordinates, replacement and full multi-device recovery |
| 13303 | Self-encrypted Invite List | Per-author replacement and tombstone preservation |
| 10304 | Armada bot manifest convention | Discoverability and replacement if bots are enabled |
| 21059 | Ephemeral presence/voice wraps | Live fanout without historical storage; phase 2 |

Profile and relay-list events used by the chosen clients need their own
acceptance cases. Inner message/control kinds ride inside 1059; accepting every
inner kind as an independent relay event is neither necessary nor sufficient.

Read-only WebSocket probes used a fresh random author filter and `limit: 1`,
without publishing anything. Both wss://relay.divine.video and
wss://relay.staging.dvines.org returned `EOSE` for each kind in the table.
Empty responses prove filter acceptance only, not kind admission or retention.
The planned wss://relay-armada.poc.dvines.org failed TLS hostname verification.
Cluster inspection was blocked by expired Google authentication; the deployed
image, runtime policy, owner-secret metadata and live staff roster remain
unverified. No secrets were read.

The dedicated writable strfry decision remains in force. Do not substitute the
main relay on the basis of NIP-59 support alone. In particular, a DM-specific
recipient-auth gate for 1059 can break Concord's stream-author queries; test
that contract without weakening existing DM privacy. Test bare kind-5 deletion
against shared-stream authors, retention, size limits, abuse controls, disk
capacity and restart recovery on an isolated relay.

## Gate A: two-device text POC

- [ ] Integrate UI and backend into one PR targeting main; run combined CI.
- [ ] Fix TLS and choose one explicit POC relay in both web and mobile builds.
- [x] Wire incoming subscriptions and matching publish acknowledgements;
      show rejected/pending sends honestly and preserve failed-send drafts.
      Verified through automated transport/repository/UI tests.
- [x] Bind durable account-scoped storage; test database reopen, sealed retry,
      deduplication, socket loss, account/room isolation and expiry.
- [ ] Exercise process-kill recovery, background/resume and offline catch-up
      on real devices and the deployed preview.
- [ ] On physical iOS and Android plus web, exchange text in both directions;
      an independent receiving client must display each accepted message.
      Repeat with local and Keycast signers using the existing Divine login.
- [ ] Verify Direct / Rooms navigation, Notifications and existing DMs,
      background/resume, logout/account switching, feature and restricted-account
      gates, dark/light appearance, large text and screen-reader focus.
- [ ] Preserve full public identifiers in diagnostic evidence; never record
      private keys, root secrets, invite fragments or message plaintext from users.

Use synthetic identities and messages in a disposable environment. This gate
can exercise public test rooms without claiming real membership or moderation.

## Gate B: actual community and public pilot

- [ ] Pin Concord and Armada revisions. Run independent cross-language vectors
      in both directions for derivation, self-ECDH, signatures, byte-exact rumor
      hashing, split control keys, nested size limits and malformed inputs.
      A shared fixture format or two clients using the same new implementation
      is not proof of compatibility with Armada.
- [ ] Test owner genesis, invite acceptance/revocation, guestbook membership,
      role/grant folding, stale grants, missing citations, concurrent editions,
      strict rank and anti-downgrade behavior. Reject forged authority.
- [ ] Test Community List 33302 on two devices: fragmented/out-of-order reads,
      offline concurrent changes, leave tombstones, unknown fields and held keys.
- [ ] Test threads, edits, deletion authority and reactions with Armada; test
      expiry on arrival, while viewing, after restart and in storage. Expired
      messages must not return through replay or notifications.
- [ ] Test private-channel rekey and full refounding, concurrent rotations,
      missing chunks, retained history and process interruption. Public invite
      reacquisition is a separate expected outcome, not successful exclusion.
- [ ] Establish the dedicated owner using the human custody workflow. Verify
      backup/IAM/audit metadata only. No owner secret in a workload or agent.
- [ ] Assign individual team accounts to explicit Admin/Moderator roles and
      verify the signed roster from a second client. Assign primary/backup
      moderation coverage and an incident lead. Discord roles are not proof of
      Concord grants; copying role names is not account mapping.
- [ ] Rehearse message removal, role stripping, cooperative kick, ban plus
      rekey/refounding, demotion and bridge shutdown. Test concurrent bans and
      encoded banlist capacity (practical ceiling near 500 npubs).
- [ ] Provide reporting/escalation and a procedure for both networks. Client
      moderation hides/rejects unauthorized content; it cannot recall copies.
      Owner compromise needs a new community identity, not merely refounding.

Staff actions require the appropriate permission and strictly higher rank.
Read access comes from possession of keys. Kicking alone is cooperative;
banning silences the identity in compliant clients; cryptographic exclusion
requires key rotation. Keep operational admin authoring in Armada initially,
while mobile must correctly enforce received state.

## Gate C: Discord bridge

- [ ] Verify portal operator, availability, app identity, requested permissions,
      retention, origins and rollback access before authorizing anything.
- [ ] A Discord server admin authorizes the bot in a disposable test server
      first. The upstream wizard requires installation before preview/import.
- [ ] Build the allowlist for all public channels. Exclude Tickets and every private
      support channel unconditionally, including after permission changes.
- [ ] Use the dedicated owner's human-controlled session for founding
      signatures: the inspected wizard creates a community. Do not create a
      different genesis first and assume it can import into that community.
- [ ] Verify the bridge bot's actual roster grant. Upstream says it retains
      Admin; treat that as privileged access, not just a message forwarder.
- [ ] Test both directions, history overlap, restart/retry, loop/duplicate
      suppression, rate limits, attachments, mentions and attribution. Determine
      how a bridged Discord author maps to a Concord identity before testing bans.
- [ ] Test deletions and moderation on both sides; do not assume bans mirror.
      Confirm forwarding stops when a channel becomes private.
- [ ] Rehearse disabling portal jobs and Discord bot/webhook access. Revoking a
      Concord role alone neither stops an external portal nor erases held keys.
- [ ] Only then enable one approved public pilot channel, with honest bridge
      labels, staffed coverage and a separate expansion decision.

Human input needed: a Discord administrator's authorization, the approved
public-channel list, named staff and their verified Divine accounts, and a human
owner custodian for signing. Google reauthentication is needed for the blocked
cluster checks. Engineering owns builds, relay setup, tests and deployment
preflight. Discord sync is unnecessary for Gate A. An ArgoCD sync is a separate
operation and must wait for published/pinned images and the existing POC gate.
Text testing does not require the placeholder LiveKit SFU; voice stays phase 2.

## Sources

- [CORD-01–08, pinned baseline](https://github.com/concord-protocol/concord/tree/173e97041f0689c9c75e72d7489c5c1d6320478c): streams, communities, roles, invites, rotation and expiry.
- [Armada import wizard](https://gitlab.com/soapbox-pub/armada/-/blob/75888848e9eb868ea893a173a41892b75b9e71bb/src/components/discord-import/DiscordImportWizard.tsx) and the same revision's `src/lib/bridgeApi.ts`.
- [Concord bots guidance](https://concordprotocol.org/build/bots/).
- Infrastructure plan: `divine-iac-coreconfig/docs/superpowers/plans/2026-10-13-armada-divine-chat.md`.
- UI implementation record: [Messages UI](2026-10-14-messages-rooms-ui.md).
