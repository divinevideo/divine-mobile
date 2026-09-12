// ABOUTME: Reusable back button for authentication flow screens
// ABOUTME: Green rounded-square button with chevron icon

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/rounded_icon_button.dart';

/// A green rounded-square back button used in authentication flow screens.
///
/// Displays a chevron-left icon inside a rounded-square container.
/// Automatically calls `context.pop()` when pressed, or uses a custom
/// [onPressed] callback if provided.
class AuthBackButton extends StatelessWidget {
  /// Creates an authentication flow back button.
  ///
  /// If [onPressed] is null, the button will perform a guarded back action.
  const AuthBackButton({super.key, this.onPressed, this.enabled = true});

  /// Optional custom callback when the button is pressed.
  ///
  /// If null, defaults to `context.pop()`.
  final VoidCallback? onPressed;

  /// Whether the back button should respond to taps.
  final bool enabled;

  void _handleBackTap(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }

    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return RoundedIconButton(
      onPressed: !enabled ? null : onPressed ?? () => _handleBackTap(context),
      semanticLabel: context.l10n.commonBack,
      // Matches DiVineAppBarLeading.backButtonSemanticId so E2E flows can
      // address either back control by the same identifier.
      semanticIdentifier: DiVineAppBarLeading.backButtonSemanticId,
      icon: DivineIcon(
        icon: DivineIconName.caretLeft,
        color: context.vineColors.onIconButton,
      ),
    );
  }
}
