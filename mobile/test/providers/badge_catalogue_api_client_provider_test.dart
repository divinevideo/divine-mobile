// ABOUTME: Badge discovery trusts the configured API, not account relay origins.

import 'dart:convert';

import 'package:badge_repository/badge_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends Mock implements AuthService {}

class _NostrClient extends Mock implements NostrClient {}

void main() {
  group('badgeCatalogueApiClientProvider', () {
    test(
      'catalogue reads ignore an account relay serving forged issuer events',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final auth = _Auth();
        when(() => auth.currentPublicKeyHex).thenReturn('1' * 64);
        when(() => auth.authStateStream)
            .thenAnswer((_) => const Stream.empty());
        final nostr = _NostrClient();
        when(() => nostr.configuredRelays)
            .thenReturn(['wss://custom-relay.example']);
        final issuer = '2' * 64;
        // Public hashes can be constructed without the issuer's signing key.
        final forged = Event(
          issuer,
          EventKind.badgeDefinition,
          [
            ['d', 'forged'],
            ['name', 'Forged from account relay'],
          ],
          '',
          createdAt: 1000,
        )..sig = '0' * 128;
        final requests = <Uri>[];
        final transport = MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode({
              'badges': request.url.host == 'api.divine.video'
                  ? []
                  : [forged.toJson()],
              'next_cursor': null,
            }),
            200,
          );
        });
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            nostrServiceProvider.overrideWithValue(nostr),
            sharedPreferencesProvider.overrideWithValue(preferences),
            contentBlocklistRepositoryProvider.overrideWithValue(
              ContentBlocklistRepository(),
            ),
            currentEnvironmentProvider.overrideWithValue(
              EnvironmentConfig.production,
            ),
            appVersionProvider.overrideWithValue('1.0.0'),
            instrumentedHttpClientFactoryProvider.overrideWithValue(
              () => transport,
            ),
          ],
        );
        addTearDown(container.dispose);

        final BadgeRepository repository = container.read(
          badgeRepositoryProvider,
        );
        final definitions = await repository.loadDefinitionsByIssuers([issuer]);

        expect(definitions, isEmpty);
        expect(requests.map((uri) => uri.origin), ['https://api.divine.video']);
      },
    );
  });
}
