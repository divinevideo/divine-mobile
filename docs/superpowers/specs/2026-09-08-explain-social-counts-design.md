# Explain social counts in Creator Analytics (#8276) — design

**Problem.** Creator Analytics shows follower/following totals but never explains
how they are calculated. The totals deliberately exclude blocked accounts and can
differ from other Nostr clients (indexing differences), which surprises creators.

## Approved design (bounded)

1. **Info affordance.** Extend the screen-local `_AnalyticsCard` with an optional
   `info: ({VoidCallback onPressed, String label})?`. When present, the card title
   renders as a row with a trailing `DivineIconButton(DivineIconName.info)` carrying
   `semanticLabel`/`tooltip` (keyboard + screen-reader accessible). Wired only on the
   Audience Snapshot card. Mirrors the existing `MetadataSection` label+info idiom.

2. **Explanation surface.** New `SocialCountsInfoSheet`, opened via
   `VineBottomSheet.show<void>` (the standard non-video sheet), built like
   `MetadataVerificationInfoSheet`: a title plus two headed sections, using
   `VineTheme` fonts and `vineColors` adaptive tokens. Two paragraphs are too much
   for a tooltip.

3. **Copy** (verbatim from the issue), new `app_en.arb` keys, English now and added
   to the `_knownUntranslatedDebt` allowlist per repo convention:
   - `analyticsSocialCountsInfoLabel` — affordance a11y label / tooltip
   - `analyticsSocialCountsInfoTitle` — sheet title
   - `analyticsFollowerCountsHeading` / `analyticsFollowerCountsBody`
   - `analyticsBlockingHeading` / `analyticsBlockingBody`

4. **Tests (TDD).** Widget tests: tapping the affordance opens the sheet and renders
   both copy blocks; the affordance exposes its accessibility label.

## Deferred (with Matt's sign-off)

**AC #4 — link to the public FAQ.** The FAQ is `divine-web#690`, which has not
shipped (no live anchor). The link is deferred as an explicit follow-up gated on
#690 (also assigned to Matt; to be done next), rather than ship a dead link.

## Files

`mobile/lib/screens/creator_analytics_screen.dart` (extend `_AnalyticsCard` + wire
the Audience Snapshot card), new `mobile/lib/screens/creator_analytics/social_counts_info_sheet.dart`,
`mobile/lib/l10n/app_en.arb` + generated, `mobile/test/l10n/arb_consistency_test.dart`
(debt entry), `mobile/test/screens/creator_analytics_screen_test.dart` (or a dedicated
sheet test).
