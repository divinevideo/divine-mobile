// ABOUTME: Creator analytics dashboard draft for profile owners.
// ABOUTME: Aggregates Funnelcake video and social metrics into creator insights.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/post_analytics_detail/post_analytics_detail_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/features/creator_analytics/video_performance.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_analytics_providers.dart';
import 'package:openvine/providers/post_live_activity_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/screens/creator_analytics/analytics_widgets.dart';
import 'package:openvine/screens/creator_analytics/creator_sounds_card.dart';
import 'package:openvine/screens/creator_analytics/social_counts_info_sheet.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Profile-accessible analytics dashboard for creators.
class CreatorAnalyticsScreen extends ConsumerStatefulWidget {
  const CreatorAnalyticsScreen({super.key});

  static const routeName = 'creator-analytics';
  static const String path = RoutePaths.creatorAnalytics;

  @override
  ConsumerState<CreatorAnalyticsScreen> createState() =>
      _CreatorAnalyticsScreenState();
}

class _CreatorAnalyticsScreenState
    extends ConsumerState<CreatorAnalyticsScreen> {
  late Future<_CreatorAnalyticsData> _analyticsFuture;
  _AnalyticsWindow _selectedWindow = _AnalyticsWindow.last28Days;
  bool _showDiagnostics = false;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _loadAnalytics();
  }

  Future<void> _refresh() async {
    setState(() {
      _analyticsFuture = _loadAnalytics();
    });
    try {
      await _analyticsFuture;
    } on Exception {
      // The FutureBuilder renders the failure. The Retry button and the
      // RefreshIndicator drop this future, so a rethrow would go unhandled.
    }
  }

  Future<_CreatorAnalyticsData> _loadAnalytics() async {
    final authService = ref.read(authServiceProvider);
    final pubkey = authService.currentPublicKeyHex;
    if (pubkey == null || pubkey.isEmpty) {
      throw const _CreatorAnalyticsSignInRequiredException();
    }

    final repository = ref.read(creatorAnalyticsRepositoryProvider);
    final snapshot = await repository.fetchCreatorAnalytics(pubkey);

    return _CreatorAnalyticsData(
      pubkey: pubkey,
      videos: snapshot.videos,
      socialCounts: snapshot.socialCounts,
      diagnostics: snapshot.diagnostics,
      fetchedAt: snapshot.diagnostics.fetchedAt,
    );
  }

  void _openPostAnalytics(VideoPerformance performance) {
    runDetached(
      PostAnalyticsDetailRouteData(
        videoId: performance.video.id,
        $extra: performance,
      ).push<void>(context),
      'open post analytics',
      logName: 'CreatorAnalyticsScreen',
      category: LogCategory.ui,
    );
  }

  List<Widget> _buildOverviewSection(
    _CreatorAnalyticsSummary summary,
    _CreatorAnalyticsData data,
  ) {
    return [
      _KpiGrid(
        summary: summary,
        followerValue: data.socialCountsFailed
            ? context.l10n.analyticsNa
            : StringUtils.formatCompactNumber(
                data.socialCounts?.followerCount ?? 0,
              ),
      ),
      if (!summary.hasViewData && summary.hasEngagementData) ...[
        const SizedBox(height: 12),
        AnalyticsCard(
          title: context.l10n.analyticsViewDataTitle,
          child: Text(
            context.l10n.analyticsViewDataUnavailable,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      _EngagementBreakdown(summary: summary),
      const SizedBox(height: 16),
      _PerformanceHighlights(
        summary: summary,
        onTapPerformance: _openPostAnalytics,
      ),
      const SizedBox(height: 16),
      _TopVideosList(summary: summary, onTapPerformance: _openPostAnalytics),
      const SizedBox(height: 16),
      CreatorSoundsSection(pubkey: data.pubkey, loadedAt: data.fetchedAt),
      const SizedBox(height: 16),
      _DailyTrendCard(summary: summary),
      const SizedBox(height: 16),
      _buildAudienceSnapshotCard(data),
      const SizedBox(height: 16),
      _buildRetentionCard(summary),
    ];
  }

  Widget _buildAudienceSnapshotCard(_CreatorAnalyticsData data) {
    return AnalyticsCard(
      title: context.l10n.analyticsAudienceSnapshot,
      info: (
        onPressed: () => SocialCountsInfoSheet.show(context),
        label: context.l10n.analyticsSocialCountsInfoLabel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.analyticsFollowersCount(
              data.socialCountsFailed
                  ? context.l10n.analyticsNa
                  : StringUtils.formatCompactNumber(
                      data.socialCounts?.followerCount ?? 0,
                    ),
            ),
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.analyticsFollowingCount(
              data.socialCountsFailed
                  ? context.l10n.analyticsNa
                  : StringUtils.formatCompactNumber(
                      data.socialCounts?.followingCount ?? 0,
                    ),
            ),
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.analyticsAudiencePlaceholder,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionCard(_CreatorAnalyticsSummary summary) {
    return AnalyticsCard(
      title: context.l10n.analyticsRetention,
      child: Text(
        summary.hasViewData
            ? context.l10n.analyticsRetentionWithViews
            : context.l10n.analyticsRetentionWithoutViews,
        style: VineTheme.bodySmallFont(
          color: context.vineColors.onSurfaceMuted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.analyticsTitle,
        showBackButton: true,
        onBackPressed: () => context.safePop(),
        actions: [
          DiVineAppBarAction(
            icon: SvgIconSource(
              (_showDiagnostics ? DivineIconName.bugFill : DivineIconName.bug)
                  .assetPath,
            ),
            onPressed: () {
              setState(() {
                _showDiagnostics = !_showDiagnostics;
              });
            },
            tooltip: context.l10n.analyticsDiagnosticsTooltip,
            semanticLabel: context.l10n.analyticsDiagnosticsSemanticLabel,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: FutureBuilder<_CreatorAnalyticsData>(
            future: _analyticsFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final Widget content;

              if (snapshot.connectionState != ConnectionState.done) {
                content = Padding(
                  padding: .only(
                    bottom: MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  child: const Center(child: BrandedLoadingIndicator()),
                );
              } else if (snapshot.hasError) {
                content = _ErrorView(error: snapshot.error, onRetry: _refresh);
              } else if (data == null) {
                content = _ErrorView(
                  error: context.l10n.analyticsUnableToLoad,
                  onRetry: _refresh,
                );
              } else {
                final summary = _CreatorAnalyticsSummary.build(
                  data: data,
                  window: _selectedWindow,
                );
                final useFixture = ref.watch(
                  useFixtureCreatorAnalyticsProvider,
                );

                content = RefreshIndicator(
                  color: VineTheme.onPrimary,
                  backgroundColor: VineTheme.vineGreen,
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      // Important on Android to ensure content is not behind
                      // the device navigation bar.
                      24 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    children: [
                      _RangeSelector(
                        selected: _selectedWindow,
                        onSelected: (window) {
                          setState(() {
                            _selectedWindow = window;
                          });
                        },
                      ),
                      if (_showDiagnostics) ...[
                        const SizedBox(height: 16),
                        _DiagnosticsPanel(
                          diagnostics: data.diagnostics,
                          useFixture: useFixture,
                          onToggleFixture: (enabled) async {
                            ref
                                    .read(
                                      useFixtureCreatorAnalyticsProvider
                                          .notifier,
                                    )
                                    .state =
                                enabled;
                            await _refresh();
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      ..._buildOverviewSection(summary, data),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.analyticsUpdatedTimestamp(
                          _formatLastUpdated(context.l10n, data.fetchedAt),
                        ),
                        style: VineTheme.bodySmallFont(
                          color: context.vineColors.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: content,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final message = _analyticsErrorMessage(context, error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              color: context.vineColors.onSurfaceMuted,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 16),
            DivineButton(
              label: context.l10n.analyticsRetry,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatorAnalyticsSignInRequiredException implements Exception {
  const _CreatorAnalyticsSignInRequiredException();

  @override
  String toString() => 'CreatorAnalyticsSignInRequiredException';
}

String _analyticsErrorMessage(BuildContext context, Object? error) {
  final l10n = context.l10n;
  if (error is _CreatorAnalyticsSignInRequiredException) {
    return l10n.analyticsSignInRequired;
  }
  if (error is CreatorAnalyticsLoadException) {
    return error.kind.localizedMessage(l10n);
  }
  return l10n.analyticsUnableToLoad;
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onSelected});

  final _AnalyticsWindow selected;
  final ValueChanged<_AnalyticsWindow> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _AnalyticsWindow.values.map((window) {
        final isSelected = window == selected;
        return ChoiceChip(
          label: Text(window.labelFor(context.l10n)),
          selected: isSelected,
          selectedColor: VineTheme.vineGreen.withValues(alpha: 0.2),
          labelStyle: VineTheme.bodySmallFont(
            color: isSelected
                ? context.vineColors.primaryText
                : context.vineColors.onSurfaceMuted,
          ),
          side: BorderSide(
            color: isSelected
                ? VineTheme.vineGreen
                : context.vineColors.outlineMuted,
          ),
          onSelected: (_) => onSelected(window),
        );
      }).toList(),
    );
  }
}

class _DiagnosticsPanel extends StatelessWidget {
  const _DiagnosticsPanel({
    required this.diagnostics,
    required this.useFixture,
    required this.onToggleFixture,
  });

  final CreatorAnalyticsDiagnostics diagnostics;
  final bool useFixture;
  final ValueChanged<bool> onToggleFixture;

  @override
  Widget build(BuildContext context) {
    String sourceLabel(AnalyticsDataSource source) {
      return switch (source) {
        AnalyticsDataSource.authorVideos => 'author-videos',
        AnalyticsDataSource.bulkVideoStats => 'bulk-video-stats',
        AnalyticsDataSource.videoViewsEndpoint => 'video-views-endpoint',
        AnalyticsDataSource.socialCounts => 'social-counts',
      };
    }

    final sourceText = diagnostics.sourcesUsed.isEmpty
        ? 'none'
        : diagnostics.sourcesUsed.map(sourceLabel).join(', ');
    final failedSourceText = diagnostics.failedSources.isEmpty
        ? 'none'
        : diagnostics.failedSources.map(sourceLabel).join(', ');

    return AnalyticsCard(
      title: context.l10n.analyticsDiagnostics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.analyticsDiagnosticsTotalVideos(
              diagnostics.totalVideos,
            ),
            style: VineTheme.bodySmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.analyticsDiagnosticsWithViews(
              diagnostics.videosWithAnyViews,
            ),
            style: VineTheme.bodySmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.analyticsDiagnosticsMissingViews(
              diagnostics.videosMissingViews,
            ),
            style: VineTheme.bodySmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.analyticsDiagnosticsHydratedBulk(
              diagnostics.videosHydratedByBulkStats,
            ),
            style: VineTheme.bodySmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.analyticsDiagnosticsHydratedViews(
              diagnostics.videosHydratedByViewsEndpoint,
            ),
            style: VineTheme.bodySmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.analyticsDiagnosticsSources(sourceText),
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.analyticsDiagnosticsFailedSources(failedSourceText),
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.analyticsDiagnosticsUseFixture,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              Switch(
                value: useFixture,
                onChanged: onToggleFixture,
                activeThumbColor: VineTheme.vineGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.summary, required this.followerValue});

  final _CreatorAnalyticsSummary summary;
  final String followerValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.max((constraints.maxWidth - 12) / 2, 140.0);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _KpiCard(
              width: cardWidth,
              label: context.l10n.analyticsVideos,
              value: StringUtils.formatCompactNumber(summary.videoCount),
              icon: DivineIconName.videoCamera,
            ),
            _KpiCard(
              width: cardWidth,
              label: context.l10n.analyticsViews,
              value: summary.hasViewData
                  ? StringUtils.formatCompactNumber(summary.totalViews)
                  : context.l10n.analyticsNa,
              icon: DivineIconName.eye,
            ),
            _KpiCard(
              width: cardWidth,
              label: context.l10n.analyticsInteractions,
              value: summary.hasEngagementData
                  ? StringUtils.formatCompactNumber(summary.totalInteractions)
                  : context.l10n.analyticsNa,
              // No design-system glyph for these two yet (#4833).
              iconWidget: const Icon(
                Icons.touch_app_outlined,
                color: VineTheme.vineGreen,
                size: 20,
              ),
            ),
            _KpiCard(
              width: cardWidth,
              label: context.l10n.analyticsEngagement,
              value:
                  !summary.hasEngagementData || summary.engagementRate == null
                  ? context.l10n.analyticsNa
                  : '${NumberFormat.decimalPattern().format(summary.engagementRate! * 100)}%',
              icon: DivineIconName.trendUp,
            ),
            _KpiCard(
              width: cardWidth,
              label: context.l10n.analyticsFollowers,
              value: followerValue,
              icon: DivineIconName.users,
            ),
            _KpiCard(
              width: cardWidth,
              label: context.l10n.analyticsAvgPerPost,
              value: !summary.hasEngagementData
                  ? context.l10n.analyticsNa
                  : summary.videoCount == 0
                  ? '0'
                  : NumberFormat.decimalPattern().format(
                      summary.averageInteractionsPerVideo,
                    ),
              iconWidget: const Icon(
                Icons.stacked_bar_chart,
                color: VineTheme.vineGreen,
                size: 20,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.width,
    required this.label,
    required this.value,
    this.icon,
    this.iconWidget,
  }) : assert(
         icon == null || iconWidget == null,
         'Pass either icon or iconWidget, not both',
       );

  final double width;
  final String label;
  final String value;

  /// Design-system glyph for this metric.
  final DivineIconName? icon;

  /// Escape hatch for metrics whose glyph the icon set does not cover (#4833).
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconWidget ??
              DivineIcon(icon: icon!, color: VineTheme.vineGreen, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EngagementBreakdown extends StatelessWidget {
  const _EngagementBreakdown({required this.summary});

  final _CreatorAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasEngagementData) {
      return AnalyticsCard(
        title: context.l10n.analyticsInteractionMix,
        child: Text(
          context.l10n.analyticsNa,
          style: VineTheme.bodySmallFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
      );
    }

    final total = summary.totalInteractions;
    final likesShare = total == 0 ? 0.0 : summary.totalLikes / total;
    final commentsShare = total == 0 ? 0.0 : summary.totalComments / total;
    final repostsShare = total == 0 ? 0.0 : summary.totalReposts / total;

    return AnalyticsCard(
      title: context.l10n.analyticsInteractionMix,
      child: Column(
        children: [
          _BreakdownRow(
            label: context.l10n.analyticsLikes,
            value: summary.totalLikes,
            share: likesShare,
            color: VineTheme.likeRed,
          ),
          const SizedBox(height: 8),
          _BreakdownRow(
            label: context.l10n.analyticsComments,
            value: summary.totalComments,
            share: commentsShare,
            color: VineTheme.commentBlue,
          ),
          const SizedBox(height: 8),
          _BreakdownRow(
            label: context.l10n.analyticsReposts,
            value: summary.totalReposts,
            share: repostsShare,
            color: VineTheme.vineGreenDark,
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.share,
    required this.color,
  });

  final String label;
  final int value;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            const Spacer(),
            Text(
              '${StringUtils.formatCompactNumber(value)} (${(share * 100).toStringAsFixed(1)}%)',
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        DivineLinearProgressIndicator(
          value: share,
          minHeight: 8,
          borderRadius: BorderRadius.circular(999),
          backgroundColor: context.vineColors.outlineMuted,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}

class _PerformanceHighlights extends StatelessWidget {
  const _PerformanceHighlights({
    required this.summary,
    required this.onTapPerformance,
  });

  final _CreatorAnalyticsSummary summary;
  final ValueChanged<VideoPerformance> onTapPerformance;

  @override
  Widget build(BuildContext context) {
    return AnalyticsCard(
      title: context.l10n.analyticsPerformanceHighlights,
      child: Column(
        children: [
          _HighlightRow(
            label: context.l10n.analyticsMostViewed,
            title: summary.hasViewData
                ? (summary.mostViewed?.displayTitle ??
                      context.l10n.analyticsNoVideosYet)
                : context.l10n.analyticsViewDataUnavailableShort,
            metricText: summary.hasViewData && summary.mostViewed != null
                ? StringUtils.compactPlural(
                    summary.mostViewed!.views ?? 0,
                    context.l10n.analyticsViewsCount,
                  )
                : context.l10n.analyticsNa,
            onTap: summary.mostViewed == null
                ? null
                : () => onTapPerformance(summary.mostViewed!),
          ),
          const SizedBox(height: 10),
          _HighlightRow(
            label: context.l10n.analyticsMostDiscussed,
            metricText: summary.hasEngagementData
                ? StringUtils.compactPlural(
                    summary.mostDiscussed?.comments ?? 0,
                    context.l10n.analyticsCommentsCount,
                  )
                : context.l10n.analyticsNa,
            title: summary.hasEngagementData
                ? (summary.mostDiscussed?.displayTitle ??
                      context.l10n.analyticsNoVideosYet)
                : context.l10n.analyticsNa,
            onTap: !summary.hasEngagementData || summary.mostDiscussed == null
                ? null
                : () => onTapPerformance(summary.mostDiscussed!),
          ),
          const SizedBox(height: 10),
          _HighlightRow(
            label: context.l10n.analyticsMostReposted,
            metricText: summary.hasEngagementData
                ? StringUtils.compactPlural(
                    summary.mostReposted?.reposts ?? 0,
                    context.l10n.analyticsRepostsCount,
                  )
                : context.l10n.analyticsNa,
            title: summary.hasEngagementData
                ? (summary.mostReposted?.displayTitle ??
                      context.l10n.analyticsNoVideosYet)
                : context.l10n.analyticsNa,
            onTap: !summary.hasEngagementData || summary.mostReposted == null
                ? null
                : () => onTapPerformance(summary.mostReposted!),
          ),
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.label,
    required this.metricText,
    required this.title,
    required this.onTap,
  });

  final String label;
  final String metricText;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(
                label,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              metricText,
              style: VineTheme.bodySmallFont(color: VineTheme.vineGreen),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopVideosList extends StatelessWidget {
  const _TopVideosList({required this.summary, required this.onTapPerformance});

  final _CreatorAnalyticsSummary summary;
  final ValueChanged<VideoPerformance> onTapPerformance;

  @override
  Widget build(BuildContext context) {
    final topVideos = summary.topVideos.take(5).toList();

    return AnalyticsCard(
      title: context.l10n.analyticsTopContent,
      child: topVideos.isEmpty
          ? Text(
              context.l10n.analyticsPublishPrompt,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceMuted,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.hasViewData
                      ? context.l10n.analyticsEngagementRateExplainer
                      : context.l10n.analyticsEngagementRateNoViews,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Spacer(),
                    SizedBox(
                      width: 96,
                      child: Text(
                        context.l10n.analyticsEngagementLabel,
                        textAlign: TextAlign.right,
                        style: VineTheme.bodySmallFont(
                          color: context.vineColors.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < topVideos.length; i++) ...[
                  _TopVideoRow(
                    rank: i + 1,
                    performance: topVideos[i],
                    hasEngagementData: summary.hasEngagementData,
                    onTap: () => onTapPerformance(topVideos[i]),
                  ),
                  if (i != topVideos.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _TopVideoRow extends StatelessWidget {
  const _TopVideoRow({
    required this.rank,
    required this.performance,
    required this.hasEngagementData,
    required this.onTap,
  });

  final int rank;
  final VideoPerformance performance;
  final bool hasEngagementData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            AnalyticsRankBadge(rank: rank),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    performance.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${performance.views != null ? StringUtils.compactPlural(performance.views!, context.l10n.analyticsViewsCount) : context.l10n.analyticsViewsUnavailable} \u2022 '
                    '${hasEngagementData ? StringUtils.compactPlural(performance.interactions, context.l10n.analyticsInteractionsCount) : context.l10n.analyticsNa}',
                    style: VineTheme.bodySmallFont(
                      color: context.vineColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              !hasEngagementData || performance.engagementRate == null
                  ? context.l10n.analyticsNa
                  : '${(performance.engagementRate! * 100).toStringAsFixed(1)}%',
              style: VineTheme.bodySmallFont(color: VineTheme.vineGreen),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-post analytics, addressable at `/creator-analytics/:videoId`.
///
/// The dashboard hands the already-built [VideoPerformance] over in `extra` so
/// the tap stays instant. Arriving without it, such as from the post's Live
/// Activity, the screen resolves the post by its event id or, after an edit
/// retired that id, by its [coordinate].
class PostAnalyticsDetailScreen extends ConsumerWidget {
  const PostAnalyticsDetailScreen({
    required this.videoId,
    this.coordinate,
    this.performance,
    super.key,
  });

  static const routeName = 'creator-analytics-post';
  static const subpath = ':videoId';

  final String videoId;

  /// The post's `kind:pubkey:d-tag` address when opened from its Live
  /// Activity; it still finds the post after an edit retires [videoId].
  final String? coordinate;
  final VideoPerformance? performance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(creatorAnalyticsRepositoryProvider);
    final ownerPubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    // Device-scoped and built once, so it cannot go stale under the cubit.
    final liveActivity = ref.read(postLiveActivityRepositoryProvider);
    return BlocProvider<PostAnalyticsDetailCubit>(
      key: ValueKey((repository, ownerPubkey, videoId)),
      create: (_) {
        final cubit = PostAnalyticsDetailCubit(
          repository: repository,
          ownerPubkey: ownerPubkey,
          videoId: videoId,
          coordinate: coordinate,
          initialPerformance: performance,
          liveActivity: liveActivity,
        );
        runDetached(
          cubit.load(),
          'load post analytics',
          logName: 'CreatorAnalyticsScreen',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: PostAnalyticsDetailView(videoId: videoId),
    );
  }
}

/// The post stats screen for whatever [PostAnalyticsDetailCubit] knows.
class PostAnalyticsDetailView extends StatelessWidget {
  @visibleForTesting
  const PostAnalyticsDetailView({required this.videoId, super.key});

  /// The event id the screen was opened with, the last resort for "View
  /// post".
  final String videoId;

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (PostAnalyticsDetailCubit cubit) => cubit.state.status,
    );
    return _RefreshLiveActivityOnResume(
      child: switch (status) {
        PostAnalyticsDetailStatus.loading =>
          const _PostAnalyticsDetailPlaceholder(
            child: BrandedLoadingIndicator(),
          ),
        PostAnalyticsDetailStatus.ready => const _PostAnalyticsDetailReady(),
        PostAnalyticsDetailStatus.couldNotLoad =>
          const _PostAnalyticsDetailPlaceholder(
            child: _PostStatsCouldNotLoad(),
          ),
        PostAnalyticsDetailStatus.onTheirWay ||
        PostAnalyticsDetailStatus.nothingYet ||
        PostAnalyticsDetailStatus.cantFind => _PostAnalyticsDetailPlaceholder(
          child: _PostStatsMessage(videoId: videoId),
        ),
      },
    );
  }
}

/// Re-checks the Live Activity when the app returns to the foreground, the
/// usual way back after it was dismissed from the Lock Screen.
class _RefreshLiveActivityOnResume extends StatefulWidget {
  const _RefreshLiveActivityOnResume({required this.child});

  final Widget child;

  @override
  State<_RefreshLiveActivityOnResume> createState() =>
      _RefreshLiveActivityOnResumeState();
}

class _RefreshLiveActivityOnResumeState
    extends State<_RefreshLiveActivityOnResume> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => runDetached(
        context.read<PostAnalyticsDetailCubit>().refreshLiveActivity(),
        'refresh post Live Activity',
        logName: 'CreatorAnalyticsScreen',
        category: LogCategory.ui,
      ),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Chrome shared by the states that have no stats to show, so the back button
/// exists before the post is resolved.
class _PostAnalyticsDetailPlaceholder extends StatelessWidget {
  const _PostAnalyticsDetailPlaceholder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.analyticsPostAnalytics,
        showBackButton: true,
        onBackPressed: () =>
            context.safePop(fallback: CreatorAnalyticsScreen.path),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// On their way, nothing yet, or can't find: what is known, plus the post
/// itself and the Stop control.
class _PostStatsMessage extends StatelessWidget {
  const _PostStatsMessage({required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (status, liveMinutes, running) = context.select(
      (PostAnalyticsDetailCubit cubit) => (
        cubit.state.status,
        cubit.state.liveMinutes,
        cubit.state.liveActivityRunning,
      ),
    );
    final message = switch (status) {
      PostAnalyticsDetailStatus.nothingYet => l10n.analyticsNoViewsYet(
        liveMinutes,
      ),
      PostAnalyticsDetailStatus.cantFind => l10n.analyticsCantFindStats,
      _ => l10n.analyticsStatsOnTheirWay,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
        ),
        _ViewPostButton(videoId: videoId),
        if (running) const _StopLiveActivityButton(),
      ],
    );
  }
}

class _PostStatsCouldNotLoad extends StatelessWidget {
  const _PostStatsCouldNotLoad();

  @override
  Widget build(BuildContext context) {
    final running = context.select(
      (PostAnalyticsDetailCubit cubit) => cubit.state.liveActivityRunning,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        Text(
          context.l10n.analyticsUnableToLoad,
          textAlign: TextAlign.center,
          style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
        ),
        DivineButton(
          label: context.l10n.analyticsRetry,
          onPressed: context.read<PostAnalyticsDetailCubit>().retry,
        ),
        // Added only while running so the column leaves no gap for it.
        if (running) const _StopLiveActivityButton(),
      ],
    );
  }
}

/// Opens the post: the version stats found, else its address, else the id
/// the screen was opened with.
class _ViewPostButton extends StatelessWidget {
  const _ViewPostButton({required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    final target = context.select(
      (PostAnalyticsDetailCubit cubit) =>
          cubit.state.performance?.video.id ?? cubit.state.coordinate,
    );
    final id = target ?? videoId;
    return DivineButton(
      label: context.l10n.analyticsViewPost,
      leadingIcon: DivineIconName.playCircle,
      type: DivineButtonType.secondary,
      expanded: true,
      onPressed: id.isEmpty
          ? null
          : () => runDetached(
              VideoDetailRouteData(id: id).push<void>(context),
              'open post video',
              logName: 'CreatorAnalyticsScreen',
              category: LogCategory.ui,
            ),
    );
  }
}

/// Ends the post's Lock Screen Live Activity; shown only while it runs.
///
/// [topGap] is the space above the button, left out with it when hidden.
class _StopLiveActivityButton extends StatelessWidget {
  const _StopLiveActivityButton({this.topGap = 0});

  final double topGap;

  @override
  Widget build(BuildContext context) {
    final running = context.select(
      (PostAnalyticsDetailCubit cubit) => cubit.state.liveActivityRunning,
    );
    if (!running) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: DivineButton(
        label: context.l10n.analyticsStopLiveActivity,
        type: DivineButtonType.secondary,
        expanded: true,
        onPressed: context.read<PostAnalyticsDetailCubit>().stop,
      ),
    );
  }
}

class _PostAnalyticsDetailReady extends StatelessWidget {
  const _PostAnalyticsDetailReady();

  @override
  Widget build(BuildContext context) {
    final (performance, counts) = context.select(
      (PostAnalyticsDetailCubit cubit) =>
          (cubit.state.performance, cubit.state.counts),
    );
    // The cubit only reports ready once it found the post.
    if (performance == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    String show(int? count) => count == null
        ? l10n.analyticsNa
        : StringUtils.formatCompactNumber(count);
    final interactions = counts.interactions;
    final engagementRate = counts.engagementRate;
    double share(int count) =>
        interactions == null || interactions == 0 ? 0 : count / interactions;

    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: l10n.analyticsPostAnalytics,
        showBackButton: true,
        // safePop: this screen has a registered path, so the back stack
        // can be empty on a cold entry and a raw pop would throw GoError.
        onBackPressed: () =>
            context.safePop(fallback: CreatorAnalyticsScreen.path),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              AnalyticsCard(
                title: performance.displayTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MetricPill(
                          label: l10n.analyticsViews,
                          value: show(counts.views),
                        ),
                        _MetricPill(
                          label: l10n.analyticsUniqueViewers,
                          value: show(counts.uniqueViewers),
                        ),
                        _MetricPill(
                          label: l10n.analyticsLikes,
                          value: show(counts.likes),
                        ),
                        _MetricPill(
                          label: l10n.analyticsComments,
                          value: show(counts.comments),
                        ),
                        _MetricPill(
                          label: l10n.analyticsReposts,
                          value: show(counts.reposts),
                        ),
                        _MetricPill(
                          label: l10n.analyticsEngagement,
                          value: engagementRate == null
                              ? l10n.analyticsNa
                              : '${(engagementRate * 100).toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (interactions != null) ...[
                      _BreakdownRow(
                        label: l10n.analyticsLikes,
                        value: counts.likes!,
                        share: share(counts.likes!),
                        color: VineTheme.likeRed,
                      ),
                      const SizedBox(height: 8),
                      _BreakdownRow(
                        label: l10n.analyticsComments,
                        value: counts.comments!,
                        share: share(counts.comments!),
                        color: VineTheme.commentBlue,
                      ),
                      const SizedBox(height: 8),
                      _BreakdownRow(
                        label: l10n.analyticsReposts,
                        value: counts.reposts!,
                        share: share(counts.reposts!),
                        color: VineTheme.vineGreenDark,
                      ),
                    ] else
                      Text(
                        l10n.analyticsNa,
                        style: VineTheme.bodySmallFont(
                          color: context.vineColors.onSurfaceMuted,
                        ),
                      ),
                    const SizedBox(height: 14),
                    DivineButton(
                      label: l10n.analyticsOpenPost,
                      leadingIcon: DivineIconName.playCircle,
                      type: DivineButtonType.secondary,
                      expanded: true,
                      onPressed: performance.video.id.isEmpty
                          ? null
                          : () => runDetached(
                              VideoDetailRouteData(
                                id: performance.video.id,
                              ).push<void>(context),
                              'open post video',
                              logName: 'CreatorAnalyticsScreen',
                              category: LogCategory.ui,
                            ),
                    ),
                    const _StopLiveActivityButton(topGap: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          Text(
            label,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTrendCard extends StatelessWidget {
  const _DailyTrendCard({required this.summary});

  final _CreatorAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasEngagementData) {
      return AnalyticsCard(
        title: context.l10n.analyticsRecentDailyInteractions,
        child: Text(
          context.l10n.analyticsNa,
          style: VineTheme.bodySmallFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
      );
    }

    final points = summary.dailyInteractions;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final maxValue = points.fold<int>(
      0,
      (maxInteractions, point) => point.interactions > maxInteractions
          ? point.interactions
          : maxInteractions,
    );

    return AnalyticsCard(
      title: context.l10n.analyticsRecentDailyInteractions,
      child: points.isEmpty
          ? Text(
              context.l10n.analyticsNoActivityYet,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceMuted,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.analyticsDailyInteractionsExplainer,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.analyticsDailyBarExplainer,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 10),
                ...points.map((point) {
                  final ratio = maxValue == 0
                      ? 0.0
                      : point.interactions / maxValue;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 68,
                          child: Text(
                            point.axisLabel(locale),
                            style: VineTheme.bodySmallFont(
                              color: context.vineColors.onSurfaceMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DivineLinearProgressIndicator(
                            value: ratio,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(999),
                            backgroundColor: context.vineColors.outlineMuted,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              VineTheme.vineGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            StringUtils.formatCompactNumber(point.interactions),
                            textAlign: TextAlign.right,
                            style: VineTheme.bodySmallFont(
                              color: context.vineColors.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

enum _AnalyticsWindow {
  last7Days(Duration(days: 7)),
  last28Days(Duration(days: 28)),
  last90Days(Duration(days: 90)),
  allTime(null);

  const _AnalyticsWindow(this.duration);

  final Duration? duration;
}

extension on _AnalyticsWindow {
  /// 7D / 28D / 90D are numeric abbreviations that read the same everywhere;
  /// only the all-time window is a word, and it shipped as a hardcoded 'All'.
  /// Switched exhaustively so a new window has to make this choice too.
  String labelFor(AppLocalizations l10n) => switch (this) {
    _AnalyticsWindow.allTime => l10n.analyticsWindowAll,
    _AnalyticsWindow.last7Days => '7D',
    _AnalyticsWindow.last28Days => '28D',
    _AnalyticsWindow.last90Days => '90D',
  };
}

class _CreatorAnalyticsData {
  const _CreatorAnalyticsData({
    required this.pubkey,
    required this.videos,
    required this.socialCounts,
    required this.diagnostics,
    required this.fetchedAt,
  });

  /// The creator these analytics were loaded for.
  final String pubkey;
  final List<VideoEvent> videos;
  final SocialCounts? socialCounts;
  final CreatorAnalyticsDiagnostics diagnostics;
  final DateTime fetchedAt;

  bool get socialCountsFailed =>
      diagnostics.failedSources.contains(AnalyticsDataSource.socialCounts);

  bool get engagementFailed =>
      diagnostics.failedSources.contains(AnalyticsDataSource.bulkVideoStats);
}

class _CreatorAnalyticsSummary {
  const _CreatorAnalyticsSummary({
    required this.videoCount,
    required this.totalViews,
    required this.hasViewData,
    required this.hasEngagementData,
    required this.totalLikes,
    required this.totalComments,
    required this.totalReposts,
    required this.totalInteractions,
    required this.engagementRate,
    required this.averageInteractionsPerVideo,
    required this.topVideos,
    required this.dailyInteractions,
    required this.mostViewed,
    required this.mostDiscussed,
    required this.mostReposted,
  });

  final int videoCount;
  final int totalViews;
  final bool hasViewData;
  final bool hasEngagementData;
  final int totalLikes;
  final int totalComments;
  final int totalReposts;
  final int totalInteractions;
  final double? engagementRate;
  final double averageInteractionsPerVideo;
  final List<VideoPerformance> topVideos;
  final List<_DailyInteractionPoint> dailyInteractions;
  final VideoPerformance? mostViewed;
  final VideoPerformance? mostDiscussed;
  final VideoPerformance? mostReposted;

  factory _CreatorAnalyticsSummary.build({
    required _CreatorAnalyticsData data,
    required _AnalyticsWindow window,
  }) {
    final now = DateTime.now();
    final start = window.duration == null
        ? null
        : now.subtract(window.duration!);

    final videos = data.videos.where((video) {
      if (start == null) return true;
      return !_videoTimestamp(video).isBefore(start);
    }).toList();

    final hasEngagementData = !data.engagementFailed;
    final performance =
        videos
            .map(
              (video) => VideoPerformance.fromVideo(
                video,
                hasEngagementData: hasEngagementData,
              ),
            )
            .toList()
          ..sort((a, b) {
            // While engagement is degraded the numbers are hidden, so ranking
            // by them would still assert an order the rest of the dashboard
            // refuses to show. Fall back to views, then recency.
            if (hasEngagementData) {
              final interactionCompare = b.interactions.compareTo(
                a.interactions,
              );
              if (interactionCompare != 0) return interactionCompare;
            }
            if (a.views == null && b.views == null) {
              return b.video.createdAt.compareTo(a.video.createdAt);
            }
            if (a.views == null) return 1;
            if (b.views == null) return -1;
            final viewCompare = b.views!.compareTo(a.views!);
            if (viewCompare != 0) return viewCompare;
            return b.video.createdAt.compareTo(a.video.createdAt);
          });

    final likes = performance.fold<int>(0, (sum, video) => sum + video.likes);
    final comments = performance.fold<int>(
      0,
      (sum, video) => sum + video.comments,
    );
    final reposts = performance.fold<int>(
      0,
      (sum, video) => sum + video.reposts,
    );
    final interactions = likes + comments + reposts;
    final hasViewData = performance.any((video) => video.views != null);
    final views = performance.fold<int>(
      0,
      (sum, video) => sum + (video.views ?? 0),
    );
    final engagementRate = hasViewData && views > 0
        ? interactions / views
        : null;
    final avgInteractions = performance.isEmpty
        ? 0.0
        : interactions / performance.length;

    VideoPerformance? byMetric(int Function(VideoPerformance video) metric) {
      if (performance.isEmpty) return null;
      var best = performance.first;
      for (final video in performance.skip(1)) {
        if (metric(video) > metric(best)) {
          best = video;
        }
      }
      return best;
    }

    VideoPerformance? byNullableMetric(
      int? Function(VideoPerformance video) metric,
    ) {
      final withMetric = performance.where((video) => metric(video) != null);
      if (withMetric.isEmpty) return null;
      var best = withMetric.first;
      for (final video in withMetric.skip(1)) {
        final currentValue = metric(video)!;
        final bestValue = metric(best)!;
        if (currentValue > bestValue) {
          best = video;
        }
      }
      return best;
    }

    final dailyPoints = _buildDailyInteractions(
      videos,
      now: now,
      window: window,
    );

    return _CreatorAnalyticsSummary(
      videoCount: performance.length,
      totalViews: views,
      hasViewData: hasViewData,
      hasEngagementData: hasEngagementData,
      totalLikes: likes,
      totalComments: comments,
      totalReposts: reposts,
      totalInteractions: interactions,
      engagementRate: engagementRate,
      averageInteractionsPerVideo: avgInteractions,
      topVideos: performance,
      dailyInteractions: dailyPoints,
      mostViewed: byNullableMetric((video) => video.views),
      mostDiscussed: byMetric((video) => video.comments),
      mostReposted: byMetric((video) => video.reposts),
    );
  }

  static List<_DailyInteractionPoint> _buildDailyInteractions(
    List<VideoEvent> videos, {
    required DateTime now,
    required _AnalyticsWindow window,
  }) {
    const maxBars = 14;
    final days = switch (window) {
      _AnalyticsWindow.last7Days => 7,
      _AnalyticsWindow.last28Days => 14,
      _AnalyticsWindow.last90Days => 14,
      _AnalyticsWindow.allTime => 14,
    };
    final barDays = math.min(days, maxBars);

    final startDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: barDays - 1));
    final byDay = <String, int>{};

    for (final video in videos) {
      final timestamp = _videoTimestamp(video);
      final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
      if (day.isBefore(startDay)) continue;
      final key = _dayKey(day);
      byDay[key] =
          (byDay[key] ?? 0) + VideoPerformance.fromVideo(video).interactions;
    }

    return List.generate(barDays, (index) {
      final day = startDay.add(Duration(days: index));
      return _DailyInteractionPoint(
        day: day,
        interactions: byDay[_dayKey(day)] ?? 0,
      );
    });
  }
}

class _DailyInteractionPoint {
  const _DailyInteractionPoint({required this.day, required this.interactions});

  final DateTime day;
  final int interactions;

  String axisLabel(String locale) =>
      '${DateFormat.E(locale).format(day)} '
      '${DateFormat.Md(locale).format(day)}';
}

DateTime _videoTimestamp(VideoEvent video) {
  if (video.createdAt > 0) {
    return DateTime.fromMillisecondsSinceEpoch(
      video.createdAt * 1000,
      isUtc: true,
    ).toLocal();
  }
  return video.timestamp.toLocal();
}

String _dayKey(DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}

String _formatLastUpdated(AppLocalizations l10n, DateTime updatedAt) {
  final diff = DateTime.now().difference(updatedAt);
  return LocalizedTimeFormatter.formatDurationAgo(l10n, diff);
}
