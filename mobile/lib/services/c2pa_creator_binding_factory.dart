// ABOUTME: Builds the signed creator binding that ties a C2PA manifest to the
// ABOUTME: Nostr account signed in when a recording, edit or post is signed.

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Creates the creator-binding assertion for a file about to be signed.
///
/// The binding is how a clip's history names the people who recorded and
/// edited it: every signing step embeds the current account's binding in its
/// own manifest, and `ClipProvenanceVerifier` credits each account whose
/// binding verifies (#9893).
class C2paCreatorBindingFactory {
  /// Creates a factory that reads the signed-in account at call time.
  ///
  /// [bindingService] and [nip05] are read per call, so an account switch
  /// between two recordings binds each to the right account.
  C2paCreatorBindingFactory({
    required NostrCreatorBindingService Function() bindingService,
    required String? Function() nip05,
    Future<String> Function(String filePath)? sha256OfFile,
    Duration timeout = defaultTimeout,
  }) : _bindingService = bindingService,
       _nip05 = nip05,
       _sha256OfFile = sha256OfFile ?? _sha256,
       _timeout = timeout;

  /// How long a remote signer may take before the file is signed without a
  /// binding. Recording and editing must not wait on an unreachable signer.
  static const defaultTimeout = Duration(seconds: 15);

  /// The C2PA assertions the binding vouches for, besides the file hash.
  static const referencedAssertions = <String>[
    'c2pa.actions.v2',
    'cawg.training-mining',
  ];

  final NostrCreatorBindingService Function() _bindingService;
  final String? Function() _nip05;
  final Future<String> Function(String filePath) _sha256OfFile;
  final Duration _timeout;

  /// Returns the binding for [filePath], or null when there is none to give.
  ///
  /// Null covers a signed-out session, an identity that cannot sign a
  /// canonical payload (NIP-46 and NIP-55 signers), a signer that does not
  /// answer within the timeout, and any failure while hashing or signing.
  /// The file is then signed without a binding rather than not at all.
  Future<NostrCreatorBindingAssertion?> create(String filePath) async {
    try {
      final hash = await _sha256OfFile(filePath);
      return await _bindingService()
          .createAssertion(
            claims: CreatorBindingClaims(nip05: _nip05()),
            hardBinding: CreatorBindingHardBinding(alg: 'sha256', value: hash),
            referencedAssertions: referencedAssertions,
          )
          .timeout(_timeout);
    } on Object catch (error) {
      Log.warning(
        'Signing without a creator binding: $error',
        name: 'C2paCreatorBindingFactory',
        category: LogCategory.video,
      );
      return null;
    }
  }

  static Future<String> _sha256(String filePath) async {
    final digest = await File(filePath)
        .openRead()
        .transform(crypto.sha256)
        .first;
    return digest.toString();
  }
}
