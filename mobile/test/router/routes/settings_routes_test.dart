// ABOUTME: Tests the settings routes registered by settingsRoutes.
// ABOUTME: Pins paths, names, nesting, badge locations, redirects, provider
// ABOUTME: reads, the Account Status hint and the developer-options slide.

import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/providers/support_route_trail_provider.dart';
import 'package:openvine/router/routes/settings_routes.dart';
import 'package:openvine/screens/badges/badge_award_screen.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';
import 'package:openvine/screens/badges/badge_editor_screen.dart';
import 'package:openvine/screens/badges/badge_videos_screen.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/clip_recovery_screen.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/settings/account/change_email_screen.dart';
import 'package:openvine/screens/settings/account/change_password_screen.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/screens/settings/app_language_screen.dart';
import 'package:openvine/screens/settings/appearance_settings_screen.dart';
import 'package:openvine/screens/settings/bluesky_settings_screen.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:openvine/screens/settings/crossposting_settings_screen.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/screens/settings/legal_screen.dart';
import 'package:openvine/screens/settings/monetization_links_settings_screen.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/screens/settings/privacy_settings_screen.dart';
import 'package:openvine/screens/settings/settings_categories_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/settings/signature_verification_policy_screen.dart';
import 'package:openvine/screens/settings/storage/storage_management_page.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/screens/settings/supporter_screen.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/stats_visibility_preferences.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/feature_request_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_pubkeys.dart';

class _FakeBuildContext extends Fake implements BuildContext {}

class _MockAuthService extends Mock implements AuthService {}

