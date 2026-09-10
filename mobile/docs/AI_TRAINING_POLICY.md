# AI Training & Data Mining Policy

Status: Current

## Policy

Divine's publish pipeline always **attempts** to embed a cryptographically
signed **CAWG `training-mining` opt-out assertion** in each video's C2PA
metadata. When C2PA signing succeeds, the signal marks the content as
`notAllowed` for AI training, AI inference, generative-AI training, and
data mining.

**This is not a default — it is the only option.** Divine does not offer an
opt-in to AI training. Creators who want their content used for training
must export it and do that outside Divine.

Keeping the policy unconditional protects every Divine creator at once: if
some content carried the signal and other content did not by policy,
downstream scrapers could argue ambiguity. A single, consistent policy
removes that argument.

## Why we don't make this a setting

A user-facing toggle would weaken the signal for everyone, not just the
person who flipped it. Per-video opt-in also pushes a decision onto creators
that most never see — burying consent in settings is how other platforms
end up training on content their users believed was protected. Divine's
position is that the protection should be uniform and visible, not opt-in.

## What this is and isn't

This is a **cryptographically signed line in the sand**, in the same spirit
as `robots.txt` or `Do Not Track`:

- **It is** a machine-readable, signed declaration in every video file
  where C2PA signing succeeds, which scrapers, dataset builders, and AI
  vendors can read and respect.
- **It is not** a technical block. Bad actors who ignore the signal will
  scrape the content anyway. The value is in making the declaration
  unambiguous and verifiable, not in preventing the scrape.

We think the signed declaration is worth shipping even though it cannot
be enforced at the protocol layer — the same reasoning that justifies
`robots.txt` despite decades of bad actors ignoring it.

## Technical details

The assertion follows the
[CAWG Training and Data Mining specification v1.1](https://cawg.io/training-and-data-mining/1.1/).
Every manifest Divine successfully signs contains a `cawg.training-mining`
assertion with all four standard entries marked `notAllowed`:

| Entry                          | Value        |
|--------------------------------|--------------|
| `cawg.ai_training`             | `notAllowed` |
| `cawg.ai_inference`            | `notAllowed` |
| `cawg.ai_generative_training`  | `notAllowed` |
| `cawg.data_mining`             | `notAllowed` |

The C2PA manifest is signed during upload via the Divine signing service.
Signing remains best-effort today: if ProofMode is unavailable on the
current platform or C2PA signing fails, upload continues without the
embedded assertion. When signing succeeds, the signature ties the
assertion to the specific video bytes — modifying the video invalidates
the signature.

## Where this lives in the code

The assertion is built unconditionally by
`C2paIdentityManifestService.buildCreatedVideoManifest`
(`mobile/lib/services/c2pa_identity_manifest_service.dart`) and embedded
during signing by `C2paSigningService.signVideoInPlace`
(`mobile/lib/services/c2pa_signing_service.dart`).

It also appears in the `referenced_assertions` list of the Nostr
creator-binding assertion built in
`VideoPublishNotifier._createCreatorBindingAssertion`
(`mobile/lib/providers/video_publish_provider.dart`), so the
creator-binding signature explicitly covers the training-mining
declaration.

The unconditional behaviour is pinned by tests in:

- `mobile/test/services/c2pa_training_mining_assertion_test.dart`
- `mobile/test/services/c2pa_identity_manifest_service_test.dart`

## Scope

This policy covers Divine's unconditional attempt to embed C2PA metadata in
video files uploaded through Divine. Out of scope for this document:

- Re-signing or backfilling videos uploaded before this policy
  was made unconditional.
- Surfacing the assertion in the in-app metadata viewer.
- Coordinating with relays or other Nostr clients on honouring
  the assertion.
