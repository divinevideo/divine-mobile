# VineBottomSheet Refactor Plan

## Goal

Consolidate the four bottom sheets currently used on the home screen and
profile onto a single, enhanced `VineBottomSheet` component. The result
should combine:

- The **structure and design-system consistency** of the sheets that already
  use `VineBottomSheet` (Profile More menu, Metadata / More button).
- The **advanced draggable behaviour** present in the custom sheets today
  (Comments: snap points, root-navigator placement, keyboard-aware initial
  size; Metadata: headerless scroll body).
- A **correctly working tap-outside-to-dismiss** for the draggable variant,
  which neither Comments nor Metadata currently have.

After the refactor, Comments and Metadata both flow through
`VineBottomSheet.show` with no parallel `showModalBottomSheet` +
`DraggableScrollableSheet` scaffolding.

Share is intentionally **out of scope**: it builds its own `Material` +
custom header and does not fit the `VineBottomSheet` structure. It can be
revisited separately.

---

## Current state summary

| Sheet | Entry point | Component in use | Dismissible on outside tap |
|---|---|---|---|
| Profile More (app bar) | `VineBottomSheet.show(scrollable: false, ...)` | `VineBottomSheet` | Yes (fixed mode, no `DraggableScrollableSheet`) |
| Metadata / More (home) | `showVideoPausingVineBottomSheet(buildScrollBody: ...)` → `VineBottomSheet.show(scrollable: true, ...)` | `VineBottomSheet` | No (wrapped in `DraggableScrollableSheet(expand: true)`) |
| Comments (home) | Raw `showModalBottomSheet` + own `DraggableScrollableSheet` with `VineBottomSheet` as the inner widget | Partial (widget, not `.show`) | No (same reason as Metadata, plus custom scaffolding) |
| Share (home) | `showVideoPausingVineBottomSheet(builder: ...)` → raw `showModalBottomSheet` with custom `Material` | Not used | Out of scope |

### Why tap-outside-to-dismiss fails for draggable sheets today

`VineBottomSheet.show(scrollable: true)` wraps content in
`DraggableScrollableSheet` with its default `expand: true`. That makes the
sheet's hit area cover the entire modal, so the scrim above the sheet
receives no pointer events, and `showModalBottomSheet`'s default
barrier-tap-to-dismiss never fires.

Profile works because `scrollable: false` skips `DraggableScrollableSheet`
entirely; the modal's normal scrim remains tappable.

---

## Gaps to close in `VineBottomSheet`

Add these parameters to `VineBottomSheet.show` (and forward where relevant
into the underlying `showModalBottomSheet` / `DraggableScrollableSheet`):

| Parameter | Default | Purpose | Driven by |
|---|---|---|---|
| `bool snap` | `false` | Enable snap behaviour on the draggable sheet | Comments |
| `List<double>? snapSizes` | `null` | Snap positions passed to `DraggableScrollableSheet` | Comments |
| `bool useRootNavigator` | `false` | Show the sheet above the tab shell | Comments |
| `bool tapOutsideToDismiss` | `true` | Opt-in-by-default tap-outside behaviour for the draggable variant | Fixes Metadata + Comments |
| `double Function(BuildContext modalContext)? initialChildSizeBuilder` | `null` | Lets callers pick `initialChildSize` dynamically (e.g. keyboard-aware) | Comments |

The table records the defaults when this plan was written. `useRootNavigator` has defaulted to `true` since #10673.

### Already supported — do **not** re-add

- `onShow` / `onDismiss` — used by `showVideoPausingVineBottomSheet` for
  video-pause integration. Keep as-is; the pause-aware layer stays in
  `mobile/lib/utils/pause_aware_modals.dart` (app-specific, not a design
  system concern).
- `buildScrollBody(scrollController)` — covers Metadata's
  `MultiBlocProvider` wrapping and gives Comments the scroll controller it
  uses for programmatic scroll-to-top.
- `isDismissible`, `enableDrag`, `initialChildSize`, `minChildSize`,
  `maxChildSize`, `isScrollControlled`, `showHeader`, `showHeaderDivider`,
  `title`, `contentTitle`, `trailing`, `bottomInput`, `body`, `children`,
  `expanded`.

### Intentionally not added

- `backgroundColor` / `elevation` overrides — fixed at
  `VineTheme.transparent` / `0` matches the design system; exposing knobs
  invites drift.
- Custom scrim colour or opacity — nobody needs it today.

---

## Tap-outside-to-dismiss implementation

Only applies to the `scrollable: true` branch at
`mobile/packages/divine_ui/lib/src/bottom_sheet/vine_bottom_sheet.dart:135`.
The fixed branch already works correctly.

Replace the current builder:

```dart
builder: (_) => DraggableScrollableSheet(
  initialChildSize: initialChildSize,
  minChildSize: minChildSize,
  maxChildSize: maxChildSize,
  builder: (context, scrollController) => VineBottomSheet(...),
),
```

