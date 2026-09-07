import 'package:divine_device_attestation/divine_device_attestation.dart';
import 'package:divine_device_attestation/divine_device_attestation_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app_attestation');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('sends the challenge and account scope to App Attest', () async {
    MethodCall? receivedCall;
    messenger.setMockMethodCallHandler(channel, (call) async {
      receivedCall = call;
      return 'attestation-payload';
    });

    final result = await DivineDeviceAttestation().getAttestationServiceSupport(
      challengeString: 'proof-hash:publishing-pubkey',
      keyScope: 'publishing-pubkey',
    );

    expect(result, 'attestation-payload');
    expect(receivedCall?.method, 'getAttestationServiceSupport');
    expect(receivedCall?.arguments, <String, dynamic>{
      'challengeString': 'proof-hash:publishing-pubkey',
      'keyScope': 'publishing-pubkey',
    });
  });

  test('accepts verified platform implementations', () async {
    final original = DivineDeviceAttestationPlatform.instance;
    addTearDown(() => DivineDeviceAttestationPlatform.instance = original);
    final platform = _MockPlatform();

    DivineDeviceAttestationPlatform.instance = platform;

    expect(DivineDeviceAttestationPlatform.instance, same(platform));
  });

  test('rejects unverified platform implementations', () {
    expect(
      () => DivineDeviceAttestationPlatform.instance = _InvalidPlatform(),
      throwsA(isA<AssertionError>()),
    );
  });
}

class _MockPlatform extends DivineDeviceAttestationPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getAttestationServiceSupport({
    required String challengeString,
    required String keyScope,
  }) async => null;
}

class _InvalidPlatform implements DivineDeviceAttestationPlatform {
  @override
  Future<String?> getAttestationServiceSupport({
    required String challengeString,
    required String keyScope,
  }) async => null;
}
