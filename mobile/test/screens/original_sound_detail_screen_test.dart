// ABOUTME: Tests for OriginalSoundDetailScreen - view-only sound detail
// ABOUTME: for videos without shared audio events.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/original_sound_detail_screen.dart';

void main() {
  group(OriginalSoundDetailScreen, () {
    const testPubkey =
        'pubkey123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';
    const testVideoId =
        'video0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';

    VideoEvent createTestVideo({String? authorName}) {
      final now = DateTime.now();
      return VideoEvent(
        id: testVideoId,
        pubkey: testPubkey,
        content: 'Test video',
        videoUrl: 'https://example.com/video.mp4',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        title: 'Cat Video',
        authorName: authorName,
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
    }

    Widget buildTestWidget({
      String pubkey = testPubkey,
      VideoEvent? sourceVideo,
    }) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: OriginalSoundDetailScreen(
            creatorPubkey: pubkey,
            sourceVideo: sourceVideo,
          ),
        ),
      );
    }

    group('Header', () {
      testWidgets('shows "Original sound" with creator name', (tester) async {
        final video = createTestVideo(authorName: 'Jake Lara');

        await tester.pumpWidget(buildTestWidget(sourceVideo: video));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Original sound - Jake Lara'),
          findsOneWidget,
        );
      });

      testWidgets('shows video title when available', (tester) async {
        final video = createTestVideo(authorName: 'Jake Lara');

        await tester.pumpWidget(buildTestWidget(sourceVideo: video));
        await tester.pumpAndSettle();

        expect(find.text('Cat Video'), findsOneWidget);
      });

      testWidgets('shows generated name when no author name', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Should show some form of display name (generated from pubkey)
        // Both header and body contain "Original sound" text
        expect(find.textContaining('Original sound'), findsAtLeastNWidgets(1));
      });
    });

    group('Content', () {
      testWidgets('does not show Use Sound button', (tester) async {
        final video = createTestVideo(authorName: 'Jake Lara');

        await tester.pumpWidget(buildTestWidget(sourceVideo: video));
        await tester.pumpAndSettle();

        expect(find.text('Use Sound'), findsNothing);
      });

      testWidgets('does not show Preview button', (tester) async {
        final video = createTestVideo(authorName: 'Jake Lara');

        await tester.pumpWidget(buildTestWidget(sourceVideo: video));
        await tester.pumpAndSettle();

        expect(find.text('Preview'), findsNothing);
      });

      testWidgets('shows info message about audio not shared', (tester) async {
        final video = createTestVideo(authorName: 'Jake Lara');

        await tester.pumpWidget(buildTestWidget(sourceVideo: video));
        await tester.pumpAndSettle();

        expect(find.textContaining('not available separately'), findsOneWidget);
      });

      testWidgets('shows music_off icon', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.music_off_outlined), findsOneWidget);
      });
    });

    group('App bar', () {
      testWidgets('shows Sound title', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Sound'), findsOneWidget);
      });

      testWidgets('renders DiVineAppBar', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(DiVineAppBar), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('has correct semantics identifier', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(OriginalSoundDetailScreen),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Semantics &&
                      w.properties.identifier == 'original_sound_detail_screen',
                ),
              )
              .first,
        );

        expect(
          semantics.properties.identifier,
          equals('original_sound_detail_screen'),
        );
      });
    });

    group('Route helpers', () {
      test('pathForPubkey generates correct path', () {
        expect(
          OriginalSoundDetailScreen.pathForPubkey(testPubkey),
          equals('/original-sound/$testPubkey'),
        );
      });

      test('path constant matches expected pattern', () {
        expect(
          OriginalSoundDetailScreen.path,
          equals('/original-sound/:pubkey'),
        );
      });
    });
  });
}
