# Sharing clips in direct messages

Co-creation from a conversation (#7992): people can send each other clips from
their clip library in a 1:1 DM, and the recipient can add a received clip to
their own library, edit it, send it on, or post it. A clip keeps the proof that
it was shot with the Divine camera through every edit (#9893), and everyone who
recorded or edited it along the way is credited. Joint projects are a later
phase.

## What travels

A clip goes out through the existing encrypted video pipeline
(`DmVideoSendService`): the file is AES-GCM encrypted, the ciphertext is
uploaded to Blossom, and a NIP-17 kind 15 file message carries the key.
Nothing about the transport is new.

The only addition is one rumor tag, written by `DmClipTag`:

```json
["divine-clip", "square"]
```

- It marks the message as a raw clip rather than a finished video, so the
  recipient's app labels the card as a clip. **Add to clips** is offered on
  every received encrypted video, tagged or not, since the C2PA check alone
  decides admission.
- Its value is the clip's target aspect ratio (`square` or `vertical`). A
  recording keeps the camera's full frame and the crop is applied later, so
  the file alone does not say which crop the clip was recorded for. An
  unknown value falls back to deriving the crop from the file.
- The tag is sender-asserted and is only a display hint. It never decides
  whether a clip may enter the library.

Other NIP-17 clients ignore the unknown tag and show an ordinary video.

## How a clip is signed

Every signing step embeds the signed-in account's creator binding
(`video.divine.nostr.creator_binding`, a Nostr signature over the hash of the
file as it was before signing) in the manifest it writes, so a clip's history
names who recorded and who edited it. Identities that cannot sign a canonical payload (NIP-46 and NIP-55 signers)
sign without one.

- **Recording.** A Divine recording is C2PA-signed by ProofSign at capture,
  with a `c2pa.created` action whose `digitalSourceType` is `digitalCapture`.
- **Edits.** Saving a clip to the library from the editor, merging clips, and
  posting a video all sign the output as what it is: an edit of the media it
  was made from, never a fresh capture. One video makes it an edit
  (`c2pa.opened` with the source as `parentOf`, plus `c2pa.edited`); several
  make it a composite (`c2pa.created`, every video a `componentOf`). Its source
  type is `compositeCapture` when every history it embeds, images and sounds
  included, names nothing but captures, and plain `composite` otherwise. Each
  source's own manifest is embedded with it.
- **Editor intermediates.** Reversing, transforming, keying, freezing a frame
  and filling a placeholder render new files without a manifest. The clip
  remembers what they were made from (`DivineVideoClip.derivedFrom`) and keeps
  those files, so the next signing step names the original footage instead.
- **Other media.** A chroma-key backdrop, a placeholder photo and the sound
  tracks are listed as `componentOf` ingredients: with their own manifest when
  they have one, as a plain declaration when they do not.
- **No fabricated provenance.** Every video source must carry a manifest. When
  one does not, such as a gallery import or stop-motion stills, the output is
  left without a C2PA manifest rather than signed with part of its history. The
  editor does not offer to retry signing then, since a retry cannot change it.
- **Recordings signed late.** A recording whose capture signing failed, for
  example offline, keeps the hash the camera wrote
  (`DivineVideoClip.recordingSha256`), and every clip edited from it carries
  that hash in its sources (`C2paEditSource.recordingSha256`). It is signed as
  a capture the next time it is sent or used in an edit, but only while the
  file still matches that hash; nothing else is ever signed as a capture after
  the fact. While such a recording is still unsigned, an edit of it is left
  unsigned too, and the editor offers to retry signing.

  A clip does not always carry the hash itself. The capture proof can come
  back after the take was saved to the clip library, so the library entry is
  given the hash then (`ClipLibraryService.rememberRecordingHash`), and later
  saves of the entry from an older copy keep it. An edit made before the proof
  came back names its sources without it, and so do a recording used as a
  chroma-key backdrop and the footage under a key. Signing therefore also
  looks the hash up by file name in the account's clip library
  (`ClipLibraryService.recordingHashesByFileName`), which covers all of them.

## The C2PA check

Before a received clip is added to the library, `ClipProvenanceVerifier` reads
the decrypted file's manifest and requires all of:

1. **A manifest signed by a trusted ProofSign signer.** The reader is given
   exactly the ProofSign trust anchors and nothing else (`trust_anchors`,
   plus `allowed_list` because the anchors are self-signed end-entity
   certificates). A manifest from any other signer is rejected even when it
   claims a camera capture.
2. **No validation failure.** The reader reports `validation_state: Trusted`
   and no failure code, so the video still matches the hash it was signed
   over.
3. **A history that ends in camera captures.** The active manifest is a
   capture, an edit of exactly one video, or a composite of videos. Following
   every video ingredient, each must carry its own manifest, signed by a
   trusted ProofSign signer and valid when it was edited, and lead the same
   way to `c2pa.created` / `digitalCapture` recordings. The reader reports an
   ingredient's signer only where it differs from what was recorded when the
   ingredient was added, and the app records every ingredient as untrusted
   because it signs without trust anchors, so a trusted ingredient is one the
   reader reports as `signingCredential.trusted`. A video ingredient without a
   manifest or that trusted signer, one recorded with a failure, an `inputTo`
   ingredient, a cycle or a chain deeper than 16 steps fails the clip. A
   recording used twice in one history, such as on its own and through an
   edit of it, is fine. Images and sounds may be declared without a manifest.
4. **No other source type anywhere.** Every action in every manifest of the
   store that names a `digitalSourceType` names `digitalCapture` or
   `compositeCapture`, so a generative (`trainedAlgorithmicMedia`,
   `compositeWithTrainedAlgorithmicMedia`, …) ingredient fails the clip.

The check also returns the accounts whose creator bindings in that history
verify, which is how the credits below reach every hop.

A verified binding proves that its account signed a file hash, not that the
hash belongs to this clip. The hash is of the file before it was signed, so it
cannot be recomputed from the signed file, and nothing else ties the binding to
the manifest it sits in. A credit is therefore a claim made by the app that
signed that step, and it is only as strong as the ProofSign signature around
it. Binding credits to their manifest is tracked in #9981.

The check runs entirely on the device. The private clip is never sent
anywhere to be checked, and remote manifests and OCSP are never fetched.

The sender runs the same check before uploading, so a clip the recipient could
never add is not sent, after first signing any of their own recordings left
unsigned. That check is a convenience only: when it cannot run, the clip is
sent and the recipient's check still decides.

### Trust anchors

`C2paTrustAnchorService` fetches Divine's canonical bundle from
`https://proofsign.divine.video/.well-known/c2pa-trust-anchors.pem`, the same
one the server-side verifier (Inquisitor) reads. It is not derived from the
build's signing endpoint: production builds sign through a ProofSign
deployment that publishes no bundle of its own, and a clip has to verify the
same way whichever build recorded it. The anchors rotate, so they are fetched
rather than built into the app:

| Age of the cached bundle | Behaviour |
|---|---|
| under 1 hour | used without a request |
| 1 hour to 7 days | refetched; the cached bundle is the offline fallback |
| over 7 days | refetched; no fallback, the check reports it cannot run |

A clip that fails as untrusted against a cached bundle is checked once more
against a freshly fetched one, so a key rotation within the hour does not
reject genuine clips.

The bundle must contain an anchor for the chain that actually signs
recordings: either the signer certificates themselves or a CA above them
(the ProofSign intermediate or root CA). A bundle that lists only a different
signer makes every genuine clip fail as untrusted — the check fails closed,
so nothing unverified gets in, but nothing verified does either.

### Outcomes

| Result | What the recipient sees |
|---|---|
| verified | the clip is added to their library |
| no credentials, untrusted signer, invalid, not a camera capture | "We couldn't confirm this was shot with the Divine camera…" — nothing is saved |
| check could not run (offline without anchors), or it could not be told whether the file is a published post | "Couldn't check this clip right now…" — try again later |

On the sending side, every picked clip is checked before the first upload. If
one fails a check that ran, none of them is sent, and the sender sees "We
couldn't confirm this clip was shot with the Divine camera, so it can't be
sent as a clip." Clips then go out one after another and keep going if the
sender leaves the chat; the outcome is reported wherever they are. If a later
upload fails, the ones before it are already sent and the sender sees how many
went out ("Sent 2 of 3").

The attach menu tells the sender, before they pick anything, that the
recipient can add what they send to their clips and post it, and that they
will be credited. That applies to gallery videos too, since "Add to clips" is
offered on every received video and only the check decides.

C2PA reading exists on Android and iOS only, so clip sharing is offered on
those platforms; elsewhere the attach button still sends a gallery video.

## In the library

`VideoClipImportService.importReceivedClip` copies the decrypted file into the
documents directory, like any other library clip, and stores:

- the sender's pubkey as the clip's first source credit, followed by every
  other account the verified history names except the recipient's own, and
- a proof record naming the verified manifest (`proofManifestJson`).

The file keeps the sender's manifest, so an edit of the clip, and the post it
ends up in, is signed with the whole history as an ingredient.

Saving the same message again returns the clip already in the library, and
restores it when it is in the trash.

The source credit is public once the clip is used. A video the recipient posts
with a received clip in it carries the credited account as a clip-source `p`
tag, so it is named and notified. For footage the sender recorded, that is the
sender, with no `a` tag, since there is no post to point to; anyone reading the
post can therefore tell the footage came from that account directly. The
sender is told about this in the attach menu.

A forwarded post passes the check like any edit, but its signed history does
not say it was published. Its file is the post's exact file, though, so before
importing, the clip's SHA-256 is looked up on
Divine's media server (`GET /<sha256>/provenance`, which names the account that
uploaded it). A match credits whoever published the post, linked to it with an
`a` tag the way a clip imported from a published video is, and not the person
who forwarded it. If the lookup cannot run, nothing is imported and the
recipient is asked to try again rather than credit the wrong person.

## Back from the gallery

Saving a clip to the gallery, from the clip library or from a received video's
save button, writes the clip's exact file, so the copy keeps its manifest. The
clips tab's **Add clips from your gallery** action brings such copies back:
it opens the system picker with multiple selection, and every picked video
goes through the same C2PA check before
`VideoClipImportService.importGalleryClip` adds it. A gallery is therefore no
way around the check: a video from another app, a screen recording or a
re-encoded download stays out exactly like an unverified DM clip.

The first time, a sheet explains that only clips shot with the Divine camera
come back and that each is verified with C2PA first; it is shown again until
the user confirms it. After the pick, `GalleryClipImportPage` lists every
picked video with its preview frame. Each row keeps a spinner while it waits
or is checked, then shows a check mark when the clip is in the library, a
prohibition sign when its credential does not prove a Divine capture, or a
warning when the check could not run. A video whose footage is already in the
library gets a muted check mark and "Already in your clips".

- **The pickers hand over the original bytes.** Android's photo picker streams
  the file into the app cache unchanged, and iOS's PHPicker is asked for the
  current representation, so it does not transcode. Only MP4 and QuickTime
  files are given to the C2PA reader. The picker's temporary copies are
  deleted once each video is handled; the library keeps its own copy.
- **Credits come from the file alone**, since nobody sent it. A file that is a
  post already published on Divine credits whoever published it, linked with
  an `a` tag, after the same media-server lookup as a received clip. Otherwise
  every account the verified history names is credited except the one whose
  library it goes into, so an own recording comes back without a credit and an
  edit of a friend's clip still credits the friend. The publisher credit
  follows the same rule, so an own post comes back without a credit too. The
  same rule now applies to received clips: nobody is credited as the source of
  their own footage.
- **Footage the library already holds is not added twice.** A clip outside
  the trash whose proof record names the same C2PA manifest, such as the
  recording the copy was saved from, a received clip or an earlier import,
  makes the row read "Already in your clips". A manifest's label is unique to
  the signing that wrote it, so the same label means the same signed footage.
- **The id comes from the account and the file's SHA-256**
  (`gallery_clip_<owner pubkey>_<sha256>`). Clips share one table across the
  accounts on a device, so a second account importing the same file gets its
  own clip. An earlier import of the same file that is in this library's trash
  is restored rather than copied again; saving over a trashed row would leave
  it in the trash. Neither import restores another account's trashed clip.
- **The import outlives its page.** `GalleryClipImportCubit` belongs to the
  library, not the page, so leaving the page keeps the check running, each
  clip that passes shows up in the grid as it is added, and the import action
  reopens the page while the import is still running.

The action is offered on Android and iOS only, and not in the library picker
the editor and the DM composer open, which only adds clips already in the
library.

## Limits

- **Edits need to reach ProofSign.** A library save or merge made offline is
  stored without a manifest and cannot be sent as a clip. It remembers what it
  was made from, so a later edit of it is signed against those sources.
- **Builds without a signing token sign nothing.** Every clip recorded or
  edited in a build without the ProofSign token, such as a local debug build,
  has no manifest and fails the sender's check.
- **Stop-motion has no camera proof.** Its stills are not signed at capture,
  so a video containing stop-motion footage is posted without a C2PA manifest.
- **Android and iOS only.** Other platforms have no C2PA reader and keep the
  plain gallery attach and save.
- **A gallery copy proves nothing once it changes.** Trimming or editing it in
  the Photos or Gallery app, or exporting it through another app, rewrites the
  file, and it fails the check like any other altered video.
