// ABOUTME: Settings "Storage" screen — clear cached media (never the clip
// ABOUTME: library) and audit the clip library for broken entries.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/storage/storage_cubit.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/storage_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/byte_size_format.dart';

/// Settings screen for clearing caches and auditing the clip library.
class StorageManagementPage extends ConsumerWidget {
  /// Creates the page.
  const StorageManagementPage({super.key});

  /// Named route.
  static const String routeName = 'storage-management';

  /// Route path.
  ///
  /// A flat, first-class path (not nested under `/settings`) so
  /// `routeNormalizationProvider` can round-trip it through
  /// `parseRoute`/`buildRoute`. A `/settings/…` path collapses to
  /// `RouteType.settings` and gets normalized straight back to the
  /// Settings screen.
  static const String path = RoutePaths.storageManagement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(storageManagementServiceProvider);
    final recoverAllCaches = ref.watch(recoverAllCachesProvider);
    return BlocProvider(
      key: ValueKey((service, recoverAllCaches)),
      create: (_) => StorageCubit(
        service: service,
        recoverAllCaches: recoverAllCaches,
      )..loadCacheSize(),
      child: const StorageManagementView(),
    );
  }
}

/// The storage screen UI. Split from [StorageManagementPage] so it can be
/// tested with a stubbed [StorageCubit].
class StorageManagementView extends StatelessWidget {
  /// Creates the view.
  @visibleForTesting
  const StorageManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.settingsStorageTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: MultiBlocListener(
        // One listener per operation. Statuses are sticky — `cacheStatus`
        // stays `cleared` for the rest of the visit — so a single
        // first-match-wins listener would keep re-announcing the first
        // outcome and never reach the later ones.
        listeners: [
          BlocListener<StorageCubit, StorageState>(
            listenWhen: (prev, curr) => prev.cacheStatus != curr.cacheStatus,
            listener: _announceCache,
          ),
          BlocListener<StorageCubit, StorageState>(
            listenWhen: (prev, curr) =>
                prev.libraryStatus != curr.libraryStatus,
            listener: _announceLibrary,
          ),
          BlocListener<StorageCubit, StorageState>(
            listenWhen: (prev, curr) =>
                prev.recoveryStatus != curr.recoveryStatus,
            listener: _announceRepair,
          ),
        ],
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: EdgeInsets.only(
                bottom: 32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                DivineSectionHeader(
                  context.l10n.settingsStorageCacheSectionTitle,
                ),
                const _CacheSection(),
                DivineSectionHeader(
                  context.l10n.settingsStorageLibrarySectionTitle,
                ),
                const _LibrarySection(),
                DivineSectionHeader(
                  context.l10n.settingsStorageRepairSectionTitle,
                ),
                const _RepairSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _announceCache(BuildContext context, StorageState state) {
    final l10n = context.l10n;
    _announce(context, switch (state.cacheStatus) {
      StorageCacheStatus.cleared => l10n.settingsStorageCleared,
      StorageCacheStatus.failure => l10n.settingsStorageError,
      _ => null,
    });
  }

  void _announceLibrary(BuildContext context, StorageState state) {
    final l10n = context.l10n;
    _announce(context, switch (state.libraryStatus) {
      StorageLibraryStatus.cleaned => l10n.settingsStorageBrokenClipsRemoved,
      StorageLibraryStatus.failure => l10n.settingsStorageError,
      _ => null,
    });
  }

  void _announceRepair(BuildContext context, StorageState state) {
    final l10n = context.l10n;
    _announce(context, switch (state.recoveryStatus) {
      StorageRecoveryStatus.recovered => l10n.settingsStorageRepairSuccess,
      StorageRecoveryStatus.failure => l10n.settingsStorageRepairFailure,
      _ => null,
    });
  }

  void _announce(BuildContext context, String? message) {
    if (message == null) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }
}

class _CacheSection extends StatelessWidget {
  const _CacheSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select((StorageCubit c) => c.state.cacheStatus);
    final bytes = context.select((StorageCubit c) => c.state.cacheSizeBytes);
    final busy =
        status == StorageCacheStatus.loading ||
        status == StorageCacheStatus.clearing ||
        status == StorageCacheStatus.initial;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text(
            l10n.settingsStorageCacheDescription,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
          Text(
            busy
                ? l10n.settingsStorageMeasuring
                : l10n.settingsStorageCacheInUse(formatByteSize(bytes)),
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const _CacheLimitControl(),
          DivineButton(
            label: l10n.settingsStorageClearButton,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: busy || bytes == 0
                ? null
                : () => _confirmClear(context, bytes),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, int bytes) async {
    final l10n = context.l10n;
    final cubit = context.read<StorageCubit>();
    final confirmed = await VineBottomSheet.show<bool>(
      context: context,
      scrollable: false,
      contentTitle: l10n.settingsStorageClearConfirmTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.settingsStorageClearConfirmMessage(formatByteSize(bytes)),
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: DivineButton(
                  label: l10n.settingsCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: l10n.settingsStorageClearConfirmAction,
                  type: DivineButtonType.error,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (confirmed ?? false) await cubit.clearCaches();
  }
}

class _CacheLimitControl extends StatelessWidget {
  const _CacheLimitControl();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<StorageCubit>();
    final limit = context.select(
      (StorageCubit c) => c.state.videoCacheLimitBytes,
    );
    final clampedBytes = limit.clamp(kCacheLimitMinBytes, kCacheLimitMaxBytes);
    final clamped = clampedBytes.toDouble();
    final approxVideos = clampedBytes ~/ kApproxVideoBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.settingsStorageMaxVideoCacheLabel,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
            Text(
              formatByteSize(limit),
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.accentPositive,
              ),
            ),
          ],
        ),
        DivineSlider(
          min: kCacheLimitMinBytes.toDouble(),
          max: kCacheLimitMaxBytes.toDouble(),
          divisions:
              (kCacheLimitMaxBytes - kCacheLimitMinBytes) ~/
              (512 * 1024 * 1024),
          value: clamped,
          onChanged: (value) => cubit.previewVideoCacheLimit(value.round()),
          onChangeEnd: (value) => cubit.commitVideoCacheLimit(value.round()),
        ),
        Text(
          l10n.settingsStorageApproxVideos(approxVideos),
          style: VineTheme.bodySmallFont(color: context.vineColors.mutedText),
        ),
      ],
    );
  }
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select((StorageCubit c) => c.state.libraryStatus);
    final brokenCount = context.select(
      (StorageCubit c) => c.state.brokenClips.length,
    );
    final busy =
        status == StorageLibraryStatus.scanning ||
        status == StorageLibraryStatus.cleaning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text(
            l10n.settingsStorageLibraryDescription,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
          if (status == StorageLibraryStatus.scanned && brokenCount == 0 ||
              status == StorageLibraryStatus.cleaned)
            Text(
              l10n.settingsStorageLibraryHealthy,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.accentPositive,
              ),
            )
          else if (status == StorageLibraryStatus.scanned && brokenCount > 0)
            Text(
              l10n.settingsStorageBrokenClipsFound(brokenCount),
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
          if (status == StorageLibraryStatus.scanned && brokenCount > 0)
            DivineButton(
              label: l10n.settingsStorageRemoveBrokenButton,
              type: DivineButtonType.error,
              expanded: true,
              onPressed: () => _confirmRemoveBroken(context),
            )
          else
            DivineButton(
              label: l10n.settingsStorageScanButton,
              type: DivineButtonType.secondary,
              expanded: true,
              onPressed: busy
                  ? null
                  : () => context.read<StorageCubit>().scanLibrary(),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveBroken(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<StorageCubit>();
    final confirmed = await VineBottomSheet.show<bool>(
      context: context,
      scrollable: false,
      contentTitle: l10n.settingsStorageRemoveBrokenConfirmTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: DivineButton(
                  label: l10n.settingsCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: l10n.commonDelete,
                  type: DivineButtonType.error,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (confirmed ?? false) await cubit.removeBrokenClips();
  }
}

/// Last-resort reset for a corrupted install. Unlike [_CacheSection] — which
/// only trims downloaded media — this wipes the Hive boxes, Application Support
/// and temp directories too, signing the user out in the process. It stays
/// clear of the word "cache" so it cannot be mistaken for a thorough variant
/// of the routine clear above.
class _RepairSection extends StatelessWidget {
  const _RepairSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select((StorageCubit c) => c.state.recoveryStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text(
            l10n.settingsStorageRepairDescription,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
          if (status == StorageRecoveryStatus.recovering)
            Text(
              l10n.settingsStorageRepairInProgress,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
            )
          else if (status == StorageRecoveryStatus.recovered)
            Text(
              l10n.settingsStorageRepairSuccess,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.accentPositive,
              ),
            )
          else if (status == StorageRecoveryStatus.failure)
            Text(
              l10n.settingsStorageRepairFailure,
              style: VineTheme.titleMediumFont(color: VineTheme.error),
            ),
          DivineButton(
            label: l10n.settingsStorageRepairButton,
            type: DivineButtonType.error,
            expanded: true,
            onPressed: status == StorageRecoveryStatus.recovering
                ? null
                : () => _confirmRepair(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRepair(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<StorageCubit>();
    // Measure alongside the open sheet rather than on screen entry: walking
    // Application Support is too slow to pay for on every visit, and the
    // number only informs this one decision.
    unawaited(cubit.loadRecoveryFootprint());
    final confirmed = await VineBottomSheet.show<bool>(
      context: context,
      scrollable: false,
      contentTitle: l10n.settingsStorageRepairConfirmTitle,
      // The sheet is a sibling route, so it does not inherit the page's
      // provider — hand the cubit down for _RepairFootprint.
      contentWrapper: (_, child) =>
          BlocProvider<StorageCubit>.value(value: cubit, child: child),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.settingsStorageRepairConfirmMessage,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _RepairFootprint(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: DivineButton(
                  label: l10n.settingsCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: l10n.settingsStorageRepairConfirmAction,
                  type: DivineButtonType.error,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (confirmed ?? false) await cubit.recoverFromCorruptedCache();
  }
}

/// How much the repair frees, shown inside the confirmation sheet. Renders
/// nothing until the measurement lands, and nothing at all if it fails — the
/// size informs the decision but must not block or alarm.
class _RepairFootprint extends StatelessWidget {
  const _RepairFootprint();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select((StorageCubit c) => c.state.recoveryStatus);
    final bytes = context.select(
      (StorageCubit c) => c.state.recoveryFootprintBytes,
    );

    return switch (status) {
      StorageRecoveryStatus.measuring => Text(
        l10n.settingsStorageMeasuring,
        style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
      ),
      StorageRecoveryStatus.measured => Text(
        l10n.settingsStorageRepairFootprint(formatByteSize(bytes)),
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
