// ABOUTME: Developer options screen for switching between environments
// ABOUTME: Allows switching relay URLs (POC, Staging, Test, Production)
// ABOUTME: Shows page load performance timing data for debugging
// ABOUTME: Includes video format selector for A/B testing server-side formats

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/clip_recovery_screen.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/video_format_preference.dart';
import 'package:openvine/widgets/developer/storage_footprint_section.dart';
import 'package:openvine/widgets/developer_options/shorebird_patch_section.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:unified_logger/unified_logger.dart';

/// Returns a color indicating speed: green (<1s), orange (1-3s), red (>3s).
Color _getSpeedColor(PageLoadRecord record) {
  final ms = record.dataLoadedMs ?? record.contentVisibleMs ?? 0;
  if (ms > 3000) return VineTheme.likeRed;
  if (ms > 1000) return VineTheme.accentOrange;
  return VineTheme.vineGreen;
}

String _recordTitle(PageLoadRecord record) {
  if (record.source == PageLoadSource.route) return record.screenName;
  return '${record.screenName} (${record.source})';
}

String _recordTimingText(BuildContext context, PageLoadRecord record) {
  return context.l10n.devOptionsPageLoadVisible(
    record.contentVisibleMs?.toString() ?? '\u2014',
    record.dataLoadedMs?.toString() ?? '\u2014',
  );
}

String _recordDetailsText(BuildContext context, PageLoadRecord record) {
  final timing = _recordTimingText(context, record);
  final result = record.result;
  if (result == null) return timing;
  return '$timing | result: $result';
}

class _FormatOption {
  const _FormatOption({
    required this.format,
    required this.label,
    required this.urlPattern,
  });
  final VideoPlaybackFormat? format;
  final String label;
  final String urlPattern;
}

const _formatOptions = [
  _FormatOption(
    format: null,
    label: 'Auto (default)',
    urlPattern: 'HLS 720p/480p, 2 requests, bandwidth tracker selects quality',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.raw,
    label: 'Raw original upload',
    urlPattern: '/{hash} — 1 request, 2-16 MB/6s, 7-21 Mbps, no transcode',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.hlsMaster,
    label: 'HLS master playlist',
    urlPattern: '/{hash}/hls/master.m3u8 — 3 requests, adaptive 720p/480p',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.hls720p,
    label: 'HLS 720p stream',
    urlPattern: '/{hash}/hls/stream_720p.m3u8 — 2 requests, 1.5-2.5 MB/6s',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.hls480p,
    label: 'HLS 480p stream',
    urlPattern: '/{hash}/hls/stream_480p.m3u8 — 2 requests, 0.6-1 MB/6s',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.ts720p,
    label: 'Progressive TS 720p',
    urlPattern: '/{hash}/720p — 1 request, MPEG-TS, 1.5-2.5 MB/6s',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.ts480p,
    label: 'Progressive TS 480p',
    urlPattern: '/{hash}/480p — 1 request, MPEG-TS, 0.6-1 MB/6s',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.mp4_720p,
    label: 'Progressive MP4 720p',
    urlPattern: '/{hash}/720p.mp4 — 1 request, faststart, 1.5-2.5 MB/6s',
  ),
  _FormatOption(
    format: VideoPlaybackFormat.mp4_480p,
    label: 'Progressive MP4 480p',
    urlPattern: '/{hash}/480p.mp4 — 1 request, faststart, 0.6-1 MB/6s',
  ),
];

class DeveloperOptionsScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'developer-options';

  /// Path for this route.
  static const String path = RoutePaths.developerOptions;

  const DeveloperOptionsScreen({this.shorebirdUpdaterFactory, super.key});

  @visibleForTesting
  final ShorebirdUpdater Function()? shorebirdUpdaterFactory;

  @override
  ConsumerState<DeveloperOptionsScreen> createState() =>
      _DeveloperOptionsScreenState();
}

