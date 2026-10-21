// ABOUTME: Support center with help tools, resource links, and account deletion
// ABOUTME: Replaces the old support dialog and drawer legal links

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/clear_logs/clear_logs_cubit.dart';
import 'package:openvine/blocs/support_contact/support_contact_cubit.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/clear_logs_confirmation_sheet.dart';
import 'package:openvine/widgets/delete_account_action.dart';
import 'package:openvine/widgets/export_logs_tile.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';
import 'package:openvine/widgets/support_contact_action.dart';
import 'package:openvine/widgets/support_tile.dart';
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

  final ComposeSupportEmail? composeEmail;
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
                SupportTile(
                  icon: DivineIconName.warningCircle,
                  title: l10n.supportReportBug,
                  subtitle: l10n.supportReportBugSubtitle,
                  onTap: () => _showBugReport(context, userPubkey),
                ),
              if (isAuthenticated)
                SupportTile(
                  icon: DivineIconName.sparkle,
                  title: l10n.supportRequestFeature,
                  subtitle: l10n.supportRequestFeatureSubtitle,
                  onTap: () => _showFeatureRequest(context),
                ),
              const ExportLogsTile(),
              const _ClearLogsTile(),
              // #6335 was filed from here by someone who could not find
              // deletion, so it has to be reachable from here too. It sits
              // above the outbound links rather than last so it stays on
              // screen without scrolling on a 667pt phone.
              if (isAuthenticated)
                SupportTile(
                  icon: DivineIconName.trash,
                  title: l10n.nostrSettingsDeleteAccount,
                  subtitle: l10n.nostrSettingsDeleteAccountSubtitle,
                  destructive: true,
                  onTap: () => startAccountDeletionFlow(
                    context: context,
                    ref: ref,
                    screenName: 'SupportCenterScreen',
                  ),
                ),
              SupportTile(
                icon: DivineIconName.question,
                title: l10n.supportFaq,
                subtitle: l10n.supportFaqSubtitle,
                onTap: () => _launchUrl(
                  context,
                  'https://divine.video/faq',
                  l10n.supportFaq,
                ),
              ),
              SupportTile(
                icon: DivineIconName.users,
                title: l10n.supportFamily,
                subtitle: l10n.supportFamilySubtitle,
                onTap: () => _launchUrl(
                  context,
                  AppConstants.familyResourcesUrl,
                  l10n.supportFamily,
                ),
              ),
              SupportTile(
                icon: DivineIconName.userFocus,
                title: l10n.supportKids,
                subtitle: l10n.supportKidsSubtitle,
                onTap: () => _launchUrl(
                  context,
                  AppConstants.kidsPolicyUrl,
                  l10n.supportKids,
                ),
              ),
              SupportTile(
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

    runDetached(
      context.push(BugReportScreen.path),
      'open bug report',
      logName: 'SupportCenterScreen',
      category: LogCategory.ui,
    );
  }

  void _showFeatureRequest(BuildContext context) {
    runDetached(
      context.push(FeatureRequestScreen.path),
      'open feature request',
      logName: 'SupportCenterScreen',
      category: LogCategory.ui,
    );
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

class _SupportContactTile extends StatelessWidget {
  const _SupportContactTile({
    this.openSupportMessages,
    this.composeEmail,
  });

  final OpenSupportMessages? openSupportMessages;
  final ComposeSupportEmail? composeEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SupportContactAction(
      openSupportMessages: openSupportMessages,
      composeEmail: composeEmail,
      builder: (context, isOpening, openSupport) {
        return SupportTile(
          icon: DivineIconName.chat,
          title: l10n.supportContactSupport,
          subtitle: l10n.supportContactSupportSubtitle,
          onTap: isOpening ? null : openSupport,
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
      child: SupportTile(
        icon: DivineIconName.trashSimple,
        title: l10n.supportClearLogs,
        subtitle: l10n.supportClearLogsSubtitle,
        onTap: () => runDetached(
          _confirmAndClear(context),
          'confirm and clear logs',
          logName: 'SupportCenterScreen',
          category: LogCategory.ui,
        ),
      ),
    );
  }

  Future<void> _confirmAndClear(BuildContext context) async {
    final confirmed = await showClearLogsConfirmation(context);
    if (confirmed != true || !context.mounted) return;
    await context.read<ClearLogsCubit>().clear();
  }
}
