Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Navigation Component Architecture

This document outlines the recommended approach for creating reusable navigation components (AppBar) that maintain consistent styling across all screens while preserving flexible routing behavior.

## Current State

The four main screens (Home, Explore, Notifications, Profile) share the same AppBar through `AppShell` (`lib/router/app_shell.dart`). However, other screens pushed via `Navigator.push()` (Settings, CuratedListFeedScreen, UserListPeopleScreen, etc.) have their own separate AppBar implementations that don't use this styling.

This leads to visual inconsistency across the app.

## Recommended Approach: Extract Reusable Components

### 1. Create `VineIconButton` Widget

A reusable styled icon button component that renders the 48x48 container with 32x32 SVG icon, rounded corners, and background color.

**Location:** `lib/widgets/vine_icon_button.dart`

```dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/theme/vine_theme.dart';

class VineIconButton extends StatelessWidget {
  const VineIconButton({
    required this.iconPath,
    required this.onPressed,
    this.tooltip,
    this.iconColor = Colors.white,
    super.key,
  });

  final String iconPath;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: VineTheme.iconButtonBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SvgPicture.asset(
          iconPath,
          width: 32,
          height: 32,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
      ),
      onPressed: onPressed,
    );
  }
}
```

### 2. Create `VineAppBar` Widget

A reusable `PreferredSizeWidget` with configurable parameters for title, leading button type, and action buttons.

**Location:** `lib/widgets/vine_app_bar.dart`

```dart
import 'package:material_ui/material_ui.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/vine_icon_button.dart';

enum LeadingButtonType { menu, back, none }

class VineAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VineAppBar({
    this.title = '',
    this.titleWidget,
    this.leadingType = LeadingButtonType.menu,
    this.onMenuPressed,
    this.onBackPressed,
    this.showSearch = true,
    this.showCamera = true,
    this.onSearchPressed,
    this.onCameraPressed,
    this.additionalActions,
    this.backgroundColor,
    super.key,
  });

  /// Text title for the AppBar
  final String title;

  /// Custom widget title (takes precedence over [title])
  final Widget? titleWidget;

  /// Type of leading button to display
  final LeadingButtonType leadingType;

  /// Callback when menu button is pressed (required if leadingType is menu)
  final VoidCallback? onMenuPressed;

  /// Callback when back button is pressed (required if leadingType is back)
  final VoidCallback? onBackPressed;

  /// Whether to show the search button
  final bool showSearch;

  /// Whether to show the camera button
  final bool showCamera;

  /// Callback when search button is pressed
  final VoidCallback? onSearchPressed;

  /// Callback when camera button is pressed
  final VoidCallback? onCameraPressed;

  /// Additional action buttons to display after search/camera
  final List<Widget>? additionalActions;

  /// Optional background color override
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      toolbarHeight: 72,
      leadingWidth: 72,
      centerTitle: false,
      titleSpacing: 12,
      backgroundColor: backgroundColor ?? VineTheme.navGreen,
      leading: _buildLeading(),
      title: titleWidget ?? Text(
        title,
        style: VineTheme.titleFont(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: _buildActions(),
    );
  }

  Widget? _buildLeading() {
    switch (leadingType) {
      case LeadingButtonType.menu:
        return VineIconButton(
          iconPath: 'assets/icon/menu.svg',
          tooltip: 'Menu',
          onPressed: onMenuPressed ?? () {},
        );
      case LeadingButtonType.back:
        return VineIconButton(
          iconPath: 'assets/icon/CaretLeft.svg',
          tooltip: 'Back',
          onPressed: onBackPressed ?? () {},
        );
      case LeadingButtonType.none:
        return null;
    }
  }

  List<Widget> _buildActions() {
    final actions = <Widget>[];

    if (showSearch) {
      actions.add(
        VineIconButton(
          iconPath: 'assets/icon/search.svg',
          tooltip: 'Search',
          onPressed: onSearchPressed ?? () {},
        ),
      );
    }

    if (showCamera) {
      if (showSearch) {
        actions.add(const SizedBox(width: 8));
      }
      actions.add(
        VineIconButton(
          iconPath: 'assets/icon/camera.svg',
          tooltip: 'Open camera',
          onPressed: onCameraPressed ?? () {},
        ),
      );
    }

    if (additionalActions != null) {
      actions.addAll(additionalActions!);
    }

    // Right padding
    actions.add(const SizedBox(width: 12));

    return actions;
  }
}
```

### 3. Refactor `AppShell` to Use `VineAppBar`

Update `AppShell` to use the new components internally, reducing code duplication:

