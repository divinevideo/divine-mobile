// ABOUTME: Tests for SocialIdentityService: availability per platform, the
// ABOUTME: nonce contract with Keycast, and how plugin errors are classified.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:keycast_flutter/keycast_flutter.dart' show SocialProvider;
import 'package:openvine/services/social_identity_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class _FakeGoogle implements GoogleIdTokenSource {
  final initializations =
      <({String? clientId, String serverClientId, String nonce})>[];
  int signOuts = 0;
  Object? authenticateError;
  String? idToken = 'google.id.token';

  @override
  Future<void> initialize({
    required String? clientId,
    required String serverClientId,
    required String nonce,
  }) async {
    initializations.add((
      clientId: clientId,
      serverClientId: serverClientId,
      nonce: nonce,
    ));
  }

  @override
  Future<String?> authenticate() async {
    final error = authenticateError;
    if (error != null) throw error;
    return idToken;
  }

  @override
  Future<void> signOut() async => signOuts++;
}

class _FakeApple implements AppleIdTokenSource {
  final nonces = <String>[];
  Object? error;
  String? identityToken = 'apple.id.token';

  @override
  Future<({String? identityToken, String authorizationCode})> authenticate({
    required String nonce,
  }) async {
    nonces.add(nonce);
    final error = this.error;
    if (error != null) throw error;
    return (identityToken: identityToken, authorizationCode: 'apple-code');
  }
}

