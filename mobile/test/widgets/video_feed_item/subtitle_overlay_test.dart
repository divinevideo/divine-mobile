import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:openvine/widgets/video_feed_item/subtitle_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

VideoEvent _makeVideo({
  String id =
      'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234',
}) => VideoEvent(
  id: id,
  pubkey: 'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3',
  createdAt: 1700000000,
  content: 'Test video',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
  videoUrl: 'https://example.com/video.mp4',
  textTrackContent: '''
WEBVTT

1
00:00:00.100 --> 00:00:01.000
Hello there

2
00:00:01.100 --> 00:00:02.000
Second line
''',
);

class _RebuildingSubtitleHost extends StatefulWidget {
  const _RebuildingSubtitleHost({
    required this.video,
    required this.positions,
    super.key,
  });

  final VideoEvent video;
  final Stream<Duration> positions;

  @override
  State<_RebuildingSubtitleHost> createState() =>
      _RebuildingSubtitleHostState();
}

class _RebuildingSubtitleHostState extends State<_RebuildingSubtitleHost> {
  Duration initialPosition = const Duration(milliseconds: 500);

  void rebuildAt(Duration position) {
    setState(() {
      initialPosition = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SubtitleCueStreamPill(
      video: widget.video,
      positionStream: widget.positions,
      initialPosition: initialPosition,
    );
  }
}

void main() {
  group('renders', () {
    testWidgets('shows attribution only for a verified machine translation', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final video = _makeVideo();
      final provider = subtitleTrackProvider(
        videoId: video.id,
        textTrackContent: video.textTrackContent,
        appLocaleCode: 'en',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            provider.overrideWith(
              (ref) async => SubtitleFetchResult(
                SubtitleFetchStatus.available,
                cues: SubtitleService.parseVtt(video.textTrackContent!),
                isMachineTranslated: true,
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SubtitleCueStreamPill(
                video: video,
                positionStream: const Stream<Duration>.empty(),
                initialPosition: const Duration(milliseconds: 300),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Machine-translated'), findsOneWidget);
      expect(find.text('Hello there'), findsOneWidget);
    });

    testWidgets(
      'replaces the visible cue immediately when its track refreshes',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final video = _makeVideo();
        final hostKey = GlobalKey<_RebuildingSubtitleHostState>();
        final positions = StreamController<Duration>.broadcast();
        addTearDown(positions.close);
        final provider = subtitleTrackProvider(
          videoId: video.id,
          textTrackContent: video.textTrackContent,
          appLocaleCode: 'en',
        );
        var track = SubtitleFetchResult(
          SubtitleFetchStatus.available,
          cues: SubtitleService.parseVtt(
            video.textTrackContent!
                .replaceAll('Hello there', 'Translated')
                .replaceAll('Second line', 'Translated second'),
          ),
          isMachineTranslated: true,
        );
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            provider.overrideWith((ref) async => track),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: _RebuildingSubtitleHost(
                  key: hostKey,
                  video: video,
                  positions: positions.stream,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Translated'), findsOneWidget);
        expect(find.text('Machine-translated'), findsOneWidget);
        positions.add(const Duration(milliseconds: 1200));
        await tester.pump();
        await tester.pump();
        expect(find.text('Translated second'), findsOneWidget);

        track = SubtitleFetchResult(
          SubtitleFetchStatus.available,
          cues: SubtitleService.parseVtt(video.textTrackContent!),
        );
        container.invalidate(provider);
        await tester.pump();
        await tester.pump();
        expect(find.text('Second line'), findsOneWidget);
        expect(find.text('Translated second'), findsNothing);
        expect(find.text('Machine-translated'), findsNothing);
        positions.add(const Duration(milliseconds: 500));
        await tester.pump();
        await tester.pump();
        expect(find.text('Hello there'), findsOneWidget);

        await container
            .read(subtitleVisibilityProvider.notifier)
            .setEnabled(false);
        await tester.pump();
        hostKey.currentState!.rebuildAt(const Duration(milliseconds: 1200));
        await tester.pump();
        await container
            .read(subtitleVisibilityProvider.notifier)
            .setEnabled(true);
        await tester.pump();
        await tester.pump();
        expect(find.text('Second line'), findsOneWidget);
      },
    );

    testWidgets('does not rebuild the caption pill for ticks within one cue', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final positions = StreamController<Duration>.broadcast();
      addTearDown(positions.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SubtitleCueStreamPill(
                  video: _makeVideo(),
                  positionStream: positions.stream,
                  initialPosition: const Duration(milliseconds: 300),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Hello there'), findsOneWidget);
      expect(find.text('Machine-translated'), findsNothing);
      final initialTextWidget = tester.widget<Text>(find.text('Hello there'));

      positions.add(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();

      expect(find.text('Hello there'), findsOneWidget);
      expect(
        identical(
          initialTextWidget,
          tester.widget<Text>(find.text('Hello there')),
        ),
        isTrue,
      );

      positions.add(const Duration(milliseconds: 1200));
      await tester.pump();
      await tester.pump();

      expect(find.text('Second line'), findsOneWidget);
    });

    testWidgets('keeps bridged cue state across parent rebuilds', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final positions = StreamController<Duration>.broadcast();
      addTearDown(positions.close);
      final hostKey = GlobalKey<_RebuildingSubtitleHostState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: _RebuildingSubtitleHost(
                  key: hostKey,
                  video: _makeVideo(),
                  positions: positions.stream,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Hello there'), findsOneWidget);

      positions.add(const Duration(milliseconds: 1050));
      await tester.pump();
      await tester.pump();
      expect(find.text('Hello there'), findsOneWidget);

      hostKey.currentState!.rebuildAt(const Duration(milliseconds: 1050));
      await tester.pump();

      expect(find.text('Hello there'), findsOneWidget);
    });
  });
}
