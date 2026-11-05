# Badge Guide For `divine-web`

This document describes the current badge behavior in `divine-mobile`.

Use this as the implementation guide for `divine-web`. The goal is to match the mobile app's badge decisions, not to infer behavior from screenshots.

## Source Of Truth

The current mobile implementation lives here:

- `lib/widgets/proofmode_badge.dart`
- `lib/widgets/video_feed_item/metadata/metadata_badges_row.dart`
- `lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart`
- `lib/widgets/video_feed_item/metadata/metadata_verification_section.dart`
- `lib/utils/proofmode_helpers.dart`
- `lib/extensions/video_event_extensions.dart`
- `packages/models/lib/src/video_event.dart`
- `lib/services/moderation_label_service.dart`
- `lib/services/video_moderation_status_service.dart`

## Important High-Level Rules

1. The UI effectively shows one primary status badge per video.
2. An archive Vine the server verifies (`verified_archive`) wins over all proof badges. While a row says the server could not check its archive, a `platform: vine` tag stands in (see `Original`).
3. A low AI score can promote an otherwise proofless video to `Human Made`.
4. A high AI score can show `Possibly AI-Generated`, but only when the video is not already proof-backed.
5. Plain proofless Divine-hosted videos do not get a visible badge anymore.
6. Never classify archive Vine content from loop count alone.

## Badge Types

### 1. `Human Made`

Rendered by `ProofModeBadge`.

It has four visual tiers, but the visible text is always `Human Made`:

- `platinum`
  - Trigger: `verified_mobile` proof plus AI score `< 0.5`
  - Meaning: strongest case, device proof plus AI scan agrees it looks human-made
- `verifiedMobile`
  - Trigger: `proofModeVerificationLevel == 'verified_mobile'`
  - Meaning: device attestation / hardware-backed proof
- `verifiedWeb`
  - Trigger A: `proofModeVerificationLevel == 'verified_web'`
  - Trigger B: no proof tags, but AI score `< 0.5`
  - Meaning: web crypto proof, or scan-only likely-human result
- `basicProof`
  - Trigger: `proofModeVerificationLevel == 'basic_proof'`
  - Meaning: basic proof metadata present

### 2. `Original`

Trigger:

- `video.countsAsArchiveVine == true`: the REST `verified_archive` field is `true`, or the row says the server could not check its archive and the event carries `platform: vine`.
- A row could not be checked when `verified_archive` is `false` and `archive_provenance_available` is not `true`. Funnelcake answers `false` for every row while its archive snapshot is missing or expired, so that `false` is not a real answer.
- Relay-delivered events carry neither field, so they count as not verified, not as unknown.

Meaning:

- an archive Vine the server has matched to its verified archive record

Important:

- A `platform: vine` tag on its own is not a trigger, except on a row the server could not check
- A verified archive Vine shows neither `Human Made` nor `Not Divine Hosted`, even when it also has proof tags
- Mobile's badge row (`MetadataBadgesRow`) renders no separate `Original` chip; the status shows as that suppression

### 3. `Not Divine Hosted`

Rendered by `NotDivineBadge`.

Trigger:

- not hosted on `divine.video`
- no proof-backed badge
- not an archive Vine under `video.countsAsArchiveVine` (server-verified, or tagged while the server could not check)
- no low-score AI promotion
- no high-score AI warning

This is the fallback badge for proofless external content.

### 4. `Possibly AI-Generated`

Rendered by `PossiblyAIBadge`.

Trigger:

- AI result exists
- `aiScore >= 0.5`
- not an original Vine
- not already showing a proof-backed `Human Made` badge

Important:

- current mobile logic does not downgrade a proof-backed video to `Possibly AI-Generated`
- proof-backed videos keep the `Human Made` badge even if an AI score exists

## Proof Inputs

These fields come from `VideoEvent`:

- `proofModeVerificationLevel`
- `proofModeManifest`
- `proofModePgpFingerprint`
- `proofModeDeviceAttestation`
- `proofModeC2paManifestId`