void main() {
  group(SocialIdentityService, () {
    late _FakeGoogle google;
    late _FakeApple apple;
    late int nonceCount;

    setUp(() {
      google = _FakeGoogle();
      apple = _FakeApple();
      nonceCount = 0;
    });

    SocialIdentityService buildService({
      TargetPlatform platform = TargetPlatform.iOS,
      bool isWeb = false,
      String serverClientId = 'server.apps.googleusercontent.com',
      Map<String, String> iosClientIds = const {
        'co.openvine.app': 'ios.apps.googleusercontent.com',
        'co.openvine.app.staging': 'ios-staging.apps.googleusercontent.com',
      },
      String bundleId = 'co.openvine.app.staging',
    }) => SocialIdentityService(
      google: google,
      apple: apple,
      readBundleId: () async => bundleId,
      platform: platform,
      isWeb: isWeb,
      generateRawNonce: () => 'raw-nonce-${nonceCount++}',
      googleServerClientId: serverClientId,
      googleIosClientIds: iosClientIds,
    );

    group('isAvailable', () {
      test('offers Apple and Google on iOS', () {
        final service = buildService();

        expect(service.isAvailable(SocialProvider.apple), isTrue);
        expect(service.isAvailable(SocialProvider.google), isTrue);
      });

      test('offers only Google on Android', () {
        final service = buildService(platform: TargetPlatform.android);

        expect(service.isAvailable(SocialProvider.apple), isFalse);
        expect(service.isAvailable(SocialProvider.google), isTrue);
      });

      test('offers neither on the web', () {
        final service = buildService(isWeb: true);

        expect(service.isAvailable(SocialProvider.apple), isFalse);
        expect(service.isAvailable(SocialProvider.google), isFalse);
      });

      test('offers neither on desktop', () {
        final service = buildService(platform: TargetPlatform.macOS);

        expect(service.isAvailable(SocialProvider.apple), isFalse);
        expect(service.isAvailable(SocialProvider.google), isFalse);
      });

      test('hides Google until its client IDs are configured', () {
        expect(
          buildService(serverClientId: '').isAvailable(SocialProvider.google),
          isFalse,
        );
        expect(
          buildService(
            iosClientIds: const {'co.openvine.app': ''},
          ).isAvailable(SocialProvider.google),
          isFalse,
        );
      });
    });

    group('obtainToken with Google', () {
      test('binds the token to the hash of the nonce it returns', () async {
        final service = buildService();

        final token = await service.obtainToken(SocialProvider.google);

        expect(token.provider, SocialProvider.google);
        expect(token.idToken, 'google.id.token');
        expect(token.authorizationCode, isNull);
        expect(google.initializations, hasLength(1));
        expect(
          google.initializations.single.nonce,
          SocialIdentityService.hashNonce(token.rawNonce),
        );
      });

      test('uses the iOS client of the running bundle', () async {
        final service = buildService(bundleId: 'co.openvine.app');

        await service.obtainToken(SocialProvider.google);

        expect(
          google.initializations.single.clientId,
          'ios.apps.googleusercontent.com',
        );
        expect(
          google.initializations.single.serverClientId,
          'server.apps.googleusercontent.com',
        );
      });

      test('lets the Android plugin find its own client', () async {
        final service = buildService(platform: TargetPlatform.android);

        await service.obtainToken(SocialProvider.google);

        expect(google.initializations.single.clientId, isNull);
      });

      test('initializes the plugin once and reuses its nonce', () async {
        final service = buildService();

        final first = await service.obtainToken(SocialProvider.google);
        final second = await service.obtainToken(SocialProvider.google);

        expect(google.initializations, hasLength(1));
        expect(second.rawNonce, first.rawNonce);
      });

      test('signs out of Google after each attempt', () async {
        final service = buildService();
        await service.obtainToken(SocialProvider.google);
        google.authenticateError = const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        );

        await expectLater(
          service.obtainToken(SocialProvider.google),
          throwsA(isA<SocialIdentityException>()),
        );
        expect(google.signOuts, 2);
      });

      test('reports a closed sheet as cancelled', () async {
        google.authenticateError = const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        );

        await expectLater(
          buildService().obtainToken(SocialProvider.google),
          throwsA(
            isA<SocialIdentityException>().having(
              (e) => e.failure,
              'failure',
              SocialIdentityFailure.cancelled,
            ),
          ),
        );
      });

      test('reports a missing ID token as failed', () async {
        google.idToken = null;

        await expectLater(
          buildService().obtainToken(SocialProvider.google),
          throwsA(
            isA<SocialIdentityException>().having(
              (e) => e.failure,
              'failure',
              SocialIdentityFailure.failed,
            ),
          ),
        );
      });

      test('refuses a bundle without its own iOS client', () async {
        final service = buildService(
          iosClientIds: const {'co.openvine.app': 'ios.apps'},
        );

        await expectLater(
          service.obtainToken(SocialProvider.google),
          throwsA(
            isA<SocialIdentityException>().having(
              (e) => e.failure,
              'failure',
              SocialIdentityFailure.unavailable,
            ),
          ),
        );
        expect(google.initializations, isEmpty);
      });
    });

    group('obtainToken with Apple', () {
      test(
        'returns the identity token, code and a fresh nonce each time',
        () async {
          final service = buildService();

          final first = await service.obtainToken(SocialProvider.apple);
          final second = await service.obtainToken(SocialProvider.apple);

          expect(first.idToken, 'apple.id.token');
          expect(first.authorizationCode, 'apple-code');
          expect(second.rawNonce, isNot(first.rawNonce));
          expect(apple.nonces, [
            SocialIdentityService.hashNonce(first.rawNonce),
            SocialIdentityService.hashNonce(second.rawNonce),
          ]);
        },
      );

      test('reports a closed sheet as cancelled', () async {
        apple.error = const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'canceled',
        );

        await expectLater(
          buildService().obtainToken(SocialProvider.apple),
          throwsA(
            isA<SocialIdentityException>().having(
              (e) => e.failure,
              'failure',
              SocialIdentityFailure.cancelled,
            ),
          ),
        );
      });

      test('reports a missing identity token as failed', () async {
        apple.identityToken = null;

        await expectLater(
          buildService().obtainToken(SocialProvider.apple),
          throwsA(
            isA<SocialIdentityException>().having(
              (e) => e.failure,
              'failure',
              SocialIdentityFailure.failed,
            ),
          ),
        );
      });

      test('is refused on Android without showing anything', () async {
        final service = buildService(platform: TargetPlatform.android);

        expect(
          () => service.obtainToken(SocialProvider.apple),
          throwsA(
            isA<SocialIdentityException>().having(
              (e) => e.failure,
              'failure',
              SocialIdentityFailure.unavailable,
            ),
          ),
        );
        expect(apple.nonces, isEmpty);
      });
    });

    group('hashNonce', () {
      test('is the lowercase hex SHA-256 Keycast recomputes', () {
        expect(
          SocialIdentityService.hashNonce('abc'),
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        );
      });
    });

    group('plugin error classification', () {
      test('treats an interrupted Google flow like a closed sheet', () {
        expect(
          SocialIdentityService.googleFailureFor(
            GoogleSignInExceptionCode.interrupted,
          ),
          SocialIdentityFailure.cancelled,
        );
      });

      test('treats missing Google configuration as unavailable', () {
        for (final code in [
          GoogleSignInExceptionCode.clientConfigurationError,
          GoogleSignInExceptionCode.providerConfigurationError,
          GoogleSignInExceptionCode.uiUnavailable,
        ]) {
          expect(
            SocialIdentityService.googleFailureFor(code),
            SocialIdentityFailure.unavailable,
            reason: '$code',
          );
        }
      });

      test('treats unknown Google errors as failed', () {
        expect(
          SocialIdentityService.googleFailureFor(
            GoogleSignInExceptionCode.unknownError,
          ),
          SocialIdentityFailure.failed,
        );
      });

      test('treats an unhandled Apple request as unavailable', () {
        expect(
          SocialIdentityService.appleFailureFor(
            AuthorizationErrorCode.notHandled,
          ),
          SocialIdentityFailure.unavailable,
        );
        expect(
          SocialIdentityService.appleFailureFor(AuthorizationErrorCode.failed),
          SocialIdentityFailure.failed,
        );
      });
    });
  });
}
