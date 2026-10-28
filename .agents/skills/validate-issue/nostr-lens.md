# Nostr lens

Line numbers below are `nostr-protocol/nips` at `a79e21d` (2026-10-05). If the
local clone has moved, re-read the line before quoting it. Command behaviour is
`nak` 0.20.6 as run on 2026-10-10; re-check flags after upgrading.

## 1. Name the authority the bug is against

| Authority | Where to read it | A mismatch means |
|---|---|---|
| NIP text | `<root>/nips/NN.md` at a pinned SHA | Someone violates the spec. Say who. |
| Divine backend (funnelcake relay + REST, Keycast, Blossom) | sibling clone source, then a live probe | Backend bug or a deliberate deviation. Belongs to that repo. |
| Third-party relays | live probe + `nak relay <url>` (NIP-11) | Interop. The client must tolerate it. |
| Other clients | their source (nostr-tools, NDK, rust-nostr, Amethyst and its Quartz library, welshman, Damus) | Convention, not spec. Evidence for a product decision. |

Verdict follows from the row: client violates spec → fix here. Relay violates
spec → issue in the relay's repo; a client workaround is the user's call. Spec
silent or ambiguous → quote it, show what two other implementations do, and
send the product question to the issue. Client deviates on purpose → find the
comment or PR that says so before "fixing" it.

SHOULD is not MUST. A relay that ignores a SHOULD is conformant, so a client
that breaks on it is the one with the bug.

The table says where other implementations keep the code. The Quartz row's
three directories (in `vitorpamplona/quartz` at `c63c35c`; Quartz no longer
lives in the `amethyst` repo) and the welshman row's files (at `7d72fa0`) were
last opened on 2026-10-28. The other rows come from a web read on 2026-10-10
and their paths were not opened. Confirm a path before citing it, and pin a commit SHA
whenever you cite one of these.

| Project | DM wrapping (NIP-17 / 59) | Video (NIP-71) |
|---|---|---|
| `vitorpamplona/quartz` (the protocol library of Amethyst, `vitorpamplona/amethyst`) | `quartz/src/commonMain/kotlin/com/vitorpamplona/quartz/nip17Dm/`, `nip59Giftwrap/` | `nip71Video/` |
| `coracle-social/welshman` (the library behind Coracle and Flotilla) | `packages/domain/src/kinds/DirectMessage.ts` (kind 14), `MessagingRelayList.ts` (kind 10050), `packages/signer/src/nip59.ts`, `packages/app/src/plugins/wraps.ts`, `packages/net/src/wrapManager.ts`. Its reaction and delete writers (`packages/domain/src/kinds/Reaction.ts`, `Delete.ts`) are generic, not NIP-17-specific | not located |
| `nbd-wtf/nostr-tools` | `nip17.ts`, `nip59.ts`, `nip44.ts` | `kinds.ts` |
| `nostr-dev-kit/ndk` | `core/src/events/gift-wrapping.ts` | `core/src/events/kinds/video.ts` |
| `rust-nostr/nostr` | `nostr/src/nips/nip17.rs`, `nip59.rs` | not located |
| `damus-io/damus` | `damus/Core/NIPs/NIP17/`, `NIP59/` | not located |
| `hoytech/strfry` (relay) | `strfry.conf` (`restrictedReadKinds = "4, 1059"`) | |

## 2. Read the NIP as it is today, and as it was when the feature shipped

```bash
N=<root>/nips; git -C $N pull --ff-only; git -C $N rev-parse --short HEAD
git -C $N log --since=<date the feature shipped> --format='%cs %s' -- NN.md   # what moved under the app
grep -n -E 'MUST|SHOULD|MAY' $N/NN.md                                        # the obligations, with line numbers
git -C $N log -S'<phrase>' --format='%h %cs %s' -- NN.md | tail -1            # when a rule entered
grep -n -i unrecommended $N/README.md                                         # NIPs not to build on (04, 26, 28, 72, 96, EE …)
gh pr list -R nostr-protocol/nips --state open --search 'NIP-NN'              # the rule may be mid-change
```