class _MockBugReportService extends Mock implements BugReportService {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

class _MockAudioSharingPreferenceService extends Mock
    implements AudioSharingPreferenceService {}

/// A route trail already holding two screens, so a report can show both.
class _FixedTrail extends SupportRouteTrail {
  @override
  List<RouteType> build() => const [RouteType.home, RouteType.profile];
}

const _coordinate = BadgeCoordinate(
  pubkey: syntheticOtherTestPubkey,
  identifier: 'daily',
);

/// Path values whose encoding has broken routes before, each with the path
/// segment it must encode to: an naddr, a hex key, an npub, a literal `%`, a
/// space, a slash, a `?` and a `#`. The encodings are written out so a test
/// does not restate the generator's own `Uri.encodeComponent`.
final _awkwardNaddrs = <({String raw, String encoded})>[
  (raw: _coordinate.toNaddr(), encoded: _coordinate.toNaddr()),
  (raw: syntheticOtherTestPubkey, encoded: syntheticOtherTestPubkey),
  (raw: syntheticOtherTestNpub, encoded: syntheticOtherTestNpub),
  (raw: '100%fun', encoded: '100%25fun'),
  (raw: 'a b', encoded: 'a%20b'),
  (raw: 'a/b', encoded: 'a%2Fb'),
  (raw: '?', encoded: '%3F'),
  (raw: '#', encoded: '%23'),
];

/// The settings route table behind a real router, so every state below is
/// the one go_router itself would hand the route.
GoRouter _settingsRouter() {
  final router = GoRouter(routes: settingsRoutes());
  addTearDown(router.dispose);
  return router;
}

/// The route [location] matches in the settings table, with its state.
({GoRoute route, GoRouterState state}) _resolve(
  String location, {
  Object? extra,
}) {
  final router = _settingsRouter();
  final match = router.configuration.findMatch(
    Uri.parse(location),
    extra: extra,
  );
  expect(match.isError, isFalse, reason: 'no settings route matches $location');
  return (
    route: match.last.route,
    state: router.configuration.buildTopLevelGoRouterState(match),
  );
}

/// What the route [location] matches builds, given [extra] and [context].
Widget _build(String location, {Object? extra, BuildContext? context}) {
  final (:route, :state) = _resolve(location, extra: extra);
  return route.builder!(context ?? _FakeBuildContext(), state);
}

/// Where the route [location] matches redirects, read through [context].
Object? _redirect(String location, BuildContext context) {
  final (:route, :state) = _resolve(location);
  return route.redirect!(context, state);
}

Iterable<GoRoute> _flatten(List<RouteBase> routes) sync* {
  for (final route in routes.whereType<GoRoute>()) {
    yield route;
    yield* _flatten(route.routes);
  }
}

GoRoute _routeNamed(String name) =>
    _flatten(settingsRoutes()).singleWhere((route) => route.name == name);

/// A context under a [ProviderScope] carrying [overrides], as the app's
/// router has, for the routes that read providers through the tree.
Future<BuildContext> _scopedContext(
  WidgetTester tester,
  List<Override> overrides,
) async {
  late BuildContext context;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Builder(
        builder: (c) {
          context = c;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return context;
}

void main() {
  group('settingsRoutes', () {
    group('declarations', () {
      // The gates, deep links, the support trail and analytics know these
      // routes by these exact strings, so they are written out rather than
      // read back from the constants the annotations use. The multi-segment
      // `/settings/...` and `/support-center/...` paths stay top-level, which
      // is the shape flat_route_cold_entry_back_test guards.
      test('registers the top-level paths in this order', () {
        expect(
          settingsRoutes().whereType<GoRoute>().map((route) => route.path),
          equals(<String>[
            '/settings',
            '/settings/account',
            '/settings/viewing',
            '/settings/app-preferences',
            '/settings/creating',
            '/settings/connections',
            '/settings/connections/nostr',
            '/settings/help-about',
            '/badges',
            '/badges/new',
            '/badges/b/:naddr',
            '/badges/b/:naddr/videos',
            '/badges/b/:naddr/edit',
            '/badges/b/:naddr/award',
            '/settings/account-status',
            '/support-center',
            '/support-center/report-bug',
            '/support-center/request-feature',
            '/legal',
            '/content-preferences',
            '/general-settings',
            '/appearance-settings',
            '/storage-management',
            '/settings/monetization-links',
            '/settings/supporter',
            '/app-language',
            '/bluesky-settings',
            '/crossposting-settings',
            '/nostr-settings',
            '/relay-settings',
            '/blossom-settings',
            '/notification-settings',
            '/key-management',
            '/relay-diagnostic',
            '/safety-settings',
            '/settings/privacy',
            '/content-filters',
            '/clip-recovery',
            '/developer-options',
            // Tests run in debug mode, where the prototype is registered.
            '/developer-options/dm-inbox-tabs',
          ]),
        );
      });

      test('keeps every top-level route name, in the same order', () {
        expect(
          settingsRoutes().whereType<GoRoute>().map((route) => route.name),
          equals(<String>[
            'settings',
            'settings-account',
            'settings-viewing',
            'settings-app-preferences',
            'settings-creating',
            'settings-connections',
            'settings-nostr-network',
            'settings-help-about',
            'badges',
            'badgeCreate',
            'badgeDetail',
            'badgeVideos',
            'badgeEdit',
            'badgeAward',
            'account-status',
            'support-center',
            'support-report-bug',
            'support-request-feature',
            'legal',
            'content-preferences',
            'general-settings',
            'appearance-settings',
            'storage-management',
            'monetization-links-settings',
            'supporter',
            'app-language',
            'bluesky-settings',
            'crossposting-settings',
            'nostr-settings',
            'relay-settings',
            'blossom-settings',
            'notification-settings',
            'key-management',
            'relay-diagnostic',
            'safety-settings',
            'privacy-settings',
            'content-filters',
            'clip-recovery',
            'developer-options',
            'dm-inbox-tabs-prototype',
          ]),
        );
      });

      test('nests only feature flags, the credential screens and the '
          'Nostr account screens', () {
        final children = {
          for (final route in settingsRoutes().whereType<GoRoute>())
            if (route.routes.isNotEmpty)
              route.path: [
                for (final child in route.routes.whereType<GoRoute>())
                  (child.path, child.name),
              ],
        };

        expect(
          children,
          equals({
            '/settings': [('feature-flags', 'feature-flags')],
            '/general-settings': [
              ('change-email', 'change-email'),
              ('change-password', 'change-password'),
            ],
            '/nostr-settings': [
              ('nip05', 'nip05-settings'),
              ('signature-verification', 'signature-verification'),
            ],
          }),
        );
      });
    });

    group('navigator', () {
      test("every route uses the router's own navigator", () {
        for (final route in _flatten(settingsRoutes())) {
          expect(route.parentNavigatorKey, isNull, reason: route.path);
        }
      });
    });

    group('locations', () {
      // Callers push these locations and the redirect compares them, so a
      // typed route that drifts from the hand-written path changes both.
      final locations = <(GoRouteData, String)>[
        (const SettingsRouteData(), '/settings'),
        (const FeatureFlagRouteData(), '/settings/feature-flags'),
        (const SettingsAccountRouteData(), '/settings/account'),
        (const ViewingSettingsRouteData(), '/settings/viewing'),
        (const AppPreferencesSettingsRouteData(), '/settings/app-preferences'),
        (const CreatingSettingsRouteData(), '/settings/creating'),
        (const ConnectionsSettingsRouteData(), '/settings/connections'),
        (const NostrNetworkSettingsRouteData(), '/settings/connections/nostr'),
        (const HelpAboutSettingsRouteData(), '/settings/help-about'),
        (const BadgesRouteData(), '/badges'),
        (const BadgeCreateRouteData(), '/badges/new'),
        (const AccountStatusRouteData(), '/settings/account-status'),
        (const SupportCenterRouteData(), '/support-center'),
        (const BugReportRouteData(), '/support-center/report-bug'),
        (const FeatureRequestRouteData(), '/support-center/request-feature'),
        (const LegalRouteData(), '/legal'),
        (const ContentPreferencesRouteData(), '/content-preferences'),
        (const GeneralSettingsRouteData(), '/general-settings'),
        (const ChangeEmailRouteData(), '/general-settings/change-email'),
        (const ChangePasswordRouteData(), '/general-settings/change-password'),
        (const AppearanceSettingsRouteData(), '/appearance-settings'),
        (const StorageManagementRouteData(), '/storage-management'),
        (
          const MonetizationLinksSettingsRouteData(),
          '/settings/monetization-links',
        ),
        (const SupporterRouteData(), '/settings/supporter'),
        (const AppLanguageRouteData(), '/app-language'),
        (const BlueskySettingsRouteData(), '/bluesky-settings'),
        (const CrosspostingSettingsRouteData(), '/crossposting-settings'),
        (const NostrSettingsRouteData(), '/nostr-settings'),
        (const Nip05SettingsRouteData(), '/nostr-settings/nip05'),
        (
          const SignatureVerificationPolicyRouteData(),
          '/nostr-settings/signature-verification',
        ),
        (const RelaySettingsRouteData(), '/relay-settings'),
        (const BlossomSettingsRouteData(), '/blossom-settings'),
        (const NotificationSettingsRouteData(), '/notification-settings'),
        (const KeyManagementRouteData(), '/key-management'),
        (const RelayDiagnosticRouteData(), '/relay-diagnostic'),
        (const SafetySettingsRouteData(), '/safety-settings'),
        (const PrivacySettingsRouteData(), '/settings/privacy'),
        (const ContentFiltersRouteData(), '/content-filters'),
        (const ClipRecoveryRouteData(), '/clip-recovery'),
        (const DeveloperOptionsRouteData(), '/developer-options'),
      ];

      for (final (route, location) in locations) {
        test('${route.runtimeType} keeps the location $location', () {
          expect(route.location, equals(location));
        });
      }

      test('the hint does not reach the Account Status URL', () {
        expect(
          const AccountStatusRouteData($extra: true).location,
          equals('/settings/account-status'),
        );
      });

      // The screens' builders take a coordinate, so they only ever see an
      // naddr; for one that encodes nothing the two must agree.
      test(
        'the badge locations match the screen builders for a coordinate',
        () {
          final naddr = _coordinate.toNaddr();

          expect(
            BadgeDetailRouteData(naddr: naddr).location,
            equals(BadgeDetailScreen.pathFor(_coordinate)),
          );
          expect(
            BadgeEditRouteData(naddr: naddr).location,
            equals(BadgeEditorScreen.editPathFor(_coordinate)),
          );
          expect(
            BadgeAwardRouteData(naddr: naddr).location,
            equals(BadgeAwardScreen.pathFor(_coordinate)),
          );
          expect(
            BadgeVideosRouteData(naddr: naddr).location,
            equals(BadgeVideosScreen.pathFor(_coordinate)),
          );
        },
      );

      // The builders do not encode, which is safe only because an naddr has
      // nothing to encode; a typed location encodes whatever it is given.
      for (final (:raw, :encoded) in _awkwardNaddrs) {
        test('the badge locations encode "$raw" as "$encoded"', () {
          expect(
            BadgeDetailRouteData(naddr: raw).location,
            equals('/badges/b/$encoded'),
          );
          expect(
            BadgeEditRouteData(naddr: raw).location,
            equals('/badges/b/$encoded/edit'),
          );
          expect(
            BadgeAwardRouteData(naddr: raw).location,
            equals('/badges/b/$encoded/award'),
          );
        });
      }

      testWidgets('every badge location round-trips its naddr', (
        tester,
      ) async {
        final seen = <String, String?>{};
        final router = GoRouter(
          initialLocation: BadgesScreen.path,
          routes: [
            for (final route in settingsRoutes().whereType<GoRoute>())
              GoRoute(
                path: route.path,
                name: route.name,
                builder: (_, state) {
                  seen['${state.name}'] = state.pathParameters['naddr'];
                  return const SizedBox.shrink();
                },
              ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );

        for (final (raw: naddr, encoded: _) in _awkwardNaddrs) {
          for (final (name, location) in [
            (
              BadgeDetailScreen.routeName,
              BadgeDetailRouteData(naddr: naddr).location,
            ),
            (
              BadgeEditorScreen.editRouteName,
              BadgeEditRouteData(naddr: naddr).location,
            ),
            (
              BadgeAwardScreen.routeName,
              BadgeAwardRouteData(naddr: naddr).location,
            ),
          ]) {
            seen.remove(name);
            router.go(location);
            await tester.pumpAndSettle();

            expect(seen[name], equals(naddr), reason: '$name at $location');
          }
        }
      });
    });

    group('screens', () {
      final screens = <String, Matcher>{
        '/settings': isA<SettingsScreen>().having(
          (s) => s.accountOnly,
          'accountOnly',
          isFalse,
        ),
        '/settings/feature-flags': isA<FeatureFlagScreen>(),
        '/settings/account': isA<SettingsScreen>().having(
          (s) => s.accountOnly,
          'accountOnly',
          isTrue,
        ),
        '/settings/viewing': isA<ViewingSettingsScreen>(),
        '/settings/app-preferences': isA<AppPreferencesSettingsScreen>(),
        '/settings/creating': isA<CreatingSettingsScreen>(),
        '/settings/connections': isA<ConnectionsSettingsScreen>(),
        '/settings/connections/nostr': isA<NostrSettingsScreen>().having(
          (s) => s.networkOnly,
          'networkOnly',
          isTrue,
        ),
        '/settings/help-about': isA<HelpAboutSettingsScreen>(),
        '/badges': isA<BadgesScreen>(),
        '/badges/new': isA<BadgeEditorScreen>().having(
          (s) => s.coordinate,
          'coordinate',
          isNull,
        ),
        '/support-center': isA<SupportCenterScreen>(),
        '/legal': isA<LegalScreen>(),
        '/content-preferences': isA<ContentPreferencesScreen>(),
        '/general-settings': isA<GeneralSettingsScreen>(),
        '/general-settings/change-email': isA<ChangeEmailScreen>(),
        '/general-settings/change-password': isA<ChangePasswordScreen>(),
        '/appearance-settings': isA<AppearanceSettingsScreen>(),
        '/storage-management': isA<StorageManagementPage>(),
        '/settings/monetization-links': isA<MonetizationLinksSettingsScreen>(),
        '/settings/supporter': isA<SupporterScreen>(),
        '/app-language': isA<AppLanguageScreen>(),
        '/bluesky-settings': isA<BlueskySettingsScreen>(),
        '/crossposting-settings': isA<CrosspostingSettingsScreen>(),
        '/nostr-settings': isA<NostrSettingsScreen>().having(
          (s) => s.networkOnly,
          'networkOnly',
          isFalse,
        ),
        '/nostr-settings/nip05': isA<Nip05SettingsScreen>(),
        '/nostr-settings/signature-verification':
            isA<SignatureVerificationPolicyScreen>(),
        '/relay-settings': isA<RelaySettingsScreen>(),
        '/blossom-settings': isA<BlossomSettingsScreen>(),
        '/notification-settings': isA<NotificationSettingsScreen>(),
        '/key-management': isA<KeyManagementScreen>(),
        '/relay-diagnostic': isA<RelayDiagnosticScreen>(),
        '/safety-settings': isA<SafetySettingsScreen>(),
        '/settings/privacy': isA<PrivacySettingsScreen>(),
        '/content-filters': isA<ContentFiltersScreen>(),
        '/clip-recovery': isA<ClipRecoveryScreen>(),
      };

      for (final MapEntry(key: location, value: matcher) in screens.entries) {
        test('$location builds its screen', () {
          expect(_build(location), matcher);
        });
      }
    });

    group('badges', () {
      final naddr = _coordinate.toNaddr();
      final badgeScreens = <String, Matcher>{
        BadgeDetailScreen.pathFor(_coordinate): isA<BadgeDetailScreen>().having(
          (s) => s.coordinate,
          'coordinate',
          _coordinate,
        ),
        BadgeEditorScreen.editPathFor(_coordinate): isA<BadgeEditorScreen>()
            .having((s) => s.coordinate, 'coordinate', _coordinate),
        BadgeAwardScreen.pathFor(_coordinate): isA<BadgeAwardScreen>().having(
          (s) => s.coordinate,
          'coordinate',
          _coordinate,
        ),
      };

      for (final MapEntry(key: location, value: matcher)
          in badgeScreens.entries) {
        test('$location opens the badge it names', () {
          expect(_build(location), matcher);
        });

        // A truncated share link, or an naddr for another kind, opens the
        // dashboard rather than an empty screen.
        final invalid = location.replaceFirst(naddr, 'invalid');
        test('$invalid falls back to the badge dashboard', () {
          expect(_build(invalid), isA<BadgesScreen>());
        });
      }
    });

    group('account status', () {
      test('opens unconfirmed when entered by URL', () {
        expect(
          _build(AccountStatusScreen.path),
          isA<AccountStatusScreen>().having(
            (s) => s.publishRestrictionConfirmed,
            'publishRestrictionConfirmed',
            isFalse,
          ),
        );
      });

      // RouteExtraCodec restores a bool by value, so a restored hint is
      // still the confirmation.
      test('opens confirmed with the hint true', () {
        expect(
          _build(AccountStatusScreen.path, extra: true),
          isA<AccountStatusScreen>().having(
            (s) => s.publishRestrictionConfirmed,
            'publishRestrictionConfirmed',
            isTrue,
          ),
        );
      });

      // Only the bool confirms; any other extra is ignored.
      for (final (label, extra) in <(String, Object)>[
        ('the string "true"', 'true'),
        ('a map', const <String, Object?>{'confirmed': true}),
      ]) {
        test('opens unconfirmed with $label as its extra', () {
          expect(
            _build(AccountStatusScreen.path, extra: extra),
            isA<AccountStatusScreen>().having(
              (s) => s.publishRestrictionConfirmed,
              'publishRestrictionConfirmed',
              isFalse,
            ),
          );
        });
      }

      testWidgets('a push with the hint opens Account Status confirmed', (
        tester,
      ) async {
        final accountStatus = _routeNamed(AccountStatusScreen.routeName);
        Widget? built;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: accountStatus.path,
              builder: (context, state) {
                built = accountStatus.builder!(context, state);
                return const SizedBox.shrink();
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        unawaited(
          const AccountStatusRouteData(
            $extra: true,
          ).push<void>(router.routerDelegate.navigatorKey.currentContext!),
        );
        await tester.pumpAndSettle();

        expect(
          built,
          isA<AccountStatusScreen>().having(
            (s) => s.publishRestrictionConfirmed,
            'publishRestrictionConfirmed',
            isTrue,
          ),
        );
      });
    });

    group('redirects', () {
      late _MockAuthService authService;

      setUp(() => authService = _MockAuthService());

      Future<BuildContext> signedInWith(
        WidgetTester tester,
        AuthenticationSource source,
      ) {
        when(() => authService.authenticationSource).thenReturn(source);
        return _scopedContext(tester, [
          authServiceProvider.overrideWithValue(authService),
        ]);
      }

      for (final location in [
        ChangeEmailScreen.path,
        ChangePasswordScreen.path,
      ]) {
        testWidgets('$location admits a Divine-login account', (tester) async {
          final context = await signedInWith(
            tester,
            AuthenticationSource.divineOAuth,
          );

          expect(_redirect(location, context), isNull);
        });

        testWidgets('$location sends a key-only identity to General Settings', (
          tester,
        ) async {
          final context = await signedInWith(
            tester,
            AuthenticationSource.importedKeys,
          );

          expect(_redirect(location, context), GeneralSettingsScreen.path);
        });
      }

      testWidgets('monetization links stay open while the flag is on', (
        tester,
      ) async {
        final context = await _scopedContext(tester, [
          featureFlagStateProvider.overrideWithValue(const {
            FeatureFlag.profileMonetizationLinks: true,
          }),
        ]);

        expect(
          _redirect(MonetizationLinksSettingsScreen.path, context),
          isNull,
        );
      });

      testWidgets('monetization links send the viewer to Settings while the '
          'flag is off', (tester) async {
        final context = await _scopedContext(tester, [
          featureFlagStateProvider.overrideWithValue(const {
            FeatureFlag.profileMonetizationLinks: false,
          }),
        ]);

        expect(
          _redirect(MonetizationLinksSettingsScreen.path, context),
          SettingsScreen.path,
        );
      });

      testWidgets('the supporter screen opens when its Worker is configured', (
        tester,
      ) async {
        final context = await _scopedContext(tester, [
          supporterApiConfiguredProvider.overrideWithValue(true),
        ]);

        expect(_redirect(SupporterScreen.path, context), isNull);
      });

      testWidgets('the supporter screen sends the viewer to Settings without '
          'its Worker', (tester) async {
        final context = await _scopedContext(tester, [
          supporterApiConfiguredProvider.overrideWithValue(false),
        ]);

        expect(_redirect(SupporterScreen.path, context), SettingsScreen.path);
      });
    });

    // The tests above hand a redirect a context they built. This one lets
    // go_router call it, from the router's own context under the scope.
    group('redirects through go_router', () {
      late SharedPreferences preferences;
      late _MockAuthService authService;
      late _MockLocaleCubit localeCubit;
      late _MockAudioSharingPreferenceService audioSharing;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        preferences = await SharedPreferences.getInstance();
        authService = _MockAuthService();
        localeCubit = _MockLocaleCubit();
        audioSharing = _MockAudioSharingPreferenceService();
        when(() => localeCubit.state).thenReturn(const LocaleState());
        when(() => authService.isAuthenticated).thenReturn(false);
        when(() => authService.isRegistered).thenReturn(false);
        when(() => authService.isAnonymous).thenReturn(false);
        when(() => authService.hasExpiredOAuthSession).thenReturn(false);
        when(
          () => authService.authenticationSource,
        ).thenReturn(AuthenticationSource.importedKeys);
        when(() => authService.getKnownAccounts()).thenAnswer((_) async => []);
        when(() => authService.currentPublicKeyHex).thenReturn(null);
        when(() => audioSharing.isAudioSharingEnabled).thenReturn(false);
      });

      testWidgets('a key-only identity opening change email lands on '
          'General Settings', (tester) async {
        final router = GoRouter(
          initialLocation: ChangeEmailScreen.path,
          routes: settingsRoutes(),
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
              authServiceProvider.overrideWithValue(authService),
              currentAuthStateProvider.overrideWithValue(
                AuthState.unauthenticated,
              ),
              audioSharingPreferenceServiceProvider.overrideWithValue(
                audioSharing,
              ),
              feedAspectRatioPreferenceServiceProvider.overrideWithValue(
                FeedAspectRatioPreferenceService(preferences),
              ),
              statsVisibilityPreferencesProvider.overrideWithValue(
                StatsVisibilityPreferences(preferences),
              ),
            ],
            child: BlocProvider<LocaleCubit>.value(
              value: localeCubit,
              child: MaterialApp.router(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(router.state.uri.path, equals(GeneralSettingsScreen.path));
        expect(find.byType(GeneralSettingsScreen), findsOneWidget);
        expect(find.byType(ChangeEmailScreen), findsNothing);
      });
    });

    group('support forms', () {
      late _MockAuthService authService;
      late _MockBugReportService bugReportService;

      setUp(() {
        authService = _MockAuthService();
        bugReportService = _MockBugReportService();
        when(
          () => authService.currentPublicKeyHex,
        ).thenReturn(syntheticOtherTestPubkey);
      });

      Future<BuildContext> scope(WidgetTester tester) =>
          _scopedContext(tester, [
            authServiceProvider.overrideWithValue(authService),
            bugReportServiceProvider.overrideWithValue(bugReportService),
            supportRouteTrailProvider.overrideWith(_FixedTrail.new),
          ]);

      testWidgets('a bug report carries the service, the trail and the '
          'signed-in key from the provider scope', (tester) async {
        final context = await scope(tester);

        expect(
          _build(BugReportScreen.path, context: context),
          isA<BugReportScreen>()
              .having(
                (s) => s.bugReportService,
                'bugReportService',
                same(bugReportService),
              )
              .having((s) => s.currentScreen, 'currentScreen', 'profile')
              .having((s) => s.recentScreens, 'recentScreens', [
                'home',
                'profile',
              ])
              .having(
                (s) => s.userPubkey,
                'userPubkey',
                syntheticOtherTestPubkey,
              ),
        );
      });

      testWidgets('a feature request carries the signed-in key from the '
          'provider scope', (tester) async {
        final context = await scope(tester);

        expect(
          _build(FeatureRequestScreen.path, context: context),
          isA<FeatureRequestScreen>().having(
            (s) => s.userPubkey,
            'userPubkey',
            syntheticOtherTestPubkey,
          ),
        );
      });
    });

    group('developer options', () {
      testWidgets('slide in from the right on a custom page', (tester) async {
        final (:route, :state) = _resolve(
          '${DeveloperOptionsScreen.path}?panel=relays',
        );

        final page = route.pageBuilder!(_FakeBuildContext(), state);

        expect(
          page,
          isA<CustomTransitionPage<void>>()
              .having((p) => p.child, 'child', isA<DeveloperOptionsScreen>())
              .having((p) => p.name, 'name', DeveloperOptionsScreen.routeName)
              .having((p) => p.key, 'key', state.pageKey)
              .having(
                (p) => p.restorationId,
                'restorationId',
                state.pageKey.value,
              )
              .having((p) => p.arguments, 'arguments', {'panel': 'relays'}),
        );
        final transition = (page as CustomTransitionPage<void>)
            .transitionsBuilder(
              _FakeBuildContext(),
              kAlwaysDismissedAnimation,
              kAlwaysDismissedAnimation,
              const SizedBox.shrink(),
            );
        expect(
          transition,
          isA<SlideTransition>().having(
            (t) => t.position.value,
            'start offset',
            const Offset(1, 0),
          ),
        );
      });
    });

    group('prototype', () {
      // The prototype is appended after the generated list, so it now sits
      // behind /developer-options; neither may capture the other.
      test('it and /developer-options each resolve to their own route', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final router = GoRouter(
          navigatorKey: NavigatorKeys.root,
          routes: container.read(Provider<List<RouteBase>>(appRoutes)),
        );
        addTearDown(router.dispose);

        for (final (location, name) in [
          ('/developer-options', 'developer-options'),
          ('/developer-options/dm-inbox-tabs', 'dm-inbox-tabs-prototype'),
        ]) {
          final match = router.configuration.findMatch(Uri.parse(location));

          expect(match.isError, isFalse, reason: location);
          expect(match.last.route.name, equals(name), reason: location);
        }
      });
    });
  });
}
