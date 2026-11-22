# Publish approved Android releases to GitHub and Zapstore

## Intent

Complete the automated release train's Android distribution handoff. Rabble
selected publication after Google Play approves the same build, and clarified
that GitHub publication is a prerequisite for Zapstore distribution.

## Behavior

The existing coordinator observes actual published Google Play production
availability, mapped to the exact build number, marketing version, source and
completed provenance. A submitted, draft, rejected, internal-only or unknown
release does not qualify. CI must have succeeded for the source.

Scheduled Android builds currently skip direct-download APKs. Produce and
retain those APKs during the original candidate build, before store approval,
using that candidate's allocated identity and existing signing configuration.
For a qualifying release, publish the original signed Android APKs and
source-bound release notes as a stable GitHub release, then use the existing
Codemagic Zapstore signer to publish that exact GitHub release. The GitHub
version, source and asset hashes must verify before Zapstore runs. Record and
reconcile both steps so interrupted runs cannot start a second native build or
silently publish another version.

Keep original artifacts immutable. Retain the APK hashes alongside the existing
Android artifact identity. Missing or conflicting source, notes, artifacts,
digests, tag targets or provider observations fail closed. Existing releases are
never overwritten. Do not invent missing historical artifact evidence. A safe
retry reuses the original files and verifies any already-completed publication.

The notes describe Android changes and actual availability; they must not claim
that iOS or macOS shipped. Reuse the validated English notes retained for the
exact Android source instead of making release-time model requests or reading
notes from a newer checkout.

## Approach

Reuse the coordinator, private operational ledger, current GitHub publisher and
existing Codemagic Zapstore signing workflow. The coordinator selects the
approved identity; publication takes explicit identity inputs rather than
assuming the current pubspec version. Signing material remains in Codemagic.

Publishing stable GitHub releases independently of Play was considered;
Rabble selected waiting for Play approval. Enabling GitHub publication on every
native build would only create beta entries and would still leave stable
promotion and Zapstore manual, so it does not solve this request.

## Scope and verification

No native rebuilds, store resubmissions, changes to release cadence or automatic
beta publication are part of this change. Preserve existing store rejection
holds and other worktrees. Reuse existing credentials; do not expose key
material or widen access.

Regression tests cover published versus pending/rejected Play state, exact
identity matching, immutable APKs, retained notes, interrupted dispatch and
publication, GitHub verification before signing, and dry runs. Run the relevant
publisher/coordinator tests, CI configuration suite and required checks; obtain
an independent review. A live publication requires the normal merged workflow
and verified approved candidate, never a branch or direct native-build bypass.

The implementer owns routine module boundaries, journal schema and test fixtures.
If safe publication of an older build lacks retained APK evidence, report that
specific candidate's limitation instead of rebuilding it or fabricating proof.
