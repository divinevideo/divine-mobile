# Divine's own sounds

Divine ships a library of sounds with the app (`assets/sounds/sounds_manifest.json`). This document describes how those sounds, and any Divine adds later, are published to the network, and what the app does with them. The app side is in place; nothing has been published yet.

## Why publish them

A video credits the sound it uses with an `['e', <sound event id>, <relay>, 'audio']` tag, and Funnelcake ranks the picker's Popular list by counting those references. A shipped sound has no event, so a video made with it references nothing: its reuse is never counted, it can never reach Popular, and when the poster allows reuse the app publishes the rendered audio as the poster's own "Original sound". Publishing each Divine sound once as a Kind 1063 event fixes all three, and lets the library grow beyond what fits in the app.

## What counts as a Divine sound

`AudioEvent.isDivine` (`lib/extensions/divine_sound_extensions.dart`) is true for:

- a sound the app ships (`isBundled`), and
- a Kind 1063 event signed by an account in `kDivineSoundPublisherPubkeys` (`lib/config/official_accounts.dart`) that carries no `a` tag.

The signer is the marker because nobody can forge it; a tag would not do, since anyone can set one. The `a` tag rule matters: such an account may also post videos, and the sound of one of those videos is an ordinary post, not part of the library. Divine HQ, the configured account, already has 26 such video sounds, all carrying `a` tags, and the app leaves them alone.

Divine sounds rank with the Divine boost in For You and in search, and show without the community mark.

## Event shape

One NIP-94 Kind 1063 event per sound:

| Tag | Value | Notes |
|---|---|---|
| `url` | Blossom URL of the audio | `media.divine.video`, like every other sound |
| `m` | MIME type | Must be one of `SoundsRepository.audioMimeTypes`. Prefer `audio/mpeg` or `audio/mp4`; iOS cannot play Ogg |
| `x` | SHA-256 of the file | |
| `size` | Bytes | |
| `duration` | Seconds | |
| `title` | Display title | Not "Original sound" or "Original sound - …": without a `source` credit, either marks an unnamed video sound, which the New list leaves out until another account uses it |
| `t` | Search tags, including `music` or `sfx` | `music` or `sfx` decides whether the sound shows under Music or Effects. Publish `sfx`; the app also reads `effect`, `soundeffect` and `soundeffects` as Effects (`SoundKind.effectTags`) |
| `allow_audio_reuse` | `true` | Required. A sound without a source video is reusable only on its own signed terms |
| `source`, `creator`, `license`, `license_url` | As the manifest has them | Credit for third-party recordings (Freesound and the like) |
| `image`, `blurhash` | Optional cover | Must be on Divine's media server (`media.divine.video`, `cdn.divine.video` or `blossom.divine.video`, see `SoundCover.isScreenedHost`), which screens every image; the app ignores a cover stored elsewhere. A `thumb` tag stands in for a missing `image`. Without either it shows a colour tile |
| `divine_sound` | Manifest id, for a sound the app ships | `AudioEvent.divineSoundTag`; ties the event to the shipped file |

No `a` tag: that is what marks a video's sound.

## How the app uses them

- `SoundsRepository.fetchDivineSounds` loads the configured accounts' standalone audio events.
- `linkDivineSounds` ties each event with a `divine_sound` tag to the shipped sound of that manifest id. The shipped sound keeps its local file, for instant and offline playback, and takes the event id as its `linkedEventId`. `attributionEventId` falls back to it, so posting references the event and the editor stops offering to republish the audio. When one id was published more than once, the newest event wins.
- Published Divine sounds the app does not ship appear in For You beside the shipped ones.
- Each Divine sound shows once in For You, also for a viewer who follows the sound account: the followed accounts' sounds leave Divine's own out.
- With nothing published, the app behaves exactly as before, so a release can ship before the events exist.

## Publishing

A one-off script, run by a maintainer who holds the account key. The key never goes into the app.

1. For each manifest entry, upload the asset to Blossom and note its URL, hash and size.
2. Build the event from the table above, with the entry's id as the `divine_sound` tag.
3. Sign it with the account in `kDivineSoundPublisherPubkeys` and publish it to `relay.divine.video` and the app's other default relays.
4. Check in the app that the sound plays and that a test video referencing it is counted. Use a staging environment, not production posts.

Publishing a sound again with the same `divine_sound` id replaces the link; the app takes the newest event.

## Rollout notes

- Older app versions show the published events in New and in search as ordinary community sounds, beside their shipped copies.
- Popular counts only videos posted by versions that reference the events.

## The imported library

Besides the curated sounds above, Divine publishes a library of freely licensed effects and music, thousands of sounds at once. It is signed by its own account, in `kSoundLibraryPublisherPubkeys` (`lib/config/official_accounts.dart`), not by a Divine sound account, so the bulk does not take the Divine boost:

- `AudioEvent.isLibrary` (`lib/extensions/divine_sound_extensions.dart`) marks it, by signer and without an `a` tag, as `isDivine` does.
- New and For you leave it out (`SoundsRepository.withoutLibrarySounds`); search and Popular keep it. It shows without the community mark.
- A library sound picked for the boost is published again by a Divine sound account.
- The set is empty until the account exists, and the app behaves as before.
- Funnelcake's search boost (`SEARCH_DIVINE_SOUND_PUBKEYS`) should not list the library account either.

### Sources

Only sources whose terms allow publishing the sounds as a library:

