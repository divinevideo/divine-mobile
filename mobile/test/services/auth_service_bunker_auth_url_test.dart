// ABOUTME: Tests for the AuthUrlLauncher port — the NIP-46 bunker auth_url
// ABOUTME: callback must launch through the injected seam, never a plugin.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart'
    show NostrRemoteSigner, NostrRemoteSignerInfo;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

import 'support/auth_service_test_harness.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

/// Mock signer that stores the auth-url callback AuthService installs, so the
/// test can fire it like the remote signer would on an `auth_url` response.
class _MockNostrRemoteSigner extends Mock implements NostrRemoteSigner {
  void Function(String authUrl)? capturedAuthUrlCallback;

  @override
  set onAuthUrlReceived(void Function(String authUrl)? callback) {
    capturedAuthUrlCallback = callback;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService bunker auth_url launching', () {
    late _MockUserDataCleanupService mockCleanupService;
    late _MockNostrRemoteSigner signer;

    setUp(() async {
      await LogCaptureService().clearAllLogs();
      mockCleanupService = _MockUserDataCleanupService();
      stubUserDataCleanupSuccess(mockCleanupService);
      AuthServiceChannelMocks.install();
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
      signer = _MockNostrRemoteSigner();
    });

    tearDown(AuthServiceChannelMocks.remove);

    /// Connects a bunker through [signer] so AuthService installs its
    /// auth-url callback on it. Returns the connected service.
    Future<AuthService> connectBunker({AuthUrlLauncher? launchAuthUrl}) async {
      final url =
          'bunker://${freshPubkeyHex()}'
          '?relay=wss%3A%2F%2Frelay.example.com&secret=testsecret';
      when(
        () => signer.info,
      ).thenReturn(NostrRemoteSignerInfo.parseBunkerUrl(url));
      when(() => signer.connect()).thenAnswer((_) async => 'ack');
      when(() => signer.pullPubkey()).thenAnswer((_) async => freshPubkeyHex());

      final authService = buildTestAuthService(
        cleanupService: mockCleanupService,
        remoteSignerFactory: (_, _) => signer,
        launchAuthUrl: launchAuthUrl,
      );
      addTearDown(authService.dispose);

      final result = await ignoringDiscoveryErrors(
        () => authService.connectWithBunker(url),
      );
      expect(result.success, isTrue);
      expect(signer.capturedAuthUrlCallback, isNotNull);
      return authService;
    }

    test('launches the auth URL through the injected port', () async {
      final launchedUris = <Uri>[];
      final launched = Completer<void>();
      await connectBunker(
        launchAuthUrl: (uri) async {
          launchedUris.add(uri);
          launched.complete();
          return true;
        },
      );

      signer.capturedAuthUrlCallback!('https://bunker.example/authorize?x=1');
      await launched.future;

      expect(
        launchedUris,
        equals([Uri.parse('https://bunker.example/authorize?x=1')]),
      );
    });

    test('does not throw when the launcher reports failure', () async {
      final launcherCalled = Completer<void>();
      await connectBunker(
        launchAuthUrl: (uri) async {
          launcherCalled.complete();
          return false;
        },
      );

      signer.capturedAuthUrlCallback!('https://bunker.example/denied');
      await launcherCalled.future;
      // Flush the callback's remaining microtasks (the Log.error branch).
      await pumpEventQueue();
    });

    test('never records the approval URL in support logs', () async {
      const approvalUrl =
          'https://bunker.example/authorize/one-time-secret?code=private';
      final launcherCalled = Completer<void>();
      await connectBunker(
        launchAuthUrl: (uri) async {
          launcherCalled.complete();
          return false;
        },
      );

      signer.capturedAuthUrlCallback!(approvalUrl);
      await launcherCalled.future;
      await pumpEventQueue();

      final messages = LogCaptureService()
          .getRecentLogs()
          .map((entry) => entry.message)
          .toList();
      expect(messages, contains('Bunker requires authentication; opening URL'));
      expect(messages, contains('Could not launch bunker authentication URL'));
      expect(messages.join('\n'), isNot(contains(approvalUrl)));
      expect(messages.join('\n'), isNot(contains('one-time-secret')));
      expect(messages.join('\n'), isNot(contains('private')));
    });

    test('does not throw when no launcher is wired', () async {
      await connectBunker();

      signer.capturedAuthUrlCallback!('https://bunker.example/unwired');
      // Flush the callback's async body — must complete without a platform
      // channel throw (the pre-port code hit url_launcher here).
      await pumpEventQueue();
    });
  });
}
