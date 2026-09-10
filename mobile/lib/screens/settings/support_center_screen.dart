// ABOUTME: Support center with help tools, resource links, and account deletion
// ABOUTME: Replaces the old support dialog and drawer legal links

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/clear_logs/clear_logs_cubit.dart';
import 'package:openvine/blocs/export_logs/export_logs_cubit.dart';
import 'package:openvine/blocs/support_contact/support_contact_cubit.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/providers/support_route_trail_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/support_email_composer.dart';
import 'package:openvine/utils/share_position_origin.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/clear_logs_confirmation_sheet.dart';
import 'package:openvine/widgets/delete_account_action.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportCenterScreen extends ConsumerWidget {
  static const routeName = 'support-center';
  static const String path = RoutePaths.supportCenter;

  const SupportCenterScreen({
    this.composeEmail,
    this.openZendeskSupport,
    super.key,
  });

  final SupportEmailCompose? composeEmail;
  final Future<bool> Function()? openZendeskSupport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final userPubkey = authService.currentPublicKeyHex;
    final isAuthenticated =
        ref.watch(currentAuthStateProvider) == AuthState.authenticated;

    final l10n = context.l10n;
    return Scaffold(
      appBar: DiVineAppBar(
        title: l10n.supportTitle,
        showBackButton: true,
        onBackPressed: () => context.safePop(fallback: WelcomeScreen.path),
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              _SupportContactTile(
                openSupportMessages: openZendeskSupport,
                composeEmail: composeEmail,
              ),
              if (isAuthenticated)
                _SupportTile(
                  icon: DivineIconName.warningCircle,
                  title: l10n.supportReportBug,
                  subtitle: l10n.supportReportBugSubtitle,
                  onTap: () => _showBugReport(context, userPubkey),
                ),
              if (isAuthenticated)
                _SupportTile(
                  icon: DivineIconName.sparkle,
                  title: l10n.supportRequestFeature,
                  subtitle: l10n.supportRequestFeatureSubtitle,
                  onTap: () => _showFeatureRequest(context),
                ),
              const _ExportLogsTile(),
              const _ClearLogsTile(),
              // #6335 was filed from here by someone who could not find
              // deletion, so it has to be reachable from here too. It sits
              // above the outbound links rather than last so it stays on
              // screen without scrolling on a 667pt phone.
              if (isAuthenticated)
                _SupportTile(
                  icon: DivineIconName.trash,
                  title: l10n.nostrSettingsDeleteAccount,
                  subtitle: l10n.nostrSettingsDeleteAccountSubtitle,
                  iconColor: VineTheme.error,
                  titleColor: VineTheme.error,
                  trailingColor: VineTheme.error,
                  onTap: () => startAccountDeletionFlow(
                    context: context,
                    ref: ref,
                    screenName: 'SupportCenterScreen',
                  ),
                ),
              _SupportTile(
                icon: DivineIconName.question,
                title: l10n.supportFaq,
                subtitle: l10n.supportFaqSubtitle,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/faq',
                  l10n.supportFaq,
                ),
              ),
              _SupportTile(
                icon: DivineIconName.users,
                title: l10n.supportFamily,
                subtitle: l10n.supportFamilySubtitle,
                onTap: () => _launchUrl(
                  context,
                  AppConstants.familyResourcesUrl,
                  l10n.supportFamily,
                ),
              ),
              _SupportTile(
                icon: DivineIconName.userFocus,
                title: l10n.supportKids,
                subtitle: l10n.supportKidsSubtitle,
                onTap: () => _launchUrl(
                  context,
                  AppConstants.kidsPolicyUrl,
                  l10n.supportKids,
                ),
              ),
              _SupportTile(
                icon: DivineIconName.shieldCheck,
                title: l10n.supportProofMode,
                subtitle: l10n.supportProofModeSubtitle,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/proofmode',
                  l10n.supportProofMode,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBugReport(BuildContext context, String? userPubkey) {
    if (userPubkey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.supportLoginRequired,
          error: true,
        ),
      );
      return;
    }

    context.push(BugReportScreen.path);
  }

  void _showFeatureRequest(BuildContext context) {
    context.push(FeatureRequestScreen.path);
  }

  Future<void> _launchUrl(
    BuildContext context,
    String urlString,
    String pageName,
  ) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(
              context.l10n.supportCouldNotOpenPage(pageName),
              error: true,
            ),
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to open $pageName: $e',
        name: 'SupportCenterScreen',
        category: LogCategory.ui,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.supportCouldNotOpenPage(pageName),
            error: true,
          ),
        );
      }
    }
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
    this.trailingColor,
    this.trailing,
  });

  final DivineIconName icon;
  final Color? iconColor;

  /// Overrides the title colour, for destructive entries.
  final Color? titleColor;
  final Color? trailingColor;
  final Widget? trailing;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: DivineIcon(
        icon: icon,
        color: iconColor ?? context.vineColors.accentPositive,
      ),
      title: Text(
        title,
        style: VineTheme.titleMediumFont(
          color: titleColor ?? context.vineColors.primaryText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
      ),
      trailing:
          trailing ??
          DivineIcon(
            icon: DivineIconName.caretRight,
            color: trailingColor ?? context.vineColors.mutedText,
          ),
      onTap: onTap,
    );
  }
}

class _SupportContactTile extends StatelessWidget {
  const _SupportContactTile({
    this.openSupportMessages,
    this.composeEmail,
  });

  final OpenSupportMessages? openSupportMessages;
  final SupportEmailCompose? composeEmail;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SupportContactCubit(
        openSupportMessages: openSupportMessages,
      ),
      child: _SupportContactTileView(composeEmail: composeEmail),
    );
  }
}

class _SupportContactTileView extends StatelessWidget {
  const _SupportContactTileView({this.composeEmail});