```dart
// In AppShell.build()
appBar: VineAppBar(
  titleWidget: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: _buildTappableTitle(context, ref, title)),
      const EnvironmentBadge(),
    ],
  ),
  leadingType: showBackButton ? LeadingButtonType.back : LeadingButtonType.menu,
  onMenuPressed: () {
    // Pause videos and open drawer
    ref.read(videoVisibilityManagerProvider).pauseAllVideos();
    Scaffold.of(context).openDrawer();
  },
  onBackPressed: () => _handleBackNavigation(context, ref),
  onSearchPressed: () => context.goSearch(),
  onCameraPressed: () => context.pushCamera(),
),
```

The app bar takes no `backgroundColor` here: it follows the active palette
(`VineThemeColors.nav`), and the environment is signalled by the
`EnvironmentBadge` next to the title rather than by tinting the bar.

### 4. Update Other Screens

Screens like Settings, CuratedListFeedScreen can migrate to use `VineAppBar`:

```dart
// In SettingsScreen
Scaffold(
  appBar: VineAppBar(
    title: 'Settings',
    leadingType: LeadingButtonType.back,
    onBackPressed: () => Navigator.pop(context),
    showSearch: false,
    showCamera: false,
  ),
  body: // ...
)
```

```dart
// In CuratedListFeedScreen
Scaffold(
  appBar: VineAppBar(
    title: listName,
    leadingType: LeadingButtonType.back,
    onBackPressed: () => Navigator.pop(context),
    showCamera: false,
  ),
  body: // ...
)
```

## Routing Considerations

### Key Insight

`VineAppBar` is a **purely visual component** that doesn't know anything about routing. It takes callbacks for button actions, and the caller decides what navigation logic to execute.

This design ensures:
- Routing is NOT affected by the component extraction
- Navigation logic stays where it belongs (in each screen or shell)
- The component remains testable and reusable

### How It Works With Different Routing Patterns

#### 1. AppShell (GoRouter ShellRoute)

The complex back button logic stays in AppShell - it just passes the callback:

```dart
VineAppBar(
  leadingType: showBackButton ? LeadingButtonType.back : LeadingButtonType.menu,
  onBackPressed: () => _handleComplexBackNavigation(context, ref),  // Existing logic
  onMenuPressed: () => Scaffold.of(context).openDrawer(),
)
```

The complex back navigation logic in AppShell involves:
- Checking `pageContextProvider` for current route context
- Checking `tabHistoryProvider` for tab navigation history
- Using `lastTabPositionProvider` for restoring scroll positions
- Calling various GoRouter methods (`context.go()`, `context.goExplore()`, etc.)

This logic remains in AppShell and is passed as a callback.

#### 2. Pushed Screens (Navigator.push)

Simple pop behavior:

```dart
VineAppBar(
  title: 'Settings',
  leadingType: LeadingButtonType.back,
  onBackPressed: () => Navigator.pop(context),
)
```

#### 3. GoRouter Sub-routes (context.push)

```dart
VineAppBar(
  title: 'Video Details',
  leadingType: LeadingButtonType.back,
  onBackPressed: () => context.pop(),
)
```

### Separation of Concerns

| Concern | Where It Lives |
|---------|----------------|
| Visual styling | `VineAppBar` and `VineIconButton` components |
| Navigation logic | Each screen/shell decides via callbacks |
| GoRouter integration | Stays in `AppShell` and route configurations |
| Simple back navigation | Screen calls `Navigator.pop()` or `context.pop()` |

## Benefits

- **Single source of truth** - All styling in one place (`VineAppBar`, `VineIconButton`)
- **Consistent UX** - Every screen looks the same
- **Flexible** - Parameters allow per-screen customization
- **Gradual migration** - Existing screens continue working, migrate one at a time
- **Testable** - Components can be tested independently
- **Follows Flutter conventions** - Standard widget composition pattern
- **No routing impact** - Navigation logic remains unchanged

## Implementation Checklist

- [ ] Create `lib/widgets/vine_icon_button.dart`
- [ ] Create `lib/widgets/vine_app_bar.dart`
- [ ] Add tests for `VineIconButton`
- [ ] Add tests for `VineAppBar`
- [ ] Refactor `AppShell` to use `VineAppBar`
- [ ] Update Settings screen to use `VineAppBar`
- [ ] Update CuratedListFeedScreen to use `VineAppBar`
- [ ] Update UserListPeopleScreen to use `VineAppBar`
- [ ] Update DiscoverListsScreen to use `VineAppBar`
- [ ] Update remaining screens
- [ ] Remove duplicate AppBar styling code

## File Structure

```
lib/
  widgets/
    vine_app_bar.dart        # Main reusable AppBar
    vine_icon_button.dart    # Styled icon button component
  router/
    app_shell.dart           # Refactored to use VineAppBar
  screens/
    settings_screen.dart     # Uses VineAppBar
    curated_list_feed_screen.dart  # Uses VineAppBar
    ...
```
