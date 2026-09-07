// ABOUTME: Signer-core collaborator: builds the atomic NostrIdentity and owns
// ABOUTME: the createAndSignEvent dispatch. Extracted from AuthService (#4741).

import 'package:flutter/foundation.dart' show compute;
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_client/nostr_client.dart' show Nip89ClientTag;
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/local_key_signer.dart';
import 'package:openvine/services/nip07_service.dart';
import 'package:openvine/services/nip07_signer_adapter.dart';
import 'package:unified_logger/unified_logger.dart';

/// Crash-reporting port for the signer core.
///
/// Mirrors AuthService's private reporting funnel so the extracted core does
/// not read the `CrashReportingService.instance` process global. Wired as a
/// tear-off of that funnel in the app layer, which keeps the Crashlytics
/// `auth_source` custom key reading live state. Implementations MUST NOT
/// throw.
typedef AuthCrashReporter =
    void Function(
      Object error,
      StackTrace stackTrace, {
      required String reason,
      required String logMessage,
    });

/// Isolate worker for [SignerFactory.createAndSignEvent]'s remote-signature
/// check.
///
/// Top-level so [compute] can pass it to a background isolate. A pure-Dart
/// Schnorr verification costs ~10ms of BigInt math, which drops frames when
/// it runs on the main isolate during the feed-scroll signing path.
bool _verifyEventSignature(Map<String, dynamic> eventJson) =>
    Event.fromJson(eventJson).isSigned;

/// Thrown when a signer returns an event whose author public key does not
/// match the active identity.
///
/// A signing-layer invariant violation: a signer must never produce an event
/// for a different account than the one that requested signing. Reported to
/// Crashlytics via [Reportable] (YES on the error-handling matrix), and the
/// caller fails the publish closed. Carries hex pubkeys only (no npub/nsec),
/// so it is safe for the [Reportable] sanitizer.
class EventSignerAccountMismatchException implements Exception {
  const EventSignerAccountMismatchException({
    required this.expectedPubkey,
    required this.actualPubkey,
  });

  /// The active identity's public key (hex) the event was created with.
  final String expectedPubkey;

  /// The public key (hex) the signer returned on the signed event.
  final String actualPubkey;

  @override
  String toString() =>
      'EventSignerAccountMismatchException: signer returned an event for '
      '$actualPubkey but the active identity is $expectedPubkey';
}

/// Builds the atomic signing identity and creates/signs Nostr events.
///
/// Extracted from `AuthService` (#4741) as a client-tier collaborator.
/// `AuthService` keeps ownership of all mutable session state (key container,
/// signer slots, auth source) and delegates here with per-call snapshots, so
/// this class never captures a stale signer reference (#3503 class of bug).
class SignerFactory {
  SignerFactory({
    AuthCrashReporter? crashReporter,
    Future<bool> Function(Map<String, dynamic> eventJson)? verifyOffMain,
  }) : _reportError = crashReporter,
       _verifyOffMain = verifyOffMain ?? _verifyEventSignatureOffMain;

  final AuthCrashReporter? _reportError;

  /// Runs the remote-signature check in a background isolate; injectable so
  /// tests can simulate isolate-spawn failure.
  final Future<bool> Function(Map<String, dynamic> eventJson) _verifyOffMain;

  static Future<bool> _verifyEventSignatureOffMain(
    Map<String, dynamic> eventJson,
  ) => compute(_verifyEventSignature, eventJson);

  /// Verifies [signedEvent]'s Schnorr signature off the main isolate,
  /// falling back to the inline check when the worker isolate cannot spawn
  /// (e.g. resource exhaustion) — a validly signed event must not be
  /// dropped because of a spawn failure (PR #5957 review).
  Future<bool> _verifyRemoteSignature(Event signedEvent) async {
    try {
      return await _verifyOffMain(signedEvent.toJson());
    } on Object {
      return signedEvent.isSigned;
    }
  }