The spec moves. Changes in 2026 that touch code Divine ships, each a place
where "the app follows the NIP" may have silently stopped being true:

| Date | Change | Line |
|---|---|---|
| 2026-01-07 | NIP-71 re-adds addressable video kinds 34235 / 34236 (`d` tag required). They had been out of the spec since 2025-01-30, when videos became regular kinds 21 / 22 | 71.md:27-28, 115 |
| 2026-01-26 | NIP-46 `switch_relays`: clients should call it on connect | 46.md:108, 129 |
| 2026-05-28 | NIP-59 ephemeral gift wrap, kind 21059 | 59.md:77 |
| 2026-05-28 | NIP-17 deletion: a kind 5 wrapped in a 1059, sent in the conversation | 17.md:87 |
| 2026-05-28 | NIP-71 multiple audio tracks as `imeta` variants; `ov` flags the original, `waveform` is optional, clients should prefer them over in-video audio | 71.md:41-50, 94-100 |
| 2026-05-28 | NIP-01: relays accept one endpoint when path segments change nothing (URL normalisation) | 01.md:111 |
| 2026-06-15 | NIP-46 `logout` method: the signer SHOULD remove the session on request; the client MUST still delete its client-keypair on logout | 46.md:109, 133-135 |
| 2026-06-23 | NIP-46 optional client metadata (`name`, `url`, `image`) in `connect`; a display hint, never authorization | 46.md:48, 115-123 |
| 2026-06-28 | NIP-44 plaintext may exceed 65535 bytes (6-byte length prefix above it) | 44.md:87-91 |
| 2026-07-15 | NIP-46: unknown methods MUST get an error reply (no silent timeout) | 46.md:164 |
| 2026-08-24 | NIP-22: the ban on kind 1111 replies to kind 1 was removed | 22.md (line deleted in 13664fb) |
| 2026-09-01 | NIP-42 / NIP-67: `EOSE` may carry an `auth` hint | 42.md:89 |
| 2026-09-03 | NIP-78: relays SHOULD require NIP-42 AUTH for kind 78 / 30078 and serve them only to the authenticated owner | 78.md:21-24 |
| 2026-09-04 | NIP-01: `limit: 0` returns no stored events, then EOSE, subscription stays live | 01.md:151 |
| 2026-10-05 | NIP-92: `imeta` on kind 0 picture and banner, carried over on republish | 92.md:49, 80 |

## 3. Relay ground truth

Three rules before any command:

1. **Close stdin.** Append `</dev/null` to every `nak` call. Under zsh a backgrounded `nak serve` never starts listening without it, and `nak event` waits on stdin.
2. **An empty result is not a zero.** Read stderr. `nak` exits 3 only when every relay fails to connect; with several relays a partial failure still exits 0. An AUTH-gated relay queried without `--auth` exits **0** with no events and `CLOSED: auth-required` on stderr. `2>/dev/null | jq -s length` turns all of these into a confident `0`. Before reporting "not on the relay", run the same query for an event you know is there.
3. **Name the key.** Export `NOSTR_SECRET_KEY` for the designated test account, read from your credential manager rather than typed into a command. `nak` reads it as a global option: the recipes below use `event`, `req`, `count` and `gift`, and `curl`, `blossom` and `bunker` also read it. (`gift wrap --help` and `gift unwrap --help` list it; the parent `gift --help` does not.) Never pass the key as `--sec <value>`: shell expansion puts it in `argv`, where the process table and shell history expose it. Without a key `nak` signs with a per-machine default key, and a bare `nak event <relay>` publishes a kind 1 "hello from the nostr army knife" under it.

