// ABOUTME: Share action for a list somebody else owns, shown in the app bar
// ABOUTME: of the video-list and people-list screens after the follow pill.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';

/// Share action shown to non-owners in a list screen's app bar, after the
/// follow pill.
///
/// Drawn in the bar's own action chrome, the back button's: a green glyph on
/// the bordered surface container.
class ShareListButton extends StatelessWidget {
  const ShareListButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DivineAppBarIconButton(
      icon: SvgIconSource(DivineIconName.shareFat.assetPath),
      onPressed: onPressed,
      tooltip: l10n.listShareAction,
      semanticLabel: l10n.listShareAction,
      backgroundColor: context.vineColors.surfaceContainer,
      borderSide: BorderSide(color: context.vineColors.outlineMuted, width: 2),
      iconColor: context.vineColors.isLight
          ? VineTheme.primaryAccessible
          : VineTheme.primary,
    );
  }
}
