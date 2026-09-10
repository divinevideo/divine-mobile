import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/notifications/widgets/notification_avatar_stack.dart';
import 'package:openvine/widgets/avatar_failure_cache.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

import '../../helpers/test_provider_overrides.dart'
    show createMockMediaCacheManager;

void main() {
  const actor1 = ActorInfo(
    pubkey: 'abc123',
    displayName: 'Alice',
    pictureUrl: 'https://example.com/alice.jpg',
  );

  const actor2 = ActorInfo(
    pubkey: 'def456',
    displayName: 'Bob',
    pictureUrl: 'https://example.com/bob.jpg',
  );

  const actorNoPhoto = ActorInfo(pubkey: 'ghi789', displayName: 'Carol');

  Widget buildSubject({required List<ActorInfo> actors, int? overflowCount}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: NotificationAvatarStack(
          actors: actors,
          overflowCount: overflowCount,
        ),
      ),
    );
  }

  group(NotificationAvatarStack, () {
    // Stub the image cache (#5158 seam) so VineCachedImage does no real
    // path_provider / cache-manager work that could settle after the test and
    // cascade in the merged VGV optimizer isolate (#5159).
    setUp(() {
      AvatarFailureCache.instance.clear();
      debugImageCacheOverride = createMockMediaCacheManager();
    });

    tearDown(() {
      debugImageCacheOverride = null;
      AvatarFailureCache.instance.clear();
    });

    testWidgets('renders single avatar for one actor', (tester) async {
      await tester.pumpWidget(buildSubject(actors: const [actor1]));
      await tester.pump();

      expect(find.byType(VineCachedImage), findsOneWidget);
    });

    testWidgets('renders two avatars for two actors', (tester) async {
      await tester.pumpWidget(buildSubject(actors: const [actor1, actor2]));
      await tester.pump();

      expect(find.byType(VineCachedImage), findsNWidgets(2));
    });

    testWidgets('renders three avatars for three actors', (tester) async {
      await tester.pumpWidget(
        buildSubject(actors: const [actor1, actor2, actorNoPhoto]),
      );
      await tester.pump();

      expect(find.byType(UserAvatar), findsNWidgets(3));
      // actor1 and actor2 have URLs => VineCachedImage.
      expect(find.byType(VineCachedImage), findsNWidgets(2));
    });

    testWidgets('renders overflow circle when overflowCount > 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(actors: const [actor1], overflowCount: 42),
      );
      await tester.pump();

      expect(find.text('+42'), findsOneWidget);
    });

    testWidgets('does not render overflow circle when overflowCount is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(actors: const [actor1]));
      await tester.pump();

      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('caps displayed avatars at 3', (tester) async {
      const actor4 = ActorInfo(
        pubkey: 'jkl012',
        displayName: 'Dave',
        pictureUrl: 'https://example.com/dave.jpg',
      );

      await tester.pumpWidget(
        buildSubject(actors: const [actor1, actor2, actorNoPhoto, actor4]),
      );
      await tester.pump();

      // Only first 3 actors shown (not 4); actor1 and actor2 have URLs.
      expect(find.byType(UserAvatar), findsNWidgets(3));
      expect(find.byType(VineCachedImage), findsNWidgets(2));
    });
  });
}