  /// Builds a [NostrIdentity] from a per-call snapshot of the session's
  /// signer state.
  ///
  /// Must be called AFTER signer fields (keycast, bunker, amber) and the key
  /// container have been set for the session.
  ///
  /// [keycastSigner] is typed [KeycastRpc] (not the [NostrSigner] supertype)
  /// on purpose: `KeycastNostrIdentity.signCanonicalPayload` does a runtime
  /// `is KeycastRpc` check, so an adapter-wrapped signer would silently
  /// disable the sign_canonical RPC fallback.
  ///
  /// Throws [StateError] if no valid identity can be constructed — this
  /// indicates a programming error in the auth flow, not a user-facing
  /// condition. Set [allowPubkeyOnlyIdentity] only for the deliberate degraded
  /// Divine OAuth restore path, where the account pubkey is known but signing
  /// RPC is temporarily unavailable.
  NostrIdentity buildIdentity({
    required SecureKeyContainer? keyContainer,
    required AuthenticationSource authSource,
    AndroidNostrSigner? amberSigner,
    Nip07Service? nip07Service,
    NostrRemoteSigner? bunkerSigner,
    KeycastRpc? keycastSigner,
    bool allowPubkeyOnlyIdentity = false,
  }) {
    if (keyContainer == null) {
      throw StateError(
        '_buildIdentity called with no key container. '
        'Auth flow must set _currentKeyContainer before building identity.',
      );
    }

    final pubkey = keyContainer.publicKeyHex;

    // Priority: Amber > NIP-07 > Bunker > Keycast > Local
    if (amberSigner case final signer?) {
      return AmberNostrIdentity(pubkey: pubkey, amberSigner: signer);
    }
    if (nip07Service case final service?) {
      return Nip07NostrIdentity(
        pubkey: pubkey,
        nip07Signer: Nip07SignerAdapter(service),
      );
    }
    if (bunkerSigner case final signer?) {
      return BunkerNostrIdentity(pubkey: pubkey, remoteSigner: signer);
    }
    if (keycastSigner case final rpc?) {
      // When a matching local nsec exists, sign locally for speed.
      LocalKeySigner? localSigner;
      if (keyContainer.hasPrivateKey) {
        localSigner = LocalKeySigner(keyContainer);
      }
      return KeycastNostrIdentity(
        pubkey: pubkey,
        rpcSigner: rpc,
        localSigner: localSigner,
      );
    }
    // Local keys only — private key required.
    if (keyContainer.hasPrivateKey) {
      if (authSource == AuthenticationSource.divineOAuth) {
        Log.warning(
          '_buildIdentity: falling back to LocalNostrIdentity for '
          'divineOAuth source — OAuth session likely expired',
          name: 'SignerFactory',
          category: LogCategory.auth,
        );
      }
      return LocalNostrIdentity(keyContainer: keyContainer);
    }
    if (allowPubkeyOnlyIdentity &&
        authSource == AuthenticationSource.divineOAuth) {
      Log.warning(
        '_buildIdentity: using pubkey-only Divine OAuth identity with no '
        'signing capability. pubkey=${pubkeyForLogs(pubkey)}',
        name: 'SignerFactory',
        category: LogCategory.auth,
      );
      return PubkeyOnlyNostrIdentity(pubkey: pubkey);
    }
    throw StateError(
      '_buildIdentity: pub-key-only container with no remote signer. '
      'source=${authSource.name}, pubkey=$pubkey',
    );
  }

