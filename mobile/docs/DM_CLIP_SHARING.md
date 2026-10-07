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

Every Divine recording is C2PA-signed by ProofSign at capture, with a
`c2pa.created` action whose `digitalSourceType` is `digitalCapture`. Before a
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
| check could not run (offline without anchors) | "Couldn't check this clip right now…" — try again later |

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
credential.
