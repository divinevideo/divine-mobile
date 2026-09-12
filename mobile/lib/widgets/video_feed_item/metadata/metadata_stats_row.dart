// ABOUTME: Stats row for the metadata expanded sheet.
// ABOUTME: Shows Likes, Comments, Reposts, Loops with vertical dividers.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/string_utils.dart';

/// Horizontal stats row displaying engagement counts for a video.
///
/// Reads live counts from [VideoInteractionsBloc] (likes, comments, reposts)
/// and static loops from [VideoEvent.totalLoops]. The headline numbers are
/// combined totals (archival Vine + live Divine); classic Vines additionally
/// get a per-source breakdown underneath.
///
/// Loops sits last rather than first. Video cards hide small public counts
/// because they discourage viewing, so this sheet is where the number stays
/// reachable — present, but not leading the row.
///
/// Layout follows Figma node `I11251:226991;9113:176278`:
/// four stat columns separated by vertical dividers.
class MetadataStatsRow extends StatelessWidget {
  const MetadataStatsRow({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoInteractionsBloc, VideoInteractionsState>(
      builder: (context, state) {
        final isLoading = state.isLoading;

        final showVineBreakdown =
            video.isOriginalVine && video.hasOriginalVineMetrics;

        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.vineColors.outlineDisabled),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    // Top padding shrinks to 4 px so the gap between the
                    // overview section's bottom (20 px padding) and the
                    // first stat row totals 24 px, matching Figma node
                    // 15675:27356's inter-group spacing.
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 4,
                      bottom: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth - 48,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatColumn(
                            count: state.likeCount,
                            label: context.l10n.metadataLikesLabel,
                            isLoading: isLoading,
                          ),
                          const _VerticalDivider(),
                          _StatColumn(
                            count: state.commentCount,
                            label: context.l10n.metadataCommentsLabel,
                            isLoading: isLoading,
                          ),
                          const _VerticalDivider(),
                          _StatColumn(
                            count: state.repostCount,
                            label: context.l10n.metadataRepostsLabel,
                            isLoading: isLoading,
                          ),
                          const _VerticalDivider(),
                          // Loops trails the interaction stats: the count
                          // stays available to anyone who wants it without
                          // leading the row.
                          _StatColumn(
                            count: video.totalLoops,
                            label: context.l10n.metadataLoopsLabel(
                              video.totalLoops,
                            ),
                            isLoading: false,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (showVineBreakdown)
                _VineDivineBreakdown(video: video, state: state),
            ],
          ),
        );
      },
    );
  }
}

/// Per-source engagement breakdown for classic Vines.
///
/// Shows the archival Vine-era counts and the live Divine counts as two
/// compact lines under the combined stats row, so the headline numbers can
/// stay big while the split remains visible.
class _VineDivineBreakdown extends StatelessWidget {
  const _VineDivineBreakdown({required this.video, required this.state});

  final VideoEvent video;
  final VideoInteractionsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String compact(int? count) => StringUtils.formatCompactNumber(count ?? 0);

    final divineViews = int.tryParse(video.rawTags['views'] ?? '') ?? 0;
    final divineLikes = divineOnlyCount(
      displayCount: state.isLoading ? null : state.likeCount,
      archivedCount: video.originalLikes,
      liveCount: video.nostrLikeCount,
    );
    final divineComments = divineOnlyCount(
      displayCount: state.isLoading ? null : state.commentCount,
      archivedCount: video.originalComments,
      liveCount: video.nostrCommentCount,
    );
    final divineReposts = divineOnlyCount(
      displayCount: state.isLoading ? null : state.repostCount,
      archivedCount: video.originalReposts,
      liveCount: video.nostrRepostCount,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          _BreakdownLine(
            label: l10n.metadataVineStatsLabel,
            value: l10n.metadataVineStatsLine(
              compact(video.originalLoops),
              compact(video.originalLikes),
              compact(video.originalComments),
              compact(video.originalReposts),
            ),
          ),
          _BreakdownLine(
            label: l10n.metadataDivineStatsLabel,
            value: l10n.metadataDivineStatsLine(
              compact(divineViews),
              compact(divineLikes),
              compact(divineComments),
              compact(divineReposts),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            label,
            style: VineTheme.labelSmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: VineTheme.labelSmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.count,
    required this.label,
    required this.isLoading,
  });

  final int? count;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final displayValue = isLoading || count == null
        ? '—'
        : StringUtils.formatCompactNumber(count!);

    return Column(
      children: [
        Text(
          displayValue,
          style: VineTheme.statNumberFont(
            color: context.vineColors.primaryText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: VineTheme.labelSmallFont(
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: VerticalDivider(
        width: 2,
        thickness: 2,
        color: context.vineColors.outlineMuted,
      ),
    );
  }
}
