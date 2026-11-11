# Named, reusable audio for classic Vines

Approved in the task conversation on 2026-11-11. This is the execution record
for that approved design; the conversation is the full specification.

## Required behavior

- Publish separate, named Kind 1063 audio records and attach them to existing
  and newly imported classic videos. Preserve compatible AAC in M4A; otherwise
  encode AAC. Preserve timing and original video bytes.
- Curated names override original titles/captions, with creator-based fallback.
  Maintain aliases in the server-side catalog; no naming editor or transcription.
- Reuse durable queue/outbox/storage confirmation. Retries reuse media and signed
  events. Preserve logical coordinates, historical dates, full event payloads,
  links, engagement, old saved sounds, and exact archive provenance.
- Respect current suppression and claimed-account signing restrictions; report
  missing, silent, unauthorized, and unverified sources.
- Use the existing first-screen sound chip and sound-detail add-to-library flow.
  Expose named synthetic originals while eligible classics await backfill.
- Make cold sound searches find titles, captions, creators and curated aliases.
  Preserve description through parsing and persistence; indexing words must not
  appear as synthetic public hashtags.
- Preserve action-time permission checks at saving, selection and publication.
- Verify the complete save/select/record/publish flow, interruption/retry,
  migration compatibility, suppression, rollout-off, network failure, provenance
  expiry, account switching and claimed accounts.
- Deliver reviewed PRs in owning repositories. Verify operational safeguards,
  run a 20-classic canary, activate through infrastructure GitOps, verify all API
  replicas, and expand resumable batches to all eligible classics. Retain the
  kill switch for new reuse; do not remove existing remixes.

## Implementation tasks

1. App: named original-sound chip, consistent titles, description persistence,
   cold full-text sound search and regression coverage.
2. Publisher: catalog, audio extraction/publication, durable backfill/import
   integration, provenance updates and compatibility receipts.
3. Backend compatibility and production configuration: verify/implement old-ID
   resolution and engagement preservation; prepare and validate activation.
4. Independent review, required checks, publication and production canary/backfill.

## Global constraints

Use existing Nostr kinds/tags; never modify content-addressed originals. Keep
creator/source identity exact and secrets out of artifacts. Existing source
policy remains authoritative. No recorder shortcut or naming editor. Test
behavior changes before implementation. Work in isolated branches from
origin/main; obtain independent review and honor actual GitHub approval gates.
