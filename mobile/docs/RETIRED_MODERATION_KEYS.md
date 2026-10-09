# Retired Moderation Keys

Divine's moderation account is a Nostr identity, and it has rotated. A DM
thread opened before a rotation stays keyed on the old pubkey forever — Nostr
has no way to move a conversation to a new key — so the app has to keep
recognising identities it will never talk to again.

`kRetiredModerationKeys` in `mobile/lib/config/official_accounts.dart` is the
register in code: each entry pairs a retired pubkey with its
[custody status](#key-custody). `kLegacyModerationPubkeys`, the flat pubkey
list `isModerationAccount` and `isRetiredModerationAccount` actually read, is
derived from it. This file is the human-readable register: what each entry
was, when it stopped being the moderation account, and what the client still
does with it.

Read this before adding an entry.

## The register

| Pubkey | Retired | Rotated by | Private key |
|---|---|---|---|
| `121b915baba659cbe59626a8afaf83b01dc42354dfecaad9d465d51bb5715d72` | 2026-03-12 | An operational secret change, carrying no PR of its own — see below | Unrecovered — `RetiredKeyCustody.unrecovered` on the `kRetiredModerationKeys` entry; see [Key custody](#key-custody) |

### `121b915b…`

Rotated because the service and the clients had drifted onto different keys.
It held **three** roles, which is the part worth knowing — retiring a
moderation key is not one revocation:

| Role | Revoked |
|---|---|
| Moderation DM, label, and report signing identity | 2026-03-12 by the secret rotation itself — though only for labels and reports; the DM half is unverifiable, see below |
| Funnelcake `RELAY_PUBKEY`, plus one of the two `ADMIN_PUBKEYS` entries | 2026-03-17, `divinevideo/divine-iac-coreconfig#280`, across the poc, test, staging, and production overlays |
| NIP-32 labeler this app subscribed to | 2026-03-20, `divinevideo/divine-mobile#2321` — plus `ModerationLabelService._migrateLegacyPubkey`, which unsubscribes it on every init |

#### Dating the rotation

No PR performed it, so every PR this gets credited to is the wrong answer. The
rotation was a secret change, and neither key appears anywhere in
`divine-moderation-service`'s history — `git log --all -S<hex>` returns nothing
for either. What *can* be dated, in UTC:

| When | What |
|---|---|
| 2026-03-12 22:50:41 | The incoming key's kind-0 is signed and published to `relay.divine.video` (`17e11af3…`) |
| 2026-03-12 22:54:42 | `divine-iac-coreconfig#280` is opened, recording NIP-05 as already repointed, kind-0 as published, and the incoming key as verified through moderation-service's debug endpoint — which derived its answer from `NOSTR_PRIVATE_KEY` alone |
| 2026-03-13 01:57:35 | `divine-moderation-service#31` is authored, describing label publishing as broken "since the key rotation" |
| 2026-03-15 15:39:37 | #31 merges |
| 2026-03-17 15:32:10 | #280 merges |
| 2026-03-20 14:54:11 | `divine-mobile#2321` merges |

The signing secret therefore already resolved to the incoming key on
**2026-03-12** — three days before the earliest PR this is usually credited to,
and eight before the latest.

Both of the usual citations name a merge date rather than the act:

- `divine-mobile#2321` (2026-03-20) is the client catching up, eight days late.
- `divine-moderation-service#31` (2026-03-15) is the cleanup. It removed the
  superseded `MODERATOR_NSEC` path and fixed the label publishing the rotation
  had just broken. Its own text dates the rotation to "today" — and it was
  written on the 13th, not the 15th it merged on.

One part is genuinely unrecoverable. DM signing read `MODERATOR_NSEC`, a secret
with no git trace, so whether the DM role moved on the 12th with everything
else or lingered until #31 removed that path on the 15th cannot be established
from any repo. Labels and reports are pinned to the 12th; treat the DM half as
"on or before 2026-03-15".

Do not read that middle row as "the relay admin key", despite `RELAY_PUBKEY`.
`divine-iac-coreconfig#280` uses the phrase *relay admin pubkey* for a
different identity —
`81549bc0b5153b4b970fe4a3892ad185698b8b8b26ec69321a527d0644cd2898` — and states
in the same PR that it is **unchanged** by the rotation. `ADMIN_PUBKEYS` was a
two-entry list holding both keys, and only the `121b915b…` entry was replaced;
`81549bc0…` sits untouched on both sides of every edit. So a rotation that goes
looking for "the relay admin key" finds `81549bc0…` and changes the wrong
thing. Match on the variable name, not the prose.

Funnelcake's `nostr.trusted_labelers` and `nostr.moderation_sources` tables are
a third trust surface, distinct from both of the above. Their configured
identity differs from the user-facing moderation account — it is `81549bc0…`
as well, so that key holds this role on top of relay admin. Whether that is an
intentional automated role or drift is tracked in
`divinevideo/divine-mobile#8253`. A rotation must audit and reconcile those
tables with the intended labeler roles rather than assuming every moderation
role uses the shared support identity.

## What the client does with a retired key

| Behaviour | Where |
|---|---|
| Official name ("Divine Moderation"), inbox search name and bundled wordmark avatar — kept for a retired key nobody can sign as (`unrecovered`, `destroyed`) | `dm_peer_identity.dart` (`dmPeerDisplayName`, `dmPeerAvatar`) and `dm_peer_name.dart`, reached from the inbox row, request row and preview, thread header, empty-conversation state, following strip, reactions sheet and the recipient pickers; resolved by `moderationPresentationOf` |
| Neutral "Former moderation account" name and the default placeholder avatar, with no handle line — withdrawn official name and wordmark, and the key's own kind-0 name, picture and NIP-05 are ignored too; the thread header shows no subtitle, not a social-proof line — for a retired key someone could still sign as (`archived`, `compromised`) | the same helpers plus `dmPeerHandle`, through `ModerationPresentation.former` |
| Conversation and request rows labelled closed | `conversation_tile.dart` and `request_tile.dart`, via `isRetiredModerationAccount` |
| Composer closed; banner routes replies to the current support key | `conversation_view.dart`, via `isRetiredModerationAccount` and `kModerationPubkeyHex` |
| Pinned support row, unread partition, and retired predicates wired into list state | `inbox_page.dart`, `message_requests_page.dart`, `app_shell_badge_scope.dart`, and `ConversationListBloc` |
| Destructive request action withheld for moderation threads, whatever the custody | `request_preview_view.dart`, via `isModerationAccount` |
| Outbound sends refused and retained as non-retryable evidence | `dmSendPolicyProvider` → `DmSendPolicyDecision.terminallyBlockedRetain` |
| Pre-rotation threads excluded from pinned-support adoption | `DmRepository.extractPinnedSupport` |
| Labeler subscription migrated to the current key | `ModerationLabelService._migrateLegacyPubkey` |
| A protected minor may read (never send to) a retired-key thread while nobody can sign as it | `OfficialAccountsService.isReadableByProtectedMinor`, gated on `RetiredKeyCustody.canStillSign` |
| Retired key refused as the moderation identity — from the persisted NIP-05 cache (at load and at each NIP-05 refresh) and from a live NIP-05 answer, before it is ever persisted. Refusing a live answer also clears the cache, so an older cached key cannot come back on the next cold start | `ModerationPubkeyResolver._refuseRetired`, reached through `.cached()` and `.resolve()` |
| Report recipient read at filing time from the label service, not captured once when the reporting provider was built — covers a stale cached key NIP-05 corrects moments later | `ContentReportingService.currentModerationPubkey` → `ModerationLabelService.divineModerationPubkeyHex`, wired in `social_providers.dart` |
| A report queued before an update, whose stored recipient this build lists as retired, sends its moderation DM to the pinned key instead, logged once per report | `_moderationDmRecipient` in `social_providers.dart`, via `isRetiredModerationAccount` and `kModerationPubkeyHex` |

`isModerationAccount` answers *"is this the moderation team's thread"* and is
true for every retired key whatever its custody: it is the **safety**
predicate (the request-removal policy and the withheld decline action), so
those protections never depend on who might hold a key.
`isRetiredModerationAccount` answers *"is this a key we can still talk to"*.
Neither chooses a name or an avatar. **Presentation** follows recorded custody
through `moderationPresentationOf`, which the UI reads from
`moderationPresentationProvider`; tests supply every custody state by
overriding `retiredModerationKeysProvider`. Anything picking a **send target**
must use `kModerationPubkeyHex` and none of these.

Presentation is keyed on the pubkey and its recorded custody: it does not
consider when a message arrived relative to the rotation. Custody is compiled
into the app, so a change reaches a user only with the build that lists it.
The repository layer is also retired-key-aware at the two delivery seams that
matter: the injected `DmSendPolicy` blocks every outbound publisher at the
lowest send primitive, and pinned-support extraction avoids adopting a
pre-rotation thread whose participants would route replies to the retired
key. The retirement and custody protocol this depends on was open at
`divinevideo/support-trust-safety#199`, closed by
`divinevideo/support-trust-safety#253`, which wrote the procedure down.

## Rotating the moderation key

The client half is small and belongs in one PR:

1. Add a `RetiredModerationKey` entry for the outgoing pubkey to
   `kRetiredModerationKeys` — not a bare pubkey to `kLegacyModerationPubkeys`,
   which is derived from it — with a comment naming the date and what
   performed the rotation, and set its [custody status](#key-custody) per
   step 5. Date the comment from the act, not from the merge of whatever PR
   cleaned up after it, and expect that there may be no commit to name at
   all.
2. Add a row to [the register](#the-register) above, including every role the
   key held — check Funnelcake's `RELAY_PUBKEY` and `ADMIN_PUBKEYS` and the
   labeler roles, not just DM signing.
3. Update `kModerationPubkeyHex` to the incoming shared support key. This is a
   mandatory routing change: the constant is the report target's fallback
   (the live recipient is the label service's NIP-05-resolved key — see the
   row above), where a queued report addressed to the outgoing key is
   re-sent, the pinned support row destination, the protected-minor gate
   anchor, the unread partition, the retired thread redirect target, and
   `ModerationLabelService`'s own NIP-05 fallback. A stale value silently
   routes support traffic to the retired account for every one of those
   pin-anchored surfaces, and for reports too whenever live NIP-05
   resolution is unavailable. Treat this step as transitional:
   `divinevideo/divine-mobile#8355` decided on 2026-08-31 that
   the client should resolve the moderation identity through NIP-05 instead of
   a shipped pubkey, so that rotation no longer needs an app release.
   `divinevideo/divine-mobile#8253` owns that change; until it lands, a
   rotation still needs one.
4. Confirm `ModerationLabelService._migrateLegacyPubkey` covers the new entry
   — it reads the list, so it does, but the test should say so.
5. Set the outgoing key's [custody status](#key-custody) on the
   `RetiredModerationKey` entry from step 1. Custody is data on the entry, and
   `OfficialAccountsService.isReadableByProtectedMinor` reads it directly, so
   the widening that lets a DM-restricted minor read a retired-key thread
   follows automatically — a data edit to the register with the right enum
   value, not a logic change.
   `unrecovered` and `destroyed` both mean nobody can sign as the key
   (`RetiredKeyCustody.canStillSign` is `false`), so that widening applies.
   `archived` and `compromised` both mean someone still could (`canStillSign`
   is `true`), so the widening does not apply. Use `compromised` whenever
   someone outside the team may hold the key — regardless of what became of
   the team's own copy — and reserve `archived` for a key that stayed fully
   inside the team's control. For an archived key the team can still decrypt
   what was already sent to it, so standing up a reader against that backlog
   is possible and whether to do so is a real decision; the composer stays
   closed either way, because outbound sends are refused for every retired
   key regardless of custody. Custody also decides branding: for `archived`
   and `compromised` the app withdraws Divine's name and wordmark from the old
   key's threads, which read as a "Former moderation account"; for
   `unrecovered` and `destroyed` they keep it (#9963).
6. Note that a rotation forks `conversation_id` on the service side, so the
   outgoing key's rows become a disjoint set that the admin UI's pubkey lookup
   can no longer reach. `divinevideo/divine-mobile#7850` is closed, but the
   retention question it raised — what happens to those rows — is still open
   with Trust & Safety; see `mobile/docs/DM_RETENTION.md`.

The service and infrastructure half — rotating the signing key, updating
Funnelcake's `RELAY_PUBKEY` and its `ADMIN_PUBKEYS` allowlist (replacing only
the outgoing entry), republishing kind-0 and kind-10050,
repointing NIP-05, and auditing Funnelcake's `nostr.trusted_labelers` and
`nostr.moderation_sources` — lives outside this repo. Do not assume those trust
tables must use the user-facing support key: reconcile them with the approved
human-support and automated-labeler roles in `divinevideo/divine-mobile#8253`.
The *current*-identity model was settled on 2026-08-31
(`divinevideo/divine-mobile#8355`). What a retirement has to do on that side is
now written down: `divinevideo/support-trust-safety#253` closed
`divinevideo/support-trust-safety#199` by adding a step-by-step procedure at
`docs/moderation/moderation-key-retirement-procedure.md` in that repo, whose
client-facing step points back at this file's checklist.

### What a rotation cannot fix

Messages already sent to the outgoing key are unreachable, for two independent
reasons — which matters, because only the second one is permanent.

The DM reader derives its subscription from its own signing key
(`divine-moderation-service`, `src/nostr/dm-reader.mjs`), so it watches exactly
one pubkey and cannot be configured to watch a second. Anything addressed to a
retired key is accepted by the relay and read by nobody — it does not error,
bounce, or queue. That much is a code limitation, and someone could lift it.

What cannot be lifted is custody. Reading those messages needs the retired
private key, because a gift wrap is encrypted to its recipient; a watched-set
in the reader would deliver ciphertext nobody can open. So for a key whose
private half is unrecovered — which is the status of the only entry in this
register — the composer is closed permanently rather than pending a backlog
item. Record each new entry's [custody status](#key-custody) so the next
rotation does not have to rediscover which of the two reasons applies.

Retired keys also publish no kind-10050. Under NIP-17 that already signals "not
ready to receive messages", so the protocol and the client agree.

## Key custody

No moderation key material has ever been committed to this repo, and none is
recoverable from it. Custody of live signing keys is owned by Trust & Safety
and is deliberately not described here. For a future register entry, obtain
the custody status from Trust & Safety or the operator responsible for the
rotation, then record the public-safe result in two places — the entry's
`RetiredKeyCustody` value in `kRetiredModerationKeys`, and this section's
prose; do not infer it from this repo.

Custody is compiled into the app: `kRetiredModerationKeys` is a `const` list,
so a change to a key's custody — discovering a compromise, for instance —
reaches users only when a new build ships, not the moment Trust & Safety
records the change.

One custody fact does belong in the register, because a shipped client
behaviour rests on it and looked provisional without it.

**`121b915b…` has no known private-key holder. Treat it as unrecovered, not as
archived somewhere.** It is an early key from Divine's initial setup — it
enters this repo on 2026-02-25 in `divinevideo/divine-mobile#1797`
(`ba51840a2`), as `ModerationLabelService.divineModerationPubkeyHex`, 15 days
before the rotation — and the operator who later rotated it out was not the one
who created it. Established on the 2026-08-31 support call and confirmed by the
rotating operator on `divinevideo/divine-mobile#7851`.

That is not a gap to be closed later. It is what makes the closed composer
correct **by fact rather than by policy**, and it retires the "if the nsec
turns up, reopen the thread" branch that
`divinevideo/support-trust-safety#199` had been holding open for this key:

- Gift wraps addressed to a retired key are NIP-44-encrypted to it. Without
  that private key nobody can read them — not Trust & Safety, not a future
  DM reader, not us. So watching the key is impossible rather than merely
  unimplemented, which is the stronger half of the argument in
  [What a rotation cannot fix](#what-a-rotation-cannot-fix).
- Recognition is therefore the only control this key still has behind it, and
  recognition is what `kLegacyModerationPubkeys` provides. Every other role it
  held was revoked either operationally or by the client's subscription
  migration — see the roles table above.

Do not re-litigate the composer for this key. A future retirement is a
different question: what makes a key retired, how access is revoked, where
remaining private material lives, how a retired identity is proved
unreactivatable, and how a replacement is announced. That protocol is now
written down, and what the fix for `divinevideo/divine-mobile#7851`
delivers against it is listed in [Open items](#open-items).
Custody also decides how the app presents a retired key; see
[What the client does with a retired key](#what-the-client-does-with-a-retired-key).

## Open items

- `divinevideo/divine-mobile#8253` — resolve the moderation identity through
  NIP-05 rather than a shipped pubkey, and reconcile Funnelcake's trusted
  labeler with the user-facing support identity.

Settled, kept here because the register used to cite these as open:

- `divinevideo/support-trust-safety#211` — whether a retired key keeps
  Divine's official name and wordmark. Decided: branding follows recorded
  custody. Kept for `unrecovered` and `destroyed`, withdrawn for `archived`
  and `compromised`. Implemented by `divinevideo/divine-mobile#9963`.

- `divinevideo/support-trust-safety#199` — the retirement protocol: what makes
  a key retired, how access is revoked, where remaining private material is
  held, how a retired identity is proved unreactivatable, and how a
  replacement is announced and verified. Closed by
  `divinevideo/support-trust-safety#253`, which wrote the procedure down at
  `docs/moderation/moderation-key-retirement-procedure.md` in that repo.
- `divinevideo/divine-mobile#7851` — the mobile behaviour that follows from
  the retirement protocol. The send refusal and closed composer predate
  #7851 (they shipped with #6416) and are not custody-aware — every
  retired key is refused alike. What #7851 delivers is custody recorded per
  register entry, the custody-aware minor-read exception, the label service
  refusing retired keys from cache and live NIP-05, the report recipient
  read at filing time, queued reports addressed to a retired key re-sent to
  the pinned key, and the composer withheld while a thread's participants
  cannot be resolved (#8664/#8677).
- `divinevideo/divine-mobile#8355` decided on 2026-08-31 that shared access to
  the current moderation identity stays acceptable, and that the client should
  resolve that identity through NIP-05. It did not cover retirement.
