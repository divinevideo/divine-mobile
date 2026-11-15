// ABOUTME: Tests for the shared ownership check both video sheets use to
// ABOUTME: decide whether to offer the owner actions.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/video_feed_item/actions/owner_video_actions_setup.dart';

import '../../../helpers/test_provider_overrides.dart';

const _creatorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

VideoEvent _video() => VideoEvent(
  id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  pubkey: _creatorPubkey,
  createdAt: 1700000000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
);

ProviderContainer _container(List<Override> overrides) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('isViewerOwnVideo', () {
    test('returns true when the signed-in viewer created the video', () {
      final container = _container([
        authServiceProvider.overrideWithValue(
          createMockAuthService(
            authState: AuthState.authenticated,
            currentPublicKeyHex: _creatorPubkey,
          ),
        ),
      ]);

      expect(isViewerOwnVideo(container, _video()), isTrue);
    });

    test('returns false when another account created the video', () {
      final container = _container([
        authServiceProvider.overrideWithValue(
          createMockAuthService(
            authState: AuthState.authenticated,
            currentPublicKeyHex: _otherPubkey,
          ),
        ),
      ]);

      expect(isViewerOwnVideo(container, _video()), isFalse);
    });

    test('returns false when the viewer is signed out', () {
      final container = _container([
        authServiceProvider.overrideWithValue(
          createMockAuthService(currentPublicKeyHex: _creatorPubkey),
        ),
      ]);

      expect(isViewerOwnVideo(container, _video()), isFalse);
    });

    test('returns false when the auth state cannot be read', () {
      final authService = createMockAuthService(
        authState: AuthState.authenticated,
        currentPublicKeyHex: _creatorPubkey,
      );
      when(() => authService.isAuthenticated).thenThrow(StateError('auth'));
      final container = _container([
        authServiceProvider.overrideWithValue(authService),
      ]);

      expect(isViewerOwnVideo(container, _video()), isFalse);
    });

    test('returns false when the auth service provider throws', () {
      final container = _container([
        authServiceProvider.overrideWith((ref) => throw StateError('auth')),
      ]);

      expect(isViewerOwnVideo(container, _video()), isFalse);
    });
  });
}