with, when `tapOutsideToDismiss` is true:

```dart
builder: (modalContext) {
  final resolvedInitial =
      initialChildSizeBuilder?.call(modalContext) ?? initialChildSize;

  return GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () => Navigator.of(modalContext).pop(),
    child: DraggableScrollableSheet(
      expand: false, // critical — frees the area above the sheet
      initialChildSize: resolvedInitial,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      snap: snap,
      snapSizes: snapSizes,
      builder: (context, scrollController) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {}, // swallow taps on non-interactive sheet body
          child: VineBottomSheet(
            showHeader: showHeader,
            title: title,
            contentTitle: contentTitle,
            scrollController: scrollController,
            buildScrollBody: buildScrollBody,
            trailing: trailing,
            bottomInput: bottomInput,
            expanded: expanded,
            showHeaderDivider: showHeaderDivider,
            body: body,
            children: children,
          ),
        );
      },
    ),
  );
};
```

Three-piece pattern, each with a specific job:

- **Outer `GestureDetector` with `HitTestBehavior.translucent`** — catches
  taps in the empty area above the sheet and pops the route.
- **`expand: false` on `DraggableScrollableSheet`** — stops it from
  claiming the full viewport, so the area above the sheet is actually
  empty layout space that the outer detector can receive taps from.
- **Inner `GestureDetector` with `HitTestBehavior.opaque` and
  empty `onTap`** — prevents taps on non-interactive parts of the sheet
  (padding, dividers, titles) from bubbling up and dismissing. Drags still
  win via gesture arena; buttons/inkwells inside still receive their own
  taps.

When `tapOutsideToDismiss` is false, keep the current builder unchanged so
existing opt-outs are not regressed.

Forward `useRootNavigator` into the `showModalBottomSheet` call for both
branches (`scrollable: true` and `scrollable: false`).

---

## Migration — Metadata (`MetadataExpandedSheet`)

File: `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart`

Metadata already goes through `VineBottomSheet.show`; the only behavioural
change is inherited — it starts dismissing on outside tap because
`tapOutsideToDismiss` defaults to `true`.

No code changes required in `metadata_expanded_sheet.dart`. Verify
manually that:

1. Tapping the scrim above the sheet closes it.
2. Dragging the handle still resizes the sheet between `minChildSize: 0.3`
   and `maxChildSize: 0.9`.
3. Taps on non-interactive areas inside the sheet (e.g. between sections)
   do **not** close it.
4. Buttons and chips inside the metadata body (tag chips, creator row
   tap target, "read more") still respond.

---

## Migration — Comments (`CommentsScreen.show`)

File: `mobile/lib/screens/comments/comments_screen.dart`

### Before

```dart
showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  backgroundColor: VineTheme.transparent,
  elevation: 0,
  builder: (builderContext) {
    final keyboardHeight = MediaQuery.of(builderContext).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    return DraggableScrollableSheet(
      initialChildSize: isKeyboardOpen ? 0.93 : 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.93,
      snap: true,
      snapSizes: const [0.7, 0.93],
      builder: (context, scrollController) => CommentsScreen(
        videoEvent: video,
        sheetScrollController: scrollController,
        initialCommentCount: initialCommentCount,
        onCommentCountChanged: onCommentCountChanged,
      ),
    );
  },
).whenComplete(() {
  overlayNotifier.setBottomSheetOpen(false);
});
```

### After

```dart
VineBottomSheet.show<void>(
  context: context,
  scrollable: true,
  useRootNavigator: true,
  snap: true,
  snapSizes: const [0.7, 0.93],
  minChildSize: 0.5,
  maxChildSize: 0.93,
  initialChildSize: 0.7, // default when keyboard closed
  initialChildSizeBuilder: (modalContext) {
    final keyboardOpen =
        MediaQuery.viewInsetsOf(modalContext).bottom > 0;
    return keyboardOpen ? 0.93 : 0.7;
  },
  onShow: () => overlayNotifier.setBottomSheetOpen(true),
  onDismiss: () => overlayNotifier.setBottomSheetOpen(false),
  buildScrollBody: (scrollController) => CommentsScreen(
    videoEvent: video,
    sheetScrollController: scrollController,
    initialCommentCount: initialCommentCount,
    onCommentCountChanged: onCommentCountChanged,
  ),
);
```

### Structural changes inside `CommentsScreen` (the widget, not `.show`)

Today `CommentsScreen`'s build method wraps its own body in a
`VineBottomSheet` widget (see `comments_screen.dart:198`). Because the
migrated `.show` call will construct the outer `VineBottomSheet` for us,
the inner one becomes double-wrapping.

Two options:

1. **Preferred** — pass the needed pieces (`title`, `bottomInput` for the
   comment input, scroll body) directly into `VineBottomSheet.show` and
   drop the inner `VineBottomSheet` from `CommentsScreen`'s build. The
   comments list becomes the `buildScrollBody` return value; the title
   ("Comments (N)" with the new-comments pill) becomes the `title`
   parameter; the comment composer becomes `bottomInput`.
