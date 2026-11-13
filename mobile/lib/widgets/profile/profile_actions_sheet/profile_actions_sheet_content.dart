// ABOUTME: Presents pending profile actions in a bottom sheet, tall for the
// ABOUTME: supporter invitation, and animates between their prompts.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/router/routes/auth_routes.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/screens/settings/supporter_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_action_type.dart';
import 'package:unified_logger/unified_logger.dart';

/// Sizes of the tall sheet the supporter invitation opens in: its content (the
/// Supporter screen's pitch, plans and terms) does not fit a half sheet. It
/// opens at the sheet's default maximum height.
abstract class ProfileActionsSheetSizing {
  static const double tallInitial = 0.9;
}

/// Shows the pending [actions] in a bottom sheet.
///
/// The short prompts use a sheet sized to its content. When the sheet opens on
/// the supporter invitation it is the tall, draggable variant, with the
/// content scrolling inside it. A supporter invitation reached through "Maybe
/// later" stays in the short sheet and scrolls inside it. Either way it opens
/// on the root navigator, so it covers the tab shell's bottom navigation.
Future<void> showProfileActionsSheet({
  required BuildContext context,
  required List<ProfileActionType> actions,
  void Function(ProfileActionType action)? onMaybeLater,
}) {
  final opensTall = switch (actions.first) {
    ProfileActionType.becomeSupporter => true,
    ProfileActionType.accountRestricted ||
    ProfileActionType.secureAccount ||
    ProfileActionType.completeProfile => false,
  };
  if (opensTall) {
    return context.showVideoPausingVineBottomSheet<void>(
      showHeaderDivider: false,
      initialChildSize: ProfileActionsSheetSizing.tallInitial,
      minChildSize: VineTheme.bottomSheetDismissFloor,
      buildScrollBody: (scrollController) => ProfileActionsSheetContent(
        actions: actions,
        onMaybeLater: onMaybeLater,
        scrollController: scrollController,
      ),
    );
  }
  return context.showVideoPausingVineBottomSheet<void>(
    scrollable: false,
    showHeaderDivider: false,
    body: ProfileActionsSheetContent(
      actions: actions,
      onMaybeLater: onMaybeLater,
    ),
  );
}

/// Content widget for the profile-actions bottom sheet.
///
/// Displays a prompt for each pending [ProfileActionType] in order.
/// When the user taps "Maybe Later", the sheet transitions to the next
/// action (if any) or dismisses. Tapping the primary button navigates
/// to the corresponding screen and closes the sheet. The supporter prompt
/// is the exception: it shows the Supporter screen's content in place, so
/// the user can join without leaving the sheet.
class ProfileActionsSheetContent extends StatefulWidget {
  /// Creates a [ProfileActionsSheetContent].
  ///
  /// [actions] must contain at least one element.
  const ProfileActionsSheetContent({
    required this.actions,
    this.onMaybeLater,
    this.scrollController,
    super.key,
  }) : assert(actions.length > 0, 'actions must not be empty');

  /// Ordered list of actions to present. The first action is shown
  /// immediately; subsequent ones appear after "Maybe Later".
  final List<ProfileActionType> actions;

  /// Called with the action the user dismissed before the sheet advances.
  final void Function(ProfileActionType action)? onMaybeLater;

  /// The tall sheet's controller, so dragging the content drags the sheet.
  final ScrollController? scrollController;

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

  void _openDestination(String route) {
    Navigator.of(context).pop();
    runDetached(
      context.push<void>(route),
      'open profile action destination',
      logName: 'ProfileActionsSheetContent',
      category: LogCategory.ui,
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.actions[_currentIndex];
    final l10n = context.l10n;
    final key = ValueKey(action);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: switch (action) {
          ProfileActionType.accountRestricted => _ActionPrompt(
            key: key,
            sticker: DivineStickerName.blocked,
            title: l10n.profileAccountRestricted,
            subtitle: l10n.accountStatusRestrictedBody,
            primaryLabel: l10n.accountStatusTitle,
            onPrimaryTap: () => _openDestination(AccountStatusScreen.path),
            onSecondaryTap: _onMaybeLater,
          ),
          ProfileActionType.secureAccount => _ActionPrompt(
            key: key,
            sticker: DivineStickerName.skeletonKey,
            title: l10n.profileSecureYourAccount,
            subtitle: l10n.profileSecureSubtitle,
            primaryLabel: l10n.profileSecurePrimaryButton,
            onPrimaryTap: () =>
                _openDestination(const SecureAccountRouteData().location),
            onSecondaryTap: _onMaybeLater,
          ),
          ProfileActionType.completeProfile => _ActionPrompt(
            key: key,
            sticker: DivineStickerName.profile,
            title: l10n.profileCompleteYourProfile,
            subtitle: l10n.profileCompleteSubtitle,
            primaryLabel: l10n.profileCompletePrimaryButton,
            onPrimaryTap: () =>
                _openDestination(const SetupProfileRouteData().location),
            onSecondaryTap: _onMaybeLater,
          ),
          ProfileActionType.becomeSupporter => _SupporterPrompt(
            key: key,
            onMaybeLater: _onMaybeLater,
            scrollController: widget.scrollController,
          ),
        },
      ),
    );
  }
}

/// Prompt for an action whose primary button opens another screen.
///
/// Displays a sticker illustration, title, subtitle, and primary/secondary
/// action buttons matching the [VineBottomSheetPrompt] layout pattern.
class _ActionPrompt extends StatelessWidget {
  const _ActionPrompt({
    required this.sticker,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
    super.key,
  });

  final DivineStickerName sticker;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;

  @override
  Widget build(BuildContext context) {
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
            label: context.l10n.profileMaybeLaterLabel,
            onPressed: onSecondaryTap,
            type: DivineButtonType.secondary,
            expanded: true,
          ),
        ],
      ),
    );
  }
}

/// The Supporter screen's content, so the user can join from the sheet,
/// followed by "Maybe later".
class _SupporterPrompt extends ConsumerWidget {
  const _SupporterPrompt({
    required this.onMaybeLater,
    this.scrollController,
    super.key,
  });

  final VoidCallback onMaybeLater;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeBillingAvailable = ref.watch(
      supporterStoreBillingAvailableProvider,
    );
    return SupporterCubitScope(
      child: SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            SupporterContent(storeBillingAvailable: storeBillingAvailable),
            DivineButton(
              label: context.l10n.profileMaybeLaterLabel,
              onPressed: onMaybeLater,
              type: DivineButtonType.secondary,
              expanded: true,
            ),
          ],
        ),
      ),
    );
  }
}
