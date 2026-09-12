// ABOUTME: Developer-only rescue for recordings the app can no longer show.
// ABOUTME: Answers "my clips are gone" with where they actually are.

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/clip_recovery/clip_recovery_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_recovery.dart';
import 'package:openvine/providers/storage_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/byte_size_format.dart';
import 'package:openvine/utils/clipboard_utils.dart';

/// Page: finds and reattaches recordings the app can no longer show.
///
/// Two things make a library look empty while the recordings are still on the
/// device: rows stamped with a different account (every query filters by
/// owner), and files left behind by a database reset. This reports both and
/// offers to move them to the signed-in account.
///
/// The report comes first on purpose — both actions write, and the owner
/// restamp in particular takes rows away from whichever account currently
/// holds them, so the operator sees the pubkey before deciding.
///
/// It gets a screen rather than a section inside Developer Options because the
/// unreferenced-file list is unbounded: one row per recording a database reset
/// stranded, each with its own preview frame.
class ClipRecoveryScreen extends ConsumerWidget {
  /// Creates the page.
  const ClipRecoveryScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'clip-recovery';

  /// Path for this route.
  static const String path = RoutePaths.clipRecovery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(clipRecoveryServiceProvider);
    return BlocProvider<ClipRecoveryCubit>(
      key: ValueKey(service),
      create: (_) => ClipRecoveryCubit(service: service),
      child: const ClipRecoveryView(),
    );
  }
}

/// View: renders the scan result. Split from [ClipRecoveryScreen] so it can be
/// tested with a stubbed [ClipRecoveryCubit].
class ClipRecoveryView extends StatelessWidget {
  /// Creates the view.
  @visibleForTesting
  const ClipRecoveryView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final orphanFiles = context.select(
      (ClipRecoveryCubit c) => c.state.report.orphanFiles,
    );

    return Scaffold(
      appBar: DiVineAppBar(
        title: l10n.devOptionsClipRecovery,
        showBackButton: true,
        // Not a raw pop: reached cold via a deep link this screen has a
        // one-entry stack and context.pop() throws (#6112). Falls back to the
        // screen that offers it.
        onBackPressed: () =>
            context.safePop(fallback: RoutePaths.developerOptions),
      ),
      backgroundColor: context.vineColors.background,
      // A CustomScrollView so the unreferenced-file rows can be a lazy sliver:
      // a reset can strand hundreds of recordings, and each row decodes its own
      // preview frame.
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _Header()),
          SliverList.builder(
            itemCount: orphanFiles.length,
            itemBuilder: (context, index) => _OrphanFileRow(orphanFiles[index]),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select((ClipRecoveryCubit c) => c.state.status);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text(
            l10n.devOptionsClipRecoveryDescription,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
          const _RecoveryActions(),
          // Both, not one or the other: a claim or rebuild can fail with the
          // scan's findings still on screen and still worth copying, and the
          // unreferenced-file rows below stay listed either way — hiding only
          // the summary would leave the two halves contradicting each other.
          if (status == ClipRecoveryStatus.failure)
            Text(
              l10n.devOptionsClipRecoveryFailure,
              style: VineTheme.titleMediumFont(color: VineTheme.error),
            ),
          const _RecoveryResult(),
        ],
      ),
    );
  }
}

class _RecoveryResult extends StatelessWidget {
  const _RecoveryResult();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ClipRecoveryCubit>().state;
    if (!state.hasReport) return const SizedBox.shrink();

