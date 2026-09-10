import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockHashtagService extends Mock implements HashtagService {}

class _MockVideosRepository extends Mock implements VideosRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  group('HashtagFeedScreen startup contract', () {
    late _MockHashtagService mockHashtagService;
    late _MockVideosRepository mockVideosRepository;

    setUp(() {
      mockHashtagService = _MockHashtagService();
      mockVideosRepository = _MockVideosRepository();

      when(() => mockHashtagService.getVideosByHashtags(any())).thenReturn([]);
    });

    Widget buildTestWidget(String hashtag) {
      return ProviderScope(
        overrides: [
          hashtagServiceProvider.overrideWith((ref) => mockHashtagService),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HashtagFeedScreen(hashtag: hashtag),
        ),
      );
    }

    testWidgets(
      'keeps loading until the initial source answers, then shows empty state even if websocket subscribe hangs',
      (tester) async {
        final subscribeCompleter = Completer<void>();
        final feedCompleter = Completer<HashtagFeedVideosResult>();
        addTearDown(() {
          if (!subscribeCompleter.isCompleted) {
            subscribeCompleter.complete();
          }
          if (!feedCompleter.isCompleted) {
            feedCompleter.complete(
              const HashtagFeedVideosResult.success(<VideoEvent>[]),
            );
          }
        });

        when(
          () => mockVideosRepository.getHashtagFeedVideos(
            hashtag: any(named: 'hashtag'),
          ),
        ).thenAnswer((_) => feedCompleter.future);
        when(
          () => mockHashtagService.subscribeToHashtagVideos(any()),
        ).thenAnswer((_) => subscribeCompleter.future);

        await tester.pumpWidget(buildTestWidget('nostr'));

        expect(find.text('Loading videos about #nostr...'), findsOneWidget);

        await tester.pump();
        await tester.pump();

        expect(find.text('Loading videos about #nostr...'), findsOneWidget);
        expect(find.text('No videos found for #nostr'), findsNothing);

        feedCompleter.complete(
          const HashtagFeedVideosResult.success(<VideoEvent>[]),
        );

        await tester.pump();
        await tester.pump();

        expect(find.text('Loading videos about #nostr...'), findsNothing);
        expect(find.text('No videos found for #nostr'), findsOneWidget);
      },
    );
  });
}
