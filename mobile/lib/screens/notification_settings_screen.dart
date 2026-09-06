// ABOUTME: Settings screen for notification preferences and controls
// ABOUTME: Allows users to customize notification types and behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_cubit.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_state.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';

/// Page: bridges Riverpod-provided dependencies into [NotificationSettingsCubit].
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'notification-settings';

  /// Path for this route.
  static const String path = RoutePaths.notificationSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesService = ref.watch(
      notificationPreferencesServiceProvider,
    );
    final repository = ref.watch(notificationRepositoryProvider);

    return BlocProvider(
      // Both providers watch authServiceProvider, so their identities can
      // change on auth flip; re-key so the Cubit reloads with the fresh
      // dependencies instead of operating on stale ones.
      key: ValueKey((preferencesService, repository)),
      create: (_) => NotificationSettingsCubit(
        preferencesService: preferencesService,
        notificationRepository: repository,
      )..load(),
      child: NotificationSettingsView(
        showNewPosts: ref.watch(
          isFeatureEnabledProvider(FeatureFlag.newPostNotifications),
        ),
      ),
    );
  }
}

/// View: renders the notification settings UI from the Cubit state.
class NotificationSettingsView extends StatelessWidget {
  @visibleForTesting
  const NotificationSettingsView({required this.showNewPosts, super.key});

