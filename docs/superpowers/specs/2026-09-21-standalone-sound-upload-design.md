# Standalone Sound Upload Design

Issue: #6743. Follows the reusable-sound rules in
`2026-07-31-saved-sound-library-metadata-design.md`.

## Summary

Let a creator publish a reusable sound from an audio file without first
making a video with it. The result is an ordinary Kind 1063 that the rest of
the app already understands: it carries the same public credit, the same
explicit `allow_audio_reuse` consent, and lands in the same discovery, sound
detail, feed attribution, and My Sounds surfaces as a sound published beside a
video.

## Problem

Today every Kind 1063 is a side effect of a video publish. `VideoAudioPublisher`
mints one for an imported file, a provider catalog sound, or the video's own
extracted audio, and always points it at the video with an `a` tag. A creator
who has a beat, a jingle, or a voice line they want others to remix has to
first ship a video that uses it. That is the wrong order for the person whose
sound it is, and it keeps "upload a sound for others" out of the product even
though every piece needed to render, credit, and reuse such a sound exists.

## Product decisions

### Entry point: Library → Sounds

The Sounds tab is the user's own sound library, so it gets an
"Upload a sound" row above the list, which opens the flow full-screen. The
editor's audio picker keeps its "Import audio" row: importing into a draft and
sharing a sound with everyone are different actions, and the picker's import
deliberately publishes nothing.

While the tab's search field has focus the action rows fold away
(`AnimatedSize`, instant under reduced motion): with the keyboard covering the
lower half of the screen they would leave almost no room for results. Tapping
outside the field, or dismissing the keyboard with Android's back button,
drops the focus and brings them back.

### One full-screen flow, no dialogs

`/sounds/upload` is a page under the Library's `/sounds` route, so back returns
to the tab. The page has three parts:

1. **Pick a file** — through `file_selector` with one shared audio type group
   (`audio/*`, `public.audio` on iOS, `aac`/`m4a`/`mp3`/`wav` for desktop
   pickers), copied into library-owned storage by the existing
   `LocalAudioImportService`, with a play/pause preview. On Android the
   picker opens on the device's audio library (`EXTRA_INITIAL_URI` to the
   MediaStore audio root) rather than "Recent", which under an audio filter is
   usually empty. `file_picker` is gone: its 10.x Android implementation
   dropped the filter to `*/*` for any unmapped extension (`weba`) and sent
   `EXTRA_MIME_TYPES` as a `String` for `FileType.audio`, which the system
   picker reads as "accept everything" — both opened the picker on images.
   The editor's "Import audio" row had the same bug and shares the fix.
2. **Public credit** — the same editor the video publish screen shows when
   remixing is enabled: sound title, creator, "I made this sound", source URL
   when it is not the user's own work, public hashtags, and a "Shared as"
   preview. The editor is extracted into a shared widget so both surfaces
   render one form.
3. **Share** — one button. The page says plainly that anyone on Divine will be
   able to use the sound; there is no remix toggle because a standalone upload
   exists to be reused. Credit-only publication stays where it is needed, on
   provider audio whose license forbids derivatives.

### Attribution defaults

The credit editor opens with "I made this sound" on and the creator prefilled
with the publisher's display name, because that is the case this flow exists
for. Turning it off clears the creator pubkey and requires a source URL, the
same rule the video path applies. The title starts as the file name without
its extension.

Flipping ownership also moves the `p` tag: on, the publisher is the credited
creator, so the feed row reads "By <name>"; off, the credited creator has no
pubkey and the row reads "By <name> · Shared by <publisher>". The video path
leaves a stale publisher pubkey behind on that flip; the cubit here owns the
rule instead of the form.

### The published event

A standalone sound is a Kind 1063 with NIP-94 file tags (`url`, `m`, `x`,
`size`), Divine's `duration`, `title`, the credit tags (`creator`, `p`,
`creator_url`, `source`, `license`, `license_url`, `t`),
`allow_audio_reuse=true`, and the readable credit in `content`. It has **no
`a` tag** — there is no source video. Nothing consuming Kind 1063 requires
one: `AudioEvent` parses `a` as optional, `SoundDetailScreen` omits the source
card when there is no source video, the feed attribution row resolves the
sound by id and credits `creator`/`p`, and `SoundsRepository` lists every Kind
1063 it sees. The relay validates videos (`d`, `title`, source, thumbnail) and
comments, not audio, so the event is accepted as-is.

