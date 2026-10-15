// ABOUTME: Tests for the video sharing service provider readiness gate.
// ABOUTME: Verifies sharing providers tolerate auth-before-Nostr-ready states.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group('videoSharingServiceProvider', () {
    test(
      'returns null instead of throwing when profile repository is unavailable',
      () {
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(_MockAuthService()),
            profileReadRepositoryProvider.overrideWithValue(null),
            dmRepositoryProvider.overrideWithValue(_MockDmRepository()),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(videoSharingServiceProvider), isNull);
      },
    );

    test('is available once the identity is known, before relays connect', () {
      // The service reads profiles and nothing more, so gating it on the
      // relay-ready client left Share a silent dead tap for the whole
      // cold-start window (#6423). Publishing readiness is enforced on the
      // send path instead, via AuthService.canPublishNostrWritesNow.
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_MockAuthService()),
          profileRepositoryProvider.overrideWithValue(null),
          profileReadRepositoryProvider.overrideWithValue(
            _MockProfileRepository(),
          ),
          dmRepositoryProvider.overrideWithValue(_MockDmRepository()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(videoSharingServiceProvider), isNotNull);
    });
  });
}
