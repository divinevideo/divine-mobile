// ABOUTME: Shared full-screen layout for route validation failures and not-found UI.
// ABOUTME: Keeps DiVineAppBar + body copy consistent before wiring GoRouter.errorBuilder.

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';

/// Full-screen error state for bad route parameters and unmatched paths.
///
/// Matches the previous inline pattern in [GoRoute] builders: [DiVineAppBar]
/// with [AppLocalizations.routeErrorTitle] and a short [message] in the body.
///
/// Every instance is escapable, even when reached via `go` / a deep link that
/// leaves nothing to pop back to:
/// - the app-bar back control degrades to [BuildContext.safePop] (home when the
///   back stack is empty) instead of throwing `GoError: There is nothing to
///   pop`, and
/// - a [showHomeButton] action under [message] always routes to the home feed,
///   so a screen with [showBackButton] `false` still has a way out.
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({
    required this.message,
    this.title,
    this.showBackButton = false,
    this.onBackPressed,
    this.showHomeButton = true,
    super.key,
  });

  /// User-visible explanation, usually from [AppLocalizations] route-related getters.
  final String message;

  /// App bar title; defaults to [AppLocalizations.routeErrorTitle].
  final String? title;

  /// When true, shows the leading back control. When [onBackPressed] is
  /// omitted it degrades to [BuildContext.safePop], so the control never
  /// throws on a `go`-navigated route with an empty back stack.
  final bool showBackButton;

  final VoidCallback? onBackPressed;

  /// When true (the default), renders a home action under [message] so the
  /// screen is always escapable regardless of [showBackButton].
  final bool showHomeButton;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? backHandler = !showBackButton
        ? null
        : (onBackPressed ?? () => context.safePop());

    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: title ?? context.l10n.routeErrorTitle,
        showBackButton: showBackButton,
        onBackPressed: backHandler,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 24,
          children: [
            Text(message),
            if (showHomeButton)
              DivineButton(
                label: context.l10n.routeGoHome,
                onPressed: () => context.go(VideoFeedPage.pathForIndex(0)),
              ),
          ],
        ),
      ),
    );
  }
}