Consent verification stays explicit: `allow_audio_reuse=true` on the event is
the same evidence the legacy resolver looks for on a source video, so a
standalone sound is reusable without any video lookup.

### After publishing

The published sound is saved to My Sounds through the app-scoped
`SavedSoundsBloc`, which also runs the waveform probe and mirrors the record to
the user's other devices. The page reports that the sound is live and returns to
the tab, where the new card is already listed. Publishing blocks back
navigation until it settles, so the save cannot be skipped by leaving early.

### Deleting a shared sound

A sound the user published can be taken back. On the Sounds tab, the trash
action on one of the user's own Kind 1063 records (their pubkey, a real event
id) asks whether to delete it for everyone or only remove it from this
library; every other saved sound keeps the plain "Remove" prompt. Deleting
publishes a NIP-09 kind 5 tagged `e` <sound id> and `k` 1063 — no `a` tag,
since a sound is not addressable — through the same `ContentDeletionService`
path videos use: one accepting relay is success, partial acceptance is
reported, and a deletion no relay took leaves the record in place for a
retry. After a relay takes it, the record leaves the library (mirrored to the
user's other devices) and the community sounds cache drops it, so the picker
stops listing it in the same session. Videos that already use the sound keep
their audio; it is rendered into them, and their attribution row falls back
to the unresolved-sound credit once the event is gone.

## Component boundaries

- `LocalAudioEventPublisher` (`lib/services/`) uploads a device-local file to
  Blossom and publishes it as a signed Kind 1063. It takes an optional
  source-video coordinate; `VideoAudioPublisher`'s imported-file path delegates
  to it with the video's coordinate, and the upload flow calls it without one.
  It returns a sealed result so the caller can name the failed step.
- `SoundUploadCubit` (`lib/blocs/sound_upload/`) owns the picked file, the
  attribution, and the publish lifecycle, and emits status enums only.
- `PublicAudioCreditEditor` (`lib/widgets/audio/`) is the credit form,
  extracted from `VideoMetadataAudioSharingSection`, driven by a value and an
  `onChanged` callback.
- `SoundUploadScreen` (`lib/screens/sound_upload/`) is a Page/View split: the
  page wires Riverpod services into the cubit; the view renders state and
  bridges the published sound into `SavedSoundsBloc`.
- `ContentDeletionService.deleteSound` shares the kind 5 publish path with
  `deleteContent`; `SavedSoundsBloc.deletePublishedSound` orders the relay
  tombstone before the local removal and evicts the sound from
  `SoundsRepository`'s cache through a callback the composition root wires.

## Failure behavior

- Unsupported or unreadable file: the picker's own copy, nothing is published.
- Upload, signing, or relay failure: an error snackbar; the page stays put with
  the user's input so they can retry.
- Account restriction from the relay: surfaced as its own message, since
  retrying cannot help.
- A save-to-library failure after a successful publish is reported as the
  existing "Couldn't save that sound" message; the sound is already on the
  relay and stays discoverable.

## Testing

- `LocalAudioEventPublisher`: tags carry no `a` tag without a coordinate and
  the coordinate with one; every failure step maps to its result.
- `SoundUploadCubit`: import populates a default own-work attribution;
  ownership flips move the creator pubkey; publish transitions and failures.
- `PublicAudioCreditEditor`: edits reach `onChanged`; the source field shows
  only when ownership is off.
- `SoundUploadScreen`: picker → credit → share → saved to My Sounds and popped;
  failures stay on the page.
- `SoundsTab`: the upload row navigates to `/sounds/upload`; an own published
  sound offers delete-for-everyone, remove-only, or cancel, and a rejected
  deletion keeps the card.
- `ContentDeletionService.deleteSound` / `SavedSoundsBloc.deletePublishedSound`:
  tag shape, ownership refusal, relay-outcome mapping, and local removal only
  after acceptance.
- Router: `/sounds/upload` resolves.
- `VideoAudioPublisher`'s imported-sound tests keep passing unchanged.