| Need | Command |
|---|---|
| The event as one relay holds it | `nak req -i <id> wss://relay </dev/null` (one relay per call, so you see which one lacks it) |
| Is it well-formed | `… \| nak verify` (silent, exit 0 = valid; exit 123 and the reason otherwise) |
| Would the app's filter match it | `nak filter '<event json>' '<filter json>'` (prints the event on a match, nothing otherwise; exit code is 0 both ways) |
| Current version of a replaceable / addressable event | `nak req -k 10002 -a <hex> -l 1 …` / `nak req -k 34236 -a <hex> -d <d> …`, per relay: relays can hold different versions |
| How many, without downloading | `nak count …` (the number is printed on **stderr** as `<relay>: <n>`); ids only: `nak req --ids-only …` |
| History past a relay's clamp | `nak req --paginate …` |
| Relay limits and claimed NIPs | `nak relay <url>` (`limitation.auth_required`, `max_limit`, `max_subid_length`, `created_at_lower_limit` / `upper_limit`, `max_message_length`) |
| AUTH-gated kinds (1059, 4) | `nak req --auth -k 1059 -p <hex> …` (with `NOSTR_SECRET_KEY` exported) |
| AUTH-gated app data (78/30078) | `nak req --auth -k 30078 -a <owner hex> …` (with the owner's `NOSTR_SECRET_KEY` exported; 30078 carries `d`, not `p`) |
| Open a test account's gift wrap | `… \| nak gift unwrap` prints the unsigned rumor (export that account's `NOSTR_SECRET_KEY` for the command). There is no `--from` flag, whatever `nak gift --help` shows |
| Build a wrap the way Divine does | `nak event -k 14 -c hi -p <B> \| nak gift wrap -p <B> --use-our-identity-key --use-their-identity-key` with the sender's `NOSTR_SECRET_KEY` exported (the flags stop a draft-NIP decoupled key from being used; `-p` is the recipient's public key, not a secret) |
| Decode / build identifiers | `nak decode <npub\|nevent\|naddr>` / `nak encode …` |
| NIP-98 request, Blossom, remote signer | `nak curl`, `nak blossom`, `nak bunker` |
| A relay you control | `nak serve --port <p> [--auth] [--eager-auth] [--events seed.jsonl] </dev/null` (in memory; prints `relay running at ws://localhost:<p>`) |

Against a slow relay use one long-lived connection and COUNT, not a process
per query; parallel one-shot processes return silent partial sets. With raw
`websocat`, hold stdin open (`{ printf …; sleep 12; }`) or the socket closes
before the relay answers.

## 4. Four read paths, one moment

The same item reaches the screen through relay REQ, funnelcake REST, the local
cache (Drift / Hive / cache_sync) and in-memory bloc state. They lag
differently: REST and tag-indexed relay queries can trail a by-id read by
minutes. "It is missing" is located by reading all four at the same moment and
naming the first one that lacks it.

## 5. Failure classes

Pick the rows the claim sheet touches. Each is a prediction to test, not a
conclusion.

