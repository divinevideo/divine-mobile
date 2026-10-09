# Sharing clips in direct messages

Phase one of co-creation from a conversation (#7992): people can send each
other raw clips from their clip library in a 1:1 DM, and the recipient can add
a received clip to their own library, for example to cut it into a video of
their own. Joint projects and co-authorship are later phases.

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

## The C2PA check

A Divine recording is C2PA-signed by ProofSign at capture, with a
`c2pa.created` action whose `digitalSourceType` is `digitalCapture` (see
[Limits](#limits) for the recordings that end up without one). Before a
received clip is added to the library, `ClipProvenanceVerifier` reads the
decrypted file's manifest and requires all of:

1. **A manifest signed by a trusted ProofSign signer.** The reader is given
   exactly the ProofSign trust anchors and nothing else (`trust_anchors`,
   plus `allowed_list` because the anchors are self-signed end-entity
   certificates). A manifest from any other signer is rejected even when it
   claims a camera capture.
2. **No validation failure.** The reader reports `validation_state: Trusted`
   and no failure code, so the video still matches the hash it was signed
   over.
3. **A camera capture.** The active manifest records `c2pa.created` with
   `digitalSourceType` `…/digitalCapture`.
4. **No other source type anywhere.** Every action in every manifest of the
   store that names a `digitalSourceType` names `digitalCapture`, so a
   generative (`trainedAlgorithmicMedia`, `compositeWithTrainedAlgorithmicMedia`,
   …) or composited ingredient fails the clip.

The check runs entirely on the device. The private clip is never sent
anywhere to be checked, and remote manifests and OCSP are never fetched.

The sender runs the same check before uploading, so a clip the recipient could
never add is not sent. That check is a convenience only: when it cannot run,
the clip is sent and the recipient's check still decides.

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

- the sender's pubkey as the clip's source credit, and
- a proof record naming the verified manifest (`proofManifestJson`).

The proof record matters. The editor's render step signs any clip without one
as a fresh `digitalCapture` by the person rendering, and would rewrite the
file in place. With the record present, the received clip keeps its original
credential in the library. That does not reach a post: posting re-renders the
video and signs the result as a fresh capture by the poster, so the sender's
credential is not carried into the published video. Carrying it through is
#9893.

The source credit is public once the clip is used. A video the recipient posts
with a received clip in it carries the credited account as a clip-source `p`
tag, so it is named and notified. For footage the sender recorded, that is the
sender, with no `a` tag, since there is no post to point to; anyone reading the
post can therefore tell the footage came from that account directly. The
sender is told about this in the attach menu.

A published Divine video is signed at publish as a fresh camera capture, so the
check cannot tell a forwarded post from a raw recording. Its file is the post's
exact file, though, so before importing, the clip's SHA-256 is looked up on
Divine's media server (`GET /<sha256>/provenance`, which names the account that
uploaded it). A match credits whoever published the post, linked to it with an
`a` tag the way a clip imported from a published video is, and not the person
who forwarded it. If the lookup cannot run, nothing is imported and the
recipient is asked to try again rather than credit the wrong person.

## Limits

- **Only untouched recordings carry a credential.** A clip that the editor
  flattened or merged has no manifest, so it cannot be sent as a clip. Keeping
  the camera proof through edits is #9893.
- **Not every recording is signed.** A recording whose signing failed at
  capture (for example offline), and every clip recorded in a build without
  the ProofSign token, such as a local debug build, has no manifest and fails
  the sender's check. Late-signing the app's own unaltered recordings is also
  part of #9893.
- **Android and iOS only.** Other platforms have no C2PA reader and keep the
  plain gallery attach and save.
