// ABOUTME: Tests the in-app deep link handler that used to be a build() closure
// ABOUTME: Asserts where each DeepLinkType lands, per #3337 AC 2

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/router/deep_link_coordinator.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/deep_link_service.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group(DeepLinkCoordinator, () {
    late GoRouter router;
    late _MockAuthService authService;

    setUp(() {
      authService = _MockAuthService();
      router = GoRouter(
        initialLocation: '/home/0',
        routes: [
          for (final path in const [
            '/home/:i',
            '/explore',
            '/welcome',
            '/video/:id',
            '/profile/:npub',
            '/profile/:npub/:i',
            '/hashtag/:tag',
            '/search/:term',
            '/list/:pubkey/:id',
            '/saved-videos',
          ])
            GoRoute(path: path, builder: (_, _) => const SizedBox()),
        ],
      );
      addTearDown(router.dispose);
    });

    String handleAndReadLocation(DeepLink link) {
      DeepLinkCoordinator(
        router: router,
        authService: authService,
      ).handle(AsyncValue.data(link));
      return router.routeInformationProvider.value.uri.toString();
    }

    group('handle', () {
      test('routes a video link to its detail route', () {
        expect(
          handleAndReadLocation(
            const DeepLink(type: DeepLinkType.video, videoRef: 'abc123'),
          ),
          equals('/video/abc123'),
        );
      });

      test('routes an index-less profile link to the profile grid', () {
        expect(
          handleAndReadLocation(
            const DeepLink(type: DeepLinkType.profile, npub: 'npub1abc'),
          ),
          equals('/profile/npub1abc'),
        );
      });

      test('routes a profile link with an index to feed mode', () {
        expect(
          handleAndReadLocation(
            const DeepLink(
              type: DeepLinkType.profile,
              npub: 'npub1abc',
              index: 4,
            ),
          ),
          equals('/profile/npub1abc/4'),
        );
      });

      test('routes a hashtag link to that hashtag', () {
        expect(
          handleAndReadLocation(
            const DeepLink(type: DeepLinkType.hashtag, hashtag: 'flutter'),
          ),
          equals('/hashtag/flutter'),
        );
      });

      test('routes a saved-videos link', () {
        expect(
          handleAndReadLocation(
            const DeepLink(type: DeepLinkType.savedVideos),
          ),
          equals('/saved-videos'),
        );
      });

      test('leaves the current route alone for an unknown link', () {
        expect(
          handleAndReadLocation(const DeepLink(type: DeepLinkType.unknown)),
          equals('/home/0'),
        );
      });

      test('leaves the current route alone when a video link has no ref', () {
        expect(
          handleAndReadLocation(const DeepLink(type: DeepLinkType.video)),
          equals('/home/0'),
        );
      });

      test(
        'leaves the current route alone when a profile link has no npub',
        () {
          expect(
            handleAndReadLocation(const DeepLink(type: DeepLinkType.profile)),
            equals('/home/0'),
          );
        },
      );

      test('reconnects relays on a signer callback without navigating', () {
        when(
          () => authService.onSignerCallbackReceived(
            relayUrl: any(named: 'relayUrl'),
          ),
        ).thenReturn(null);

        final location = handleAndReadLocation(
          const DeepLink(
            type: DeepLinkType.signerCallback,
            signerCallbackRelay: 'wss://relay.example.com',
          ),
        );

        expect(location, equals('/home/0'));
        verify(
          () => authService.onSignerCallbackReceived(
            relayUrl: 'wss://relay.example.com',
          ),
        ).called(1);
      });

      test('navigates nothing while the stream is still loading', () {
        DeepLinkCoordinator(
          router: router,
          authService: authService,
        ).handle(const AsyncValue<DeepLink>.loading());

        expect(
          router.routeInformationProvider.value.uri.toString(),
          equals('/home/0'),
        );
      });

      test('navigates nothing when the stream reports an error', () {
        DeepLinkCoordinator(router: router, authService: authService).handle(
          const AsyncValue<DeepLink>.error('boom', StackTrace.empty),
        );

        expect(
          router.routeInformationProvider.value.uri.toString(),
          equals('/home/0'),
        );
      });
    });
  });
}