class _DeveloperOptionsScreenState
    extends ConsumerState<DeveloperOptionsScreen> {
  @override
  Widget build(BuildContext context) {
    final currentConfig = ref.watch(currentEnvironmentProvider);
    final reviewStatusAsync = ref.watch(
      currentMinorAccountReviewStatusProvider,
    );

    // All available environment configurations
    const environments = [
      EnvironmentConfig.production,
      EnvironmentConfig(environment: AppEnvironment.staging),
      EnvironmentConfig(environment: AppEnvironment.poc),
    ];

    final pageLoadHistory = ref.read(pageLoadHistoryProvider);
    final recentRecords = pageLoadHistory.getRecent(10);
    final slowestRecords = pageLoadHistory.getSlowest(5);

    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.devOptionsTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              // Environment configs
              ...environments.map((env) {
                final isSelected = env == currentConfig;
                return ListTile(
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(env.indicatorColorValue),
                    ),
                  ),
                  title: Text(
                    env.displayName,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    env.relayUrl,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                  trailing: isSelected
                      ? DivineIcon(
                          icon: DivineIconName.check,
                          color: context.vineColors.accentPositive,
                        )
                      : null,
                  onTap: () => _switchEnvironment(context, env, isSelected),
                );
              }),

              // Divider between environments and Shorebird patches
              Divider(color: context.vineColors.outline, height: 32),

              ShorebirdPatchSection(
                preferences: ref.watch(sharedPreferencesProvider),
                updaterFactory: widget.shorebirdUpdaterFactory,
              ),

              // Divider between Shorebird patches and page load times
              Divider(color: context.vineColors.outline, height: 32),

              // Page Load Times section header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  context.l10n.devOptionsPageLoadTimes,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.accentPositive,
                  ),
                ),
              ),

              // Recent page load records
              if (recentRecords.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.l10n.devOptionsNoPageLoads,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                )
              else
                ...recentRecords.map((record) {
                  return ListTile(
                    title: Text(
                      _recordTitle(record),
                      style: VineTheme.labelLargeFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                    subtitle: Text(
                      _recordDetailsText(context, record),
                      style: VineTheme.bodySmallFont(
                        color: context.vineColors.secondaryText,
                      ),
                    ),
                    trailing: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getSpeedColor(record),
                      ),
                    ),
                  );
                }),

              // Slowest Screens subsection
              if (slowestRecords.isNotEmpty) ...[
                Divider(color: context.vineColors.outline, height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    context.l10n.devOptionsSlowestScreens,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.accentPositive,
                    ),
                  ),
                ),
                ...slowestRecords.map((record) {
                  final dataMs = record.dataLoadedMs ?? 0;
                  final result = record.result == null
                      ? ''
                      : ' | result: ${record.result}';
                  return ListTile(
                    title: Text(
                      _recordTitle(record),
                      style: VineTheme.labelLargeFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                    subtitle: Text(
                      '${record.source} | data: ${dataMs}ms$result',
                      style: VineTheme.bodySmallFont(
                        color: _getSpeedColor(record),
                      ),
                    ),
                    trailing: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getSpeedColor(record),
                      ),
                    ),
                  );
                }),
              ],

              Divider(color: context.vineColors.outline, height: 32),

              const StorageFootprintSection(),

              Divider(color: context.vineColors.outline, height: 32),

              ListTile(
                title: Text(
                  context.l10n.devOptionsClipRecovery,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                subtitle: Text(
                  context.l10n.devOptionsClipRecoveryDescription,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
                trailing: const DivineIcon(icon: .caretRight),
                onTap: () => context.push(ClipRecoveryScreen.path),
              ),

              Divider(color: context.vineColors.outline, height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  context.l10n.devOptionsVideoPlaybackFormat,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.accentPositive,
                  ),
                ),
              ),

              ..._formatOptions.map((option) {
                final isSelected =
                    option.format == videoFormatPreference.format;
                return ListTile(
                  title: Text(
                    option.label,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    option.urlPattern,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                  trailing: isSelected
                      ? DivineIcon(
                          icon: DivineIconName.check,
                          color: context.vineColors.accentPositive,
                        )
                      : null,
                  onTap: () => _switchFormat(option.format),
                );
              }),

              if (kDebugMode) ...[
                Divider(color: context.vineColors.outline, height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    context.l10n.devOptionsMinorReviewSimulationTitle,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.accentPositive,
                    ),
                  ),
                ),
                ListTile(
                  title: Text(
                    context.l10n.devOptionsMinorReviewCurrentStateLabel,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    reviewStatusAsync.when(
                      data: (status) => status.isRestricted
                          ? context.l10n.devOptionsMinorReviewStateRestricted(
                              status.currentCase?.state.name ?? 'unknown',
                            )
                          : context.l10n.devOptionsMinorReviewStateActive,
                      loading: () =>
                          context.l10n.devOptionsMinorReviewStateLoading,
                      error: (error, stackTrace) =>
                          context.l10n.devOptionsMinorReviewStateError,
                    ),
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                ),
                ListTile(
                  title: Text(
                    context.l10n.devOptionsMinorReviewClearTitle,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    context.l10n.devOptionsMinorReviewClearSubtitle,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                  onTap: _clearMinorReviewOverride,
                ),
                ListTile(
                  title: Text(
                    context.l10n.devOptionsMinorReviewTeenTitle,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    context.l10n.devOptionsMinorReviewTeenSubtitle,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                  onTap: () => _simulateTeenMinorReview(
                    deadline: MinorReviewResponseDeadline(
                      clock: MinorReviewResponseClock.running,
                      serverNow: DateTime.utc(2026, 8, 26, 14, 30),
                      deadlineAt: DateTime.utc(2026, 9, 10, 14, 30),
                    ),
                    toast: context
                        .l10n
                        .devOptionsMinorReviewResponseClockRunningToast,
                  ),
                ),
                ListTile(
                  title: Text(
                    context.l10n.devOptionsMinorReviewUnder13Title,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    context.l10n.devOptionsMinorReviewUnder13Subtitle,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                  onTap: _simulateUnder13MinorReview,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    context.l10n.devOptionsMinorReviewResponseClockTitle,
                    style: VineTheme.titleSmallFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                ),
                ...[
                  (
                    context.l10n.devOptionsMinorReviewResponseClockRunning,
                    MinorReviewResponseDeadline(
                      clock: MinorReviewResponseClock.running,
                      serverNow: DateTime.utc(2026, 8, 26, 14, 30),
                      deadlineAt: DateTime.utc(2026, 9, 10, 14, 30),
                    ),
                    context.l10n.devOptionsMinorReviewResponseClockRunningToast,
                  ),
                  (
                    context.l10n.devOptionsMinorReviewResponseClockPaused,
                    MinorReviewResponseDeadline(
                      clock: MinorReviewResponseClock.paused,
                      pausedAt: DateTime.utc(2026, 8, 26, 14, 30),
                      remainingDaysWhenPaused: 7.5,
                    ),
                    context.l10n.devOptionsMinorReviewResponseClockPausedToast,
                  ),
                  (
                    context.l10n.devOptionsMinorReviewResponseClockExpired,
                    MinorReviewResponseDeadline(
                      clock: MinorReviewResponseClock.expired,
                      serverNow: DateTime.utc(2026, 9, 11, 14, 30),
                      deadlineAt: DateTime.utc(2026, 9, 10, 14, 30),
                    ),
                    context.l10n.devOptionsMinorReviewResponseClockExpiredToast,
                  ),
                  (
                    context
                        .l10n
                        .devOptionsMinorReviewResponseClockNotApplicable,
                    const MinorReviewResponseDeadline(
                      clock: MinorReviewResponseClock.notApplicable,
                    ),
                    context
                        .l10n
                        .devOptionsMinorReviewResponseClockNotApplicableToast,
                  ),
                  (
                    context.l10n.devOptionsMinorReviewResponseClockMalformed,
                    MinorReviewResponseDeadline.fromJson({
                      'clock': 'running',
                      'serverNow': '2026-08-26T14:30:00.000Z',
                      'deadlineAt': null,
                    }),
                    context
                        .l10n
                        .devOptionsMinorReviewResponseClockMalformedToast,
                  ),
                ].map(
                  (option) => ListTile(
                    title: Text(
                      option.$1,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                    onTap: () => _simulateTeenMinorReview(
                      deadline: option.$2,
                      toast: option.$3,
                    ),
                  ),
                ),
                // Protected-minor (13-15) simulation (#5721): flips the
                // debug-only ProtectedMinorOverrideService so QA can exercise
                // the #175/#176 protections without a real approved-minor
                // account. Sibling of the review simulation above.
                Divider(color: context.vineColors.outline, height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    context.l10n.devOptionsProtectedMinorSimulationTitle,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.accentPositive,
                    ),
                  ),
                ),
                ListTile(
                  title: Text(
                    context.l10n.devOptionsProtectedMinorCurrentStateLabel,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    _protectedMinorStateText(context),
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                ),
                ListTile(
                  title: Text(
                    context.l10n.devOptionsProtectedMinorSimulateTitle,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    context.l10n.devOptionsProtectedMinorSimulateSubtitle,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                  onTap: () => _setProtectedMinorOverride(true),
                ),
                ListTile(
                  title: Text(
                    context.l10n.devOptionsProtectedMinorSimulateNonMinorTitle,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    context
                        .l10n
                        .devOptionsProtectedMinorSimulateNonMinorSubtitle,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                  onTap: () => _setProtectedMinorOverride(false),
                ),
                ListTile(
                  title: Text(
                    context.l10n.devOptionsProtectedMinorClearTitle,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    context.l10n.devOptionsProtectedMinorClearSubtitle,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                  onTap: _clearProtectedMinorOverride,
                ),
              ],

              Divider(color: context.vineColors.outline, height: 32),
              ListTile(
                leading: const DivineIcon(
                  icon: DivineIconName.bracketsAngle,
                  color: VineTheme.warning,
                ),
                title: Text(
                  context.l10n.devOptionsDisableDeveloperMode,
                  style: VineTheme.titleMediumFont(color: VineTheme.warning),
                ),
                subtitle: Text(
                  context.l10n.devOptionsDisableDeveloperModeSubtitle,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
                onTap: _disableDeveloperMode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _disableDeveloperMode() async {
    await ref.read(environmentServiceProvider).disableDeveloperMode();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.devOptionsDisableDeveloperModeToast,
      ),
    );
    context.pop();
  }

  String _protectedMinorStateText(BuildContext context) {
    final protectedMinorAsync = ref.watch(protectedMinorStatusProvider);
    // Plain service read: prefs-backed value, not reactive — the action
    // handlers call setState() after mutating it, matching the minor-review
    // simulation idiom above. This method is only invoked from the kDebugMode
    // section, so release builds do not subscribe to protected-minor providers
    // just by opening Developer Options.
    final protectedMinorOverride = ref
        .watch(protectedMinorOverrideServiceProvider)
        .getOverride();

    final statusText = protectedMinorAsync.when(
      data: (status) => status.isProtectedMinor
          ? context.l10n.devOptionsProtectedMinorStateProtected
          : context.l10n.devOptionsProtectedMinorStateNotProtected,
      loading: () => context.l10n.devOptionsProtectedMinorStateLoading,
      error: (error, stackTrace) =>
          context.l10n.devOptionsProtectedMinorStateError,
    );
    final overrideText = switch (protectedMinorOverride) {
      true => context.l10n.devOptionsProtectedMinorOverrideProtected,
      false => context.l10n.devOptionsProtectedMinorOverrideNotProtected,
      null => context.l10n.devOptionsProtectedMinorOverrideNone,
    };

    return '$statusText\n$overrideText';
  }

  Future<void> _switchEnvironment(
    BuildContext context,
    EnvironmentConfig newConfig,
    bool isSelected,
  ) async {
    // Don't switch if already selected
    if (isSelected) return;

    // Show confirmation dialog
    final confirmed = await VineBottomSheet.show<bool>(
      context: context,
      scrollable: false,
      contentTitle: context.l10n.devOptionsSwitchEnvironmentTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            context.l10n.devOptionsSwitchEnvironmentMessage(
              newConfig.displayName,
            ),
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
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
                  label: context.l10n.devOptionsCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: context.l10n.devOptionsSwitch,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (confirmed != true) return;

    Log.info(
      'Switching environment to ${newConfig.displayName}',
      name: 'DeveloperOptions',
      category: LogCategory.system,
    );

    // Clear in-memory video events
    final videoEventService = ref.read(videoEventServiceProvider);
    videoEventService.clearVideoEvents();

    // Switch environment (clears video cache from DB and updates config)
    await switchEnvironment(ref, newConfig);

    Log.info(
      'Environment switched to ${newConfig.displayName}',
      name: 'DeveloperOptions',
      category: LogCategory.system,
    );

    // Show confirmation and go back
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.devOptionsSwitchedTo(newConfig.displayName),
          // The environment's own indicator colour is the point of this toast.
          backgroundColor: Color(newConfig.indicatorColorValue),
        ),
      );
      context.pop();
    }
  }

  Future<void> _switchFormat(VideoPlaybackFormat? format) async {
    await videoFormatPreference.setFormat(format);
    await openVineMediaCache.clearCache();

    final videoEventService = ref.read(videoEventServiceProvider);
    videoEventService.clearVideoEvents();

    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.devOptionsSwitchedFormat(format?.name ?? 'HLS (default)'),
      ),
    );
  }

  Future<void> _setProtectedMinorOverride(bool isProtectedMinor) async {
    await ref
        .read(protectedMinorOverrideServiceProvider)
        .setOverride(isProtectedMinor);
    ref.invalidate(protectedMinorStatusProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        isProtectedMinor
            ? context.l10n.devOptionsProtectedMinorEnabledToast
            : context.l10n.devOptionsProtectedMinorNonMinorToast,
      ),
    );
    setState(() {});
  }

  Future<void> _clearProtectedMinorOverride() async {
    await ref.read(protectedMinorOverrideServiceProvider).clearOverride();
    ref.invalidate(protectedMinorStatusProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.devOptionsProtectedMinorClearedToast,
      ),
    );
    setState(() {});
  }

  Future<void> _clearMinorReviewOverride() async {
    final service = ref.read(minorAccountReviewOverrideServiceProvider);
    await service.clearOverride();
    ref.invalidate(currentMinorAccountReviewStatusProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.devOptionsMinorReviewClearedToast,
      ),
    );
    setState(() {});
  }

  Future<void> _simulateTeenMinorReview({
    required MinorReviewResponseDeadline deadline,
    required String toast,
  }) async {
    final l10n = context.l10n;
    final authService = ref.read(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex;
    final moderationPubkey = ref
        .read(moderationLabelServiceProvider)
        .divineModerationPubkeyHex;

    final override = MinorAccountReviewStatus(
      restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
      currentCase: MinorReviewCase(
        id: 'sim-teen-review',
        state: MinorReviewCaseState.restrictedPendingUserResponse,
        suspectedAgeBand: SuspectedAgeBand.age13To15,
        allowedResolution: MinorReviewResolutionType.parentVideoOrEmail,
        instructions: MinorReviewInstructions(
          title: l10n.minorAccountReviewDefaultTitle,
          body: l10n.minorAccountReviewDefaultBody,
        ),
        supportEmail: AppConstants.supportEmail,
        responseDeadline: deadline,
        moderationConversationPubkey: moderationPubkey,
        moderationConversationId: currentPubkey == null
            ? null
            : DmRepository.computeConversationId([
                currentPubkey,
                moderationPubkey,
              ]),
      ),
    );

    await ref
        .read(minorAccountReviewOverrideServiceProvider)
        .setOverride(override);
    ref.invalidate(currentMinorAccountReviewStatusProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(DivineSnackbarContainer.snackBar(toast));
    setState(() {});
  }

  Future<void> _simulateUnder13MinorReview() async {
    final l10n = context.l10n;
    final authService = ref.read(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex;
    final moderationPubkey = ref
        .read(moderationLabelServiceProvider)
        .divineModerationPubkeyHex;

    final override = MinorAccountReviewStatus(
      restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
      currentCase: MinorReviewCase(
        id: 'sim-under13-review',
        state: MinorReviewCaseState.restrictedPendingSupportEmail,
        suspectedAgeBand: SuspectedAgeBand.under13,
        allowedResolution: MinorReviewResolutionType.supportEmailOnly,
        instructions: MinorReviewInstructions(
          title: l10n.minorAccountReviewUnder13SupportTitle,
          body: l10n.minorAccountReviewUnder13Heading,
        ),
        supportEmail: AppConstants.supportEmail,
        moderationConversationPubkey: moderationPubkey,
        moderationConversationId: currentPubkey == null
            ? null
            : DmRepository.computeConversationId([
                currentPubkey,
                moderationPubkey,
              ]),
      ),
    );

    await ref
        .read(minorAccountReviewOverrideServiceProvider)
        .setOverride(override);
    ref.invalidate(currentMinorAccountReviewStatusProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.devOptionsMinorReviewUnder13EnabledToast,
      ),
    );
    setState(() {});
  }
}
