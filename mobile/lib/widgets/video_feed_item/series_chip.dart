// ABOUTME: The chip on a series episode in a feed: series name and Ep n of N.
// ABOUTME: Tapping it opens the series in the list player at this episode.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_series/video_series_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/routes/lists_routes.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/utils/detached_future.dart';

/// The kind of a curated video list, and so of a series.
const _curatedListKind = 30005;

/// The list a list player is playing, so that its videos do not show a
/// [SeriesChip] that would open that same list again.
class PlayingListScope extends InheritedWidget {
  const PlayingListScope({
    required this.authorPubkey,
    required this.listId,
    required super.child,
    super.key,
  });

  /// The list's author in hex, or null while it is not known.
  final String? authorPubkey;

  /// The list's d-tag.
  final String listId;

  /// The scope around [context], if any.
  static PlayingListScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayingListScope>();

  /// Whether the list played here is the one at [listCoordinate], a
  /// `30005:<pubkey>:<d-tag>` address.
  bool plays(String listCoordinate) =>
      authorPubkey != null &&
      listCoordinate == '$_curatedListKind:$authorPubkey:$listId';

  @override
  bool updateShouldNotify(PlayingListScope oldWidget) =>
      authorPubkey != oldWidget.authorPubkey || listId != oldWidget.listId;
}

/// Shows which series [video] is an episode of, and opens the series at it.
///
/// Shows nothing for a video that names no series, until its series is read,
/// when the series does not hold the video, and inside the player of that
/// series.
class SeriesChip extends ConsumerWidget {
  const SeriesChip({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesCoordinate = video.seriesCoordinate;
    final episodeCoordinate = video.addressableId;
    if (seriesCoordinate == null ||
        episodeCoordinate == null ||
        (PlayingListScope.maybeOf(context)?.plays(seriesCoordinate) ?? false)) {
      return const SizedBox.shrink();
    }
    final repository = ref.watch(curatedListRepositoryProvider);
    return BlocProvider<VideoSeriesCubit>(
      key: ValueKey((repository, seriesCoordinate, episodeCoordinate)),
      create: (_) {
        final cubit = VideoSeriesCubit(
          repository: repository,
          seriesCoordinate: seriesCoordinate,
          episodeCoordinate: episodeCoordinate,
        );
        runDetached(
          cubit.load(),
          'load video series',
          logName: 'SeriesChip',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: const SeriesChipView(),
    );
  }
}

/// Renders the chip once [VideoSeriesCubit] has found the episode.
@visibleForTesting
class SeriesChipView extends StatelessWidget {
  @visibleForTesting
  const SeriesChipView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoSeriesCubit, VideoSeriesState>(
      builder: (context, state) => switch (state) {
        VideoSeriesEpisode() => _SeriesChipButton(episode: state),
        VideoSeriesLoading() || VideoSeriesNone() => const SizedBox.shrink(),
      },
    );
  }
}

class _SeriesChipButton extends StatelessWidget {
  const _SeriesChipButton({required this.episode});

  final VideoSeriesEpisode episode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final series = episode.series;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final episodeNumber = number.format(episode.episodeNumber);
    final episodeCount = number.format(episode.episodeCount);
    return Semantics(
      button: true,
      label: l10n.videoSeriesChipSemanticLabel(
        series.name,
        episodeNumber,
        episodeCount,
      ),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: Padding(
          // The chip is 28 tall; this makes the tap target 48.
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: DecoratedBox(
            decoration: const ShapeDecoration(
              color: VineTheme.scrim65,
              shape: StadiumBorder(),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 8, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  const DivineIcon(
                    icon: .listNumbers,
                    size: 16,
                    color: VineTheme.whiteText,
                  ),
                  Flexible(
                    child: Text(
                      series.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.labelMediumFont(
                        color: VineTheme.whiteText,
                      ),
                    ),
                  ),
                  Text(
                    l10n.videoSeriesChipEpisode(episodeNumber, episodeCount),
                    maxLines: 1,
                    style: VineTheme.labelMediumFont(
                      color: VineTheme.onSurfaceVariant,
                    ),
                  ),
                  DivineIcon(
                    icon: isRtl ? .caretLeft : .caretRight,
                    size: 14,
                    color: VineTheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final series = episode.series;
    runDetached(
      CuratedListByAuthorRouteData(
        pubkey: episode.authorPubkey,
        listId: series.id,
        play: '${episode.listPosition}',
        $extra: CuratedListRouteExtra(listName: series.name, list: series),
      ).push<void>(context),
      'open series',
      logName: 'SeriesChip',
      category: LogCategory.ui,
    );
  }
}
