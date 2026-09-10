// ABOUTME: Shared error message box for authentication screens
// ABOUTME: Displays error text in a red-tinted container with border

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// A styled error message box for authentication screens.
///
/// Displays error text in a red-tinted container with a red border,
/// centered text, and consistent styling across all auth screens.
class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox({required this.message, super.key});

  /// The error message to display.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VineTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VineTheme.error),
      ),
      child: Text(
        message,
        style: const TextStyle(color: VineTheme.error, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}
