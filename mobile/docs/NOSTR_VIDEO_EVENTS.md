# Nostr Video Events Schema

Status: Current
Validated against: current mobile implementation on 2026-08-14; Funnelcake-specific
Kind 22236 behavior is identified separately below.

This document describes the Nostr event schemas for video-related events as implemented in Divine.

## Event Kinds

| Kind | Type | Range | Description |
|------|------|-------|-------------|
| 34236 | Addressable short video | Parameterized replaceable | Primary video content (NIP-71) |
| 34235 | Addressable normal video | Parameterized replaceable | Horizontal/longer videos (NIP-71) |
| 22236 | Video view event | Ephemeral | Analytics for video views |

---

## Kind 34236 - Addressable Short Video

This is the primary video content kind used by Divine for short looping videos per NIP-71.

## Event Structure

```
Kind: 34236 (NIP-71 addressable short looping videos)
Content: Video description/caption (optional)
Tags: Array of [tagName, tagValue, ...additionalParams]
```

## Core NIP-71 Tags

### Video Content Tags

| Tag | Format | Description | Required |
|-----|--------|-------------|----------|
| `url` | `["url", "https://..."]` | Direct video URL | Recommended |
| `streaming` | `["streaming", "https://...m3u8", "hls"]` | HLS/DASH streaming URL | Optional |
| `imeta` | `["imeta", "url https://...", "m video/mp4", ...]` | NIP-92 inline metadata with multiple key-value pairs | Recommended |

### Media Metadata Tags

| Tag | Format | Description | Required |
|-----|--------|-------------|----------|
| `title` | `["title", "Video Title"]` | Video title | Recommended |
| `m` | `["m", "video/mp4"]` | MIME type (video/mp4, video/webm, etc.) | Recommended |
| `x` | `["x", "sha256hash"]` | SHA-256 hash of video file | Optional |
| `size` | `["size", "12345678"]` | File size in bytes | Optional |
| `dim` | `["dim", "1080x1920"]` | Video dimensions (width x height) | Optional |
| `duration` | `["duration", "6"]` | Duration in seconds | Recommended |
| `alt` | `["alt", "Description for accessibility"]` | Alt text for accessibility | Optional |

### Thumbnail Tags

| Tag | Format | Description | Required |
|-----|--------|-------------|----------|
| `thumb` | `["thumb", "https://...jpg"]` | Static thumbnail image URL | Recommended |
| `image` | `["image", "https://...jpg"]` | Alternative thumbnail tag | Optional |
| `preview` | `["preview", "https://...gif"]` | Animated GIF preview (not used as main thumbnail) | Optional |
| `blurhash` | `["blurhash", "LKO2?U%2Tw=w]~RBVZRi.AaxE1H"]` | Blurhash for progressive loading | Optional |

### Hashtags

