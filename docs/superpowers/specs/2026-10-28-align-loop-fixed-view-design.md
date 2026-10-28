# Align loop: one fixed view

## Intent

A repaired single-clip loop should hold its static background in one framing while scene content keeps moving. A successful render and a better seam are insufficient if the view floats around.

## Chosen approach

The user selected automatic selection of the least-cropped fixed view. Keep the existing confident camera-path anchors. For each trusted anchor as a candidate reference, cancel the measured camera path into that same reference for the whole clip. Choose the candidate with the smallest coverage zoom. Use one constant zoom throughout.

The existing periodically smoothed target intentionally moves and fails this goal. Locking to the opening frame would preserve the opening composition but can require more crop; the user chose automatic selection instead.

## Constraints

- Keep the existing maximum zoom of 1.08, confidence thresholds, duration/frame-count/audio checks and seam improvement requirements.
- Keep rejecting a missing or unreliable required anchor; do not invent a trusted pose across a tracking gap.
- Preserve timestamps, source media, moving scene content, cancellation and operation-owned cleanup.
- Change the framing of single-clip repairs; preserve existing multi-clip boundary correction and already-smooth policy.
- Deterministic ties select the earliest trusted candidate.
- No new dependencies, UI controls, copy, protocol or storage changes.

## Acceptance

Generated camera-motion scenes must have constant corrected background framing at interior times as well as the seam. The selected reference must need no more crop than other trusted candidates. Coverage and confidence rejection remain enforced for landscape, portrait, translated and rotated scenes.

Run the real iPhone pipeline on the supplied footage, retaining output and local-only evidence. Check all frames for static-background drift, aiming for at most two pixels of measured residual travel at 1080 resolution. Verify the seam, full duration, frames and audio, and five full end-to-start playback wraps. The tracking measurement remains an estimate, not a substitute for inspecting the output.

The user's media and identifiers must stay outside commits and public artifacts.