  final SupportEmailCompose? composeEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<SupportContactCubit, SupportContactState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == SupportContactStatus.unavailable,
      listener: (context, _) => _composeSupportEmail(context),
      builder: (context, state) {
        final isOpening = state.status == SupportContactStatus.opening;
        return _SupportTile(
          icon: DivineIconName.chat,
          title: l10n.supportContactSupport,
          subtitle: l10n.supportContactSupportSubtitle,
          onTap: isOpening
              ? null
              : () => context.read<SupportContactCubit>().open(),
          trailing: isOpening
              ? const SizedBox.square(
                  dimension: 20,
                  child: DivineCircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        );
      },
    );
  }

  Future<void> _composeSupportEmail(BuildContext context) async {
    final l10n = context.l10n;
    final sharePositionOrigin = shareAnchorForContext(context);
    try {
      await (composeEmail ?? SupportEmailComposer().compose)(
        toEmail: AppConstants.supportEmail,
        subject: l10n.supportContactSupport,
        body:
            '${l10n.supportCouldNotOpenMessages}\n\n'
            '${l10n.supportContactSupportSubtitle}',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          l10n.authCouldNotOpenEmail(AppConstants.supportEmail),
          error: true,
        ),
      );
    }
  }
}

/// Hands the captured log file to the system share sheet.
///
/// Goes through [ExportLogsCubit] rather than calling `BugReportService`
/// from here, so the widget layer never sees the service type.
class _ExportLogsTile extends ConsumerWidget {
  const _ExportLogsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bugReportService = ref.watch(bugReportServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final authState = ref.watch(currentAuthStateProvider);
    ref.watch(supportRouteTrailProvider);
    final routeSnapshot = ref.read(supportRouteTrailProvider.notifier).snapshot;
    return BlocProvider<ExportLogsCubit>(
      key: ValueKey((
        bugReportService,
        authService,
        authState,
        routeSnapshot.currentScreen,
        routeSnapshot.recentScreens.join('|'),
      )),
      create: (_) => ExportLogsCubit(
        bugReportService: bugReportService,
        currentScreen: routeSnapshot.currentScreen,
        recentScreens: routeSnapshot.recentScreens,
        userPubkey: authService.currentPublicKeyHex,
      ),
      child: const _ExportLogsTileView(),
    );
  }
}

class _ExportLogsTileView extends StatelessWidget {
  const _ExportLogsTileView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<ExportLogsCubit, ExportLogsState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _showOutcome,
      child: _SupportTile(
        icon: DivineIconName.save,
        title: l10n.supportSaveLogs,
        subtitle: l10n.supportSaveLogsSubtitle,
        // Resolve the popover anchor before the cubit's first await — the
        // iPad idiom (including iOS builds on Apple Silicon Macs) rejects the
        // share sheet without it.
        onTap: () => context.read<ExportLogsCubit>().export(
          sharePositionOrigin: shareAnchorForContext(context),
        ),
      ),
    );
  }

  static void _showOutcome(BuildContext context, ExportLogsState state) {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    if (state.status == ExportLogsStatus.exporting) {
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          l10n.supportExportingLogs,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    messenger.hideCurrentSnackBar();

    switch (state.status) {
      case ExportLogsStatus.idle:
      case ExportLogsStatus.exporting:
      case ExportLogsStatus.cancelled:
        // Cancelled means the user backed out — they know what they did.
        return;
      case ExportLogsStatus.noLogs:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            l10n.supportNoLogsToExport,
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      case ExportLogsStatus.unconfirmed:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            l10n.supportExportLogsUnconfirmed,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      case ExportLogsStatus.failed:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            l10n.supportExportLogsFailed,
            error: true,
          ),
        );
        return;
      case ExportLogsStatus.shared:
      case ExportLogsStatus.saved:
        break;
    }

    final filePath = state.filePath;
    if (filePath == null) return;

    final cubit = context.read<ExportLogsCubit>();
    messenger.showSnackBar(
      DivineSnackbarContainer.snackBar(
        l10n.supportLogsSavedTo(filePath),
        duration: const Duration(seconds: 8),
        actionLabel: l10n.supportRevealLogsAction,
        onActionPressed: () {
          // DivineSnackbarContainer's action is a plain button, so unlike
          // SnackBarAction it does not dismiss the banner for us.
          messenger.hideCurrentSnackBar();
          cubit.revealFile(filePath);
        },
      ),
    );
  }
}

/// Clears the in-memory log capture buffer, behind a confirmation.
///
/// Goes through [ClearLogsCubit] rather than calling `BugReportService`
/// from here, so the widget layer never sees the service type.
class _ClearLogsTile extends ConsumerWidget {
  const _ClearLogsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bugReportService = ref.watch(bugReportServiceProvider);
    return BlocProvider<ClearLogsCubit>(
      key: ValueKey(bugReportService),
      create: (_) => ClearLogsCubit(bugReportService: bugReportService),
      child: const _ClearLogsTileView(),
    );
  }
}

class _ClearLogsTileView extends StatelessWidget {
  const _ClearLogsTileView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<ClearLogsCubit, ClearLogsState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status != ClearLogsStatus.cleared) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            DivineSnackbarContainer.snackBar(context.l10n.supportLogsCleared),
          );
      },
      child: _SupportTile(
        icon: DivineIconName.trashSimple,
        title: l10n.supportClearLogs,
        subtitle: l10n.supportClearLogsSubtitle,
        onTap: () => _confirmAndClear(context),
      ),
    );
  }

  Future<void> _confirmAndClear(BuildContext context) async {
    final confirmed = await showClearLogsConfirmation(context);
    if (confirmed != true || !context.mounted) return;
    context.read<ClearLogsCubit>().clear();
  }
}