| Tag | Format | Description | Required |
|-----|--------|-------------|----------|
| `t` | `["t", "funny"]` | Hashtag (without #) | Optional |

### Divine Collaborator Tags

Divine uses a project-specific collaborator marker on top of the standard `p`
tag shape for NIP-71 video events:

| Tag | Format | Description |
|-----|--------|-------------|
| `p` | `["p", "<pubkey>", "<relay>", "collaborator"]` | Marks a tagged pubkey as a collaborator rather than a generic mention. |

This role marker is a Divine convention, not a NIP-71 standardized field.
Publishing is centralized in `mobile/lib/utils/collaborator_tags.dart`, and
parsing is enforced in `mobile/packages/models/lib/src/video_event.dart` and
`mobile/packages/models/lib/src/video_stats.dart`.

### Divine Attribution Markers

Attribution reuses the same marker convention on `p` tags, and extends it to
`a` tags. All of these are Divine conventions rather than NIP-71 fields.

| Tag | Format | Description |
|-----|--------|-------------|
| `a` | `["a", "34236:<pubkey>:<d>", "<relay>", "mention"]` | The video the creator chose as their Inspired By source. Written at publish. |
| `a` | `["a", "34236:<pubkey>:<d>", "<relay>", "inspired-by"]` | The same reference, rewritten by the metadata edit flow. |
| `a` | `["a", "34236:<pubkey>:<d>", "<relay>", "clip-source"]` | A published video this one actually reuses footage from. One per distinct source. |
| `p` | `["p", "<pubkey>", "<relay>", "inspired-by"]` | Notifies the Inspired By creator (NIP-27: a mention without a `p` tag does not notify). |
| `p` | `["p", "<pubkey>", "<relay>", "clip-source"]` | Notifies the author of reused footage. |

`clip-source` is a factual claim about footage in the video; `mention` /
`inspired-by` is the creator's own attribution choice. They are emitted
independently even when they point at the same source video, so clearing manual
Inspired By attribution during metadata edit does not erase factual clip
provenance. Publishing lives in
`mobile/lib/utils/inspired_by_tags.dart` and
`mobile/lib/services/video_event_publisher.dart`; parsing in
`mobile/packages/models/lib/src/video_event.dart`.

### Event Metadata

| Tag | Format | Description | Required |
|-----|--------|-------------|----------|
| `d` | `["d", "unique-identifier"]` | Replaceable event identifier (required for kind 34236) | **Required** |
| `published_at` | `["published_at", "1234567890"]` | Publication timestamp | Optional |
| `h` | `["h", "group-id"]` | Group/community identifier | Optional |

## Divine-Specific Tags

### Original Vine Metrics (for imported vintage vines)

| Tag | Format | Description |
|-----|--------|-------------|
| `vine_id` | `["vine_id", "original-vine-id"]` | Original Vine platform ID |
| `loops` | `["loops", "1000000"]` | Original loop count from Vine |
| `likes` | `["likes", "50000"]` | Original like count from Vine |
| `comments` | `["comments", "1000"]` | Original comment count from Vine |
| `reposts` | `["reposts", "25000"]` | Original repost count from Vine |

## ProofMode Tags (Verification System)

### Verification Level

| Tag | Format | Description |
|-----|--------|-------------|
| `verification` | `["verification", "verified_mobile"]` | Verification tier: `verified_mobile`, `verified_web`, `basic_proof`, or `unverified` |

### ProofMode Metadata

| Tag | Format | Description |
|-----|--------|-------------|
| `proofmode` | `["proofmode", "{\"videoHash\":\"...\"}"]` | JSON-serialized `NativeProofData`, including optional creator-binding and verifier identity payloads |
| `device_attestation` | `["device_attestation", "ATTESTATION_TOKEN"]` | Device attestation token from secure hardware |
| `pgp_fingerprint` | `["pgp_fingerprint", "ABCD1234EFGH5678"]` | PGP public key fingerprint for signature verification |
| `c2pa_manifest_id` | `["c2pa_manifest_id", "<manifest-id>"]` | Active C2PA manifest identifier when available |

#### `device_attestation` payload (iOS)

On iOS the tag value is the App Attest payload verbatim:

```json
{
  "keyID": "<key identifier>",
  "attestationString": "<base64 attestation object>",
  "assertionString": "<base64 assertion>"
}
```

The payload is minted when the event is signed, not when the video is recorded.
The account a clip goes out under is not fixed until then — a clip can be
recorded, sit in the library, and be published from an account the user switched
to afterwards — so only the publish step knows which identity the attestation
should speak for.

**What the client signs.** The challenge is the proof hash and the event pubkey
joined by a colon, and Apple's client data hash is `SHA-256` over its UTF-8
bytes:

```
clientDataHash = SHA-256(UTF-8("<proofHash>:<pubkeyHex>"))
```

`proofHash` is the same string the `proofmode` tag carries as `videoHash`, and
`pubkeyHex` is the event's own `pubkey` — so a verifier reconstructs the
challenge from the event alone. Because the pubkey is inside it, the payload
cannot be lifted from one event and republished under a different pubkey
carrying the same media: the challenge no longer matches.

Legacy iOS payloads published before PR #6490 used
`SHA-256(UTF-8("<proofHash>"))` and minted a fresh key during proof generation.
Those payloads have no `assertionString` and are not bound to the event pubkey.
Verifiers that need to evaluate historical events must branch on publication
date or another release cutover signal instead of applying the publish-time
challenge above to every existing iOS event.

**Two branches.** Apple rate limits `generateKey` and `attestKey`, so the Secure
Enclave key is provisioned on an account's first publish and `keyID` plus
`attestationString` are replayed from cache afterwards:

- **`assertionString` present** — verify the assertion against *this* event's
  client data hash. The attestation still proves the key came from a genuine
  Apple device, but its embedded nonce binds the event that provisioned the key,
  not this one.
- **`assertionString` absent** — this is the provisioning event, so the
  attestation nonce binds the current client data hash and the plain nonce check
  applies.

**Assertion counter.** Apple's assertion verification requires checking the
counter in the assertion's `authenticatorData`: it increments per assertion of
that key and must be strictly greater than the highest value already seen for
that `keyID`. A verifier that skips this accepts replayed assertions.

**Linkability.** The key is scoped to the Nostr account, not the install: every
video published from one account carries the same `keyID` and
`attestationString`, and the counter above is a monotonic sequence over that
account's publishes. That correlates only videos the account already signed with
its own pubkey, so it exposes nothing the event does not already carry. It also
follows Apple's guidance against sharing one App Attest key among several users
of a device — switching accounts provisions a separate key rather than reusing
one across identities. Caches are wiped on uninstall and on a
`DCError.invalidKey` recovery (device restore, OS reset). Nothing consumes these
fields yet.

### Creator Identity Hints

These tags are discovery hints only. They do not replace the event pubkey as the
source of truth for authorship.

| Tag | Format | Description |
|-----|--------|-------------|
| `identity_binding` | `["identity_binding", "nostr_creator"]` | Signals that the media carries a user-signed Nostr creator-binding payload |
| `identity_verifier` | `["identity_verifier", "verifier.divine.video"]` | Signals which verifier issued the optional portable identity overlay |
| `identity_portable` | `["identity_portable", "cawg"]` | Signals that a CAWG-compatible identity overlay is present |

### Nostr-First Identity Layer

- Authorship remains anchored to the event pubkey and the user-signed creator
  binding embedded in the media proof payload.
- `verifier.divine.video` may attest only to external claims such as `nip05`,
  domain control, and later social-handle proofs.
- Portable CAWG identity is optional and additive. Publish remains valid when
  only the creator binding is present.

### Verification Levels Explained

- **verified_mobile**: Highest level - includes device attestation + manifest + PGP signature
- **verified_web**: Medium level - includes manifest + PGP signature (no hardware attestation)
- **basic_proof**: Low level - has some proof data but doesn't meet higher criteria
- **unverified**: No ProofMode data present

## NIP-92 imeta Tag Structure

The `imeta` tag provides inline metadata as key-value pairs:

```
["imeta",
  "url https://cdn.example.com/video.mp4",
  "m video/mp4",
  "x sha256hash",
  "size 12345678",
  "dim 1080x1920",
  "duration 6.5",
  "blurhash LKO2...",
  "thumb https://cdn.example.com/thumb.jpg"
]
```

## Tag Processing Order

Divine processes tags with the following priorities:

1. **Video URL**: Searches in order: `imeta` → `url` → `streaming` → `r` → content fallback
2. **Thumbnail**: Searches in order: `imeta.thumb` → `imeta.image` → `thumb` → `image` → generated fallback
3. **Metadata**: Direct tags override `imeta` values (first wins)

## URL Validation

Video URLs must match one of these patterns:
- `http://` or `https://`
- File extensions: `.mp4`, `.webm`, `.mov`, `.m4v`, `.avi`, `.mkv`, `.flv`, `.wmv`, `.m3u8`

## Fallback Behavior

### Missing Tags
- **No `d` tag**: Falls back to event ID
- **No `title`**: Uses empty string
- **No thumbnail**: Generates thumbnail URL via API service
- **No duration**: Displays as unknown

### Invalid URLs
- Automatically fixes `apt.openvine.co` → `api.openvine.co` typos
- Accepts URLs in any tag via Postel's Law (be liberal in what you accept)

## Storage

All tags are stored in `VideoEvent.rawTags` as a `Map<String, String>` for:
- ProofMode verification lookups
- Future extensibility
- Debug/analysis purposes

## Example Event

```json
{
  "kind": 34236,
  "content": "Check out this amazing sunset! 🌅 #nature #beautiful",
  "tags": [
    ["d", "sunset-video-2024"],
    ["title", "Beautiful Sunset Timelapse"],
    ["url", "https://cdn.divine.video/videos/sunset.mp4"],
    ["imeta",
      "url https://cdn.divine.video/videos/sunset.mp4",
      "m video/mp4",
      "dim 1080x1920",
      "duration 6",
      "thumb https://cdn.divine.video/thumbs/sunset.jpg",
      "blurhash LKO2?U%2Tw=w]~RBVZRi.AaxE1H"
    ],
    ["t", "nature"],
    ["t", "beautiful"],
    ["verification", "verified_mobile"],
    ["proofmode", "{\"videoHash\":\"abc123\",\"creatorBindingAssertionLabel\":\"video.divine.nostr.creator_binding\"}"],
    ["device_attestation", "ATTESTATION_TOKEN_HERE"],
    ["pgp_fingerprint", "ABCD1234EFGH5678"],
    ["identity_binding", "nostr_creator"],
    ["identity_verifier", "verifier.divine.video"],
    ["identity_portable", "cawg"]
  ]
}
```

---

## Kind 22236 - Ephemeral Video View Event

Kind 22236 is an **ephemeral event** for tracking video views for analytics purposes.

The schema below is the contract emitted by current Divine mobile. Two-phase
counting landed relay-side in
[divine-funnelcake#922](https://github.com/divinevideo/divine-funnelcake/pull/922).
Fractional `loops` from the client did not: #922 derives loops from the
`viewed` seconds itself and never reads the `loops` tag. The earlier proposal
to read it,
[divine-funnelcake#921](https://github.com/divinevideo/divine-funnelcake/pull/921),
was closed unmerged.

### Purpose

These events are published when a user views a video and are consumed by analytics services. As ephemeral events (20000-29999 range per NIP-01), relays keep them in memory only and do not persist them to disk.

The `.content` field is optional and could contain a free-form note.

### Event Range

- **Kind 22236** is in the ephemeral range (20000-29999)
- Relays will NOT store these events permanently
- Multiple events per user+video are expected (one per view session)
- Designed for analytics consumption, not user-facing history

### Tags

| Tag | Format | Description | Required |
|-----|--------|-------------|----------|
| `a` | `["a", "<kind>:<pubkey>:<d-tag>", "<relay-url>"]` | Addressable reference to kind 34235 or 34236 video event | **Required** |
| `e` | `["e", "<event-id>", "<relay-url>"]` | Event ID reference (specific version viewed) | **Required** |
| `phase` | `["phase", "start"\|"end"]` | Two-phase session marker: `start` counts the view, `end` carries watch time and loops. Absent = legacy single-shot event | Optional |
| `viewed` | `["viewed", "0", "<whole-seconds-watched>"]` | Elapsed whole playback seconds for this segment | **Required on `end` and legacy events; omitted on `start`** |
| `loops` | `["loops", "<playthrough-fraction>"]` | Exact finite, non-negative playthrough count emitted by mobile, including partial loops. Funnelcake does not read this tag — it derives loops from `viewed` — so it is informational for other consumers | Optional |
| `source` | `["source", "<source-type>"]` | Traffic source: `home`, `discovery`, `profile`, `share`, `search` | Optional |
| `client` | `["client", "<name>", "31990:<app-pubkey>:<d-identifier>", "<relay-url>"]` | NIP-89 client attribution for Divine | Optional |
| `version` | `["version", "<app-version>"]` | Shipped app version (`PackageInfo.version`, e.g. `1.0.23`), so a view-reporting regression attributes to a release. Kept separate from `client`, whose exact value keys Funnelcake's view-volume detector | Optional |

### Two-phase sessions

One viewing session publishes one `start` event at playback start and one or
more `end` events (on feed interruption, video change, or dispose), each
carrying only the watch/loop delta since the previous `end`. An end event
with no new playback emits nothing. An app kill mid-session still leaves the
`start` — and therefore the view — counted.

### Traffic Sources

| Source | Description |
|--------|-------------|
| `home` | Video viewed from home/following feed |
| `discovery` | Video viewed from explore/discovery feed |
| `profile` | Video viewed from a user's profile page |
| `share` | Video viewed via shared link |
| `search` | Video viewed from search results |

### Example Event

```json
{
  "id": "<32-bytes lowercase hex-encoded SHA-256 of the serialized event data>",
  "pubkey": "<32-bytes lowercase hex-encoded public key of the viewer>",
  "created_at": <Unix timestamp in seconds>,
  "kind": 22236,
  "content": "",
  "tags": [
    ["a", "34236:<video event author pubkey>:<d-identifier of video event>", "<relay url>"],
    ["e", "<event-id>", "<relay-url>"],
    ["viewed", "0", "5"],
    ["loops", "0.75"],
    ["source", "discovery"],
    ["version", "1.0.23"],
    ["client", "Divine", "31990:d95aa8fc0eff8e488952495b8064991d27fb96ed8652f12cdedc5a4e8b5ae540:divine-mobile", "wss://relay.divine.video"]
  ]
}
```

### Notes

- **No `d` tag** - ephemeral events are not addressable/replaceable
- **Both `a` and `e` tags are required** - `a` provides stable addressable reference, `e` tracks specific version viewed
- The `viewed` tag carries elapsed playback seconds for the session, not positions within the video. Mobile always emits `["viewed", "0", "<whole seconds watched>"]`, so a 6s video looped twice reports `["viewed", "0", "12"]`, and a sub-second view truncates to `["viewed", "0", "0"]`
- Analytics services should consume these events in real-time before relays discard them
- No minimum watch threshold: a playback start counts as a view even when the session ends before the first loop completes (a fractional loop is valid)
- Mobile emits one `start` per viewing session plus one `end` segment per
  interruption. A cover (comment sheet, route push, tab switch, backgrounding)
  flushes an `end` segment but keeps the session, so watch time after the cover
  lifts still belongs to it. Scrolling away ends the session, and scrolling back
  starts a new one that reports its own `start`.
- Funnelcake counts these phases as of divine-funnelcake#922: a `start` counts
  the view and contributes zero loops, each `end` contributes
  `viewed` seconds ÷ video duration as loops, and an event with no `phase` keeps
  the legacy single-shot behaviour (`viewed` floored at one second)
