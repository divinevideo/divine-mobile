// ABOUTME: Screen displayed when viewing a blocked or unavailable user's profile
// ABOUTME: Shows a simple message with back navigation

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/unavailable_profile_actions.dart';

/// Screen shown when viewing a blocked or unavailable user's profile.
class BlockedUserScreen extends StatelessWidget {
  const BlockedUserScreen({
    required this.onBack,
    required this.userIdHex,
    super.key,
  });

  /// Callback when back button is pressed.
  final VoidCallback onBack;

  /// Hex pubkey of the account this screen stands in for, so reporting and
  /// unfollowing stay reachable even though the profile does not render.
  final String userIdHex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: '',
        showBackButton: true,
        onBackPressed: onBack,
        backgroundMode: DiVineAppBarBackgroundMode.transparent,
        customActions: [UnavailableProfileActions(userIdHex: userIdHex)],
      ),
      body: Center(
        child: Text(
          context.l10n.profileBlockedAccountNotAvailable,
          style: TextStyle(color: context.vineColors.mutedText, fontSize: 16),
        ),
      ),
    );
  }
}
