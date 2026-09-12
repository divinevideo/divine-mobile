// ABOUTME: Multi-state bottom sheet content for pending profile actions.
// ABOUTME: Animates between "Secure Your Account" and "Complete Your Profile"
// ABOUTME: prompts using AnimatedSwitcher for cross-fade transitions.

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/profile_setup/profile_setup.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_action_type.dart';

/// Content widget for the profile-actions bottom sheet.
///
/// Displays a prompt for each pending [ProfileActionType] in order.
/// When the user taps "Maybe Later", the sheet transitions to the next
/// action (if any) or dismisses. Tapping the primary button navigates
/// to the corresponding screen and closes the sheet.
class ProfileActionsSheetContent extends StatefulWidget {
  /// Creates a [ProfileActionsSheetContent].
  ///
  /// [actions] must contain at least one element.
  const ProfileActionsSheetContent({
    required this.actions,
    this.onMaybeLater,
    super.key,
  }) : assert(actions.length > 0, 'actions must not be empty');

  /// Ordered list of actions to present. The first action is shown
  /// immediately; subsequent ones appear after "Maybe Later".
  final List<ProfileActionType> actions;

  /// Called with the action the user dismissed before the sheet advances.
  final void Function(ProfileActionType action)? onMaybeLater;

  @override
  State<ProfileActionsSheetContent> createState() =>
      _ProfileActionsSheetContentState();
}

class _ProfileActionsSheetContentState
    extends State<ProfileActionsSheetContent> {
  int _currentIndex = 0;

  void _onMaybeLater() {
    widget.onMaybeLater?.call(widget.actions[_currentIndex]);
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= widget.actions.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _currentIndex = nextIndex);
  }

  void _onPrimaryTap(ProfileActionType action) {
    final route = switch (action) {
      ProfileActionType.accountRestricted => AccountStatusScreen.path,
      ProfileActionType.secureAccount => SecureAccountScreen.path,
      ProfileActionType.completeProfile => ProfileSetupScreen.setupPath,
    };

    Navigator.of(context).pop();
    if (context.mounted) {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.actions[_currentIndex];

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: _ActionPrompt(
          key: ValueKey(action),
          action: action,
          onPrimaryTap: () => _onPrimaryTap(action),
          onSecondaryTap: _onMaybeLater,
        ),
      ),
    );
  }
}

/// Single prompt view for one [ProfileActionType].
///
/// Displays a sticker illustration, title, subtitle, and primary/secondary
/// action buttons matching the [VineBottomSheetPrompt] layout pattern.
class _ActionPrompt extends StatelessWidget {
  const _ActionPrompt({
    required this.action,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
    super.key,
  });

  final ProfileActionType action;
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (sticker, title, subtitle, primaryLabel) = switch (action) {
      ProfileActionType.accountRestricted => (
        DivineStickerName.blocked,
        l10n.profileAccountRestricted,
        l10n.accountStatusRestrictedBody,
        l10n.accountStatusTitle,
      ),
      ProfileActionType.secureAccount => (
        DivineStickerName.skeletonKey,
        l10n.profileSecureYourAccount,
        l10n.profileSecureSubtitle,
        l10n.profileSecurePrimaryButton,
      ),
      ProfileActionType.completeProfile => (
        DivineStickerName.profile,
        l10n.profileCompleteYourProfile,
        l10n.profileCompleteSubtitle,
        l10n.profileCompletePrimaryButton,
      ),
    };

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DivineSticker(sticker: sticker),
          const SizedBox(height: 32),
          Text(
            title,
            style: VineTheme.headlineSmallFont(
              color: context.vineColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          DivineButton(
            label: primaryLabel,
            onPressed: onPrimaryTap,
            expanded: true,
          ),
          const SizedBox(height: 16),
          DivineButton(
            label: l10n.profileMaybeLaterLabel,
            onPressed: onSecondaryTap,
            type: DivineButtonType.secondary,
            expanded: true,
          ),
        ],
      ),
    );
  }
}
