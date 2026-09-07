import 'dart:async';

import 'package:divine_device_attestation/divine_device_attestation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/ios_device_attestation_service.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const attestationChannel = MethodChannel('app_attestation');
  const proofHash =
      'bfe97053586981c5d2373625c3ee921d8af88c79fca442e189a82230d99bdc78';
  const pubkeyHex =
      '3f8a1c5d2e4b6079a1c3e5d7b9f0246813579bdf02468ace13579bdf02468ace';

  late IosDeviceAttestationService service;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    service = IosDeviceAttestationService();
    await LogCaptureService().clearAllLogs();
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(attestationChannel, null);
    await LogCaptureService().clearAllLogs();
  });

  group(IosDeviceAttestationService, () {
    test('signs a challenge binding the proof hash to the publisher', () async {
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(attestationChannel, (call) async {
            received = call;
            return '{"keyID":"k1","attestationString":"a1"}';
          });

      final payload = await service.attestationFor(
        proofHash: proofHash,
        pubkeyHex: pubkeyHex,
      );

      expect(payload, '{"keyID":"k1","attestationString":"a1"}');
      final arguments = received!.arguments as Map<Object?, Object?>;
      expect(arguments['challengeString'], '$proofHash:$pubkeyHex');
      expect(
        arguments['keyScope'],
        pubkeyHex,
        reason: 'the key must be scoped to the account, not the install',
      );
    });

    test('degrades to no attestation when App Attest fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(attestationChannel, (call) async {
            throw PlatformException(code: '-5', message: 'Attestation failed');
          });

      final payload = await service.attestationFor(
        proofHash: proofHash,
        pubkeyHex: pubkeyHex,
      );

      expect(payload, isNull);
      expect(
        LogCaptureService().getRecentLogs().where(
          (log) => log.message.contains('Device attestation unavailable'),
        ),
        isNotEmpty,
      );
    });

    test('times out when App Attest never answers', () async {
      service = IosDeviceAttestationService(
        deviceAttestation: _NeverCompletingDeviceAttestation(),
        attestationTimeout: const Duration(milliseconds: 1),
      );

      final payload = await service.attestationFor(
        proofHash: proofHash,
        pubkeyHex: pubkeyHex,
      );

      expect(payload, isNull);
      expect(
        LogCaptureService().getRecentLogs().where(
          (log) => log.message.contains('Device attestation timed out'),
        ),
        isNotEmpty,
      );
    });

    test('does not attest without an account to scope the key to', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            attestationChannel,
            (call) async => fail('App Attest must not run unscoped'),
          );

      final payload = await service.attestationFor(
        proofHash: proofHash,
        pubkeyHex: '',
      );

      expect(payload, isNull);
    });

    test('leaves platforms that attest at generation time alone', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            attestationChannel,
            (call) async => fail('Android attests during proof generation'),
          );

      expect(
        IosDeviceAttestationService.handlesPublishTimeAttestation,
        isFalse,
      );
      expect(
        await service.attestationFor(
          proofHash: proofHash,
          pubkeyHex: pubkeyHex,
        ),
        isNull,
      );
    });
  });
}

class _NeverCompletingDeviceAttestation extends DivineDeviceAttestation {
  @override
  Future<String?> getAttestationServiceSupport({
    required String challengeString,
    required String keyScope,
  }) => Completer<String?>().future;
}
