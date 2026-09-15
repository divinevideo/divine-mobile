# Confirm deletion without waiting for relay indexing

Tracking: https://github.com/divinevideo/divine-moderation-service/issues/226

Relay acceptance precedes database visibility. The app already has the signed kind-5 event when it asks the moderation service to enforce deletion. Send that event directly so cleanup does not depend on a read after publication.

## Wire contract

POST `/api/delete/{event_id}` optionally carries JSON `{"event": <raw signed Nostr kind-5 event>}`. Sign the exact serialized body using the NIP-98 `payload` SHA-256 tag. The service bounds the body to 64 KiB, verifies the payload hash, event signature, event ID, kind, e tags, and matching authenticated author. Keep target ownership and blob authorization in the existing processor. Invalid provided bodies fail closed; empty-body legacy requests retain the relay lookup fallback.

## Work

1. Service: add regression tests for a valid supplied event while the relay lookup is unavailable; reject forged/mismatched/malformed/oversized bodies and missing or incorrect payload hashes; retain legacy tests. Implement bounded parsing and validated direct processing. Run relevant tests, lint, and full suite.
2. Mobile: carry the signed deletion event from publication through cleanup; encode it once and bind NIP-98 to exactly the posted bytes. Test publication-to-cleanup handoff and request body/signing, preserving legacy callers and GET polling.
3. Independently review both diffs and cross-service contract. Fix findings, run checks, commit, publish separate PRs and request normal plus platform review for the auth changes.

## Rollout and validation

Deploy the reviewed service first, then release the app. Older services ignore the optional body and older apps retain lookup behavior. Verify the new app no longer incurs kind-5 lookup/backoff and monitor cleanup outcome and latency; target lookup and blob deletion can still take time. Do not claim production recovery before deployment and measurement. Existing monitoring PRs remain independent.
