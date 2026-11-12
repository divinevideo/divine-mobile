import 'dart:async';

// ABOUTME: Pins bookmarksRepositoryProvider to one BookmarksRepository per
// ABOUTME: container, and pins that an identity change still rebuilds it.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

/// Lets a test reassign the client the way an identity change does.
///
/// `NostrService` replaces `state` on every identity change, and
/// [NostrClient] does not override `==`, so the reassignment always
/// propagates to anything watching it.
class _SwappableNostrService extends NostrService {
  _SwappableNostrService(this.initialClient);

  final NostrClient initialClient;

  @override
  NostrClient build() => initialClient;

  void replaceWith(NostrClient client) => state = client;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bookmarksRepositoryProvider', () {
    late _MockNostrClient nostrClient;
    late _MockAuthService authService;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      nostrClient = _MockNostrClient();
      authService = _MockAuthService();
    });

    ProviderContainer containerWith(NostrService nostrService) {
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWith(() => nostrService),
          authServiceProvider.overrideWithValue(authService),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    group('lifetime', () {
      test(
        'serves one instance to reads that leave no listener (#7596)',
        () async {
          final container = containerWith(_SwappableNostrService(nostrClient));

          // Both consumers read this with `ref.read`, which registers no
          // listener. Under autoDispose the element was torn down between these
          // two reads and the second built a second repository — with a second
          // operation queue, over the one unscoped `global_bookmarks` key, so
          // the #7598 serialization guard stopped covering the pair.
          final first = container.read(bookmarksRepositoryProvider);
          await container.pump();
          final second = container.read(bookmarksRepositoryProvider);

          expect(identical(first, second), isTrue);
        },
      );
    });

    group('identity change', () {
      test('rebuilds against the client an identity change installs', () async {
        final nostrService = _SwappableNostrService(nostrClient);
        final container = containerWith(nostrService);

        final before = container.read(bookmarksRepositoryProvider);

        // What `NostrService` does on every identity change.
        nostrService.replaceWith(_MockNostrClient());
        await container.pump();

        final after = container.read(bookmarksRepositoryProvider);

        expect(
          identical(before, after),
          isFalse,
          reason:
              "A repository bound to the previous identity's client must not "
              'survive the swap — keeping it alive would serve the previous '
              "account's bookmarks.",
        );
      });

      test("closes the previous instance's change stream", () async {
        final nostrService = _SwappableNostrService(nostrClient);
        final container = containerWith(nostrService);

        final before = container.read(bookmarksRepositoryProvider);
        final closed = Completer<void>();
        final subscription = before.watchGlobalBookmarks().listen(
          (_) {},
          onDone: closed.complete,
        );
        addTearDown(subscription.cancel);

        nostrService.replaceWith(_MockNostrClient());
        await container.pump();
        // The element is only rebuilt — and the old one disposed — on the
        // next read.
        container.read(bookmarksRepositoryProvider);

        // A grid still subscribed to the previous account's repository is
        // released instead of being left listening to it.
        await closed.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail(
            'The previous repository change stream did not close after '
            'identity replacement.',
          ),
        );
      });
    });

    // A video edit republishes it under a new event id, so an `e` bookmark
    // saved before the edit only matches once it resolves to the video's
    // coordinate (#7135).
    group('video addresses', () {
      late _MockVideosRepository videosRepository;
      late String author;
      late String coordinate;
      final originalId = '1' * 64;
      final editedId = '2' * 64;

      setUp(() {
        videosRepository = _MockVideosRepository();
        author = '4' * 64;
        coordinate = '34236:$author:clip';
        when(() => authService.isAuthenticated).thenReturn(true);
        when(() => authService.currentPublicKeyHex).thenReturn('5' * 64);
        when(() => authService.currentIdentity).thenReturn(null);
        when(
          () => nostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: [
              Event('5' * 64, 10003, [
                ['e', originalId],
              ], ''),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );
      });

      setUpAll(() => registerFallbackValue(<Filter>[]));

      test(
        'matches an event id saved before an edit to the edited video',
        () async {
          final original = VideoEvent.fromNostrEvent(
            Event(author, 34236, [
              ['d', 'clip'],
              ['url', 'https://media.example/clip.mp4'],
            ], ''),
          );
          when(
            () => videosRepository.getVideosByIds(
              [originalId],
              hydrateBulkStats: false,
              includeFeedShape: false,
            ),
          ).thenAnswer((_) async => [_withId(original, originalId)]);
          final container = ProviderContainer(
            overrides: [
              nostrServiceProvider.overrideWith(
                () => _SwappableNostrService(nostrClient),
              ),
              authServiceProvider.overrideWithValue(authService),
              sharedPreferencesProvider.overrideWithValue(prefs),
              videosRepositoryProvider.overrideWithValue(videosRepository),
            ],
          );
          addTearDown(container.dispose);

          final repository = container.read(bookmarksRepositoryProvider);
          await repository.syncGlobalBookmarks();

          expect(
            repository.isVideoBookmarkedGlobally(
              editedId,
              addressableId: coordinate,
            ),
            isTrue,
          );
        },
      );

      test('is not rebuilt when the videos repository is', () async {
        final videosVersion = StateProvider<int>((ref) => 0);
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWith(
              () => _SwappableNostrService(nostrClient),
            ),
            authServiceProvider.overrideWithValue(authService),
            sharedPreferencesProvider.overrideWithValue(prefs),
            // What a content-filter change does to the real provider.
            videosRepositoryProvider.overrideWith((ref) {
              ref.watch(videosVersion);
              return _MockVideosRepository();
            }),
          ],
        );
        addTearDown(container.dispose);

        final before = container.read(bookmarksRepositoryProvider);
        container.read(videosRepositoryProvider);
        container.read(videosVersion.notifier).state++;
        await container.pump();
        container.read(videosRepositoryProvider);
        final after = container.read(bookmarksRepositoryProvider);

        expect(identical(before, after), isTrue);
      });
    });
  });
}

class _MockVideosRepository extends Mock implements VideosRepository {}

/// [video] as the version published under [id].
VideoEvent _withId(VideoEvent video, String id) => video.copyWith(id: id);
