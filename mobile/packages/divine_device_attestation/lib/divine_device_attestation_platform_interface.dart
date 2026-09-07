import 'package:divine_device_attestation/divine_device_attestation_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Platform interface for Divine's iOS App Attest integration.
abstract class DivineDeviceAttestationPlatform extends PlatformInterface {
  DivineDeviceAttestationPlatform() : super(token: _token);

  static final Object _token = Object();

  static DivineDeviceAttestationPlatform _instance =
      MethodChannelDivineDeviceAttestation();

  /// The default instance, backed by the package's method channel.
  static DivineDeviceAttestationPlatform get instance => _instance;

  /// Platform-specific implementations may replace this during registration.
  static set instance(DivineDeviceAttestationPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// [keyScope] selects which cached App Attest key answers the challenge on
  /// iOS. Apple's guidance is against sharing one key among several users of a
  /// device, so callers pass the identity the attestation speaks for.
  Future<String?> getAttestationServiceSupport({
    required String challengeString,
    required String keyScope,
  }) {
    throw UnimplementedError(
      'getAttestationServiceSupport() has not been implemented.',
    );
  }
}
