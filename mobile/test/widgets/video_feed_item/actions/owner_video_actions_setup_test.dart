// ABOUTME: Tests for the shared viewer checks the video sheets use to decide
// ABOUTME: whether to offer the owner actions and Report this remix.

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

VideoEvent _video({
  String pubkey = _creatorPubkey,
  List<ClipSourceCredit> clipSourceCredits = const [],
}) => VideoEvent(
  id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  pubkey: pubkey,
  clipSourceCredits: clipSourceCredits,
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
  group('signedInViewerPubkey', () {
    test('returns the signed-in viewer', () {
      final container = _container([
        authServiceProvider.overrideWithValue(
          createMockAuthService(
            authState: AuthState.authenticated,
            currentPublicKeyHex: _otherPubkey,
          ),
        ),
      ]);

      expect(signedInViewerPubkey(container), equals(_otherPubkey));
    });

    test('returns null when the viewer is signed out', () {
      final container = _container([
        authServiceProvider.overrideWithValue(
          createMockAuthService(currentPublicKeyHex: _otherPubkey),
        ),
      ]);

      expect(signedInViewerPubkey(container), isNull);
    });

    test('returns null when the auth service provider throws', () {
      final container = _container([
        authServiceProvider.overrideWith((ref) => throw StateError('auth')),
      ]);

      expect(signedInViewerPubkey(container), isNull);
    });
  });

  group('isVideoByViewer', () {
    test('returns true when the viewer created the video', () {
      expect(isVideoByViewer(_video(), _creatorPubkey), isTrue);
    });

    test('matches the viewer whatever the pubkey case', () {
      expect(_creatorPubkey, isNot(_creatorPubkey.toUpperCase()));
      expect(isVideoByViewer(_video(), _creatorPubkey.toUpperCase()), isTrue);
    });

    test('returns false for another viewer or none', () {
      expect(isVideoByViewer(_video(), _otherPubkey), isFalse);
      expect(isVideoByViewer(_video(), null), isFalse);
    });
  });

  group('isRemixOfViewersVideo', () {
    final remix = _video(
      pubkey: _otherPubkey,
      clipSourceCredits: [
        ClipSourceCredit.fromAddressableId(
          addressableId: '34236:$_creatorPubkey:source',
        ),
      ],
    );

    test('returns true when the video credits a clip of the viewer', () {
      expect(isRemixOfViewersVideo(remix, _creatorPubkey), isTrue);
    });

    test('matches the credited pubkey whatever its case', () {
      expect(
        isRemixOfViewersVideo(remix, _creatorPubkey.toUpperCase()),
        isTrue,
      );
    });

    test('returns false when it credits someone else', () {
      expect(isRemixOfViewersVideo(remix, _otherPubkey), isFalse);
    });

    test('returns false for a video crediting no clip', () {
      expect(
        isRemixOfViewersVideo(_video(pubkey: _otherPubkey), _creatorPubkey),
        isFalse,
      );
    });

    test("returns false on the viewer's own video", () {
      final ownRemix = _video(
        clipSourceCredits: [
          ClipSourceCredit.fromAddressableId(
            addressableId: '34236:$_creatorPubkey:source',
          ),
        ],
      );

      expect(isRemixOfViewersVideo(ownRemix, _creatorPubkey), isFalse);
    });

    test('returns false with no signed-in viewer', () {
      expect(isRemixOfViewersVideo(remix, null), isFalse);
    });
  });
}