  /// Whether to offer the new-post ("bell") toggle. Hidden until the push
  /// service delivers kind 34236, since there is no bell to switch off and
  /// the toggle would change nothing a user could observe.
  final bool showNewPosts;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.vineColors.background,
    appBar: DiVineAppBar(
      title: context.l10n.notificationSettingsTitle,
      showBackButton: true,
      onBackPressed: context.pop,
      actions: [
        DiVineAppBarAction(
          icon: SvgIconSource(DivineIconName.arrowClockwise.assetPath),
          tooltip: context.l10n.notificationSettingsResetTooltip,
          onPressed: () => _onResetPressed(context),
        ),
      ],
    ),
    body: BlocListener<NotificationSettingsCubit, NotificationSettingsState>(
      listenWhen: (previous, current) =>
          previous.markAllAsReadStatus != current.markAllAsReadStatus,
      listener: _onMarkAllAsReadStatusChanged,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child:
              BlocBuilder<NotificationSettingsCubit, NotificationSettingsState>(
                builder: (context, state) {
                  final cubit = context.read<NotificationSettingsCubit>();
                  final prefs = state.preferences;
                  return ListView(
                    padding: .fromLTRB(
                      16,
                      16,
                      16,
                      16 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    children: [
                      DivineSectionHeader(
                        context.l10n.notificationSettingsTypes,
                        padding: const EdgeInsets.only(bottom: 8),
                      ),
                      _NotificationCard(
                        icon: DivineIconName.heart,
                        iconColor: VineTheme.likeRed,
                        title: context.l10n.notificationSettingsLikes,
                        subtitle:
                            context.l10n.notificationSettingsLikesSubtitle,
                        value: prefs.likesEnabled,
                        onChanged: (value) => cubit.setPreferences(
                          prefs.copyWith(likesEnabled: value),
                        ),
                      ),
                      _NotificationCard(
                        icon: DivineIconName.chat,
                        iconColor: VineTheme.commentBlue,
                        title: context.l10n.notificationSettingsComments,
                        subtitle:
                            context.l10n.notificationSettingsCommentsSubtitle,
                        value: prefs.commentsEnabled,
                        onChanged: (value) => cubit.setPreferences(
                          prefs.copyWith(commentsEnabled: value),
                        ),
                      ),
                      _NotificationCard(
                        icon: DivineIconName.user,
                        iconColor: VineTheme.vineGreen,
                        title: context.l10n.notificationSettingsFollows,
                        subtitle:
                            context.l10n.notificationSettingsFollowsSubtitle,
                        value: prefs.followsEnabled,
                        onChanged: (value) => cubit.setPreferences(
                          prefs.copyWith(followsEnabled: value),
                        ),
                      ),
                      _NotificationCard(
                        icon: DivineIconName.chat,
                        iconColor: VineTheme.warning,
                        title: context.l10n.notificationSettingsMentions,
                        subtitle:
                            context.l10n.notificationSettingsMentionsSubtitle,
                        value: prefs.mentionsEnabled,
                        onChanged: (value) => cubit.setPreferences(
                          prefs.copyWith(mentionsEnabled: value),
                        ),
                      ),
                      _NotificationCard(
                        icon: DivineIconName.repeat,
                        iconColor: VineTheme.vineGreenDark,
                        title: context.l10n.notificationSettingsReposts,
                        subtitle:
                            context.l10n.notificationSettingsRepostsSubtitle,
                        value: prefs.repostsEnabled,
                        onChanged: (value) => cubit.setPreferences(
                          prefs.copyWith(repostsEnabled: value),
                        ),
                      ),
                      if (showNewPosts)
                        _NotificationCard(
                          icon: DivineIconName.bellSimple,
                          iconColor: VineTheme.vineGreen,
                          title: context.l10n.notificationSettingsNewPosts,
                          subtitle:
                              context.l10n.notificationSettingsNewPostsSubtitle,
                          value: prefs.newPostsEnabled,
                          onChanged: (value) => cubit.setPreferences(
                            prefs.copyWith(newPostsEnabled: value),
                          ),
                        ),
                      DivineSectionHeader(
                        context.l10n.notificationSettingsActions,
                        padding: const EdgeInsets.only(top: 24, bottom: 8),
                      ),
                      _ActionCard(
                        icon: DivineIconName.checkCircle,
                        iconColor: VineTheme.vineGreenDark,
                        title: context.l10n.notificationSettingsMarkAllAsRead,
                        subtitle: context
                            .l10n
                            .notificationSettingsMarkAllAsReadSubtitle,
                        isBusy:
                            state.markAllAsReadStatus ==
                            MarkAllAsReadStatus.inProgress,
                        onTap: state.canMarkAllAsRead
                            ? cubit.markAllAsRead
                            : null,
                      ),
                      const SizedBox(height: 24),
                      const _InfoCard(),
                    ],
                  );
                },
              ),
        ),
      ),
    ),
  );

  void _onMarkAllAsReadStatusChanged(
    BuildContext context,
    NotificationSettingsState state,
  ) {
    final status = state.markAllAsReadStatus;
    if (status != MarkAllAsReadStatus.success &&
        status != MarkAllAsReadStatus.failure) {
      return;
    }
    final failed = status == MarkAllAsReadStatus.failure;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        failed
            ? context.l10n.notificationSettingsMarkAllAsReadFailed
            : context.l10n.notificationSettingsAllMarkedAsRead,
        error: failed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onResetPressed(BuildContext context) async {
    await context.read<NotificationSettingsCubit>().resetToDefaults();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.notificationSettingsResetToDefaults,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final DivineIconName icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    color: context.vineColors.card,
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: .hardEdge,
    child: DivineSwitchTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DivineIcon(icon: icon, color: iconColor),
      ),
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isBusy = false,
  });

  final DivineIconName icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Swaps the trailing caret for a spinner while the action runs.
  final bool isBusy;

  @override
  Widget build(BuildContext context) => Card(
    color: context.vineColors.card,
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: .hardEdge,
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DivineIcon(icon: icon, color: iconColor),
      ),
      title: Text(
        title,
        style: VineTheme.labelLargeFont(color: context.vineColors.primaryText),
      ),
      subtitle: Text(
        subtitle,
        style: VineTheme.bodySmallFont(color: context.vineColors.secondaryText),
      ),
      trailing: isBusy
          ? SizedBox.square(
              dimension: DivineIcon.scaleSize(context, 24),
              child: DivineCircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: context.l10n.commonLoading,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  VineTheme.primary,
                ),
              ),
            )
          : const DivineIcon(
              icon: DivineIconName.caretRight,
              color: VineTheme.primary,
            ),
      onTap: onTap,
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) => DivineInfoCard(
    tone: DivineInfoCardTone.neutral,
    title: context.l10n.notificationSettingsAbout,
    message: context.l10n.notificationSettingsAboutDescription,
  );
}
