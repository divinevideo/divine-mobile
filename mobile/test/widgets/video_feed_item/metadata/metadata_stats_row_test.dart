// ABOUTME: Widget tests for the metadata sheet's stats row.
// ABOUTME: Pins loops trailing the interaction stats rather than leading them.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_stats_row.dart';

class _MockVideoInteractionsBloc
    extends MockBloc<VideoInteractionsEvent, VideoInteractionsState>
    implements VideoInteractionsBloc {}

const _vineEraCreatedAt = 1398124800; // 2014-04-22

VideoEvent _video({
  int? originalLoops,
  Map<String, String> rawTags = const {},
  int createdAt = _vineEraCreatedAt,
}) {
  return VideoEvent(
    id: 'a' * 64,
    pubkey: 'b' * 64,
    createdAt: createdAt,
    content: 'caption',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      createdAt * 1000,
      isUtc: true,
    ),
    originalLoops: originalLoops,
    rawTags: rawTags,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required VideoEvent video,
  required VideoInteractionsBloc bloc,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<VideoInteractionsBloc>.value(
          value: bloc,
          child: MetadataStatsRow(video: video),
        ),
      ),
    ),
  );
}

/// Horizontal position of the stat column whose label is [label].
double _labelX(WidgetTester tester, String label) =>
    tester.getTopLeft(find.text(label)).dx;

void main() {
  group(MetadataStatsRow, () {
    late VideoInteractionsBloc bloc;

    setUp(() {
      bloc = _MockVideoInteractionsBloc();
      whenListen(
        bloc,
        const Stream<VideoInteractionsState>.empty(),
        initialState: const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 847,
          commentCount: 23,
          repostCount: 12,
        ),
      );
    });

    testWidgets('renders loops to the right of every interaction stat', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await _pump(
        tester,
        video: _video(originalLoops: 2100000),
        bloc: bloc,
      );

      final loopsX = _labelX(tester, l10n.metadataLoopsLabel(2100000));

      expect(loopsX, greaterThan(_labelX(tester, l10n.metadataLikesLabel)));
      expect(loopsX, greaterThan(_labelX(tester, l10n.metadataCommentsLabel)));
      expect(loopsX, greaterThan(_labelX(tester, l10n.metadataRepostsLabel)));
    });

    testWidgets('leads with likes', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await _pump(
        tester,
        video: _video(originalLoops: 2100000),
        bloc: bloc,
      );

      final likesX = _labelX(tester, l10n.metadataLikesLabel);

      expect(likesX, lessThan(_labelX(tester, l10n.metadataCommentsLabel)));
      expect(likesX, lessThan(_labelX(tester, l10n.metadataRepostsLabel)));
    });

    testWidgets('keeps the count reachable rather than removing it', (
      tester,
    ) async {
      // The sheet is where a hidden card count remains available, so the
      // number itself must still render.
      await _pump(
        tester,
        video: _video(originalLoops: 2100000),
        bloc: bloc,
      );

      expect(find.text('2.1M'), findsOneWidget);
    });

    testWidgets('shows unknown interaction counts without fabricating zero', (
      tester,
    ) async {
      whenListen(
        bloc,
        const Stream<VideoInteractionsState>.empty(),
        initialState: const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
        ),
      );

      await _pump(tester, video: _video(), bloc: bloc);

      expect(find.text('—'), findsNWidgets(3));
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('shows the Vine and diVine breakdown for a classic Vine', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await _pump(
        tester,
        video: _video(
          originalLoops: 2100000,
          rawTags: {'platform': 'vine', 'views': '340'},
        ),
        bloc: bloc,
      );

      expect(find.text(l10n.metadataVineStatsLabel), findsOneWidget);
      expect(find.text(l10n.metadataDivineStatsLabel), findsOneWidget);
    });

    testWidgets('omits the breakdown for a diVine-native post', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await _pump(
        tester,
        video: _video(rawTags: {'views': '340'}),
        bloc: bloc,
      );

      expect(find.text(l10n.metadataVineStatsLabel), findsNothing);
    });
  });
}
