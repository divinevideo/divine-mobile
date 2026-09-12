# Divine UI — Design System Components

Package: `packages/divine_ui`

## Theme

### VineTheme
Complete dark-mode design system providing:
- **Colors**: 30+ named color constants (brand greens, surfaces, text, accents, navigation, utility)
- **Typography**: Google Fonts — Bricolage Grotesque (display, headline, title) and Inter (body, label)
- **ThemeData**: Pre-configured `ThemeData` for the app

## Components

### Buttons

| Component | Description |
|-----------|-------------|
| `DivineButton` | Primary button component with multiple variants (primary, secondary, tertiary, ghost, ghostSecondary, link, error). Supports leading/trailing icons, loading state, and expanded width. |
| `DivineIconButton` | Icon-only button with primary/secondary/tertiary variants and small/base sizes. |
| `DivineFollowButton` | Follow badge for an author avatar: a 20dp disc centred in a 44dp tap target, with follow/selected variants and a 100ms cross-fade between them. |
| `DivineTextLink` | Inline text link for use within text flows. Provides both widget and `TextSpan` versions. |

**DivineButton Types:**
- `primary` — Green background, dark text (main actions)
- `secondary` — Dark background, green border, green text
- `tertiary` — White background, dark green text
- `ghost` — Semi-transparent dark background (65% black), white text
- `ghostSecondary` — Lighter scrim (15% black), white text
- `link` — No background, underlined text
- `error` — Red background, light text (destructive actions)

### Icons

| Component | Description |
|-----------|-------------|
| `DivineIcon` | SVG icon component using `DivineIconName` enum. Supports custom size and color. |
| `DivineIconName` | Enum with 170+ icon entries from Phosphor Icons (bold weight). Includes fill (`_fill`) and duotone (`_duo`) variants. |

### Checkboxes

| Component | Description |
|-----------|-------------|
| `DivineCheckbox` | Standalone checkbox with selected/unselected/indeterminate states. |
| `DivineRowCheckbox` | Checkbox with label, suitable for forms and settings. |

### Bottom Sheet

| Component | Description |
|-----------|-------------|
| `VineBottomSheet` | Base bottom sheet with drag handle and themed styling. Supports scrollable and fixed modes. |
| `VineBottomSheetActionMenu` | Action menu variant (list of tappable actions) |
| `VineBottomSheetDragHandle` | Reusable drag handle widget |
| `VineBottomSheetHeader` | Header with title/subtitle for bottom sheets |
| `VineBottomSheetSelectionMenu` | Selection menu variant (pick from options) |

**Removed:** `VineBottomSheetTileMenu` — an icon-and-label tile menu, never
exported from the package barrel and never called. Use
`VineBottomSheetActionMenu` for icon-and-label action lists, or
`VineBottomSheet.show<T>` with private tiles that pop a typed result
(`lib/screens/comments/widgets/comment_options_modal.dart` is the worked
example).

### Text Field

| Component | Description |
|-----------|-------------|
| `DivineAuthTextField` | Text input field for auth screens (sign-in/sign-up) |
| `DivineTextField` | **Deprecated** — delegates to `DivineAuthTextField` |

### Feedback

| Component | Description |
|-----------|-------------|
| `DivineSnackbarContainer` | Themed snackbar container |
| `DivineInfoCard` | Explanation callout — icon, optional title, body, optional footer. Four tones (`info`, `neutral`, `warning`, `error`) and a `compact` step. Replaces the per-screen "about this setting" boxes. |

**DivineInfoCard tones:**
- `info` — `accentPositive`, for explaining a feature or a concept (default). This is brand green in dark mode and a darker green in light mode.
- `neutral` — card surface with a muted outline, for detail that should recede
- `warning` — something to read before acting
- `error` — a risk or a failure

The tinted tones derive their surface from one accent colour (background 15%, border 30%), so tones stay consistent by construction. `compact: true` tightens padding, radius, icon, and type by one step, for a note beside a control rather than a section-level explanation. `icon: null` drops the glyph, for a section intro that reads as prose rather than as a callout to act on.

### Loading

| Component | Description |
|-----------|-------------|
| `PartialCircleSpinner` | Animated partial-circle loading indicator |

## Usage Examples

### DivineButton
```dart
// Primary button with icon
DivineButton(
  label: 'Continue with email',
  leadingIcon: DivineIconName.envelope,
  expanded: true,
  onPressed: () => doSomething(),
)

// Secondary button
DivineButton(
  label: 'Enter Nostr key',
  type: DivineButtonType.secondary,
  leadingIcon: DivineIconName.key,
  onPressed: () => importKey(),
)

// Button with loading state
DivineButton(
  label: 'Submit',
  isLoading: isSubmitting,
  onPressed: isSubmitting ? null : handleSubmit,
)
```

### DivineIconButton
```dart
// Back button
DivineIconButton(
  icon: DivineIconName.caretLeft,
  type: DivineIconButtonType.secondary,
  size: DivineIconButtonSize.small,
  onPressed: () => context.pop(),
)
```

### DivineFollowButton
```dart
// Follow badge on an author avatar. The caller flips the variant and the
// badge cross-fades to it; a badge without onPressed is inert.
DivineFollowButton(
  variant: isFollowing
      ? DivineFollowButtonVariant.selected
      : DivineFollowButtonVariant.follow,
  onPressed: isFollowing ? null : () => bloc.add(FollowRequested(pubkey)),
  semanticLabel: isFollowing
      ? context.l10n.profileFollowingLabel
      : context.l10n.videoFollowButtonFollow,
)
```

