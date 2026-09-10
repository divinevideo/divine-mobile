// ABOUTME: App bar for conversation detail screen.
// ABOUTME: Wraps DiVineAppBar with back button, user name/handle, and options.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Top app bar for the conversation detail screen.
///
/// Wraps [DiVineAppBar] with a back button, the other user's display name
/// and handle, and a trailing options button.
class ConversationAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ConversationAppBar({
    required this.displayName,
    required this.handle,
    required this.onBack,
    required this.onOptions,
    this.isResolving = false,
    this.loadingDisplayName,
    this.onTitleTap,
    super.key,
  });

  final String displayName;
  final String handle;
  final VoidCallback onBack;
  final VoidCallback onOptions;
  final bool isResolving;
  final String? loadingDisplayName;

  /// Called when the user taps the name/handle in the app bar.
  final VoidCallback? onTitleTap;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return DiVineAppBar(
      title: isResolving ? null : displayName,
      titleWidget: isResolving
          ? Semantics(
              label: context.l10n.commonLoading,
              child: IdentitySkeletonizer(
                isLoading: true,
                excludeSemantics: true,
                child: Text(
                  loadingDisplayName ?? context.l10n.commonLoading,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          : null,
      subtitle: handle.isNotEmpty ? handle : null,
      titleMode: onTitleTap != null
          ? DiVineAppBarTitleMode.tappable
          : DiVineAppBarTitleMode.simple,
      onTitleTap: onTitleTap,
      showBackButton: true,
      onBackPressed: onBack,
      backgroundColor: context.vineColors.surface,
      style: DiVineAppBarStyle(
        titleStyle: VineTheme.titleMediumFont(
          color: context.vineColors.primaryText,
        ),
        horizontalPadding: 10,
        // 16 px visual gap to the title: leadingWidth − (start padding + button)
        // = 74 − (10 + 48).
        leadingWidth: 74,
      ),
      actions: [
        DiVineAppBarAction(
          icon: SvgIconSource(DivineIconName.dotsThree.assetPath),
          onPressed: onOptions,
          semanticLabel: context.l10n.inboxConversationOptionsLabel,
        ),
      ],
    );
  }
}
