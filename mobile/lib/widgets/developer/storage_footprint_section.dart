// ABOUTME: Developer-only readout of every directory the app writes to.
// ABOUTME: Answers "the OS reports tens of GB but the cache readout says MB".

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/storage/storage_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/storage_footprint.dart';
import 'package:openvine/providers/storage_providers.dart';
import 'package:openvine/utils/byte_size_format.dart';
import 'package:openvine/utils/clipboard_utils.dart';

/// Developer Options section that measures the app's on-disk footprint.
///
/// The Storage settings screen reports only what "Clear caches" can reclaim,
/// so it cannot explain a footprint that sits in the documents directory or
/// the durable database. This walks every root and lists the biggest entries
/// in each, with a copy action so a support thread gets numbers instead of
/// guesses.
class StorageFootprintSection extends ConsumerWidget {
  /// Creates the section.
  const StorageFootprintSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(storageManagementServiceProvider);
    return BlocProvider<StorageCubit>(
      key: ValueKey(service),
      create: (_) => StorageCubit(service: service),
      child: const StorageFootprintView(),
    );
  }
}

/// The section UI. Split from [StorageFootprintSection] so it can be tested
/// with a stubbed [StorageCubit].
class StorageFootprintView extends StatelessWidget {
  /// Creates the view.
  @visibleForTesting
  const StorageFootprintView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select((StorageCubit c) => c.state.footprintStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.devOptionsStorageFootprint,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.accentPositive,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text(
                l10n.devOptionsStorageFootprintDescription,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
              if (status == StorageFootprintStatus.measuring)
                Text(
                  l10n.settingsStorageMeasuring,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                )
              else if (status == StorageFootprintStatus.failure)
                Text(
                  l10n.devOptionsStorageFootprintFailure,
                  style: VineTheme.titleMediumFont(color: VineTheme.error),
                )
              else if (status == StorageFootprintStatus.measured)
                const _FootprintResult(),
              const _FootprintActions(),
            ],
          ),
        ),
      ],
    );
  }
}

class _FootprintResult extends StatelessWidget {
  const _FootprintResult();

  @override
  Widget build(BuildContext context) {
    final footprint = context.select((StorageCubit c) => c.state.footprint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          context.l10n.devOptionsStorageFootprintTotal(
            formatByteSize(footprint.totalBytes),
          ),
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        ...footprint.roots.map(_RootBreakdown.new),
      ],
    );
  }
}

class _RootBreakdown extends StatelessWidget {
  const _RootBreakdown(this.root);

  final StorageFootprintRoot root;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${root.label} — ${formatByteSize(root.totalBytes)}',
          style: VineTheme.labelLargeFont(
            color: context.vineColors.primaryText,
          ),
        ),
        ...root.largestChildren.map(_ChildRow.new),
      ],
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow(this.entry);

  final StorageFootprintEntry entry;

  @override
  Widget build(BuildContext context) {
    final style = VineTheme.bodySmallFont(
      color: context.vineColors.secondaryText,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          SizedBox(
            width: 72,
            child: Text(formatByteSize(entry.bytes), style: style),
          ),
          Expanded(
            child: Text(
              entry.isDirectory ? '${entry.name}/' : entry.name,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _FootprintActions extends StatelessWidget {
  const _FootprintActions();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select((StorageCubit c) => c.state.footprintStatus);

    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: DivineButton(
            label: l10n.devOptionsStorageFootprintMeasure,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: status == StorageFootprintStatus.measuring
                ? null
                : () => context.read<StorageCubit>().measureFootprint(),
          ),
        ),
        if (status == StorageFootprintStatus.measured)
          Expanded(
            child: DivineButton(
              label: l10n.shareSheetCopy,
              type: DivineButtonType.secondary,
              expanded: true,
              onPressed: () => ClipboardUtils.copyVerified(
                context,
                context.read<StorageCubit>().state.footprint.toReportText(),
                message: l10n.devOptionsStorageFootprintCopied,
              ),
            ),
          ),
      ],
    );
  }
}
