import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:openvine/features/guest_classics/guest_classics_providers.dart';

void main() {
  group('resolveGuestClassicsBase', () {
    test('accepts valid https base on first iOS or Android session', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        expect(
          resolveGuestClassicsBase(
            configured: 'https://example.test/seeds',
            isWeb: false,
            platform: platform,
            sessionCount: 1,
          ).toString(),
          'https://example.test/seeds/',
        );
        expect(
          resolveGuestClassicsBase(
            configured: 'https://example.test/seeds/',
            isWeb: false,
            platform: platform,
            sessionCount: 1,
          ).toString(),
          'https://example.test/seeds/',
        );
        expect(
          resolveGuestClassicsBase(
            configured: 'https://example.test',
            isWeb: false,
            platform: platform,
            sessionCount: 1,
          ).toString(),
          'https://example.test/',
        );
      }
    });

    test('rejects empty, web, desktop, non-first-session, and unsafe URIs', () {
      expect(
        resolveGuestClassicsBase(
          configured: '',
          isWeb: false,
          platform: TargetPlatform.iOS,
          sessionCount: 1,
        ),
        isNull,
      );
      expect(
        resolveGuestClassicsBase(
          configured: 'https://example.test/seeds',
          isWeb: true,
          platform: TargetPlatform.iOS,
          sessionCount: 1,
        ),
        isNull,
      );
      for (final desktop in [
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(
          resolveGuestClassicsBase(
            configured: 'https://example.test/seeds',
            isWeb: false,
            platform: desktop,
            sessionCount: 1,
          ),
          isNull,
        );
      }
      for (final count in [null, 0, 2]) {
        expect(
          resolveGuestClassicsBase(
            configured: 'https://example.test/seeds',
            isWeb: false,
            platform: TargetPlatform.android,
            sessionCount: count,
          ),
          isNull,
        );
      }
      for (final badUri in [
        'http://example.test/seeds',
        'https://user@example.test/seeds',
        'https://example.test/seeds?a=1',
        'https://example.test/seeds#frag',
        'https:///missing-host',
      ]) {
        expect(
          resolveGuestClassicsBase(
            configured: badUri,
            isWeb: false,
            platform: TargetPlatform.iOS,
            sessionCount: 1,
          ),
          isNull,
        );
      }
    });
  });

  group('guestClassicsProviders', () {
    test('defaults to null when no compile-time manifest URL is set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(guestClassicsBaseProvider), isNull);
    });

    test(
      'manifest loader returns null without network when base is null',
      () async {
        final container = ProviderContainer(
          overrides: [guestClassicsBaseProvider.overrideWithValue(null)],
        );
        addTearDown(container.dispose);
        var requests = 0;
        final client = MockClient((_) async {
          requests++;
          throw StateError('unexpected network request');
        });
        final loader = container.read(guestClassicsManifestProvider);
        expect(await loader(client, muted: true), isNull);
        expect(requests, 0);
      },
    );
  });
}
