# Profile badge display modes

**Status:** Proposed. Builds on the floating badge animation in the same
branch (`feat/floating-profile-badges`); per the no-stacked-PRs rule it
ships in that PR rather than a follow-up.

## Goal

Let a profile owner choose how their accepted NIP-58 badges appear on their
profile:

- **Floating animation** — what this branch already ships: chips drift up
  through the banner, behind the avatar, name and username.
- **Badge stack** — a compact, tappable row of overlapping circular badge
  images under the username, opening a lightbox with every badge.

The choice lives in **Edit Profile → Badges → Display badges as**.

## Behaviour

### Edit Profile

- A new **Badges** section in `ProfileSetupScreenView`, using the existing
  `ProfileSelectRow` (`lib/screens/profile_setup/widgets/profile_setup_rows.dart`).
- One row, **Display badges as**, showing the current value. Tapping opens a
  picker with the two options. Saving publishes with the rest of the profile.

### Badge stack

- Up to **5** circular badge images, each **30×30**, partially overlapping
  left to right.
- Each image has a **40×40** tap target. Overlapping targets are fine: the
  whole stack is one action.
- The 5 shown are the **most recently awarded**, newest first.
- When there are more than 5, a sixth circle at the end shows the remainder,
  e.g. **+6** for 11 badges.
- Tapping **anywhere** in the stack opens the badges lightbox.

### Badges lightbox

- Modelled on the avatar lightbox (`_showAvatarLightbox` /
  `_AvatarLightbox` in `profile_header_media.dart`): a non-opaque
  `PageRouteBuilder` on the root navigator, blurred backdrop over
  `VineTheme.scrim65`, fade transition, close button top-left, tap outside to
  dismiss.
- Title: **"{name}'s awarded badges"** (see open question 4).
- Below it, every accepted badge laid out the way hashtags are in the video
  metadata sheet (`MetadataTagsSection`) and search results
  (`SearchTagChip`): a `Wrap` of chips, `spacing: 8`, 48dp tap targets with
  the 8px visible row gap.
- Each chip is the badge image plus name, reusing `_ProfileBadgeImage`.
- Tapping a badge opens the existing badge details sheet
  (`_showProfileBadgeSheet` → `_ProfileBadgeDetailsSheet`), unchanged.

### Accessibility fallback

Today, under Reduce Motion or a screen reader, the floating mode falls back
to a static chip row under the username. With the badge stack available,
**that fallback becomes the badge stack**, and the static chip row is
deleted. One accessible layout instead of two; the stack plus lightbox reach
every badge.

## Data and storage

### Where the setting lives (open question 1)

**Recommended: owner-level, published in the profile (Kind 0).** Edit Profile
edits what everyone sees, so a viewer's device should render the owner's
choice.

- New Divine custom Kind 0 key, alongside `divine_monetization_links`
  (`packages/models/lib/src/monetization_link.dart`):
  `divine_badge_display`, value `floating` or `stack`.
- Absent or unknown value → the default (open question 2).
- Other clients ignore unknown keys, so this does not affect them.
- **Read:** a getter on `UserProfile` over `rawData`, next to
  `enabledMonetizationLinks` (`packages/models/lib/src/user_profile.dart`).
- **Write:** through `ProfileRepository`'s publish path, which already
  re-seeds from the freshest relay Kind 0 to preserve custom keys and writes
  `divineMonetizationLinksKey` explicitly
  (`packages/profile_repository/lib/src/profile_repository.dart`, around the
  `newContent` map). Add a `badgeDisplay` parameter the same way.
- **Edit state:** `ProfileEditorBloc` (`lib/blocs/profile_editor/`) gains the
  field, an event to change it, and passes it on save.

The alternative is a viewer-level device preference: no protocol change,
but the owner's choice would be meaningless to anyone else.

### Badge ordering

"Most recently awarded" sorts by the award event's `createdAt`, newest first.
Badges whose award event could not be loaded (`award == null`) go last, in
their profile-badges list order.

