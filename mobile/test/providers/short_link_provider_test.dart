// ABOUTME: Verifies short-link auth binding, opt-in and account-scoped cache disposal.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/short_link_provider.dart';
import 'package:openvine/services/auth_service.dart';

class _Auth extends Mock implements AuthService {}

void main() {
  const target = 'https://divine.video/video/synthetic-provider-check';
  const shortened = 'https://divine.video/l/Abc12345';
  group('shortLinkClientProvider', () {
    test('short-link sharing is enabled by default on native builds', () {
      expect(
        const BuildConfiguration(
          isWeb: false,
        ).getDefault(FeatureFlag.shortLinksSharing),
        isTrue,
      );
    });

    test('web builds retain canonical links by default', () {
      expect(
        const BuildConfiguration(
          isWeb: true,
        ).getDefault(FeatureFlag.shortLinksSharing),
        isFalse,
      );
    });

    test(
      'disabled sharing does not construct auth or HTTP',
      () {
        final container = ProviderContainer(
          overrides: [
            isFeatureEnabledProvider(FeatureFlag.shortLinksSharing)
                .overrideWithValue(false),
            authServiceProvider.overrideWith(
              (ref) => throw StateError('auth must not be read'),
            ),
            instrumentedHttpClientFactoryProvider.overrideWith(
              (ref) => throw StateError('HTTP must not be created'),
            ),
          ],
        );
        addTearDown(container.dispose);
        expect(container.read(shortLinkClientProvider), isNull);
      },
    );

    test('signed-out opt-in has no creator or HTTP side effects', () {
      final auth = _Auth();
      when(() => auth.isAuthenticated).thenReturn(false);
      final container = ProviderContainer(
        overrides: [
          isFeatureEnabledProvider(FeatureFlag.shortLinksSharing)
              .overrideWithValue(true),
          authServiceProvider.overrideWithValue(auth),
          currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
          currentAccountActivationReceiptProvider.overrideWithValue(null),
          instrumentedHttpClientFactoryProvider.overrideWith(
            (ref) => throw StateError('HTTP must not be created'),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(shortLinkClientProvider), isNull);
    });

    test(
      'signs exact POST body with NIP-98 and disposes the old cache',
      () async {
        final auth = _Auth();
        when(() => auth.isAuthenticated).thenReturn(true);
        when(() => auth.canPublishNostrWritesNow).thenReturn(true);
        when(() => auth.currentPublicKeyHex).thenReturn('c' * 64);
        when(
          () => auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer(
          (call) async => Event.fromJson({
            'id': 'a' * 64,
            'pubkey': 'c' * 64,
            'created_at': call.namedArguments[#createdAt] as int,
            'kind': 27235,
            'content': '',
            'tags': call.namedArguments[#tags] as List<List<String>>,
            'sig': 'b' * 128,
          }),
        );
        var requests = 0;
        final transport = MockClient((request) async {
          requests++;
          expect(
            request.url.toString(),
            'https://gateway.divine.video/api/links',
          );
          final header = request.headers['Authorization']!;
          expect(header, startsWith('Nostr '));
          final event = jsonDecode(
            utf8.decode(base64.decode(header.substring(6))),
          ) as Map<String, dynamic>;
          expect(event['kind'], 27235);
          expect(
            event['tags'],
            containsAll([
              ['u', request.url.toString()],
              ['method', 'POST'],
              ['payload', sha256.convert(utf8.encode(request.body)).toString()],
            ]),
          );
          return http.Response(
            jsonEncode({
              'code': 'Abc12345',
              'short_url': shortened,
              'url': target,
            }),
            201,
          );
        });
        final container = ProviderContainer(
          overrides: [
            isFeatureEnabledProvider(FeatureFlag.shortLinksSharing)
                .overrideWithValue(true),
            authServiceProvider.overrideWithValue(auth),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            currentAccountActivationReceiptProvider.overrideWithValue(null),
            instrumentedHttpClientFactoryProvider.overrideWithValue(
              () => transport,
            ),
          ],
        );
        addTearDown(container.dispose);
        final old = container.read(shortLinkClientProvider)!;
        expect(await old.shorten(target), shortened);
        container.invalidate(shortLinkClientProvider);
        expect(await old.shorten(target), target);
        expect(requests, 1);
        verifyNever(auth.getBoundDivineAccessToken);
      },
    );
  });
}
