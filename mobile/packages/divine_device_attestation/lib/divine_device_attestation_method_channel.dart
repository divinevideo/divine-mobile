import 'package:divine_device_attestation/divine_device_attestation_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Method-channel implementation of [DivineDeviceAttestationPlatform].
class MethodChannelDivineDeviceAttestation
    extends DivineDeviceAttestationPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('app_attestation');

  @override
  Future<String?> getAttestationServiceSupport({
    required String challengeString,
    required String keyScope,
  }) async {
    final token = await methodChannel.invokeMethod<String>(
      'getAttestationServiceSupport',
      <String, dynamic>{
        'challengeString': challengeString,
        'keyScope': keyScope,
      },
    );
    return token;
  }
}