Derived helpers:

- `video.hasProofMode`
- `video.isVerifiedMobile`
- `video.isVerifiedWeb`
- `video.hasBasicProof`
- `video.getVerificationLevel()`
- `video.shouldShowProofModeBadge`

## Original Vine Inputs

Original Vine detection comes from:

- `rawTags['platform'] == 'vine'`

This is deliberate. Mobile no longer trusts loop count or old timestamps by themselves.

Do not do this:

- "If `originalLoops > 0`, treat as Original Vine"
- "If old timestamp plus loops, treat as Original Vine"

Do this:

- require `platform: vine`

`platform: vine` is author-supplied, so it marks a classic for display only (feed membership, the comments archive notice, square clip imports). Badge and trust decisions read the REST `verified_archive` field (`video.isVerifiedArchive`) instead:

- The verified-only source preference and `Human Made` and `Not Divine Hosted` suppression use `video.countsAsArchiveVine`, which lets the tag stand in only while a row says the server could not check its archive.
- The OG Viner badge learns only from `verified_archive: true`.
- A received clip counts as an archived Vine only when a post naming the file is verified; when the server could not check, the import reports a lookup it could not make.

Relay-delivered events never carry either field.

There is also an original-date helper:

- `video.hasUnknownOriginalDate`

That means:

- `isOriginalVine == true`
- no usable `published_at` tag
- and missing/zero `created_at`, or `created_at` at/after Vine shutdown

Mobile uses `isOriginalVine` for the comments empty-state archive notice. It uses `hasUnknownOriginalDate` only to avoid displaying an import timestamp as the original Vine date.

## Hosting Inputs

Divine-hosted detection is:

- `video.videoUrl?.toLowerCase().contains('divine.video') == true`

This is what mobile uses for badge decisions.

Important:

- Divine hosting is still used in modal copy and AI fallback logic
- it is no longer a visible badge by itself

## AI Inputs

Mobile checks AI results in this order:

1. `ModerationLabelService.getAIDetectionResult(video.id)`
2. `ModerationLabelService.getAIDetectionByHash(resolvedSha256 ?? video.vineId)`
3. For Divine-hosted videos only: `videoModerationStatusProvider(resolvedSha256)`

Where `resolvedSha256` means:

- `normalize(video.sha256)` if present
- otherwise extract the 64-char hash from any Divine media URL path segment
  - this must work for:
    - `https://media.divine.video/{hash}.mp4`
    - `https://media.divine.video/{hash}/720p`
    - `https://media.divine.video/{hash}/hls/master.m3u8`

Notes:

- Kind `1985` labels are the first-class source when present
- Hash lookup is the fallback if event-ID lookup misses
- do not require the `sha256` field to be populated if the hash is recoverable from the media URL
- Divine-hosted videos get an extra fallback to the moderation-service check-result endpoint
- the badge row uses the raw `aiScore` threshold, not `VideoModerationStatus.aiGenerated`

Thresholds used by badge logic:

- `aiScore < 0.5` => likely human / eligible for `Human Made`
- `aiScore >= 0.5` => eligible for `Possibly AI-Generated`

Important:

- `VideoModerationStatus.aiGenerated` uses a different threshold internally in the moderation service model
- mobile badge rendering does not use that boolean for the badge row decision
- for web parity, use the raw score threshold above

## Exact Badge Decision Order

Use this order.

```text
1. Resolve AI result
   a. by event ID
   b. by hash
   c. if still null and Divine-hosted, by moderation status service

2. If archive Vine (`verified_archive`, or `platform: vine` on a row the server could not check):
   show Original
   stop

3. Compute base proof verification level

4. If proof-backed and verified_mobile and aiScore < 0.5:
   show Human Made (platinum)
   stop

5. If proof-backed:
   show Human Made (gold / silver / bronze based on verification level)
   stop

6. If no proof and aiScore < 0.5:
   show Human Made (silver)
   stop

7. If no proof and aiScore >= 0.5:
   show Possibly AI-Generated
   stop

8. If Divine-hosted:
   show no badge
   stop

9. Otherwise:
   show Not Divine Hosted
```

