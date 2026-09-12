import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/inspired_by_attribution_row.dart';

void main() {
  const firstCreator =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const secondCreator =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const explicitCreator =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  group('renders', () {
    testWidgets('renders compact count for multiple clip source credits', (
      tester,
    ) async {
      final video = VideoEvent(
        id: 'video-id',
        pubkey:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263000),
        videoUrl: 'https://cdn.example.com/video.mp4',
        clipSourceCredits: const [
          ClipSourceCredit(
            authorPubkey: firstCreator,
            addressableId: '34236:$firstCreator:first',
          ),
          ClipSourceCredit(
            authorPubkey: secondCreator,
            addressableId: '34236:$secondCreator:second',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: InspiredByAttributionRow(video: video, isActive: true),
            ),
          ),
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      final creatorName = UserProfile.defaultDisplayNameFor(firstCreator);

      expect(
        find.text(l10n.videoInspiredByAttributionMultiple(creatorName, 1)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            RegExp.escape(
              l10n.inspiredByAttributionMultipleSemanticLabel(creatorName, 1),
            ),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders no count for a single clip source credit', (
      tester,
    ) async {
      final video = VideoEvent(
        id: 'video-id',
        pubkey:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263000),
        videoUrl: 'https://cdn.example.com/video.mp4',
        clipSourceCredits: const [
          ClipSourceCredit(
            authorPubkey: firstCreator,
            addressableId: '34236:$firstCreator:first',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: InspiredByAttributionRow(video: video, isActive: true),
            ),
          ),
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      final creatorName = UserProfile.defaultDisplayNameFor(firstCreator);

      expect(
        find.text(l10n.videoInspiredByAttribution(creatorName)),
        findsOneWidget,
      );
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets(
      'includes explicit inspired-by creator with clip source credits',
      (
        tester,
      ) async {
        final video = VideoEvent(
          id: 'video-id',
          pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          createdAt: 1757385263,
          content: 'Test video',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263000),
          videoUrl: 'https://cdn.example.com/video.mp4',
          inspiredByVideo: const InspiredByInfo(
            addressableId: '34236:$explicitCreator:chosen-source',
          ),
          clipSourceCredits: const [
            ClipSourceCredit(
              authorPubkey: firstCreator,
              addressableId: '34236:$firstCreator:first',
            ),
            ClipSourceCredit(
              authorPubkey: explicitCreator,
              addressableId: '34236:$explicitCreator:chosen-source',
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: InspiredByAttributionRow(video: video, isActive: true),
              ),
            ),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        final creatorName = UserProfile.defaultDisplayNameFor(explicitCreator);

        expect(
          find.text(l10n.videoInspiredByAttributionMultiple(creatorName, 1)),
          findsOneWidget,
        );
      },
    );
  });
}
