// ABOUTME: Tests for AudioAttributionRow widget - displays sound attribution on videos.
// ABOUTME: Verifies shared audio, original sound fallback, dark theme, tap, and accessibility.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/widgets/video_feed_item/audio_attribution_row.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:unified_logger/unified_logger.dart';

void main() {
  group(AudioAttributionRow, () {
    // Full 64-character Nostr IDs as required by CLAUDE.md
    const testAudioEventId =
        'audio0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';
    const testPubkey =
        'pubkey123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';
    const testVideoId =
        'video0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';
    const sourceCreatorPubkey =
        'source123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';

    late AudioEvent testAudio;

    setUp(() {
      testAudio = AudioEvent(
        id: testAudioEventId,
        pubkey: testPubkey,
        createdAt: 1704067200,
        title: 'Original sound - @testuser',
        duration: 6.2,
        url: 'https://blossom.example/audio.aac',
        mimeType: 'audio/aac',
      );
    });

    VideoEvent createVideoWithAudio({InspiredByInfo? inspiredByVideo}) {
      final now = DateTime.now();
      return VideoEvent(
        id: testVideoId,
        pubkey: testPubkey,
        content: 'Test video with audio',
        videoUrl: 'https://example.com/video.mp4',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        title: 'Test Video',
        audioEventId: testAudioEventId,
        inspiredByVideo: inspiredByVideo,
      );
    }

    VideoEvent createVideoWithoutAudio() {
      final now = DateTime.now();
      return VideoEvent(
        id: testVideoId,
        pubkey: testPubkey,
        content: 'Test video without audio',
        videoUrl: 'https://example.com/video.mp4',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        title: 'Test Video',
      );
    }

    Widget buildTestWidget({
      required VideoEvent video,
      AudioEvent? audioOverride,
      bool resolvesAudio = true,
      Object? audioError,
      List<Override> additionalOverrides = const [],
      ValueNotifier<int>? rebuilds,
    }) {
      return ProviderScope(
        overrides: [
          if (video.hasAudioReference)
            soundByIdProvider(testAudioEventId).overrideWith((ref) async {
              if (audioError != null) throw audioError;
              return resolvesAudio ? audioOverride ?? testAudio : null;
            }),
          ...additionalOverrides,
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: rebuilds == null
                ? AudioAttributionRow(video: video)
                : ValueListenableBuilder<int>(
                    valueListenable: rebuilds,
                    builder: (context, rebuild, child) => Column(
                      children: [
                        Text('Rebuild $rebuild'),
                        AudioAttributionRow(video: video),
                      ],
                    ),
                  ),
          ),
        ),
      );
    }

    int renderPathLogCount() => LogCaptureService()
        .getRecentLogs()
        .where(
          (entry) =>
              entry.name == 'AudioAttributionRow' &&
              (entry.message.startsWith('Audio event not found') ||
                  entry.message.startsWith('Failed to load audio')),
        )
        .length;

    group('Original sound (no audio reference)', () {
      testWidgets('renders nothing for videos without audio reference', (
        tester,
      ) async {
        final video = createVideoWithoutAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        // Should render SizedBox.shrink - no visible content
        expect(
          find.descendant(
            of: find.byType(AudioAttributionRow),
            matching: find.byType(SizedBox),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Original sound'), findsNothing);
      });
    });

    group('Shared audio (has audio reference)', () {
      testWidgets('displays sound title', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Original sound - @testuser'),
          findsOneWidget,
        );
      });

      testWidgets('displays music note icon with vineGreen color', (
        tester,
      ) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final divineIcons = tester.widgetList<DivineIcon>(
          find.descendant(
            of: find.byType(AudioAttributionRow),
            matching: find.byType(DivineIcon),
          ),
        );
        final musicNoteIcon = divineIcons.firstWhere(
          (icon) => icon.icon == DivineIconName.musicNote,
        );
        expect(musicNoteIcon.color, equals(VineTheme.vineGreen));
      });

      testWidgets('displays fallback when sound has no title', (tester) async {
        final video = createVideoWithAudio();
        final noTitleAudio = AudioEvent(
          id: testAudioEventId,
          pubkey: testPubkey,
          createdAt: 1704067200,
          duration: 6.2,
          url: 'https://blossom.example/audio.aac',
        );

        await tester.pumpWidget(
          buildTestWidget(video: video, audioOverride: noTitleAudio),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Original sound'), findsOneWidget);
      });

      testWidgets('shows creator, publisher, license, and public tags', (
        tester,
      ) async {
        final creditedAudio = testAudio.copyWith(
          creatorName: 'Original Artist',
          licenseName: 'CC BY 4.0',
          publicTags: const ['field-recording'],
        );

        await tester.pumpWidget(
          buildTestWidget(
            video: createVideoWithAudio(),
            audioOverride: creditedAudio,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('By Original Artist'), findsOneWidget);
        expect(find.textContaining('Shared by'), findsOneWidget);
        expect(find.textContaining('CC BY 4.0'), findsOneWidget);
        expect(find.textContaining('#field-recording'), findsOneWidget);
        expect(find.textContaining('personalLabel'), findsNothing);
      });

      testWidgets('displays caret right icon', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final divineIcons = tester.widgetList<DivineIcon>(
          find.descendant(
            of: find.byType(AudioAttributionRow),
            matching: find.byType(DivineIcon),
          ),
        );
        expect(
          divineIcons.any((icon) => icon.icon == DivineIconName.caretRight),
          isTrue,
        );
      });

      testWidgets('uses white text color', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final text = tester.widget<Text>(
          find.textContaining('Original sound - @testuser'),
        );
        expect(text.style?.color, equals(VineTheme.whiteText));
      });
    });

    // The video carries an audio reference, so it did reuse a sound. When the
    // referenced event can't be fetched the credit must degrade rather than
    // vanish (#6185).
    group('Unresolvable audio reference', () {
      testWidgets('does not log when the null fallback rebuilds', (
        tester,
      ) async {
        final rebuilds = ValueNotifier<int>(0);
        addTearDown(rebuilds.dispose);
        final logsBefore = renderPathLogCount();

        await tester.pumpWidget(
          buildTestWidget(
            video: createVideoWithAudio(),
            resolvesAudio: false,
            rebuilds: rebuilds,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Sound unavailable'), findsOneWidget);
        final logsAfterInitialRender = renderPathLogCount();

        rebuilds.value = 1;
        await tester.pump();

        expect(find.text('Rebuild 1'), findsOneWidget);
        expect(renderPathLogCount(), logsAfterInitialRender);
        expect(logsAfterInitialRender, logsBefore);
      });

      testWidgets('does not log when the error fallback rebuilds', (
        tester,
      ) async {
        final rebuilds = ValueNotifier<int>(0);
        addTearDown(rebuilds.dispose);
        final logsBefore = renderPathLogCount();

        await tester.pumpWidget(
          buildTestWidget(
            video: createVideoWithAudio(),
            audioError: StateError('relay unavailable'),
            rebuilds: rebuilds,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Sound unavailable'), findsOneWidget);
        final logsAfterInitialRender = renderPathLogCount();

        rebuilds.value = 1;
        await tester.pump();

        expect(find.text('Rebuild 1'), findsOneWidget);
        expect(renderPathLogCount(), logsAfterInitialRender);
        expect(logsAfterInitialRender, logsBefore);
      });

      testWidgets('shows a neutral label when the audio event is null', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(
          buildTestWidget(video: createVideoWithAudio(), resolvesAudio: false),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(l10n.audioAttributionUnavailableSound),
          findsOneWidget,
        );
        expect(
          find.textContaining(l10n.audioAttributionOriginalSound),
          findsNothing,
        );
      });

      testWidgets('credits the reused sound creator when inspired-by is set', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            video: createVideoWithAudio(
              inspiredByVideo: const InspiredByInfo(
                addressableId: '34236:$sourceCreatorPubkey:vine-xyz',
              ),
            ),
            resolvesAudio: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            UserProfile.defaultDisplayNameFor(sourceCreatorPubkey),
          ),
          findsOneWidget,
        );
      });

      testWidgets('uses the same display-only fallback on provider errors', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(
          buildTestWidget(
            video: createVideoWithAudio(),
            audioError: StateError('relay unavailable'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(l10n.audioAttributionUnavailableSound),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AudioAttributionRow),
            matching: find.byType(GestureDetector),
          ),
          findsNothing,
        );
      });

      testWidgets('is not a reuse entry point', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(video: createVideoWithAudio(), resolvesAudio: false),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(AudioAttributionRow),
            matching: find.byType(GestureDetector),
          ),
          findsNothing,
        );

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(AudioAttributionRow),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(semantics.properties.button, isFalse);
      });

      testWidgets('renders no caret, since there is nowhere to navigate', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(video: createVideoWithAudio(), resolvesAudio: false),
        );
        await tester.pumpAndSettle();

        final divineIcons = tester.widgetList<DivineIcon>(
          find.descendant(
            of: find.byType(AudioAttributionRow),
            matching: find.byType(DivineIcon),
          ),
        );
        expect(
          divineIcons.any((icon) => icon.icon == DivineIconName.caretRight),
          isFalse,
        );
      });
    });

    group('Loading state', () {
      testWidgets('shows skeleton during loading', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              soundByIdProvider(testAudioEventId).overrideWith((ref) async {
                return testAudio;
              }),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              home: Scaffold(
                backgroundColor: Colors.black,
                body: AudioAttributionRow(video: video),
              ),
            ),
          ),
        );

        // Pump once - at this point the future may still be loading
        await tester.pump();

        // After settling, should show music note icon (either skeleton or loaded)
        await tester.pumpAndSettle();
        final divineIcons = tester.widgetList<DivineIcon>(
          find.descendant(
            of: find.byType(AudioAttributionRow),
            matching: find.byType(DivineIcon),
          ),
        );
        expect(
          divineIcons.any((icon) => icon.icon == DivineIconName.musicNote),
          isTrue,
        );
      });
    });

    group('Accessibility', () {
      testWidgets('has correct semantics identifier for shared audio', (
        tester,
      ) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(AudioAttributionRow),
                matching: find.byType(Semantics),
              )
              .first,
        );

        expect(
          semantics.properties.identifier,
          equals('audio_attribution_row'),
        );
      });

      testWidgets('has semantic label with sound info', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(AudioAttributionRow),
                matching: find.byType(Semantics),
              )
              .first,
        );

        expect(
          semantics.properties.label,
          contains('Sound: Original sound - @testuser'),
        );
      });

      testWidgets('is marked as button for tap interaction', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(AudioAttributionRow),
                matching: find.byType(Semantics),
              )
              .first,
        );

        expect(semantics.properties.button, isTrue);
      });
    });

    group('Bundled sound attribution', () {
      testWidgets('displays artist via source for bundled sounds', (
        tester,
      ) async {
        final video = createVideoWithAudio();
        final bundledAudio = AudioEvent(
          id: 'bundled_freesound_crowd',
          pubkey: 'bundled',
          createdAt: 0,
          title: 'Oh No No No Crowd',
          duration: 5.9,
          url: 'asset://assets/sounds/oh-no-no-no-crowd.mp3',
          mimeType: 'audio/mpeg',
          source: 'ThePauny via Freesound',
        );

        await tester.pumpWidget(
          buildTestWidget(video: video, audioOverride: bundledAudio),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Oh No No No Crowd'), findsOneWidget);
        expect(find.textContaining('ThePauny via Freesound'), findsOneWidget);
      });

      testWidgets('does not try to fetch profile for bundled sounds', (
        tester,
      ) async {
        final video = createVideoWithAudio();
        final bundledAudio = AudioEvent(
          id: 'bundled_freesound_crowd',
          pubkey: 'bundled',
          createdAt: 0,
          title: 'Oh No No No Crowd',
          duration: 5.9,
          url: 'asset://assets/sounds/oh-no-no-no-crowd.mp3',
          mimeType: 'audio/mpeg',
          source: 'ThePauny via Freesound',
        );

        await tester.pumpWidget(
          buildTestWidget(video: video, audioOverride: bundledAudio),
        );
        await tester.pumpAndSettle();

        // Should show source, not @npub... or default display name
        expect(find.textContaining('npub'), findsNothing);
      });
    });

    group('Dark theme compliance', () {
      testWidgets('uses dark background with opacity', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(AudioAttributionRow),
                matching: find.byType(Container),
              )
              .first,
        );

        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.color?.a, lessThan(0.5));
      });
    });
  });
}
