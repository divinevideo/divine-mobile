// ABOUTME: Shared log-export control for support and restricted-account screens.
// ABOUTME: Preserves route diagnostics, share anchoring, and export outcomes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/export_logs/export_logs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/providers/support_route_trail_provider.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/share_position_origin.dart';
import 'package:unified_logger/unified_logger.dart';

/// Hands the captured log file to the system share sheet.
///
/// Goes through [ExportLogsCubit] rather than calling `BugReportService`
/// from here, so the widget layer never sees the service type.
class ExportLogsTile extends ConsumerWidget {
  const ExportLogsTile({super.key});

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
      child: ListTile(
        leading: DivineIcon(
          icon: DivineIconName.save,
          color: context.vineColors.accentPositive,
        ),
        title: Text(
          l10n.supportSaveLogs,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        subtitle: Text(
          l10n.supportSaveLogsSubtitle,
          style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
        ),
        trailing: DivineIcon(
          icon: DivineIconName.caretRight,
          color: context.vineColors.mutedText,
        ),
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
          runDetached(
            cubit.revealFile(filePath),
            'reveal exported logs',
            logName: 'ExportLogsTile',
            category: LogCategory.ui,
          );
        },
      ),
    );
  }
}