In code terms, current mobile behavior is implemented by these booleans:

- `video.shouldShowProofModeBadge`
- `hasAIScanBadge`
- `isPossiblyAI`
- `video.shouldShowNotDivineBadge`

## Metadata Sheet Behavior

Mobile no longer opens a badge-specific explanation modal. The info action,
video title, and video description open `MetadataExpandedSheet`.

The metadata sheet header renders non-interactive badge labels from
`MetadataBadgesRow` between the title and description.

`MetadataVerificationSection` appears later in the sheet only when
`video.hasProofMode == true`.

Proof checklist items:

- Device attestation
- PGP signature
- C2PA Content Credentials
- Proof manifest

Each item is shown as pass/fail based on whether the corresponding field exists.

## Current Edge Cases To Preserve

### Verified archive Vine beats proof

If a video has both:

- `verified_archive: true`
- proof tags

mobile still shows no `Human Made` badge. A video with proof tags and only a `platform: vine` tag shows `Human Made`, unless its row says the server could not check its archive.

### Low AI score promotes proofless videos

If a video has:

- no proof tags
- AI score `< 0.5`

mobile promotes it to `Human Made` instead of leaving it at:

- no visible badge
- or `Not Divine Hosted`

### High AI score only warns on proofless videos

If a video has:

- proof badge eligibility
- AI score `>= 0.5`

mobile does not replace the proof badge with `Possibly AI-Generated`.

### Loop count alone is not enough

Do not use:

- `originalLoops`
- timestamp
- `publishedAt`

as the primary archive badge trigger.

Only the server's `verified_archive` flag makes a video an Original Vine for badges. `platform: vine` alone does not, except on a row the server could not check.

## Recommended Web Pseudocode

```ts
function resolveBadge(video, aiResult) {
  // Only a REST row can be unchecked: a relay-delivered event carries neither
  // field and counts as not verified.
  const archiveUnchecked =
    video.fromRestApi === true &&
    video.verifiedArchive !== true &&
    video.archiveProvenanceAvailable !== true;
  if (
    video.verifiedArchive === true ||
    (archiveUnchecked && video.platform === "vine")
  ) {
    return { kind: "original_vine" };
  }

  const baseLevel = getVerificationLevel(video);
  const hasProof = hasProofMode(video);
  const isLikelyHuman = aiResult != null && aiResult.score < 0.5;
  const isPossiblyAI = aiResult != null && aiResult.score >= 0.5;
  const isDivineHosted = (video.videoUrl ?? "").toLowerCase().includes("divine.video");

  if (hasProof) {
    if (baseLevel === "verified_mobile" && isLikelyHuman) {
      return { kind: "human_made", tier: "platinum" };
    }
    return { kind: "human_made", tier: mapBaseLevelToTier(baseLevel) };
  }

  if (isLikelyHuman) {
    return { kind: "human_made", tier: "silver" };
  }

  if (isPossiblyAI) {
    return { kind: "possibly_ai_generated" };
  }

  if (isDivineHosted) {
    return null;
  }

  return { kind: "not_divine_hosted" };
}
```

## Related Non-Badge Archive Notice

This is not part of the badge row, but it is easy to confuse with badge logic.

In comments, mobile shows a `Classic Vine` archive notice when:

- `video.isOriginalVine == true`

That means:

- `platform: vine`

This is specific to the comments empty state and independent of whether the original publish date is known.

## Short Version

If the web agent only remembers five things, they should be these:

1. The server's `verified_archive` flag is the trusted Original Vine signal; `platform: vine` is display-only, and stands in only on a row whose `archive_provenance_available` is not `true`.
2. A verified archive Vine suppresses all other badge types.
3. Proof-backed videos show `Human Made`.
4. Proofless videos with AI score `< 0.5` also show `Human Made` in silver.
5. Proofless Divine-hosted videos have no visible badge unless AI or proof pushes them into a stronger trust state.
