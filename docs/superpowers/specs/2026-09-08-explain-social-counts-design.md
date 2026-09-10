# Explain social counts in Creator Analytics (#8276) — design

**Problem.** Creator Analytics shows a follower total without defining what it
represents. The app needs a short explanation while leaving detailed questions
about blocking and count differences to the public FAQ.

## Approved design (bounded)

1. **Info affordance.** Extend the screen-local `_AnalyticsCard` with an optional
   `info: ({VoidCallback onPressed, String label})?`. When present, the card title
   renders as a row with a trailing `DivineIconButton(DivineIconName.info)` carrying
   `semanticLabel`/`tooltip` (keyboard + screen-reader accessible). Wired only on the
   Audience Snapshot card. Mirrors the existing `MetadataSection` label+info idiom.

2. **Explanation surface.** New `SocialCountsInfoSheet`, opened via
   `VineBottomSheet.show<void>` (the standard non-video sheet), built like
   `MetadataVerificationInfoSheet`: a title, one plain-language sentence, and an
   accessible link to the detailed FAQ, using `VineTheme` fonts and `vineColors`
   adaptive tokens.

3. **Copy**, using new `app_en.arb` keys, English now and added
   to the `_knownUntranslatedDebt` allowlist per repo convention:
   - `analyticsSocialCountsInfoLabel` — affordance a11y label / tooltip
   - `analyticsSocialCountsInfoTitle` — sheet title
   - `analyticsFollowerCountsBody` — the in-app definition
   - `analyticsSocialCountsLearnMore` — visible FAQ link text
   - `analyticsSocialCountsLearnMoreSemantics` — accessible FAQ link label

4. **Tests (TDD).** Widget tests: tapping the affordance opens the sheet and renders
   the localized definition; the affordance and FAQ link expose localized
   accessibility labels; the FAQ link has a 48 dp tap target and opens the stable
   deep link.

## Detailed FAQ follow-up

Blocking, unblocking, propagation delay, and cross-app count differences belong
in the public FAQ rather than this compact in-app surface. That content is tracked
in #9055. The app links to the stable `https://divine.video/faq#follower-counts`
anchor.

## Files

`mobile/lib/screens/creator_analytics_screen.dart` (extend `_AnalyticsCard` + wire
the Audience Snapshot card), new `mobile/lib/screens/creator_analytics/social_counts_info_sheet.dart`,
`mobile/lib/l10n/app_en.arb` + generated, `mobile/test/l10n/arb_consistency_test.dart`
(debt entry), `mobile/test/screens/creator_analytics_screen_test.dart` (or a dedicated
sheet test).
