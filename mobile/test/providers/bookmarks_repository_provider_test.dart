// ABOUTME: Pins bookmarksRepositoryProvider to one BookmarksRepository per
// ABOUTME: container, and pins that an identity change still rebuilds it.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

      test(
        'survives repeated listener-less reads across one session',
        () async {
          final container = containerWith(_SwappableNostrService(nostrClient));

          final first = container.read(bookmarksRepositoryProvider);
          for (var i = 0; i < 5; i++) {
            await container.pump();
            expect(
              identical(container.read(bookmarksRepositoryProvider), first),
              isTrue,
              reason: 'read ${i + 2} built a new repository',
            );
          }
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
    });
  });
}
