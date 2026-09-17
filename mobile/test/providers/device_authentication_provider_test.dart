// ABOUTME: Tests fail-closed device authentication result mapping
// ABOUTME: Covers granted, denied, unsupported, and unconfigured devices

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/device_authentication_provider.dart';

class _MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  group(LocalDeviceAuthentication, () {
    late _MockLocalAuthentication localAuthentication;
    late LocalDeviceAuthentication authentication;

    setUp(() {
      localAuthentication = _MockLocalAuthentication();
      authentication = LocalDeviceAuthentication(
        localAuthentication: localAuthentication,
      );
    });

    void stubSupportedAuthentication(bool result) {
      when(
        () => localAuthentication.isDeviceSupported(),
      ).thenAnswer((_) async => true);
      when(
        () => localAuthentication.authenticate(
          localizedReason: any(named: 'localizedReason'),
          persistAcrossBackgrounding: true,
        ),
      ).thenAnswer((_) async => result);
    }

    test('returns authenticated after a successful device challenge', () async {
      stubSupportedAuthentication(true);

      final result = await authentication.authenticate(reason: 'Verify');

      expect(result, DeviceAuthenticationResult.authenticated);
    });

    test('returns denied after a rejected device challenge', () async {
      stubSupportedAuthentication(false);

      final result = await authentication.authenticate(reason: 'Verify');

      expect(result, DeviceAuthenticationResult.denied);
    });

    testWidgets(
      'retries once after authentication is canceled while backgrounded',
      (tester) async {
        final firstAttempt = Completer<bool>();
        final secondAttempt = Completer<bool>();
        when(
          () => localAuthentication.isDeviceSupported(),
        ).thenAnswer((_) async => true);
        when(
          () => localAuthentication.authenticate(
            localizedReason: any(named: 'localizedReason'),
            persistAcrossBackgrounding: true,
          ),
        ).thenAnswer((_) => firstAttempt.future);

        final resultFuture = authentication.authenticate(reason: 'Verify');
        await tester.pump();

        firstAttempt.completeError(
          const LocalAuthException(
            code: LocalAuthExceptionCode.systemCanceled,
          ),
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        when(
          () => localAuthentication.authenticate(
            localizedReason: any(named: 'localizedReason'),
            persistAcrossBackgrounding: true,
          ),
        ).thenAnswer((_) => secondAttempt.future);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        secondAttempt.complete(true);

        expect(
          await resultFuture,
          DeviceAuthenticationResult.authenticated,
        );
        verify(
          () => localAuthentication.authenticate(
            localizedReason: 'Verify',
            persistAcrossBackgrounding: true,
          ),
        ).called(2);
      },
    );

    testWidgets(
      'does not re-present the prompt when a cancellation arrives while the '
      'app is merely inactive',
      (tester) async {
        // iOS resigns active while the system authentication sheet is up.
        // That is not a background transition and must not be retried.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        when(
          () => localAuthentication.isDeviceSupported(),
        ).thenAnswer((_) async => true);

        var attempts = 0;
        when(
          () => localAuthentication.authenticate(
            localizedReason: any(named: 'localizedReason'),
            persistAcrossBackgrounding: any(
              named: 'persistAcrossBackgrounding',
            ),
          ),
        ).thenAnswer((_) async {
          attempts++;
          throw const LocalAuthException(
            code: LocalAuthExceptionCode.userCanceled,
          );
        });

        final resultFuture = authentication.authenticate(reason: 'Verify');
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(await resultFuture, DeviceAuthenticationResult.denied);
        expect(
          attempts,
          1,
          reason: 'a plain cancellation must not trigger a second prompt',
        );
      },
    );

    test(
      'does not ask local_auth to persist across backgrounding on macOS, '
      'where the native retry hook is not compiled',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        when(
          () => localAuthentication.isDeviceSupported(),
        ).thenAnswer((_) async => true);
        when(
          () => localAuthentication.authenticate(
            localizedReason: any(named: 'localizedReason'),
            persistAcrossBackgrounding: any(
              named: 'persistAcrossBackgrounding',
            ),
          ),
        ).thenAnswer((_) async => true);

        await authentication.authenticate(reason: 'Verify');

        final captured = verify(
          () => localAuthentication.authenticate(
            localizedReason: 'Verify',
            persistAcrossBackgrounding: captureAny(
              named: 'persistAcrossBackgrounding',
            ),
          ),
        ).captured;

        expect(captured.single, isFalse);
      },
    );

    test(
      'returns unavailable when device authentication is unsupported',
      () async {
        when(
          () => localAuthentication.isDeviceSupported(),
        ).thenAnswer((_) async => false);

        final result = await authentication.authenticate(reason: 'Verify');

        expect(result, DeviceAuthenticationResult.unavailable);
        verifyNever(
          () => localAuthentication.authenticate(
            localizedReason: any(named: 'localizedReason'),
            biometricOnly: any(named: 'biometricOnly'),
            persistAcrossBackgrounding: any(
              named: 'persistAcrossBackgrounding',
            ),
          ),
        );
      },
    );

    test(
      'returns unavailable when no device credential is configured',
      () async {
        when(
          () => localAuthentication.isDeviceSupported(),
        ).thenAnswer((_) async => true);
        when(
          () => localAuthentication.authenticate(
            localizedReason: any(named: 'localizedReason'),
            persistAcrossBackgrounding: true,
          ),
        ).thenThrow(
          const LocalAuthException(
            code: LocalAuthExceptionCode.noCredentialsSet,
          ),
        );

        final result = await authentication.authenticate(reason: 'Verify');

        expect(result, DeviceAuthenticationResult.unavailable);
      },
    );

    testWidgets(
      'returns denied when the platform reports an unmapped failure code',
      (tester) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        when(
          () => localAuthentication.isDeviceSupported(),
        ).thenAnswer((_) async => true);
        when(
          () => localAuthentication.authenticate(
            localizedReason: any(named: 'localizedReason'),
            persistAcrossBackgrounding: true,
          ),
        ).thenThrow(
          const LocalAuthException(code: LocalAuthExceptionCode.userCanceled),
        );

        final resultFuture = authentication.authenticate(reason: 'Verify');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 251));
        final result = await resultFuture;

        expect(result, DeviceAuthenticationResult.denied);
      },
    );

    test(
      'returns unavailable when the device reports an internal error',
      () async {
        when(
          () => localAuthentication.isDeviceSupported(),
        ).thenAnswer((_) async => true);
        when(
          () => localAuthentication.authenticate(
            localizedReason: any(named: 'localizedReason'),
            persistAcrossBackgrounding: true,
          ),
        ).thenThrow(
          const LocalAuthException(code: LocalAuthExceptionCode.deviceError),
        );

        final result = await authentication.authenticate(reason: 'Verify');

        expect(result, DeviceAuthenticationResult.unavailable);
      },
    );

    test(
      'returns unavailable when the platform channel throws unexpectedly',
      () async {
        when(
          () => localAuthentication.isDeviceSupported(),
        ).thenAnswer((_) async => true);
        when(
          () => localAuthentication.authenticate(
            localizedReason: any(named: 'localizedReason'),
            persistAcrossBackgrounding: true,
          ),
        ).thenThrow(MissingPluginException('no local_auth implementation'));

        final result = await authentication.authenticate(reason: 'Verify');

        expect(result, DeviceAuthenticationResult.unavailable);
      },
    );
  });
}
