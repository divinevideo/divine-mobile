// ABOUTME: Ensures eligibility response caches follow the active API client.
// ABOUTME: An environment change cannot reuse another backend's badge answer.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/profile_api_cache_provider.dart';

class _Api extends Mock implements FunnelcakeApiClient {}

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const otherPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  group('profileApiCacheProvider', () {
    setUpAll(() => registerFallbackValue(<String>[]));

    test(
      'keeps batchWindow disabled so single lookups preserve archived_loops',
      () async {
        final api = _Api();
        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getUserProfile(any())).thenAnswer(
          (invocation) async => UserProfileNotPublished(
            pubkey: invocation.positionalArguments.single as String,
            isOgDiviner: false,
          ),
        );
        final container = ProviderContainer(
          overrides: [funnelcakeApiClientProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);

        final cache = container.read(profileApiCacheProvider);
        await Future.wait([
          cache.getProfile(pubkey),
          cache.getProfile(otherPubkey),
        ]);

        verify(() => api.getUserProfile(pubkey)).called(1);
        verify(() => api.getUserProfile(otherPubkey)).called(1);
        verifyNever(() => api.getBulkProfiles(any()));
      },
    );

    test('disposes cleanly with the container', () {
      final api = _Api();
      when(() => api.isAvailable).thenReturn(true);
      final container = ProviderContainer(
        overrides: [funnelcakeApiClientProvider.overrideWithValue(api)],
      );

      container.read(profileApiCacheProvider);
      expect(container.dispose, returnsNormally);
    });

    test(
      'replaces the eligibility cache with the environment client',
      () async {
        final firstApi = _Api();
        when(() => firstApi.isAvailable).thenReturn(true);
        when(() => firstApi.getUserProfile(pubkey)).thenAnswer(
          (_) async => const UserProfileNotPublished(
            pubkey: pubkey,
            isOgDiviner: true,
          ),
        );
        final secondApi = _Api();
        when(() => secondApi.isAvailable).thenReturn(true);
        when(() => secondApi.getUserProfile(pubkey)).thenAnswer(
          (_) async => const UserProfileNotPublished(
            pubkey: pubkey,
            isOgDiviner: false,
          ),
        );
        final container = ProviderContainer(
          overrides: [funnelcakeApiClientProvider.overrideWithValue(firstApi)],
        );
        addTearDown(container.dispose);
        final first = container.read(profileApiCacheProvider);
        expect(await first.isOgDiviner(pubkey), isTrue);

        container.updateOverrides([
          funnelcakeApiClientProvider.overrideWithValue(secondApi),
        ]);
        await container.pump();
        final second = container.read(profileApiCacheProvider);
        expect(identical(first, second), isFalse);
        expect(await second.isOgDiviner(pubkey), isFalse);
        verify(() => firstApi.getUserProfile(pubkey)).called(1);
        verify(() => secondApi.getUserProfile(pubkey)).called(1);
      },
    );
  });
}
