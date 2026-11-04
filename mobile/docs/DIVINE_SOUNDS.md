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
| `title` | Display title | Not "Original sound" or "Original sound - …": without a `source` credit, either marks an unnamed video sound, which New and For You leave out and search lists last until another account uses it |
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

## Open decisions

- **Signing account.** HQ is configured. A dedicated sound account keeps HQ's own posts apart; changing it is one line in `official_accounts.dart` and needs a release, like the other official sets.
- **Tag schema.** `divine_sound` and the use of `music`/`sfx` should be confirmed before the first publish. The app also reads the effect synonyms above.
- **The shipped set.** Once the library is published, the app can ship a small starter set and load the rest from the network.
