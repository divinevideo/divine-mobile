import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/inbox/messages/messages_home_page.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends Fake implements AuthService {
  _Auth(this.currentPublicKeyHex, {this.isAuthenticated = true});
  @override
  final bool isAuthenticated;
  @override
  final String? currentPublicKeyHex;
  @override
  AuthState get authState =>
      isAuthenticated ? AuthState.authenticated : AuthState.unauthenticated;
  @override
  Stream<AuthState> get authStateStream => const Stream.empty();
}

void main() {
  group(MessagesHomePage, () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Future<ProviderContainer> pumpPage(
      WidgetTester tester, {
      bool enabled = true,
      bool restricted = false,
      String? account,
    }) async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_Auth(account)),
          sharedPreferencesProvider.overrideWithValue(prefs),
          featureFlagStateProvider.overrideWithValue({
            FeatureFlag.concordChat: enabled,
          }),
          isDmRestrictedProvider.overrideWithValue(restricted),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessagesHomePage(direct: Text('direct-content')),
            ),
          ),
        ),
      );
      return container;
    }

    for (final scenario in [
      (enabled: false, restricted: false, account: 'a' * 64),
      (enabled: true, restricted: true, account: 'a' * 64),
      (enabled: true, restricted: false, account: null),
    ]) {
      testWidgets('keeps Direct only for access gate $scenario', (
        tester,
      ) async {
        await pumpPage(
          tester,
          enabled: scenario.enabled,
          restricted: scenario.restricted,
          account: scenario.account,
        );
        expect(find.text('direct-content'), findsOneWidget);
        expect(find.byType(ChoiceChip), findsNothing);
      });
    }

    testWidgets('tapping a room asks the router for that room', (tester) async {
      Map<String, String>? opened;
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_Auth('a' * 64)),
          sharedPreferencesProvider.overrideWithValue(prefs),
          featureFlagStateProvider.overrideWithValue({
            FeatureFlag.concordChat: true,
          }),
          isDmRestrictedProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: MessagesHomePage(direct: Text('direct-content')),
            ),
          ),
          GoRoute(
            path: '/chat',
            name: 'chat',
            builder: (_, state) {
              opened = state.uri.queryParameters;
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.messagesRooms));
      await tester.pump();
      await tester.tap(find.text('#introductions'));
      await tester.pumpAndSettle();
      expect(opened, {
        'community': 'community-test',
        'channel': 'introductions',
      });
    });

    testWidgets('auth teardown hides Rooms even before the key is cleared', (
      tester,
    ) async {
      final container = await pumpPage(tester, account: 'a' * 64);
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.messagesRooms));
      await tester.pump();
      container.updateOverrides([
        authServiceProvider.overrideWithValue(
          _Auth('a' * 64, isAuthenticated: false),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        featureFlagStateProvider.overrideWithValue({
          FeatureFlag.concordChat: true,
        }),
        isDmRestrictedProvider.overrideWithValue(false),
      ]);
      await tester.pump();
      expect(find.text(l10n.messagesPublicTestRooms), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('switching accounts clears the previous Rooms selection', (
      tester,
    ) async {
      final container = await pumpPage(tester, account: 'a' * 64);
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.messagesRooms));
      await tester.pump();
      expect(find.text(l10n.messagesPublicTestRooms), findsOneWidget);
      container.updateOverrides([
        authServiceProvider.overrideWithValue(_Auth('b' * 64)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        featureFlagStateProvider.overrideWithValue({
          FeatureFlag.concordChat: true,
        }),
        isDmRestrictedProvider.overrideWithValue(false),
      ]);
      await tester.pump();
      expect(find.text('direct-content'), findsOneWidget);
      expect(find.text(l10n.messagesPublicTestRooms), findsNothing);
    });
  });
}