    final report = state.report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        if (state.status == ClipRecoveryStatus.claimed ||
            state.status == ClipRecoveryStatus.imported)
          Text(
            l10n.devOptionsClipRecoveryRecovered(state.lastRecoveredCount),
            style: VineTheme.titleMediumFont(
              color: context.vineColors.accentPositive,
            ),
          ),
        // The verdict leads and the inventory follows it, not the other way
        // round: read in the other order, "23 clips" looks like the finding
        // and "nothing to recover" like a contradiction of it.
        if (!report.hasRecoverableContent)
          Text(
            l10n.devOptionsClipRecoveryEmpty,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
        Text(
          l10n.devOptionsClipRecoveryVisible(
            report.ownedClipCount,
            report.ownedDraftCount,
          ),
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        if (report.foreignGroups.isNotEmpty) ...[
          Text(
            l10n.devOptionsClipRecoveryOtherAccounts,
            style: VineTheme.labelLargeFont(
              color: context.vineColors.primaryText,
            ),
          ),
          ...report.foreignGroups.map(_OwnerGroupRow.new),
        ],
        if (report.orphanFiles.isNotEmpty)
          Text(
            l10n.devOptionsClipRecoveryOrphanFiles(
              report.orphanFiles.length,
              formatByteSize(report.orphanBytes),
            ),
            style: VineTheme.labelLargeFont(
              color: context.vineColors.primaryText,
            ),
          ),
      ],
    );
  }
}

class _OwnerGroupRow extends StatelessWidget {
  const _OwnerGroupRow(this.group);

  final ClipOwnerGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isBusy = context.select((ClipRecoveryCubit c) => c.state.isBusy);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          // Printed in full: a truncated pubkey cannot be matched against an
          // account, and this is the one value the operator has to verify
          // before handing the rows to someone else.
          Text(
            group.ownerPubkey,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.secondaryText,
            ),
          ),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: Text(
                  l10n.devOptionsClipRecoveryCounts(
                    group.clipCount,
                    group.draftCount,
                  ),
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              DivineButton(
                label: l10n.devOptionsClipRecoveryClaim,
                type: DivineButtonType.secondary,
                onPressed: isBusy
                    ? null
                    : () => context.read<ClipRecoveryCubit>().claimOwnerGroup(
                        group,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrphanFileRow extends StatelessWidget {
  const _OrphanFileRow(this.file);

  final OrphanClipFile file;

  @override
  Widget build(BuildContext context) {
    final isBusy = context.select((ClipRecoveryCubit c) => c.state.isBusy);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        spacing: 12,
        children: [
          _OrphanPreview(file),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                // Symbols and numbers only, so the line needs no translation:
                // "2.1 MB · 6.0s", or just the size when the file would not
                // decode.
                Text(
                  [
                    formatByteSize(file.sizeBytes),
                    if (file.duration != null)
                      '${(file.duration!.inMilliseconds / 1000).toStringAsFixed(1)}s',
                  ].join(' · '),
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          DivineButton(
            label: context.l10n.devOptionsClipRecoveryImport,
            type: DivineButtonType.secondary,
            onPressed: isBusy
                ? null
                : () =>
                      context.read<ClipRecoveryCubit>().importOrphanFile(file),
          ),
        ],
      ),
    );
  }
}

/// The frame the scan pulled out of a recording, so the operator can see which
/// one a row is before restoring it. Falls back to a blank tile when no frame
/// could be taken — which, together with a missing duration, is the signal
/// that the file is unlikely to restore into anything playable.
class _OrphanPreview extends StatelessWidget {
  const _OrphanPreview(this.file);

  final OrphanClipFile file;

  @override
  Widget build(BuildContext context) {
    final previewPath = file.previewPath;

    // No semantics: a frame out of a recording cannot be described, and the row
    // already announces the filename, size and length that identify it.
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 48,
          height: 64,
          child: previewPath == null
              ? ColoredBox(color: context.vineColors.surfaceContainer)
              : Image.file(
                  File(previewPath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) =>
                      ColoredBox(color: context.vineColors.surfaceContainer),
                ),
        ),
      ),
    );
  }
}

class _RecoveryActions extends StatelessWidget {
  const _RecoveryActions();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ClipRecoveryCubit>().state;

    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: DivineButton(
            label: l10n.devOptionsClipRecoveryScan,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: state.isBusy
                ? null
                : () => context.read<ClipRecoveryCubit>().scan(),
          ),
        ),
        if (state.hasReport)
          Expanded(
            child: DivineButton(
              label: l10n.shareSheetCopy,
              type: DivineButtonType.secondary,
              expanded: true,
              onPressed: () => ClipboardUtils.copyVerified(
                context,
                state.report.toReportText(),
                message: l10n.devOptionsClipRecoveryCopied,
              ),
            ),
          ),
      ],
    );
  }
}