  /// Creates and signs a Nostr event via [identity].
  ///
  /// [authSource] is used for log/diagnostic strings only. The caller owns
  /// the authenticated/identity-present guard.
  Future<Event?> createAndSignEvent({
    required NostrIdentity identity,
    required AuthenticationSource authSource,
    required int kind,
    required String content,
    List<List<String>>? tags,
    int? createdAt,
  }) async {
    try {
      // 1. Prepare event metadata and tags
      // CRITICAL: Divine relays require specific tags for storage
      final eventTags = List<List<String>>.from(tags ?? []);

      // CRITICAL: Kind 0 events require an expiration tag appended before
      // signing (matching the pre-extraction tag construction order).
      if (kind == 0) {
        final expirationTimestamp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
            (72 * 60 * 60); // 72 hours
        eventTags.add(['expiration', expirationTimestamp.toString()]);
      }

      if (!Nip89ClientTag.shouldSkipKind(kind) &&
          !Nip89ClientTag.hasClientTag(eventTags) &&
          await Nip89ClientTag.isEnabled()) {
        eventTags.add(Nip89ClientTag.tag);
      }

      // Create the unsigned event with the identity's pubkey — both the
      // pubkey and the signing key come from the same identity instance,
      // structurally preventing the PRIMARY-slot desync bug (#2233).
      final driftTolerance = NostrTimestamp.getDriftToleranceForKind(kind);
      final event = Event(
        identity.pubkey,
        kind,
        eventTags,
        content,
        createdAt:
            createdAt ?? NostrTimestamp.now(driftTolerance: driftTolerance),
      );

      // 2. Sign via the identity — delegates to the correct signer
      Log.info(
        'Signing kind $kind via ${identity.runtimeType} '
        '(authSource=${authSource.name}, '
        'eventPubkey=${pubkeyForLogs(event.pubkey)})',
        name: 'SignerFactory',
        category: LogCategory.auth,
      );
      final signedEvent = await identity.signEvent(event);

      // 3. Post-Signing Validation
      if (signedEvent == null) {
        Log.error(
          'Signing failed: Signer returned null',
          name: 'SignerFactory',
        );
        return null;
      }

      // Guard against a signer returning an event bound to a different
      // account than the active identity (e.g. a remote signer whose
      // backend swapped the authorized key). isSigned/isValid only prove
      // the signature and id are self-consistent for the event's own
      // pubkey — not that it is the account we intended to sign as. Cheap
      // string compare; runs for every signer, local or remote. Throwing
      // (rather than returning null) keeps this off the frozen sentinel
      // ceiling and surfaces the invariant violation via Reportable in the
      // catch below. #5450.
      if (signedEvent.pubkey != identity.pubkey) {
        throw EventSignerAccountMismatchException(
          expectedPubkey: identity.pubkey,
          actualPubkey: signedEvent.pubkey,
        );
      }

      // Re-verifying a signature we just produced with our own in-process
      // key only exercises the crypto library and costs a full schnorr
      // verification per event (hot on the feed-scroll signing path). Skip
      // it for local signers; remote/external signers cross a trust
      // boundary, so their returned signature is still verified — in a
      // background isolate, because the pure-Dart verify blocked the main
      // isolate for ~10ms per signed event (on-device profiling). The cheap
      // structural check (isValid: id == hash) below always runs.
      if (!identity.signsWithLocalKey &&
          !await _verifyRemoteSignature(signedEvent)) {
        Log.error(
          'Event signature validation FAILED! '
          'kind=$kind, eventPubkey=${pubkeyForLogs(signedEvent.pubkey)}, '
          'authSource=${authSource.name}, '
          'identityPubkey=${pubkeyForLogs(identity.pubkey)}',
          name: 'SignerFactory',
          category: LogCategory.auth,
        );
        return null;
      }

      if (!signedEvent.isValid) {
        Log.error(
          'Event structure validation FAILED! '
          'Event ID does not match computed hash',
          name: 'SignerFactory',
          category: LogCategory.auth,
        );
        return null;
      }

      Log.info(
        'Event signed and validated: ${signedEvent.id}',
        name: 'SignerFactory',
        category: LogCategory.auth,
      );

      return signedEvent;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to create or sign event',
        name: 'SignerFactory',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
      );
      // An event signed for a different account is an invariant violation
      // (YES on the Reportable matrix), not an expected domain/network
      // failure — surface it to Crashlytics. Other errors keep the existing
      // log-only behavior to avoid flooding the dashboard.
      if (e is EventSignerAccountMismatchException || e is Error) {
        final isAccountMismatch = e is EventSignerAccountMismatchException;
        _reportError?.call(
          Reportable(e, context: 'createAndSignEvent'),
          stackTrace,
          reason: isAccountMismatch
              ? 'Signer returned an event for a different account'
              : 'Unexpected signer invariant failure',
          logMessage: isAccountMismatch
              ? 'Signer account mismatch during createAndSignEvent'
              : 'Unexpected signer invariant failure during createAndSignEvent',
        );
      }
      return null;
    }
  }
}
