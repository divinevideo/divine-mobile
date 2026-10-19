// ABOUTME: Tests the Edit Profile setting that makes supporter status public.
// ABOUTME: Covers who sees it, the instant flip, and a failed save.

import 'dart:async';
import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/screens/profile_setup/widgets/supporter_recognition_section.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/supporter_api_client.dart';
import 'package:openvine/services/supporter_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/l10n.dart';

class _MockAuth extends Mock implements AuthService {}

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

String _accountJson({required bool active, required bool haloVisible}) =>
    jsonEncode({
      'status': active ? 'active' : 'expired',
      'entitlement': {'source': 'server', 'isActive': active},
      'recognition': {'haloVisible': haloVisible},
    });

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  /// Pumps the section for an account read from a stubbed supporters API,
  /// with public recognition off. [onRecognition] answers a change.
  Future<void> pumpSection(
    WidgetTester tester, {
    required bool isSupporter,
    Future<http.Response> Function(http.Request request)? onRecognition,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _MockAuth();
    when(() => auth.isAuthenticated).thenReturn(true);
    // No refresh from the screen; the account is read up front.
    when(() => auth.canPublishNostrWritesNow).thenReturn(false);
    final client = SupporterApiClient(
      baseUri: Uri.parse('https://supporters.test'),
      authHeaderProvider: ({required url, required method, payload}) async =>
          (authorizationHeader: 'Nostr fixture', pubkey: _pubkey),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/recognition')) {
          return onRecognition!(request);
        }
        return http.Response(
          _accountJson(active: isSupporter, haloVisible: false),
          200,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupporterRepository(
      pubkey: _pubkey,
      validator: StubEntitlementValidator(),
      prefs: await SharedPreferences.getInstance(),
      apiClient: client,
    );
    addTearDown(repository.dispose);
    await tester.runAsync(repository.refreshFromServer);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supporterApiConfiguredProvider.overrideWithValue(true),
          authServiceProvider.overrideWithValue(auth),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          supporterRepositoryProvider.overrideWithValue(repository),
        ],
        child: buildLocalizedWidget(
          const Scaffold(body: SupporterRecognitionSection()),
        ),
      ),
    );
    await tester.pump();
  }

  bool switchValue(WidgetTester tester) =>
      tester.widget<DivineSwitch>(find.byType(DivineSwitch)).value;

  group(SupporterRecognitionSection, () {
    group('renders', () {
      testWidgets('shows the public setting to supporters', (tester) async {
        await pumpSection(tester, isSupporter: true);

        expect(find.text(l10n.supporterPublicRecognition), findsOneWidget);
        expect(switchValue(tester), isFalse);
      });

      testWidgets('shows nothing to anyone else', (tester) async {
        await pumpSection(tester, isSupporter: false);

        expect(find.text(l10n.supporterPublicRecognition), findsNothing);
        expect(find.byType(DivineSwitch), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('flips on as soon as it is tapped and saves the change', (
        tester,
      ) async {
        final response = Completer<http.Response>();
        final sent = <Object?>[];
        await pumpSection(
          tester,
          isSupporter: true,
          onRecognition: (request) {
            sent.add(jsonDecode(request.body));
            return response.future;
          },
        );

        await tester.tap(find.text(l10n.supporterPublicRecognition));
        await tester.pump();
        expect(switchValue(tester), isTrue);

        response.complete(
          http.Response(_accountJson(active: true, haloVisible: true), 200),
        );
        await tester.pumpAndSettle();

        expect(sent, [containsPair('halo_visible', true)]);
        expect(switchValue(tester), isTrue);
      });

      testWidgets('flips back and says so when saving fails', (tester) async {
        await pumpSection(
          tester,
          isSupporter: true,
          onRecognition: (_) async => http.Response('{}', 500),
        );

        await tester.tap(find.text(l10n.supporterPublicRecognition));
        await tester.pumpAndSettle();

        expect(switchValue(tester), isFalse);
        expect(find.byType(SnackBar), findsOneWidget);
      });
    });
  });
}
