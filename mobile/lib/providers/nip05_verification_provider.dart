// ABOUTME: Riverpod providers for NIP-05 verification with reactive state management
// ABOUTME: Watches user profiles and returns verification status for badge display

import 'dart:async';

import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

/// Re-exported so UI can render a verification badge without reaching
/// into the service layer for the status type alone.
export 'package:openvine/services/nip05_verification_service.dart'
    show Nip05VerificationStatus;

part 'nip05_verification_provider.g.dart';

/// Provider for the NIP-05 verification service singleton
@Riverpod(keepAlive: true)
Nip05VerificationService nip05VerificationService(Ref ref) {
  final db = ref.watch(databaseProvider);
  final service = Nip05VerificationService(db.nip05VerificationsDao);

  // Clean up expired entries on startup
  Future.microtask(service.deleteExpired);

  ref.onDispose(service.dispose);

  return service;
}

/// Provider that returns the NIP-05 verification status for a pubkey.
///
/// This provider:
/// 1. Watches the user profile to get the NIP-05 claim
/// 2. Returns the verification status reactively
/// 3. Triggers verification if needed
///
/// Usage in widgets:
/// ```dart
/// final statusAsync = ref.watch(nip05VerificationProvider(pubkey));
/// final isVerified = switch (statusAsync) {
///   AsyncData(:final value) => value == Nip05VerificationStatus.verified,
///   _ => false,
/// };
/// ```
@riverpod
Future<Nip05VerificationStatus> nip05Verification(
  Ref ref,
  String pubkey,
) async {
  final verificationService = ref.watch(nip05VerificationServiceProvider);
  final profileAsync = ref.watch(userProfileReactiveProvider(pubkey));

  // Extract NIP-05 from profile using pattern matching
  final nip05 = switch (profileAsync) {
    AsyncData(:final value) when value != null => value.nip05,
    _ => null,
  };

  // No NIP-05 claim
  if (nip05 == null || nip05.isEmpty) {
    return Nip05VerificationStatus.none;
  }

  // Check memory cache first for instant response
  final cachedStatus = verificationService.getCachedStatus(pubkey);
  if (cachedStatus != null && cachedStatus != Nip05VerificationStatus.pending) {
    return cachedStatus;
  }

  // Get verification status (may trigger network request)
  final status = await verificationService.getVerificationStatus(pubkey, nip05);

  // If pending, listen for updates
  if (status == Nip05VerificationStatus.pending) {
    final completer = Completer<Nip05VerificationStatus>();

    void listener() {
      final updated = verificationService.getCachedStatus(pubkey);
      if (updated != null && updated != Nip05VerificationStatus.pending) {
        verificationService.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(updated);
        }
      }
    }

    ref.onDispose(() {
      verificationService.removeListener(listener);
      if (!completer.isCompleted) {
        completer.complete(Nip05VerificationStatus.none);
      }
    });

    verificationService.addListener(listener);

    // Wait for verification to complete with timeout
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        Log.warning(
          'NIP-05 verification timeout for ${pubkeyForLogs(pubkey)}',
          name: 'Nip05VerificationProvider',
          category: LogCategory.system,
        );
        verificationService.removeListener(listener);
        return Nip05VerificationStatus.error;
      },
    );
  }

  return status;
}

/// Stream provider for reactive NIP-05 verification updates.
///
/// Use this when you need to reactively update UI when verification
/// status changes (e.g., after a fresh verification completes).
@riverpod
Stream<Nip05VerificationStatus> nip05VerificationStream(
  Ref ref,
  String pubkey,
) async* {
  final verificationService = ref.watch(nip05VerificationServiceProvider);
  final profileAsync = ref.watch(userProfileReactiveProvider(pubkey));

  // Extract NIP-05 from profile using pattern matching
  final nip05 = switch (profileAsync) {
    AsyncData(:final value) when value != null => value.nip05,
    _ => null,
  };

  // No NIP-05 claim
  if (nip05 == null || nip05.isEmpty) {
    yield Nip05VerificationStatus.none;
    return;
  }

  // Emit current status immediately
  final currentStatus = await verificationService.getVerificationStatus(
    pubkey,
    nip05,
  );
  yield currentStatus;

  // If pending, wait for completion and emit final status
  if (currentStatus == Nip05VerificationStatus.pending) {
    final controller = StreamController<Nip05VerificationStatus>();

    void listener() {
      final updated = verificationService.getCachedStatus(pubkey);
      if (updated != null && updated != Nip05VerificationStatus.pending) {
        if (!controller.isClosed) {
          controller.add(updated);
        }
      }
    }

    verificationService.addListener(listener);

    ref.onDispose(() {
      verificationService.removeListener(listener);
      controller.close();
    });

    yield* controller.stream;
  }
}