2. **Fallback** — keep the inner `VineBottomSheet` and pass `showHeader:
   false` to the outer one so only the drag handle is rendered outside.
   This is simpler but wastes a Column.

Go with option 1 during the migration.

The "scroll to top when the new-comments pill is tapped" logic
(`comments_screen.dart:206-210`) already lives in a `BlocListener` inside
the widget tree that has access to `sheetScrollController`. Because
`buildScrollBody` receives the controller, this keeps working unchanged.

---

## Step-by-step execution plan

1. **Extend `VineBottomSheet.show`** with the five new parameters (`snap`,
   `snapSizes`, `useRootNavigator`, `tapOutsideToDismiss`,
   `initialChildSizeBuilder`). Forward to `showModalBottomSheet` and
   `DraggableScrollableSheet` appropriately. Keep both branches (scrollable
   / fixed). Preserve all existing parameter defaults.
2. **Implement the tap-outside-to-dismiss wrapper** in the scrollable
   branch, gated on `tapOutsideToDismiss`. Add unit tests in
   `mobile/packages/divine_ui/test/src/bottom_sheet/vine_bottom_sheet_test.dart`
   covering:
   - tap outside dismisses when `tapOutsideToDismiss: true` and
     `scrollable: true`
   - tap outside does **not** dismiss when `tapOutsideToDismiss: false`
   - tap on sheet body does not dismiss
   - drag handle still resizes the sheet
   - fixed mode (`scrollable: false`) behaviour unchanged
3. **Wire the new parameters through `pause_aware_modals.dart`** so
   `showVideoPausingVineBottomSheet` can forward them (only the
   `VineBottomSheet`-path branch; the raw `builder:` path stays the same).
4. **Migrate `MetadataExpandedSheet`**: no call-site change; just verify
   manually and with widget tests that tap-outside now closes the sheet.
5. **Migrate `CommentsScreen.show`** to use `VineBottomSheet.show` per the
   "After" snippet above. Fold the inner `VineBottomSheet` from
   `CommentsScreen`'s build method into the `.show` call's `title` /
   `bottomInput` / `buildScrollBody` parameters.
6. **Run the relevant test suites**:
   - `flutter test packages/divine_ui/test/src/bottom_sheet/`
   - `flutter test test/screens/comments/`
   - `flutter test test/widgets/video_feed_item/metadata/`
   - Any golden tests that include Comments or Metadata.
7. **Manual QA** (device or emulator):
   - Profile More menu still opens, dismisses on outside tap (unchanged).
   - Metadata sheet opens, dismisses on outside tap (new behaviour),
     drag-resize works, taps on rows still route.
   - Comments sheet opens, dismisses on outside tap (new behaviour), snaps
     between 0.7 and 0.93, composer still works, keyboard open → initial
     size 0.93, new-comments pill still scrolls to top, root-navigator
     placement still sits above tabs.
   - Video pause integration: video pauses when sheet opens, resumes when
     sheet dismisses, for both Comments and Metadata.

---

## Risks and things to watch

- **Gesture arena regressions**: the inner `GestureDetector(onTap: () {})`
  must not break taps on interactive sheet children. Verify hashtag links,
  avatar taps, like buttons on each comment, tag chips in Metadata, and
  the comment composer's text field all still respond.
- **Keyboard interaction in Comments**: the composer's focus and keyboard
  resize behaviour depend on `isScrollControlled: true` and the system
  `viewInsets`. Confirm the composer still sits above the keyboard and
  that tapping the scrim above the (now smaller) sheet dismisses instead
  of closing the keyboard.
- **Drag-to-dismiss vs snap**: when `snap: true` with snap sizes that do
  not include 0, dragging past `minChildSize` should dismiss only if
  `enableDrag: true` on the modal — confirm behaviour matches today's
  Comments.
- **Accessibility**: the outer `GestureDetector` should not appear in the
  semantics tree as a focusable element. `HitTestBehavior.translucent`
  keeps it pointer-only; verify with a semantics test that it does not
  announce.
- **Tests that stub `showModalBottomSheet`**: any existing test that
  pokes at the sheet's widget tree will need the new nesting
  (`GestureDetector > DraggableScrollableSheet(expand: false) >
  GestureDetector > VineBottomSheet`) accounted for.

---

## Out of scope / follow-ups

- **Share sheet**: its custom `Material` + drag indicator doesn't fit
  `VineBottomSheet`'s structure. Migrating it is a separate effort that
  needs either a new `VineBottomSheet` layout variant or a redesign of
  the share sheet to use the standard header. Track separately.
- **`showVideoPausingVineBottomSheet`'s `builder:` path**: stays as-is
  until Share migrates; it remains the escape hatch for fully custom
  sheets.
- **Fixed-mode tap-outside-to-dismiss**: already works by default via
  `isDismissible: true`; no change needed. The new
  `tapOutsideToDismiss` flag is only wired to the scrollable branch.
