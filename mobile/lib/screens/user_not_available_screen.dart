import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/unavailable_profile_actions.dart';

// TODO(SofiaRey): revisit when designs are ready
/// Screen shown when the target user has blocked us.
class UserNotAvailableScreen extends StatelessWidget {
  const UserNotAvailableScreen({
    required this.onBack,
    required this.userIdHex,
    super.key,
  });

  final VoidCallback onBack;

  /// Hex pubkey of the account this screen stands in for, so reporting and
  /// unfollowing stay reachable even though the profile does not render.
  final String userIdHex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.profileTitle,
        showBackButton: true,
        onBackPressed: onBack,
        customActions: [UnavailableProfileActions(userIdHex: userIdHex)],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                DivineIconName.prohibit.assetPath,
                width: 48,
                height: 48,
                colorFilter: ColorFilter.mode(
                  context.vineColors.secondaryText,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.userNotAvailableTitle,
                style: VineTheme.titleLargeFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.userNotAvailableBody,
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
