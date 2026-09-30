import 'dart:async';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockBlossomAuthService extends Mock implements BlossomAuthService {}

class MockNip98AuthService extends Mock implements Nip98AuthService {}

class MockNostrSigner extends Mock implements NostrSigner {}

class MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

const _testPublicKey =
    'aabbccdd0123456789abcdef0123456789abcdef0123456789abcdef01234567';

void main() {
  late MockAuthService mockAuthService;
  late MockBlossomAuthService mockBlossomAuthService;
  late MockNip98AuthService mockNip98AuthService;
  late MockNostrSigner mockNostrSigner;
  late MediaViewerAuthService service;

  setUpAll(() {
    registerFallbackValue(HttpMethod.get);
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockBlossomAuthService = MockBlossomAuthService();
    mockNip98AuthService = MockNip98AuthService();
    mockNostrSigner = MockNostrSigner();
    // Default: the signer is not the non-interactive remote one, so signing is
    // awaited unbounded (matches every pre-existing test's expectation). The
    // timeout tests below opt in by stubbing this true.
    when(() => mockAuthService.currentIdentity).thenReturn(
      BunkerNostrIdentity(
        pubkey: _testPublicKey,
        remoteSigner: mockNostrSigner,
      ),
    );
    service = MediaViewerAuthService(
      authService: mockAuthService,
      blossomAuthService: mockBlossomAuthService,
      nip98AuthService: mockNip98AuthService,
    );
  });

  group('MediaViewerAuthService', () {
    test('canCreatePassiveHeaders allows local signing', () {
      final keyContainer = MockSecureKeyContainer();
      when(() => keyContainer.publicKeyHex).thenReturn(_testPublicKey);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.currentIdentity,
      ).thenReturn(LocalNostrIdentity(keyContainer: keyContainer));

      expect(service.canCreatePassiveHeaders, isTrue);
    });

    test('canCreatePassiveHeaders allows non-interactive remote signing', () {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentIdentity).thenReturn(
        KeycastNostrIdentity(
          pubkey: _testPublicKey,
          rpcSigner: mockNostrSigner,
        ),
      );

      expect(service.canCreatePassiveHeaders, isTrue);
    });

    test('canCreatePassiveHeaders blocks interactive signing', () {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentIdentity).thenReturn(
        BunkerNostrIdentity(
          pubkey: _testPublicKey,
          remoteSigner: mockNostrSigner,
        ),
      );

      expect(service.canCreatePassiveHeaders, isFalse);
    });

    test('prefers Blossom auth when a SHA-256 hash is known', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockBlossomAuthService.createGetAuthHeader(
          sha256Hash: any(named: 'sha256Hash'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer((_) async => 'Nostr blossom-token');

      final result = await service.createAuthHeaders(
        sha256Hash: 'abc123',
        url: 'https://media.divine.video/abc123/720p.mp4',
        serverUrl: 'https://media.divine.video',
      );

      expect(result, isA<ViewerAuthAuthorized>());
      expect(
        result.headersOrNull,
        equals({'Authorization': 'Nostr blossom-token'}),
      );
      verify(
        () => mockBlossomAuthService.createGetAuthHeader(
          sha256Hash: 'abc123',
          serverUrl: 'https://media.divine.video',
        ),
      ).called(1);
      verifyNever(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
        ),
      );
    });

    test('falls back to NIP-98 auth when only a URL is available', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
        ),
      ).thenAnswer(
        (_) async => Nip98Token(
          token: 'nip98-token',
          signedEvent: _createMockEvent(),
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        ),
      );

      final result = await service.createAuthHeaders(
        url: 'https://media.divine.video/no-hash/playlist.m3u8',
      );

      expect(result, isA<ViewerAuthAuthorized>());
      expect(
        result.headersOrNull,
        equals({'Authorization': 'Nostr nip98-token'}),
      );
      verify(
        () => mockNip98AuthService.createAuthToken(
          url: 'https://media.divine.video/no-hash/playlist.m3u8',
          method: HttpMethod.get,
        ),
      ).called(1);
      verifyNever(
        () => mockBlossomAuthService.createGetAuthHeader(
          sha256Hash: any(named: 'sha256Hash'),
          serverUrl: any(named: 'serverUrl'),
        ),
      );
    });

    test('returns null when the user is unauthenticated', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(false);

      final result = await service.createAuthHeaders(
        sha256Hash: 'abc123',
        url: 'https://media.divine.video/abc123/720p.mp4',
      );

      expect(result, isA<ViewerAuthUnavailable>());
      verifyNever(
        () => mockBlossomAuthService.createGetAuthHeader(
          sha256Hash: any(named: 'sha256Hash'),
          serverUrl: any(named: 'serverUrl'),
        ),
      );
      verifyNever(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
        ),
      );
    });

    test('never returns both protocols for a single request', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockBlossomAuthService.createGetAuthHeader(
          sha256Hash: any(named: 'sha256Hash'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer((_) async => 'Nostr blossom-token');

      final result = await service.createAuthHeaders(
        sha256Hash: 'abc123',
        url: 'https://media.divine.video/abc123/720p.mp4',
      );

      expect(result, isA<ViewerAuthAuthorized>());
      expect(
        result.headersOrNull,
        equals({'Authorization': 'Nostr blossom-token'}),
      );
      verify(
        () => mockBlossomAuthService.createGetAuthHeader(sha256Hash: 'abc123'),
      ).called(1);
      verifyNever(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
        ),
      );
    });

    group('remote-signer timeout', () {
      test(
        'bounds a hung remote Blossom sign and reports the signer unreachable '
        'at the timeout',
        () {
          fakeAsync((async) {
            when(() => mockAuthService.isAuthenticated).thenReturn(true);
            when(() => mockAuthService.currentIdentity).thenReturn(
              KeycastNostrIdentity(
                pubkey: _testPublicKey,
                rpcSigner: mockNostrSigner,
              ),
            );
            // Signer never responds (e.g. unreachable Keycast RPC).
            when(
              () => mockBlossomAuthService.createGetAuthHeader(
                sha256Hash: any(named: 'sha256Hash'),
                serverUrl: any(named: 'serverUrl'),
              ),
            ).thenAnswer((_) => Completer<String?>().future);

            final request = _RequestOutcome(
              service.createAuthHeaders(
                sha256Hash: 'abc123',
                serverUrl: 'https://media.divine.video',
              ),
            );

            // Still pending just before the 6s caller-side timeout.
            async.elapse(const Duration(seconds: 5));
            expect(request.isCompleted, isFalse);

            // Fires at the timeout, far short of Keycast's 30s ceiling.
            async.elapse(const Duration(seconds: 2));
            expect(request.error, isNull);
            expect(request.result, isA<ViewerAuthSignerUnreachable>());
          });
        },
      );

      test(
        'bounds a hung remote NIP-98 sign and reports the signer unreachable '
        'at the timeout',
        () {
          fakeAsync((async) {
            when(() => mockAuthService.isAuthenticated).thenReturn(true);
            when(() => mockAuthService.currentIdentity).thenReturn(
              KeycastNostrIdentity(
                pubkey: _testPublicKey,
                rpcSigner: mockNostrSigner,
              ),
            );
            when(
              () => mockNip98AuthService.createAuthToken(
                url: any(named: 'url'),
                method: any(named: 'method'),
              ),
            ).thenAnswer((_) => Completer<Nip98Token?>().future);

            final request = _RequestOutcome(
              service.createAuthHeaders(
                url: 'https://media.divine.video/no-hash/playlist.m3u8',
              ),
            );

            async.elapse(const Duration(seconds: 7));
            expect(request.error, isNull);
            expect(request.result, isA<ViewerAuthSignerUnreachable>());
          });
        },
      );

      test('a fast remote sign still returns real headers', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockAuthService.currentIdentity).thenReturn(
          KeycastNostrIdentity(
            pubkey: _testPublicKey,
            rpcSigner: mockNostrSigner,
          ),
        );
        when(
          () => mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: any(named: 'sha256Hash'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer((_) async => 'Nostr fast-token');

        final result = await service.createAuthHeaders(
          sha256Hash: 'abc123',
          serverUrl: 'https://media.divine.video',
        );

        expect(result, isA<ViewerAuthAuthorized>());
        expect(
          result.headersOrNull,
          equals({'Authorization': 'Nostr fast-token'}),
        );
      });

      test('does NOT bound a non-interactive=false signer — a slow-but-valid '
          'sign past the timeout still returns headers', () {
        fakeAsync((async) {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          // Interactive / local signer: must never be truncated.
          when(() => mockAuthService.currentIdentity).thenReturn(
            BunkerNostrIdentity(
              pubkey: _testPublicKey,
              remoteSigner: mockNostrSigner,
            ),
          );
          final completer = Completer<String?>();
          when(
            () => mockBlossomAuthService.createGetAuthHeader(
              sha256Hash: any(named: 'sha256Hash'),
              serverUrl: any(named: 'serverUrl'),
            ),
          ).thenAnswer((_) => completer.future);

          final request = _RequestOutcome(
            service.createAuthHeaders(
              sha256Hash: 'abc123',
              serverUrl: 'https://media.divine.video',
            ),
          );

          // Well past the 6s timeout: because the timeout is NOT applied to
          // this signer, the call is still awaiting the human approval.
          async.elapse(const Duration(seconds: 20));
          expect(request.isCompleted, isFalse);

          // The valid signature finally arrives and is used.
          completer.complete('Nostr slow-token');
          async.flushMicrotasks();
          expect(request.error, isNull);
          expect(request.result, isA<ViewerAuthAuthorized>());
          expect(
            request.result?.headersOrNull,
            equals({'Authorization': 'Nostr slow-token'}),
          );
        });
      });
    });
  });
}

/// Records how a viewer-auth request settles, so a `fakeAsync` body can
/// assert on it synchronously after advancing fake time.
///
/// The request is deliberately not awaited: it only progresses when the
/// `fakeAsync` body calls `elapse` or `flushMicrotasks`, so awaiting it would
/// stall.
class _RequestOutcome {
  _RequestOutcome(Future<ViewerAuthResult> request) {
    unawaited(
      request.then<void>(
        (value) => result = value,
        onError: (Object caught) => error = caught,
      ),
    );
  }

  ViewerAuthResult? result;
  Object? error;

  bool get isCompleted => result != null || error != null;
}

Event _createMockEvent() {
  final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
  return Event.fromJson({
    'id': 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    'kind': 27235,
    'pubkey': _testPublicKey,
    'created_at': timestamp,
    'content': '',
    'tags': const <List<String>>[
      ['u', 'https://media.divine.video/no-hash/playlist.m3u8'],
      ['method', 'GET'],
    ],
    'sig':
        'deadbeef0123456789abcdef0123456789abcdef0123456789abcdef01234567'
        '89abcdef0123456789abcdef0123456789abcdef0123456789abcdef01234567'
        '89ab',
  });
}
