// ABOUTME: Tests fail-closed device authentication result mapping
// ABOUTME: Covers granted, denied, unsupported, and unconfigured devices

import 'package:flutter/services.dart';
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

    test(
      'returns denied when the platform reports an unmapped failure code',
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
          const LocalAuthException(code: LocalAuthExceptionCode.userCanceled),
        );

        final result = await authentication.authenticate(reason: 'Verify');

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
