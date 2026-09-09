// ABOUTME: Tests for SoundTile widget - displays audio events in list and compact modes
// ABOUTME: Verifies dark theme colors, duration formatting, callbacks, and accessibility

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/sound_tile.dart';

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group('SoundTile', () {
    late AudioEvent testSound;

    setUp(() {
      testSound = AudioEvent(
        id: 'test-audio-event-id-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        pubkey: 'test-pubkey-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        createdAt: 1704067200,
        title: 'Original sound - @testuser',
        duration: 6.2,
        url: 'https://blossom.example/audio.aac',
        mimeType: 'audio/aac',
      );
    });

    Widget buildTestWidget({
      AudioEvent? sound,
      VoidCallback? onTap,
      VoidCallback? onPlayPreview,
      bool compact = false,
      int? videoCount,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: SoundTile(
            sound: sound ?? testSound,
            onTap: onTap,
            onPlayPreview: onPlayPreview,
            compact: compact,
            videoCount: videoCount,
          ),
        ),
      );
    }

    group('Normal mode', () {
      testWidgets('displays sound title', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('Original sound - @testuser'), findsOneWidget);
      });

      testWidgets('displays duration in seconds format', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('6s'), findsOneWidget);
      });

      testWidgets('displays video count when provided', (tester) async {
        await tester.pumpWidget(buildTestWidget(videoCount: 142));

        expect(find.textContaining('142 videos'), findsOneWidget);
      });

      testWidgets('displays singular video when count is 1', (tester) async {
        await tester.pumpWidget(buildTestWidget(videoCount: 1));

        expect(find.textContaining('1 video'), findsOneWidget);
      });

      testWidgets('does not display video count when zero', (tester) async {
        await tester.pumpWidget(buildTestWidget(videoCount: 0));

        expect(find.textContaining('video'), findsNothing);
      });

      testWidgets('does not display video count when null', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.textContaining('video'), findsNothing);
      });

      testWidgets('displays music note icon', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(_divineIcon(DivineIconName.musicNote), findsWidgets);
      });

      testWidgets('displays play arrow icon', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      });

      testWidgets('displays chevron right icon', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(_divineIcon(DivineIconName.caretRight), findsOneWidget);
      });

      testWidgets('calls onTap when tile is tapped', (tester) async {
        var tapped = false;

        await tester.pumpWidget(buildTestWidget(onTap: () => tapped = true));

        await tester.tap(find.byType(SoundTile));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('calls onPlayPreview when play button is tapped', (
        tester,
      ) async {
        var previewTapped = false;

        await tester.pumpWidget(
          buildTestWidget(onPlayPreview: () => previewTapped = true),
        );

        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pumpAndSettle();

        expect(previewTapped, isTrue);
      });

      testWidgets('uses dark theme card background', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(SoundTile),
                matching: find.byType(Container),
              )
              .first,
        );

        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.color, equals(VineTheme.cardBackground));
      });

      testWidgets('uses white text for title', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final titleText = tester.widget<Text>(
          find.text('Original sound - @testuser'),
        );

        expect(titleText.style?.color, equals(Colors.white));
      });

      testWidgets('has correct semantics identifier', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(SoundTile),
                matching: find.byType(Semantics),
              )
              .first,
        );

        expect(semantics.properties.identifier, contains('sound_tile_'));
      });
    });

    group('Compact mode', () {
      testWidgets('displays music note icon in compact mode', (tester) async {
        await tester.pumpWidget(buildTestWidget(compact: true));

        expect(_divineIcon(DivineIconName.musicNote), findsOneWidget);
      });

      testWidgets('displays title in compact mode', (tester) async {
        await tester.pumpWidget(buildTestWidget(compact: true));

        // Compact mode shows title (truncated) to help identify the sound
        expect(find.text('Original sound - @testuser'), findsOneWidget);
      });

      testWidgets('does not display video count in compact mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(compact: true, videoCount: 50));

        expect(find.textContaining('video'), findsNothing);
      });

      testWidgets('does not display duration in compact mode', (tester) async {
        await tester.pumpWidget(buildTestWidget(compact: true));

        // Compact mode no longer shows duration - shows title instead
        expect(find.text('6s'), findsNothing);
      });

      testWidgets('calls onTap when compact tile is tapped', (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          buildTestWidget(compact: true, onTap: () => tapped = true),
        );

        await tester.tap(find.byType(SoundTile));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('uses dark theme card background in compact mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(compact: true));

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SoundTile),
            matching: find.byType(Container),
          ),
        );

        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.color, equals(VineTheme.cardBackground));
      });

      testWidgets('has compact semantics identifier', (tester) async {
        await tester.pumpWidget(buildTestWidget(compact: true));

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(SoundTile),
                matching: find.byType(Semantics),
              )
              .first,
        );

        expect(
          semantics.properties.identifier,
          contains('sound_tile_compact_'),
        );
      });
    });

    group('Duration formatting', () {
      testWidgets('formats short duration as seconds', (tester) async {
        final shortSound = testSound.copyWith(duration: 5.0);

        await tester.pumpWidget(buildTestWidget(sound: shortSound));

        expect(find.text('5s'), findsOneWidget);
      });

      testWidgets('rounds fractional seconds', (tester) async {
        final fractionalSound = testSound.copyWith(duration: 6.7);

        await tester.pumpWidget(buildTestWidget(sound: fractionalSound));

        expect(find.text('7s'), findsOneWidget);
      });

      testWidgets('formats minute+ durations with colon', (tester) async {
        final longSound = testSound.copyWith(duration: 75.0);

        await tester.pumpWidget(buildTestWidget(sound: longSound));

        expect(find.text('1:15'), findsOneWidget);
      });

      testWidgets('handles null duration', (tester) async {
        final nullDurationSound = AudioEvent(
          id: 'null-duration-id-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          pubkey: 'null-duration-pubkey-0123456789abcdef0123456789abcdef0123456789abcdef0123',
          createdAt: 1704067200,
          title: 'No duration sound',
        );

        await tester.pumpWidget(buildTestWidget(sound: nullDurationSound));

        expect(find.text('0s'), findsOneWidget);
      });

      testWidgets('uses full Vine duration for legacy original sounds', (
        tester,
      ) async {
        final legacyOriginalSound = AudioEvent(
          id: 'video_legacy-original-id-0123456789abcdef0123456789abcdef0123456789abcdef',
          pubkey: 'legacy-original-pubkey-0123456789abcdef0123456789abcdef0123456789abcdef',
          createdAt: 1704067200,
          title: 'Original sound - Kenya',
          url: 'https://example.com/video.mp4',
          source: 'Original Sound',
          sourceVideoReference: '34236:legacy-original-pubkey-0123456789abcdef0123456789abcdef0123456789abcdef:legacy-vine',
        );

        await tester.pumpWidget(buildTestWidget(sound: legacyOriginalSound));

        expect(find.text('6s'), findsOneWidget);
        expect(find.text('0s'), findsNothing);
      });

      testWidgets('handles zero duration', (tester) async {
        final zeroSound = testSound.copyWith(duration: 0.0);

        await tester.pumpWidget(buildTestWidget(sound: zeroSound));

        expect(find.text('0s'), findsOneWidget);
      });
    });

    group('Title handling', () {
      testWidgets('displays fallback for null title', (tester) async {
        final noTitleSound = AudioEvent(
          id: 'no-title-id-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          pubkey: 'no-title-pubkey-0123456789abcdef0123456789abcdef0123456789abcdef01234567',
          createdAt: 1704067200,
          duration: 5.0,
        );

        await tester.pumpWidget(buildTestWidget(sound: noTitleSound));

        expect(find.text('Untitled sound'), findsOneWidget);
      });

      testWidgets('truncates long title with ellipsis', (tester) async {
        final longTitleSound = testSound.copyWith(
          title: 'This is a very long title that should be truncated with ellipsis',
        );

        await tester.pumpWidget(buildTestWidget(sound: longTitleSound));

        final titleText = tester.widget<Text>(
          find.textContaining('This is a very long'),
        );

        expect(titleText.overflow, equals(TextOverflow.ellipsis));
        expect(titleText.maxLines, equals(1));
      });
    });

    group('VineTheme color compliance', () {
      testWidgets('music note uses vineGreen color', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final musicNoteIcons = tester.widgetList<DivineIcon>(
          _divineIcon(DivineIconName.musicNote),
        );

        for (final icon in musicNoteIcons) {
          expect(icon.color, equals(VineTheme.vineGreen));
        }
      });

      testWidgets('play button uses vineGreen color', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final playIcon = tester.widget<Icon>(find.byIcon(Icons.play_arrow));

        expect(playIcon.color, equals(VineTheme.vineGreen));
      });

      testWidgets('chevron uses grey color', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final chevronIcon = tester.widget<DivineIcon>(
          _divineIcon(DivineIconName.caretRight),
        );

        expect(chevronIcon.color, equals(VineTheme.lightText));
      });
    });
  });
}
