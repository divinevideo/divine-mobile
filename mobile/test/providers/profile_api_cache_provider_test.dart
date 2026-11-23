// ABOUTME: Ensures eligibility response caches follow the active API client.
// ABOUTME: An environment change cannot reuse another backend's badge answer.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
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

    test('sends lookups started within one window as one bulk request', () {
      fakeAsync((async) {
        final api = _Api();
        when(() => api.isAvailable).thenReturn(true);
        when(
          () => api.getBulkProfiles(any()),
        ).thenAnswer((_) => Completer<BulkProfilesResponse>().future);
        final container = ProviderContainer(
          overrides: [funnelcakeApiClientProvider.overrideWithValue(api)],
        );
        final cache = container.read(profileApiCacheProvider);
        unawaited(cache.getProfile(pubkey));
        unawaited(cache.getProfile(otherPubkey));

        async.elapse(
          profileLookupBatchWindow - const Duration(milliseconds: 1),
        );
        verifyNever(() => api.getBulkProfiles(any()));
        async.elapse(const Duration(milliseconds: 1));

        final asked = verify(
          () => api.getBulkProfiles(captureAny()),
        ).captured;
        expect(asked, [
          [pubkey, otherPubkey],
        ]);
        container.dispose();
      });
    });

    test('disposes the cache with the container', () {
      fakeAsync((async) {
        final api = _Api();
        when(() => api.isAvailable).thenReturn(true);
        final container = ProviderContainer(
          overrides: [funnelcakeApiClientProvider.overrideWithValue(api)],
        );
        Object? result = #pending;
        unawaited(
          container
              .read(profileApiCacheProvider)
              .getProfile(pubkey)
              .then((value) => result = value),
        );

        container.dispose();
        async.elapse(profileLookupBatchWindow);

        expect(result, isNull);
        verifyNever(() => api.getUserProfile(any()));
      });
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
