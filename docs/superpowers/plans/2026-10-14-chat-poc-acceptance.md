# Concord chat test and pilot acceptance

Status checked 2026-10-14. This is an acceptance checklist, not a deployment
approval or evidence of a working community. Discord remains canonical.

## Review and implementation state

Backend PR: https://github.com/divinevideo/divine-mobile/pull/10093
Backend inspected at `60908610be5eba45c67b273a08e871b15bb3d1e1`.
Messages UI inspected at `f15caa847faf5d518d70c1e76e86c6a90b9f92fa`.
The backend owner must integrate the UI into the combined feature PR before
its checks can validate the complete feature. No stacked PR is required.

The Messages UI provides Direct / Rooms behind the disabled-by-default
`concordChat` gate. Its catalog is an explicitly public test community. It
reuses the current Divine account. It does not establish membership or staff
permissions. UI widget tests are not evidence of relay interoperability.

Observed runtime gaps in this revision:

- `mobile/lib/features/chat/concord_session.dart` defaults to
  wss://relay.staging.dvines.org, not the planned dedicated chat relay.
- The Page/Cubit does not call `subscribeWraps` or ingest incoming relay
  messages. Connect, subscribe, verify/decrypt, ingest, and emit need an
  account/channel-scoped lifecycle, including cancellation and reconnect.
- `mobile/packages/concord_repository/lib/src/websocket_relay.dart` writes
  `EVENT` to the socket without awaiting its matching relay `OK`. It does not
  handle `CLOSED`, `NOTICE`, `EOSE`, authentication, or reconnect as state.
  A successful local send is therefore not proof of delivery.
- The app binds `InMemoryConcordStore`. Package restore/retry tests do not
  demonstrate persistence across app termination. The retry path also uses
  the legacy cipher path, while the app supplies an unavailable legacy cipher.
- The catalog and fallback keys are a deterministic public POC. Real invite
  admission, membership/list loading, roster enforcement and key rotations
  must replace that wiring before any real community is exposed.
- Community List merging is currently a shallow entry merge; full CORD-02
  fragment freshness, tombstones, unknown-field preservation and key-vault
  semantics still need independent interoperability tests.
- Expiry helpers exist, but no app lifecycle invokes purge. Receiver-side
  CORD-08 expiry cannot wait for phase-2 timer controls.

These are backend integration dependencies. This checklist does not modify
another session's backend branch or claim those features are implemented.

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
- [ ] Wire incoming subscriptions and matching publish acknowledgements;
      show rejected/pending sends honestly and preserve failed-send drafts.
- [ ] Bind durable account-scoped storage; test process-kill recovery, sealed
      retry, deduplication, offline catch-up, socket loss and channel switching.
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
- [ ] Approve a public-channel allowlist. Exclude Tickets and every private
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
