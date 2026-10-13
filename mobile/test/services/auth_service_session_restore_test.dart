// ABOUTME: Tests that AuthService.initialize reports a signed-in session whose
// ABOUTME: stored key is gone, instead of signing the user out silently.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show generatePrivateKey;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_service_test_harness.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _RecordingCrashReporter implements CrashReporter {
  final reported = <({Object error, String? reason})>[];

  @override
  Future<void> setCustomKey(String key, Object value) async {}

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    reported.add((error: error, reason: reason));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService session restore', () {
    late _MockUserDataCleanupService mockCleanupService;
    late _RecordingCrashReporter crashReporter;

    setUp(() {
      mockCleanupService = _MockUserDataCleanupService();
      stubUserDataCleanupSuccess(mockCleanupService);
      AuthServiceChannelMocks.install();
      crashReporter = _RecordingCrashReporter();
    });

    tearDown(AuthServiceChannelMocks.remove);

    AuthService createAuthService() => buildTestAuthService(
      cleanupService: mockCleanupService,
      crashReporter: crashReporter,
    );

    group('initialize', () {
      test('reports a signed-in session whose stored key is gone', () async {
        final npub = SecureKeyContainer.fromPrivateKeyHex(
          generatePrivateKey(),
        ).npub;
        SharedPreferences.setMockInitialValues({
          kKnownAccountsKey: '[]',
          'authentication_source': 'imported_keys',
          'last_used_npub': npub,
        });
        final authService = createAuthService();
        addTearDown(authService.dispose);

        await authService.initialize();

        expect(authService.authState, equals(AuthState.unauthenticated));
        expect(
          crashReporter.reported.map((report) => report.reason),
          contains('_checkExistingAuth no stored key'),
        );
      });

      test('does not report a fresh install', () async {
        SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
        final authService = createAuthService();
        addTearDown(authService.dispose);

        await authService.initialize();

        expect(authService.authState, equals(AuthState.unauthenticated));
        expect(crashReporter.reported, isEmpty);
      });
    });
  });
}
