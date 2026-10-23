// ABOUTME: Tests own-account membership entries in settings and on the profile.
// ABOUTME: Covers refresh without store work and suppression of external prompts.

import 'dart:async';
import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/supporter/supporter_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
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

/// Stands in for whatever the membership scope wraps, reading its cubit as
/// the profile does, so a test can tell whether that subtree was kept or
/// rebuilt from scratch.
class _ScopedContent extends StatefulWidget {
  const _ScopedContent();

  @override
  State<_ScopedContent> createState() => _ScopedContentState();
}

class _ScopedContentState extends State<_ScopedContent> {
  @override
  Widget build(BuildContext context) {
    context.select<SupporterCubit?, bool>(
      (cubit) => cubit?.state.isSupporter ?? false,
    );
    return const SizedBox.shrink();
  }
}

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('own account membership', () {
    testWidgets('signed-out compact entry supplies its own Material', (
      tester,
    ) async {
      final auth = _MockAuth();
      when(() => auth.isAuthenticated).thenReturn(false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            currentAuthStateProvider.overrideWithValue(
              AuthState.unauthenticated,
            ),
          ],
          child: buildLocalizedWidget(
            const ColoredBox(
              color: Colors.black,
              child: SupporterMembership(compact: true),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ActionChip), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('signed-out settings entry describes the subscription', (
      tester,
    ) async {
      final auth = _MockAuth();
      when(() => auth.isAuthenticated).thenReturn(false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            currentAuthStateProvider.overrideWithValue(
              AuthState.unauthenticated,
            ),
          ],
          child: buildLocalizedWidget(
            const Scaffold(body: SupporterMembership()),
          ),
        ),
      );
      expect(find.text(l10n.supporterTileSubtitle), findsOneWidget);
    });

    // DivineIcon ignores the chip's IconTheme and would otherwise keep the
    // asset's white fill, which disappears on the light chip.
    for (final (mode, theme, colors) in [
      ('light', VineTheme.lightTheme, VineTheme.lightColors),
      ('dark', VineTheme.theme, VineTheme.darkColors),
    ]) {
      testWidgets('compact entry tints its heart with $mode primary text', (
        tester,
      ) async {
        final auth = _MockAuth();
        when(() => auth.isAuthenticated).thenReturn(false);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(auth),
              currentAuthStateProvider.overrideWithValue(
                AuthState.unauthenticated,
              ),
            ],
            child: MaterialApp(
              theme: theme,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: SupporterMembership(compact: true)),
            ),
          ),
        );

        final heart = tester.widget<DivineIcon>(
          find.descendant(
            of: find.byType(ActionChip),
            matching: find.byType(DivineIcon),
          ),
        );
        expect(heart.color, equals(colors.primaryText));
      });
    }

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
      expect(find.text(l10n.supporterTitle), findsOneWidget);
      expect(find.text(l10n.supporterJoinLabel), findsNothing);
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
      expect(find.text(l10n.supporterBadgeLabel), findsNothing);
      expect(find.text(l10n.supporterJoinLabel), findsOneWidget);
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
            expect(find.text(l10n.supporterTitle), findsOneWidget);
          } else if (!succeeds) {
            expect(requests, 1);
            expect(find.text(l10n.supporterTitle), findsOneWidget);
            expect(find.text(l10n.supporterJoinLabel), findsNothing);
          } else {
            expect(requests, 1);
            expect(repo.isSupporter, isTrue);
            // The halo and wings mark a supporter's profile instead.
            expect(find.byType(ActionChip), findsNothing);
            expect(repo.snapshot?.haloVisible, isFalse);

            // Settings still acknowledges the membership.
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
                  const Scaffold(body: SupporterMembership()),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text(l10n.supporterBadgeLabel), findsOneWidget);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets('refreshes when a remote signer becomes ready without '
        'rebuilding what it wraps', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var signerReady = false;
      final capability = StreamController<AuthRpcCapability>();
      addTearDown(capability.close);
      final auth = _MockAuth();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(
        () => auth.authenticationSource,
      ).thenReturn(AuthenticationSource.divineOAuth);
      when(() => auth.canPublishNostrWritesNow).thenAnswer((_) => signerReady);
      when(() => auth.authRpcCapability).thenAnswer(
        (_) => signerReady
            ? AuthRpcCapability.rpcReady
            : AuthRpcCapability.unavailable,
      );
      when(
        () => auth.authRpcCapabilityStream,
      ).thenAnswer((_) => capability.stream);
      var requests = 0;
      final client = SupporterApiClient(
        baseUri: Uri.parse('https://supporters.test'),
        authHeaderProvider: ({required url, required method, payload}) async =>
            (authorizationHeader: 'Nostr fixture', pubkey: pubkey),
        httpClient: MockClient((_) async {
          requests++;
          return http.Response(
            jsonEncode({
              'status': 'active',
              'entitlement': {'source': 'server', 'isActive': true},
              'recognition': {'haloVisible': true},
            }),
            200,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = SupporterRepository(
        pubkey: pubkey,
        validator: StubEntitlementValidator(),
        prefs: await SharedPreferences.getInstance(),
        apiClient: client,
      );
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            currentAuthStateProvider.overrideWithValue(
              AuthState.authenticated,
            ),
            supporterRepositoryProvider.overrideWithValue(repo),
          ],
          child: buildLocalizedWidget(
            const Scaffold(
              body: SupporterMembershipScope(child: _ScopedContent()),
            ),
          ),
        ),
      );
      await tester.pump();
      final content = tester.state(find.byType(_ScopedContent));
      expect(requests, isZero);

      signerReady = true;
      capability.add(AuthRpcCapability.rpcReady);
      await tester.pumpAndSettle();

      expect(requests, 1);
      expect(tester.state(find.byType(_ScopedContent)), same(content));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