| Class | Rule | How it presents |
|---|---|---|
| Replaceable tie-break | "the event with the lowest id … should be retained" (01.md:101) | Two publishes in one second; relays or caches keep different winners |
| Read-modify-write clobber (kinds 0, 3, 10002, 10050, lists) | No NIP protects you; NIP-51 only says append (51.md:13) | A partial update republishes from a stale or empty base and drops tags or fields. Diff the relay's event before and after |
| Addressable identity | `d` required for 34235 / 34236 (71.md:115); address is `kind:pubkey:d` | Edits appear as duplicates; `#a` and `#e` queries disagree |
| Video kind coverage | 34235 / 34236 were absent from NIP-71 from 2025-01-30 to 2026-01-07; `duration` is an `imeta` property (71.md:48) yet the addressable example carries a top-level `duration` tag (71.md:207); multiple audio tracks are `imeta` variants and clients should prefer them over in-video audio (71.md:41-50) | A client written in that year queries only 21 / 22 and never sees Divine's 34236 videos, or the reverse; duration missing depending on which place a client reads; a client ignores or duplicates an audio track |
| `since` / `until` inclusive | 01.md:143 | Paging duplicates or skips the boundary second |
| `limit` | initial query only (01.md:149); `limit: 0` (01.md:151); relays clamp (`max_limit`) | "Missing" items past the clamp; a count that equals the clamp |
| Unanswered is not empty | EOSE ends stored events (01.md:159); CLOSED refuses (01.md:178) | A timeout or CLOSED rendered as "nothing here yet" |
| `OK` handling | 3rd field is the verdict; prefixes `duplicate, pow, blocked, rate-limited, invalid, restricted, mute, error` (01.md:166-182); `auth-required:` / `restricted:` (42.md:58-59) | `duplicate:` arrives with `true`; `rate-limited:` and `error:` are retryable; a late OK after a client timeout means the relay stored it |
| Subscription id | max 64 chars (01.md:121) | Strict relays reject; Divine's own relays do not, so no local test catches it |
| Id serialisation | escapes for `\n " \\ \r \t \b \f` only (01.md:49-55) | "event id does not match" on content with TAB / CR when either side escapes differently |
| Relay URL identity | one endpoint per relay (01.md, 2026-05-28) | Trailing-slash or path variants treated as two relays: double REQ or a skipped publish |
| Gift-wrap time | seal and wrap `created_at` randomised "up to two days in the past" (17.md:59); the canonical time is the rumor's (59.md:111) | A `since` cursor misses fresh wraps: a wrap built with `nak gift wrap` in testing was dated 36 h back. Order by the rumor's time |
| Seal authorship | kind 13 pubkey MUST equal the rumor's pubkey (17.md:57) | Impersonation if unchecked |
| DM routing | publish only to the recipient's kind 10050 relays; if none, "clients shouldn't try" (17.md:77); relays SHOULD serve kind 1059 only to p-tagged users via AUTH (17.md:81) | Sends to the general pool; "delivered" with no reader; a relay leaks DM metadata or an unauthenticated client reads an empty inbox |
| AUTH | challenge lives for the connection; kind 22242 with `relay` + `challenge`; retry the REQ/EVENT after AUTH (42.md:41-111) | Empty DM inbox for 1059, or an empty creator-sync library / refused 30078 publish, on relays that gate them; first query after reconnect fails |
| Deletion | relays act only on same-pubkey targets (09.md:31); clients MUST check the pubkey before hiding (09.md:41); an `a` deletion covers versions up to its `created_at` (09.md:35); keep rebroadcasting the kind 5 (09.md:33) | Deleted items return from another relay or cache; a later edit survives the deletion; someone else's kind 5 hides your event |
| Vanish | everything up to `created_at`, on tagged relays; no re-broadcast; kind 5 cannot undo (62.md:13-41) | Events newer than the boundary survive; re-publish is rejected |
| Expiration | relays MAY keep, SHOULD NOT serve; clients SHOULD ignore expired (40.md:41-48) | Expired items shown from cache |
| Protected events | relays reject `["-"]` by default; reposts MUST NOT embed (70.md:13-17) | Publish fails only on some relays |
| Comments (1111) | uppercase tags = root, lowercase = parent; `K` and `k` MUST be present (22.md:13-44) | Thread queries need both `#E`/`#A` and `#e`/`#a`; counts differ by which tag was queried |
| Reactions | `e` MUST; add `a` for addressable targets (25.md:23-27) | Likes on a 34236 counted by `#e` only vanish after an edit |
| Reposts | kind 6 is for kind 1; others are kind 16 with `k`; `e` carries a relay URL (18.md:15-37) | Reposts of videos invisible to clients that query kind 6 |
| Outbox | read an author from their write relays; mentions from read relays (65.md:27-34) | "Missing" content that lives on relays the client never asked |
| NIP-98 | `u` exactly equals the request URL including query; window ~60 s (98.md:42-43) | 401s from normalised URLs or device clock skew |
| Blossom auth | kind 24242; `created_at` MUST be in the past, `expiration` in the future, `t` verb MUST match; header is Base64url without padding (BUD-11 at `hzrd149/blossom` b5bd280), unlike NIP-98's standard base64 | 401 on a device whose clock runs fast; 401 only for tokens whose base64 happens to contain `+ / =` |
| NIP-46 | `remote-signer-pubkey` is not the user pubkey: call `get_public_key`; validate `secret` (46.md:9, 55-67) | Events signed or attributed to the wrong key; hijacked connect |
| NIP-46 session teardown | `logout` is a courtesy hint; the client MUST still delete its client-keypair (46.md:133-135). Client metadata is unauthenticated and for display only (46.md:115-123) | A stale signer session survives logout; a signer trusts client metadata for authorization |
| Signer readiness | repo rule, not a NIP: identity known ≠ signer ready | A publish attempted at `authenticated` fails once and is never retried |

