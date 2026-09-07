import 'package:divine_device_attestation/divine_device_attestation_platform_interface.dart';

/// Mints account-scoped App Attest payloads on iOS.
class DivineDeviceAttestation {
  /// [keyScope] selects which cached App Attest key answers the challenge on
  /// iOS. Apple's guidance is against sharing one key among several users of a
  /// device, so callers pass the identity the attestation speaks for.
  Future<String?> getAttestationServiceSupport({
    required String challengeString,
    required String keyScope,
  }) => DivineDeviceAttestationPlatform.instance.getAttestationServiceSupport(
    challengeString: challengeString,
    keyScope: keyScope,
  );
}