### DivineTextLink
```dart
// Inline text link
Text.rich(
  TextSpan(
    children: [
      TextSpan(text: 'Have an account? '),
      DivineTextLink.span(
        text: 'Sign in',
        onTap: () => navigateToLogin(),
      ),
    ],
  ),
)
```

### DivineCheckbox
```dart
DivineRowCheckbox(
  state: isChecked
      ? DivineCheckboxState.selected
      : DivineCheckboxState.unselected,
  onChanged: (value) => setState(() => isChecked = value),
  label: Text('I agree to the terms'),
)
```

## Accessibility & Visual Contract

`divine_ui` is the canonical accessibility + visual contract for the core
reusable controls. App-layer reviewers can point at the package tests instead
of re-checking these guarantees per screen.

### Guaranteed accessibility (enforced by `meetsGuideline` / semantics tests)

| Component | Guarantee |
|-----------|-----------|
| `DivineButton` | `base` (48px) and `small` (40px visible / 48dp tap target) meet the 48dp Android / 44pt iOS tap-target minimum — `small` keeps pressed ink clipped to the 40px chip while its pre-existing 4px outer halo is tappable. `tiny` (32px) deliberately keeps a 32px tap target (it sits flush next to 32px avatars / type icons; expanding it would bleed into that neighbor's hit area) — tracked as a known gap in #6235 pending design input. Optional `semanticLabel` for icon-only buttons (a disabled labelled button announces `enabled: false`). Error-button label/icon contrast against the red background is tracked as a known gap in #6235 pending design sign-off on the tone. |
| `DivineIconButton` | Tap target ≥ 48dp (small pill centred in a 48px InkWell). Pass `semanticLabel` (or `tooltip`) for an accessible name. |
| `DivineRowCheckbox` | Exposes a checkbox semantics node with checked / mixed / enabled state. A `disabled` checkbox is non-interactive (no tap, no `onChanged`). |
| `DivineSlider` | Optional `semanticLabel` describing what it controls. Touch-target height is unchanged (32px) — growing it shifts adjacent widgets in real screens (storage settings, video editor sheets); tracked as a known gap in #6235 pending Figma-fit confirmation. |
| `DivineAuthTextField` | Password toggle and the editable field both meet the 48dp / 44pt tap-target minimum. The editable field fills the 76px control, while animated content padding places the input text row at 26px when centered and 36px below a floating label. |
| `DiVineAppBarActions` / `DivineAppBarIconButton` | Actions meet the 48dp / 44pt tap-target minimum, and a `semanticLabel` on `DiVineAppBarAction` reaches the rendered button. Pass `semanticLabel` **or** `tooltip` for an accessible name — either satisfies the guideline, neither is enforced, and an action with neither renders as an unnamed button. `DivineAppBarIconButton` also takes `semanticIdentifier` as an E2E anchor; `DiVineAppBarAction` has no field for one, so actions cannot carry an identifier today. |
| `DiVineAppBar` leading slot | `expandLeadingHitArea: true` stretches the tap target across the whole leading slot and publishes exactly one node — the labelled button. The stretching `GestureDetector` is excluded from semantics because it declares the same tap action as the `Semantics` above it, and two configs declaring one action cannot merge, which previously left an anonymous button nested inside the labelled one. |
| `VineBottomSheet` | The `onComplete` header's close (X) and check buttons carry accessible names via `closeSemanticLabel` / `completeSemanticLabel` (English defaults `Close` / `Done`; `divine_ui` carries no localizations, so callers pass a translated string). The check button's loading spinner keeps the same name. Both are 48dp. The tap-outside scrim and the sheet's tap-swallowing detector are excluded from semantics — the route's `ModalBarrier` is the one dismiss node a screen reader sees. |
| `VineBottomSheetActionMenu` | Tiles meet the 48dp / 44pt tap-target minimum in both appearances. A disabled tile reports `isEnabled: false`, which is what makes its dimmed label legitimate — WCAG exempts inactive components and `MinimumTextContrastGuideline` honours that, so the dimming is not a contrast defect. **Known gap:** an `isDestructive` tile is 3.68:1 in light (`VineTheme.error` on the light sheet surface), below the 4.5:1 minimum — pending a design call on the tone (#6235). It passes in dark. |
| `DivineSnackbarContainer` | Action, secondary action, and dismiss button all meet the 48dp / 44pt tap-target minimum (the action's `minimumSize` is 72×48), and every tappable node carries a name — `dismissSemanticLabel` defaults to `Dismiss`. Label and action text meet 4.5:1 in both appearances, in default and `error` variants. That guarantee covers the theme's own surfaces only — a caller-supplied `backgroundColor` picks its ink from the app palette rather than from the custom surface, so a saturated or mid-dark override can land well under 4.5:1. Reach for it only for a banner whose colour *is* the message, and check the pair. `liveRegion` is deliberately **not** set on the container: every call site renders it as a Material `SnackBar`'s `content`, and `SnackBar` already sets one; a nested second live region would double-announce. |

**Icon-only interactive controls need an accessible name.** Enforcing this at
every call site (and labelling the app's unlabeled `DivineIconButton`
usages) is tracked as a fast-follow; the components already accept the label.

### Visual (golden) coverage

Component gallery goldens for `divine_ui` are tracked as a fast-follow
(**#6235**): alchemist obscured-text goldens are non-deterministic under the
package's `very_good test --optimization` merged isolate (google_fonts loads
asynchronously, so the block-text metrics vary), and would need a CI-side
generation workflow. Behaviour and accessibility are already covered by the
widget + `meetsGuideline` tests above.
