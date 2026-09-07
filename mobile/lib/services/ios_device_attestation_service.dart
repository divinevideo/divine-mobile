// ABOUTME: Mints the iOS App Attest payload that a published video event carries
// ABOUTME: Binds the media proof hash and the publishing pubkey into the challenge

import 'dart:async';

import 'package:divine_device_attestation/divine_device_attestation.dart';
import 'package:flutter/foundation.dart';
import 'package:unified_logger/unified_logger.dart';

/// Produces the iOS App Attest payload attached to a video event at publish
/// time.
///
/// Deliberately not part of proof generation. The account a clip goes out under
/// is not fixed until the event is signed — a clip can be recorded, sit in the
/// library, and be published from an account the user switched to afterwards —
/// so generation time can neither pick the right key nor bind the challenge to
/// the identity that ends up on the event.
class IosDeviceAttestationService {
  IosDeviceAttestationService({
    DivineDeviceAttestation? deviceAttestation,
    Duration attestationTimeout = _defaultAttestationTimeout,
  }) : _deviceAttestation = deviceAttestation ?? DivineDeviceAttestation(),
       _attestationTimeout = attestationTimeout;

  final DivineDeviceAttestation _deviceAttestation;
  final Duration _attestationTimeout;

  static const _defaultAttestationTimeout = Duration(seconds: 10);

  /// Whether this platform mints its device attestation at publish time.
  ///
  /// Android attests during proof generation with a throwaway hardware key, so
  /// its payload is already in the proof and publishing must leave it alone.
  static bool get handlesPublishTimeAttestation =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// The challenge App Attest signs for [proofHash] published by [pubkeyHex].
  ///
  /// Both halves carry weight: the proof hash ties the payload to this media,
  /// and the pubkey ties it to the account signing the event, so the payload
  /// cannot be lifted onto someone else's event carrying the same media. What
  /// Apple actually signs is `SHA-256` over the UTF-8 bytes of this string;
  /// the verifier contract is written up in
  /// `mobile/docs/NOSTR_VIDEO_EVENTS.md`.
  static String challengeFor({
    required String proofHash,
    required String pubkeyHex,
  }) => '$proofHash:$pubkeyHex';

  /// Returns the App Attest payload binding [proofHash] to [pubkeyHex], or
  /// `null` when the platform cannot produce one.
  ///
  /// App Attest needs Apple's attestation servers the first time an account
  /// uses it, so it fails on the Simulator, offline, and whenever Apple
  /// throttles the app. None of that invalidates the proof itself — the PGP
  /// signature and the C2PA manifest stand on their own — so a failure here
  /// only drops the `device_attestation` field.
  Future<String?> attestationFor({
    required String proofHash,
    required String pubkeyHex,
  }) async {
    if (!handlesPublishTimeAttestation) return null;

    if (pubkeyHex.isEmpty) {
      Log.warning(
        '🔐 No publishing pubkey to scope device attestation to',
        name: 'IosDeviceAttestation',
        category: LogCategory.system,
      );
      return null;
    }

    try {
      return await _deviceAttestation
          .getAttestationServiceSupport(
            challengeString: challengeFor(
              proofHash: proofHash,
              pubkeyHex: pubkeyHex,
            ),
            keyScope: pubkeyHex,
          )
          .timeout(
            _attestationTimeout,
            onTimeout: () {
              Log.warning(
                '🔐 Device attestation timed out, continuing without it',
                name: 'IosDeviceAttestation',
                category: LogCategory.system,
              );
              return null;
            },
          );
    } catch (e) {
      Log.warning(
        '🔐 Device attestation unavailable, continuing without it: $e',
        name: 'IosDeviceAttestation',
        category: LogCategory.system,
      );
      return null;
    }
  }
}
