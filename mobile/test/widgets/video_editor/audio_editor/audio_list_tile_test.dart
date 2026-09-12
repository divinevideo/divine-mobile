// ABOUTME: Tests for AudioListTile widget
// ABOUTME: Validates rendering, selected state, and tap callback

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_list_tile.dart';

AudioEvent _createTestAudioEvent({
  String id = 'test-sound-id',
  String pubkey = 'test-pubkey',
  int createdAt = 1704067200,
  String? url,
  String? title,
  String? source,
  double? duration,
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    url: url ?? 'https://example.com/audio/$id.mp3',
    title: title,
    source: source,
    duration: duration,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(AudioListTile, () {
    late bool tapped;

    setUp(() {
      tapped = false;
    });

    Widget buildWidget({
      required AudioEvent audio,
      bool isSelected = false,
      bool isPlaying = false,
      bool isUnavailable = false,
      int? videoCount,
      String? semanticIdentifier,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AudioListTile(
            audio: audio,
            isSelected: isSelected,
            isPlaying: isPlaying,
            isUnavailable: isUnavailable,
            videoCount: videoCount,
            semanticIdentifier: semanticIdentifier,
            onTap: () => tapped = true,
          ),
        ),
      );
    }

    group('semantics', () {
      // The lip-sync E2E flow picks a sound by tapping the first tile of a
      // search result (e2e/maestro/tests/lipSyncModeRecordClip.yaml). Every
      // other test here matches on rendered text and would stay green with the
      // anchor dropped.
      testWidgets('exposes the E2E identifier it is given', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(
            audio: _createTestAudioEvent(title: 'Anthem'),
            semanticIdentifier: SemanticIds.audioSoundTile(3),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier(SemanticIds.audioSoundTile(3)),
          findsOneWidget,
        );

        handle.dispose();
      });

      // The editor's audio row reuses this tile without an anchor, so an
      // identifier that defaulted to something non-null would collide with the
      // indexed ones the picker hands out.
      testWidgets('carries no identifier when none is given', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(audio: _createTestAudioEvent(title: 'Anthem')),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier(SemanticIds.audioSoundTile(0)),
          findsNothing,
        );

        handle.dispose();
      });
    });

    group('unavailable', () {
      testWidgets('says the file is gone and cannot be chosen', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            audio: _createTestAudioEvent(title: 'Gone Sound', duration: 6),
            isUnavailable: true,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text('Gone Sound'), findsOneWidget);
        expect(find.text(l10n.videoEditorAudioFileMissing), findsOneWidget);

        await tester.tap(find.text('Gone Sound'));
        await tester.pumpAndSettle();
        expect(
          tapped,
          isFalse,
          reason:
              'Selecting it would attach a source that plays nothing to the '
              'draft (#8023).',
        );
      });

      testWidgets('leaves a playable sound tappable', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            audio: _createTestAudioEvent(title: 'Here Sound', duration: 6),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorAudioFileMissing), findsNothing);

        await tester.tap(find.text('Here Sound'));
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      });
    });

    group('Rendering', () {
      testWidgets('renders sound title', (tester) async {
        final audio = _createTestAudioEvent(title: 'My Cool Sound');
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.text('My Cool Sound'), findsOneWidget);
      });

      testWidgets('renders untitled sound l10n string when title is null', (
        tester,
      ) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorAudioUntitledSound), findsOneWidget);
      });

      testWidgets('renders formatted duration', (tester) async {
        final audio = _createTestAudioEvent(duration: 125.0);
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('02:05'), findsOneWidget);
      });

      testWidgets('renders 00:01 when duration is null', (tester) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('00:01'), findsOneWidget);
      });

      testWidgets('renders source when available', (tester) async {
        final audio = _createTestAudioEvent(
          duration: 60.0,
          source: 'Artist Name',
        );
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('Artist Name'), findsOneWidget);
      });

      testWidgets('renders ListTile', (tester) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.byType(ListTile), findsOneWidget);
      });
    });

    group('Reuse count', () {
      testWidgets('renders the localized reuse count', (tester) async {
        await tester.pumpWidget(
          buildWidget(audio: _createTestAudioEvent(), videoCount: 12),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.textContaining(l10n.soundVideoCount(12)), findsOneWidget);
      });

      testWidgets('renders the singular form for one reuse', (tester) async {
        await tester.pumpWidget(
          buildWidget(audio: _createTestAudioEvent(), videoCount: 1),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.textContaining(l10n.soundVideoCount(1)), findsOneWidget);
      });

      // A picker row for an unused sound should read the same as one whose
      // count has not arrived yet, rather than advertising the zero.
      testWidgets('renders no reuse count for an unused sound', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            audio: _createTestAudioEvent(duration: 12),
            videoCount: 0,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.textContaining(l10n.soundVideoCount(0)), findsNothing);
        // The subtitle still renders; only the count segment is absent.
        expect(find.textContaining('00:12'), findsOneWidget);
      });

      testWidgets('renders no reuse count when it is unknown', (tester) async {
        await tester.pumpWidget(
          buildWidget(audio: _createTestAudioEvent(duration: 12)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.textContaining(l10n.soundVideoCount(1)), findsNothing);
        expect(find.textContaining('00:12'), findsOneWidget);
      });
    });

    group('Selected state', () {
      testWidgets('renders no trailing indicator when not selected', (
        tester,
      ) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        final tile = tester.widget<ListTile>(find.byType(ListTile));
        expect(tile.trailing, isNull);
      });

      testWidgets('renders trailing indicator when selected', (tester) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio, isSelected: true));
        await tester.pump();

        final tile = tester.widget<ListTile>(find.byType(ListTile));
        expect(tile.trailing, isNotNull);
      });
    });

    group('Callbacks', () {
      testWidgets('calls onTap when tile is tapped', (tester) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });
    });

    group('Duration formatting', () {
      testWidgets('formats single digit seconds correctly', (tester) async {
        final audio = _createTestAudioEvent(duration: 5.0);
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('00:05'), findsOneWidget);
      });

      testWidgets('formats minutes correctly', (tester) async {
        final audio = _createTestAudioEvent(duration: 90.0);
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('01:30'), findsOneWidget);
      });

      testWidgets('truncates fractional seconds', (tester) async {
        final audio = _createTestAudioEvent(duration: 65.7);
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('01:05'), findsOneWidget);
      });
    });

    group('playing indicator motion', () {
      Widget buildWithMotion({required bool disableAnimations}) {
        return MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: Scaffold(
              body: AudioListTile(
                audio: _createTestAudioEvent(),
                // The indicator is the tile's `trailing`, which only exists
                // while selected. Without this the tests below pass vacuously.
                isSelected: true,
                isPlaying: true,
                onTap: () {},
              ),
            ),
          ),
        );
      }

      testWidgets('animates the bars when motion is allowed', (tester) async {
        await tester.pumpWidget(buildWithMotion(disableAnimations: false));
        await tester.pump();

        expect(tester.binding.transientCallbackCount, greaterThan(0));
      });

      testWidgets('stops the ticker when motion is disabled', (tester) async {
        // The controller has to actually stop, not merely go unpainted. A
        // ticker with no listener still schedules frames, so the app never
        // reaches quiescence and every XCUITest hierarchy query on the audio
        // editor waits out its timeout.
        await tester.pumpWidget(buildWithMotion(disableAnimations: true));
        await tester.pump();

        expect(tester.binding.transientCallbackCount, 0);
      });
    });
  });
}
