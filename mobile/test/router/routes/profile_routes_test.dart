// ABOUTME: Tests the profile routes registered by profileRoutes.
// ABOUTME: Pins their locations against the path builders and their extra hints.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/router/widgets/followers_screen_router.dart';
import 'package:openvine/router/widgets/following_screen_router.dart';
import 'package:openvine/router/widgets/other_profile_screen_router.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_setup/profile_setup.dart';
import 'package:openvine/screens/verify/verify_connect_screen.dart';
import 'package:openvine/screens/verify/verify_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState({
    required String location,
    this.pathParameters = const {},
    this.extra,
  }) : uri = Uri.parse(location),
       matchedLocation = Uri.parse(location).path,
       fullPath = Uri.parse(location).path,
       pageKey = ValueKey<String>(location);

  @override
  final Uri uri;

  @override
  final String matchedLocation;

  @override
  final String? fullPath;

  @override
  final ValueKey<String> pageKey;

  @override
  final Map<String, String> pathParameters;

  @override
  final Object? extra;
}

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group('profileRoutes', () {
    late BuildContext context;
    final npub = NostrKeyUtils.encodePubKey(_pubkey);

    Future<void> captureContext(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    Iterable<GoRoute> flatten(List<RouteBase> routes) sync* {
      for (final route in routes.whereType<GoRoute>()) {
        yield route;
        yield* flatten(route.routes);
      }
    }

    GoRoute routeNamed(String name) =>
        flatten(profileRoutes()).singleWhere((route) => route.name == name);

    Widget build(
      String name,
      String location, {
      Map<String, String> pathParameters = const {},
      Object? extra,
    }) => routeNamed(name).builder!(
      context,
      _FakeGoRouterState(
        location: location,
        pathParameters: pathParameters,
        extra: extra,
      ),
    );

    group('locations', () {
      // Redirects, the route parser and page-context restoration still build
      // these locations from RoutePaths and the screens' path builders, so the
      // typed routes must produce the same URLs for the ids callers pass.
      test('an other-profile location matches pathForNpub', () {
        expect(
          OtherProfileRouteData(npub: npub).location,
          equals(OtherProfileScreen.pathForNpub(npub)),
        );
      });

      test('a followers location matches pathForPubkey', () {
        expect(
          const FollowersRouteData(pubkey: _pubkey).location,
          equals(FollowersScreenRouter.pathForPubkey(_pubkey)),
        );
      });

      test('a following location matches pathForPubkey', () {
        expect(
          const FollowingRouteData(pubkey: _pubkey).location,
          equals(FollowingScreenRouter.pathForPubkey(_pubkey)),
        );
      });

      test('the profile editors and verify keep their paths', () {
        expect(
          const EditProfileRouteData().location,
          equals(RoutePaths.profileSetupEdit),
        );
        expect(
          const SetupProfileRouteData().location,
          equals(ProfileSetupScreen.setupPath),
        );
        expect(const VerifyRouteData().location, equals(VerifyPage.path));
      });

      // The platform key comes from the verifier service, and the hand-written
      // call site resolved it by route name, which encodes it.
      for (final platform in ['github', 'two words', 'a/b', '100%']) {
        test('a connect location matches its named location for '
            '"$platform"', () {
          final router = GoRouter(routes: profileRoutes());
          addTearDown(router.dispose);

          expect(
            VerifyConnectRouteData(platform: platform).location,
            equals(
              router.namedLocation(
                VerifyConnectPage.routeName,
                pathParameters: {'platform': platform},
              ),
            ),
          );
        });
      }
    });

    group('builders', () {
      testWidgets('connect passes the platform key through', (tester) async {
        await captureContext(tester);

        final screen = build(
          VerifyConnectPage.routeName,
          const VerifyConnectRouteData(platform: 'github').location,
          pathParameters: const {'platform': 'github'},
        );

        expect(
          screen,
          isA<VerifyConnectPage>().having(
            (s) => s.platformKey,
            'platformKey',
            'github',
          ),
        );
      });

      testWidgets('connect passes the link it renews through', (tester) async {
        await captureContext(tester);
        const route = VerifyConnectRouteData(
          platform: 'twitter',
          replacing: 'jack',
        );

        final screen = build(
          VerifyConnectPage.routeName,
          route.location,
          pathParameters: const {'platform': 'twitter'},
        );

        expect(
          route.location,
          equals('/verify/connect/twitter?replacing=jack'),
        );
        expect(
          screen,
          isA<VerifyConnectPage>().having(
            (s) => s.replacingIdentity,
            'replacingIdentity',
            'jack',
          ),
        );
      });

      testWidgets('edit profile opens the editor for an existing user', (
        tester,
      ) async {
        await captureContext(tester);

        final screen = build(
          ProfileSetupScreen.editRouteName,
          ProfileSetupScreen.editPath,
        );

        expect(
          screen,
          isA<ProfileSetupScreen>().having(
            (s) => s.isNewUser,
            'isNewUser',
            isFalse,
          ),
        );
      });

      testWidgets('setup profile opens the editor for a new user', (
        tester,
      ) async {
        await captureContext(tester);

        final screen = build(
          ProfileSetupScreen.setupRouteName,
          ProfileSetupScreen.setupPath,
        );

        expect(
          screen,
          isA<ProfileSetupScreen>().having(
            (s) => s.isNewUser,
            'isNewUser',
            isTrue,
          ),
        );
      });

      testWidgets('followers reads a display-name hint', (tester) async {
        await captureContext(tester);

        final screen = build(
          FollowersScreenRouter.routeName,
          FollowersScreenRouter.pathForPubkey(_pubkey),
          pathParameters: const {'pubkey': _pubkey},
          extra: 'Alice',
        );

        expect(
          screen,
          isA<FollowersScreenRouter>()
              .having((s) => s.pubkey, 'pubkey', _pubkey)
              .having((s) => s.displayName, 'displayName', 'Alice'),
        );
      });

      testWidgets('following reads a display-name hint', (tester) async {
        await captureContext(tester);

        final screen = build(
          FollowingScreenRouter.routeName,
          FollowingScreenRouter.pathForPubkey(_pubkey),
          pathParameters: const {'pubkey': _pubkey},
          extra: 'Alice',
        );

        expect(
          screen,
          isA<FollowingScreenRouter>()
              .having((s) => s.pubkey, 'pubkey', _pubkey)
              .having((s) => s.displayName, 'displayName', 'Alice'),
        );
      });

      // Restored route state can hand `extra` back as a decoded map; a typed
      // String $extra would throw inside the generated redirect.
      testWidgets('followers opens without a hint from a restored map', (
        tester,
      ) async {
        await captureContext(tester);

        final screen = build(
          FollowersScreenRouter.routeName,
          FollowersScreenRouter.pathForPubkey(_pubkey),
          pathParameters: const {'pubkey': _pubkey},
          extra: const <String, dynamic>{'displayName': 'Alice'},
        );

        expect(
          screen,
          isA<FollowersScreenRouter>()
              .having((s) => s.pubkey, 'pubkey', _pubkey)
              .having((s) => s.displayName, 'displayName', isNull),
        );
      });

      testWidgets('an other profile reads its name and avatar hints', (
        tester,
      ) async {
        await captureContext(tester);

        // The shape the classic viners slider passes.
        final screen = build(
          OtherProfileScreen.routeName,
          OtherProfileScreen.pathForNpub(npub),
          pathParameters: {'npub': npub},
          extra: const <String, String?>{
            'displayName': 'Alice',
            'avatarUrl': 'https://example.com/a.png',
          },
        );

        expect(
          screen,
          isA<OtherProfileScreenRouter>()
              .having((s) => s.npub, 'npub', npub)
              .having((s) => s.displayNameHint, 'displayNameHint', 'Alice')
              .having(
                (s) => s.avatarUrlHint,
                'avatarUrlHint',
                'https://example.com/a.png',
              ),
        );
      });

      testWidgets('an other profile opens from a deep link with no hints', (
        tester,
      ) async {
        await captureContext(tester);

        final screen = build(
          OtherProfileScreen.routeName,
          OtherProfileScreen.pathForNpub(npub),
          pathParameters: {'npub': npub},
        );

        expect(
          screen,
          isA<OtherProfileScreenRouter>()
              .having((s) => s.npub, 'npub', npub)
              .having((s) => s.displayNameHint, 'displayNameHint', isNull)
              .having((s) => s.avatarUrlHint, 'avatarUrlHint', isNull),
        );
      });
    });

    group('invalid ids', () {
      for (final (name, base) in [
        (FollowersScreenRouter.routeName, RoutePaths.followersBase),
        (FollowingScreenRouter.routeName, RoutePaths.followingBase),
      ]) {
        testWidgets('$name shows its own error for an empty pubkey', (
          tester,
        ) async {
          await captureContext(tester);

          final screen = build(
            name,
            '$base/',
            pathParameters: const {'pubkey': ''},
          );

          expect(
            screen,
            isA<RouteErrorScreen>().having(
              (s) => s.message,
              'message',
              context.l10n.routeInvalidUserId,
            ),
          );
        });
      }

      testWidgets('an other profile shows its own error for an empty npub', (
        tester,
      ) async {
        await captureContext(tester);

        final screen = build(
          OtherProfileScreen.routeName,
          '${RoutePaths.otherProfile}/',
          pathParameters: const {'npub': ''},
        );

        expect(
          screen,
          isA<RouteErrorScreen>().having(
            (s) => s.message,
            'message',
            context.l10n.routeInvalidProfileId,
          ),
        );
      });
    });
  });
}