- CC0 effects from `lavenderdotpet/CC0-Public-Domain-Sounds`, only from packs whose own licence file names the original author: Kenney (`kenney_*`, `sci-fi-sounds`), Ben Burnes (`BB_*`, `bb - *`, `Micro Pack - *`), The Motion Monkey (`MMRetroArcadeSoundsPack1_0_5`) and Team Forbidden (`warfork-cc0`, without its trailer voice-overs). Folders without a licence file are left out. `tools/sound_import/cc0_packs.dart` lists the packs, their credits and kinds.
- Music by Kevin MacLeod from incompetech (`pieces.json`), CC BY 4.0. Its credit is the one incompetech asks for: the title, "Kevin MacLeod (incompetech.com)", "Licensed under Creative Commons: By Attribution 4.0 License" and the licence link.
- Not Freesound, Pixabay or the Sonniss bundles: their terms forbid this use.

The CC0 catalog tree and all audio/source URLs are pinned to the verified
revision `f2b6264f9ab89fabc266914c3654685d68c5a39b`, not upstream `main`.
Changing `cc0VerifiedCommit` requires checking the pack licence policy again;
new files on upstream `main` do not automatically inherit the verified terms.

### Event shape

As in the table above, with these values:

| Tag | Value |
|---|---|
| `m` | `audio/mp4` (AAC) |
| `source` | The track's incompetech page, or the file in the CC0 repository at the commit it was read from |
| `creator`, `creator_url` | The original author |
| `license`, `license_url` | `CC0 1.0` or `CC BY 4.0`, with the Creative Commons URL |
| `t` | `music` or `sfx`, then pack and folder words or incompetech's feel and instruments (at most five). Pure speech gets no kind tag |
| `i`, `k` | `isrc:<ISRC>` and `isrc` for incompetech music, in NIP-73's shape for external ids; ISRC is not in its table yet |
| `summary` | incompetech's description |
| `alt` | `Sound: <title>` |

`content` holds the readable credit, in English, and a line `Edited: …` naming what preparing changed (edge silence trimmed, loudness normalized), as CC BY 4.0 asks for an adapted file. The encoded file carries the title, artist and credit in its own metadata too.

### Importing

`tools/import_free_sounds.dart` runs the import in five steps, from `mobile/`. Each keeps its state in the work directory and resumes where it stopped:

```bash
dart run tools/import_free_sounds.dart catalog --work-dir <dir>
dart run tools/import_free_sounds.dart prepare --work-dir <dir> --limit 20
dart run tools/import_free_sounds.dart events --work-dir <dir> --blossom <server> --created-at <unix seconds>
dart run tools/import_free_sounds.dart upload --work-dir <dir> --blossom <server> --dry-run
dart run tools/import_free_sounds.dart publish --work-dir <dir> --relay <url> --expect-pubkey <hex> --dry-run
```

1. `catalog` reads the two listings; nothing is downloaded.
2. `prepare` downloads, one file every two seconds, and uses ffmpeg to trim edge silence (below -60 dBFS, keeping 50 ms before and 200 ms after the sound), bring the sound to -16 LUFS without lifting its true peak above -1.5 dBTP, and encode AAC (192 kbps for music, 128 kbps otherwise; mono stays mono). A silent file is rejected. It prepares 20 per run unless `--limit` or `--all` says otherwise: the full sources are about 12.5 GB from incompetech plus the CC0 packs, so a full run needs the maintainers' go and runs once.
3. `events` writes the unsigned events to `events.jsonl`. A Blossom URL is the server and the file's SHA-256, so the events can be built before the upload. `--created-at` is the newest timestamp: each subsequent unique output in catalog order is one second older. Duplicate outputs consume no timestamp. This allows `until`/`limit` relay pagination to reach the entire import. A base too small to keep every timestamp at or after the Unix epoch is rejected without replacing the events file. Choose a base in the past to keep the import out of the relays' newest pages, which older app versions show as New. Repeating with the same catalog, state and base produces the same events.
4. `upload` asks the server for each file and uploads the missing ones with a BUD-02 authorization signed by the key in `SOUND_IMPORT_UPLOAD_NSEC`. Divine's own media servers need `--confirm-production`. Staging builds use the production media server too, so trying the library on staging needs that go as well.
5. `publish` signs each event with the key in `SOUND_IMPORT_PUBLISHER_NSEC`, which must belong to `--expect-pubkey`, and sends the events the account has not published yet, found by their `x` tags. Each event is signed once and kept in `signed.json`, so every relay and every later run gets the same event.

Publication requires the event's full content-addressed URL to match a server
recorded in `uploadedTo` for that exact output SHA-256. An upload to another
server does not qualify. This check also applies in dry runs and to the actual
cached signed event, not just a regenerated unsigned event. A cached event
for another account or file stops publication before connecting to any relay;
use separate work directories for separate accounts. Regenerating unsigned
events does not rewrite previously cached signatures or change retry event IDs.

Keys come from the environment of the maintainer who runs the step and never go into the app, the repository or the work directory. `--dry-run` needs no key: `upload` only asks the server, `publish` only asks the relays.

## Open decisions

- **Signing account.** HQ is configured. A dedicated sound account keeps HQ's own posts apart; changing it is one line in `official_accounts.dart` and needs a release, like the other official sets. The imported library has its own account, decided 2026-11-04; its pubkey goes into `kSoundLibraryPublisherPubkeys` once it exists.
- **Browsing the library.** New and For you leave the library out, so it is reached through search and Popular. A picker list that shows it by kind, without a search, is not built yet.
- **Tag schema.** `divine_sound` and the use of `music`/`sfx` should be confirmed before the first publish. The app also reads the effect synonyms above.
- **The shipped set.** Once the library is published, the app can ship a small starter set and load the rest from the network.
