// ABOUTME: Tests persistent own-account acknowledgement and public opt-in badges.
// ABOUTME: Covers refresh without store work and suppression of external prompts.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/supporter_api_client.dart';
import 'package:openvine/services/supporter_repository.dart';
import 'package:openvine/widgets/supporter_membership.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/l10n.dart';

class _MockAuth extends Mock implements AuthService {}

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('own account membership', () {
    testWidgets('account switch ignores an old in-flight membership response', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = _MockAuth();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.canPublishNostrWritesNow).thenReturn(true);
      when(() => auth.authenticationSource)
          .thenReturn(AuthenticationSource.divineOAuth);
      final pending = Completer<http.Response>();
      SupporterRepository repositoryFor(
        String key,
        Future<http.Response> response,
      ) {
        final client = SupporterApiClient(
          baseUri: Uri.parse('https://supporters.test'),
          authHeaderProvider: ({
            required url,
            required method,
            payload,
          }) async => (authorizationHeader: 'Nostr fixture', pubkey: key),
          httpClient: MockClient((_) => response),
        );
        addTearDown(client.dispose);
        final repository = SupporterRepository(
          pubkey: key,
          validator: StubEntitlementValidator(),
          prefs: prefs,
          apiClient: client,
        );
        addTearDown(repository.dispose);
        return repository;
      }

      final first = repositoryFor(pubkey, pending.future);
      final second = repositoryFor(
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        Future.value(
          http.Response(
            '{"status":"expired","entitlement":{"isActive":false}}',
            200,
          ),
        ),
      );
      var current = first;
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          supporterRepositoryProvider.overrideWith((ref) => current),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildLocalizedWidget(
            const Scaffold(body: SupporterMembership(compact: true)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Divine Supporters'), findsOneWidget);
      expect(find.text('Become a supporter'), findsNothing);
      current = second;
      container.invalidate(supporterRepositoryProvider);
      await tester.pumpAndSettle();
      pending.complete(
        http.Response(
          '{"status":"active","entitlement":{"isActive":true,"source":"server"}}',
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(first.isSupporter, isTrue);
      expect(second.isSupporter, isFalse);
      expect(find.text('Supporter'), findsNothing);
      expect(find.text('Become a supporter'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final (source, succeeds) in [
      (AuthenticationSource.divineOAuth, true),
      (AuthenticationSource.divineOAuth, false),
      (AuthenticationSource.amber, true),
    ]) {
      testWidgets(
        'refreshes only without prompts and keeps unknown status neutral: $source $succeeds',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final auth = _MockAuth();
          when(() => auth.isAuthenticated).thenReturn(true);
          when(() => auth.canPublishNostrWritesNow).thenReturn(true);
          when(() => auth.authenticationSource).thenReturn(source);
          var requests = 0;
          final client = SupporterApiClient(
            baseUri: Uri.parse('https://supporters.test'),
            authHeaderProvider: ({
              required url,
              required method,
              payload,
            }) async => (authorizationHeader: 'Nostr fixture', pubkey: pubkey),
            httpClient: MockClient((_) async {
              requests++;
              if (!succeeds) return http.Response('{}', 503);
              return http.Response(
                jsonEncode({
                  'status': 'active',
                  'entitlement': {'source': 'server', 'isActive': true},
                  'recognition': {'haloVisible': false},
                }),
                200,
              );
            }),
          );
          final repo = SupporterRepository(
            pubkey: pubkey,
            validator: StubEntitlementValidator(),
            prefs: await SharedPreferences.getInstance(),
            apiClient: client,
          );
          addTearDown(repo.dispose);
          addTearDown(client.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authServiceProvider.overrideWithValue(auth),
                currentAuthStateProvider.overrideWithValue(
                  AuthState.authenticated,
                ),
                currentAuthRpcCapabilityProvider.overrideWithValue(
                  AuthRpcCapability.rpcReady,
                ),
                supporterRepositoryProvider.overrideWithValue(repo),
              ],
              child: buildLocalizedWidget(
                const Scaffold(body: SupporterMembership(compact: true)),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (source == AuthenticationSource.amber) {
            expect(requests, 0);
            expect(find.text('Divine Supporters'), findsOneWidget);
          } else if (!succeeds) {
            expect(requests, 1);
            expect(find.text('Divine Supporters'), findsOneWidget);
            expect(find.text('Become a supporter'), findsNothing);
          } else {
            expect(requests, 1);
            expect(find.text('Supporter'), findsOneWidget);
            expect(repo.snapshot?.haloVisible, isFalse);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  });

  group('public profile recognition', () {
    for (final visible in [true, false]) {
      testWidgets('renders only an opted-in public result: $visible', (
        tester,
      ) async {
        var signatures = 0;
        final client = SupporterApiClient(
          baseUri: Uri.parse('https://supporters.test'),
          authHeaderProvider: ({required url, required method, payload}) async {
            signatures++;
            return null;
          },
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'supporters': visible
                    ? [
                        {'pubkey': pubkey, 'haloVisible': true},
                      ]
                    : [],
              }),
              200,
            ),
          ),
        );
        addTearDown(client.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [supporterApiClientProvider.overrideWithValue(client)],
            child: buildLocalizedWidget(
              const Scaffold(body: PublicSupporterBadge(pubkey: pubkey)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Supporter'), visible ? findsOneWidget : findsNothing);
        expect(signatures, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });
}