The sort is domain logic, so it belongs in `badge_repository`, not the
widget. Either add an `awardedAt` getter on `ProfileBadgeViewData` and a
pure sort helper there, or have `loadAcceptedBadgesForProfile` return them
sorted.

`badge_repository` is a strict 100%-coverage package, so the helper ships
with tests in the same change.

## UI structure

| Piece | Where | Notes |
|---|---|---|
| `ProfileBadgeDisplay` enum (`floating`, `stack`) | `packages/models` | Parsed from `divine_badge_display` |
| `ProfileFloatingBadgesLayer` | existing, banner layer | Renders only in `floating` mode, and only when motion is allowed |
| `_ProfileBadgeStack` | header identity, under the username | Replaces `_ProfileBadgesBlock` / `_ProfileBadgesRow` |
| `_ProfileBadgesLightbox` + `_showProfileBadgesLightbox` | header library | Same route shape as the avatar lightbox |
| `_ProfileBadgeLightboxChip` | header library | Image + name, 48dp target |
| Badges section in Edit Profile | `lib/screens/profile_setup/` | `ProfileSelectRow` + picker |

The header decides the mode from the displayed profile. Reading it is a pure
property of the profile, so no new cubit is needed for the header itself.

## Localization

New `app_en.arb` keys, each read through `context.l10n` in the same change:

- `profileSetupBadgesSectionTitle` — "Badges"
- `profileSetupBadgeDisplayLabel` — "Display badges as"
- `profileBadgeDisplayFloating` — "Floating animation"
- `profileBadgeDisplayStack` — "Badge stack"
- `profileBadgesLightboxTitle(name)` — "{name}'s awarded badges"
- `profileBadgeStackMoreCount(count)` — "+{count}"
- `profileBadgeStackSemanticLabel(count)` — "{count} badges. Opens all badges."
- `profileBadgesLightboxCloseSemanticLabel` — "Close badges"

Mirror into every `app_*.arb` locale or add to `_knownUntranslatedDebt`; run
`test/l10n/arb_consistency_test.dart`.

## Tests

- **models:** `divine_badge_display` parsing: `floating`, `stack`, absent,
  unknown.
- **profile_repository:** saving with each value writes the key; saving
  without it preserves an existing value.
- **badge_repository:** award-date ordering, `award == null` last, ties
  stable.
- **Header widget:**
  - Stack shows at most 5 circles plus `+N`.
  - Tapping anywhere opens the lightbox.
  - Floating mode with Reduce Motion shows the stack.
  - Floating mode shows no stack.
- **Lightbox:** title uses the display name; all badges render; tapping one
  opens the details sheet.
- **Edit Profile:** the row shows the current value; picking one dispatches
  the event; save passes it to the repository.

## Steps

1. Model and storage: enum, `UserProfile` getter, repository write,
   `ProfileEditorBloc` field. Tests.
2. Ordering helper in `badge_repository`. Tests.
3. Badge stack under the username, replacing the static chip row; becomes the
   Reduce Motion / screen reader fallback. Tests.
4. Badges lightbox and chips; wire badge taps to the existing details sheet.
   Tests.
5. Edit Profile Badges section and picker. Tests.
6. l10n keys across locales.
7. Simulator pass on both modes, own and other profile, dark and light, large
   text, VoiceOver.

## Open questions

1. **Owner-level or viewer-level setting?** Recommended owner-level (above).
2. **Default when unset:** floating animation or badge stack?
3. **Stack placement:** directly under the username where the static row was,
   or elsewhere?
4. **Lightbox title copy:** "{name}'s awarded badges", "Badges awarded to
   {name}", or the literal "{username} awarded badges"? The last reads as if
   the user gave the badges.
5. **Overflow circle:** is "+6" the count of hidden badges (11 total → +6),
   as assumed here?
6. **Own profile with no badges:** show nothing, or an entry point to the
   badges dashboard?