Divine-specific contracts (relay policy, REST lag, vanish boundary, moderation
labels) are in divine-context (`NOSTR.md`, `ARCHITECTURE.md`, `repo-context/`),
Divine Brain, `docs/NOSTR_EVENT_TYPES.md`, `mobile/docs/NOSTR_VIDEO_EVENTS.md`
and the repo's `nostr-*` skills. Read the notes for the area before probing
production.

## 6. Make a protocol bug deterministic

- **Controlled relay.** `nak serve` (optionally `--auth`) seeded with a jsonl file gives a relay whose contents you chose. Use it to answer "what does the client do when the relay holds exactly this".
- **Fault injection.** `scripts/relay-fault-proxy.dart` (beside this file, `dart:io` only) sits between the client and a relay and misbehaves on demand:

  ```bash
  dart <skill dir>/scripts/relay-fault-proxy.dart --upstream ws://localhost:10547 --listen 47801 \
      --drop-ok 1 > <scratch>/proxy.jsonl </dev/null &      # then point the client at ws://localhost:47801
  ```

  To put the app behind it, start the local stack (`mise run local_up` from `mobile/`; for the iOS simulator export `BLOSSOM_PUBLIC_URL=http://localhost:43003` first, per `AGENTS.md`), use `--upstream ws://localhost:47777` (the stack's relay, `localRelayPort` in `mobile/lib/models/environment_config.dart`), run the app with `DEFAULT_ENV=LOCAL`, and add `ws://localhost:47801` in the app's relay settings. Not yet run with the app as the client: so far only `nak` and `websocat` have connected through it.

  | Flag | Reproduces |
  |---|---|
  | `--drop-ok N` | the relay stored the event and the client never heard: with `nak` as client the publish "failed" while a direct read returned the event |
  | `--close-req auth-required` | a refused REQ (`CLOSED`), for the first `--close-req-count` requests |
  | `--delay-eose-ms MS`, `--never-eose` | a slow relay, and a REQ that never terminates |
  | `--refuse-connects N` | the first N connections fail (HTTP 503), then recover |
  | `--delay-ms MS` | latency on every relay frame |

  It logs one JSON line per frame (direction, type, size, action, and the frame itself, untruncated so ids stay greppable), forwards the NIP-11 document, and exits by itself after `--max-seconds` (default 1800) so it cannot outlive the session. All of the above ran against `nak serve`; none of it, including the app wiring above, has been run against the app yet. A simulator reaches it on `localhost` with `DEFAULT_ENV=LOCAL`. A phone cannot reach the Mac's `localhost`, and the app drops a cleartext `ws://` relay on any other host (`normalizeRelayUrl` in `mobile/packages/nostr_client/lib/src/relay_manager.dart` checks `isLoopbackHost`), so a phone run silently loads zero relays. It needs `--bind-all`, the Mac's LAN address, and a scratch, never-committed patch that lets that check accept the LAN address: an ask-the-user item.
- **Test level.** A fake relay in a package test reproduces most ordering and refusal bugs in milliseconds. Reach for the device only when the claim involves lifecycle, sockets across backgrounding, or the UI.

## 7. Safety

- Production relays are public and permanent; a kind 5 is a request, not an eraser. Local or staging first. A production write needs the user's yes, a throwaway key, and content that reads as a test.
- Never read, print or log a secret key: not the user's, not a test account's, not `nak key default`. Never put one in a command line; use `NOSTR_SECRET_KEY` from the credential manager.
- Never put a pubkey beside an IP, location or email in any artifact. In public text state the property, not the value.
- Write identifiers whole, hex and npub.
