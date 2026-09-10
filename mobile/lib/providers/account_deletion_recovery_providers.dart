// ABOUTME: Riverpod wiring for resumable server-side account deletion.
// ABOUTME: Fetches current attempt after authentication for launch routing.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/blocs/account_deletion_recovery/account_deletion_recovery_cubit.dart';
import 'package:openvine/blocs/account_deletion_recovery/account_deletion_recovery_poll_budget.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Durable store for the recovery polling budget.
///
/// Wired here rather than defaulted inside the cubit so the budget is measured
/// against wall-clock time that survives a relaunch; the cubit's in-memory
/// fallback would restart it on every launch.
final accountDeletionRecoveryPollBudgetProvider =
    Provider<AccountDeletionRecoveryPollBudgetStore>(
      (ref) => ReceiptAnchoredPollBudgetStore(
        readReceiptAnchor: () {
          final receipt = ref.read(submittedAccountDeletionAttemptProvider);
          return receipt == null
              ? null
              : (
                  attemptId: receipt.attempt.id,
                  startedAt: receipt.recoveryWatchStartedAt,
                );
        },
        fallback: SharedPreferencesAccountDeletionRecoveryPollBudgetStore(
          ref.watch(sharedPreferencesProvider),
        ),
      ),
    );

final accountDeletionRecoveryRepositoryProvider =
    Provider<AccountDeletionRecoveryRepository>((ref) {
      final client = ref.watch(instrumentedHttpClientFactoryProvider)();
      ref.onDispose(client.close);
      return AccountDeletionRecoveryRepository(
        baseUrl: ref.watch(currentEnvironmentProvider).apiBaseUrl,
        nameServerBaseUrl: ref
            .watch(currentEnvironmentProvider)
            .nameServerBaseUrl,
        httpClient: client,
        nip98AuthService: ref.watch(nip98AuthServiceProvider),
        currentPubkey: () => ref.read(authServiceProvider).currentPublicKeyHex,
      );
    });

/// Wall clock for deletion-recovery timing, injectable for tests.
final accountDeletionRecoveryClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

/// Durable receipt for a deletion this installation submitted.
final class SubmittedAccountDeletionAttempt {
  const SubmittedAccountDeletionAttempt({
    required this.pubkeyHex,
    required this.attempt,
    required this.vanishEventId,
    required this.recoveryWatchStartedAt,
    this.submissionOwnedLocally = false,
  });

  factory SubmittedAccountDeletionAttempt.fromJson(
    Map<String, dynamic> json, {
    DateTime Function() now = DateTime.now,
  }) {
    final startedAtMs = (json['recovery_watch_started_at_ms'] as num?)?.toInt();
    return SubmittedAccountDeletionAttempt(
      pubkeyHex: json['pubkey_hex'] as String,
      vanishEventId: json['vanish_event_id'] as String,
      attempt: AccountDeletionAttempt.fromJson(
        json['attempt'] as Map<String, dynamic>,
      ),
      // A receipt written before this field existed anchors from the first
      // read that adopts it, and the notifier persists that stamp so the
      // anchor stops moving.
      recoveryWatchStartedAt: startedAtMs == null
          ? now().toUtc()
          : DateTime.fromMillisecondsSinceEpoch(startedAtMs, isUtc: true),
    );
  }

  final String pubkeyHex;
  final AccountDeletionAttempt attempt;
  final String vanishEventId;

  /// When this install started watching the deletion, used as the durable
  /// anchor for the support-escape budget. Carried on the receipt so the
  /// common path needs no preference key of its own.
  final DateTime recoveryWatchStartedAt;

  /// True only while this process's deletion dialog owns submission and cleanup.
  /// It is deliberately not persisted, so an app restart adopts the receipt.
  /// Do not invalidate this notifier while that in-process owner is running.
  final bool submissionOwnedLocally;

  Map<String, dynamic> toJson() => {
    'pubkey_hex': pubkeyHex,
    'vanish_event_id': vanishEventId,
    'attempt': attempt.toJson(),
    'recovery_watch_started_at_ms': recoveryWatchStartedAt
        .toUtc()
        .millisecondsSinceEpoch,
  };

  SubmittedAccountDeletionAttempt copyWith({
    AccountDeletionAttempt? attempt,
    DateTime? recoveryWatchStartedAt,
    bool? submissionOwnedLocally,
  }) => SubmittedAccountDeletionAttempt(
    pubkeyHex: pubkeyHex,
    attempt: attempt ?? this.attempt,
    vanishEventId: vanishEventId,
    recoveryWatchStartedAt:
        recoveryWatchStartedAt ?? this.recoveryWatchStartedAt,
    submissionOwnedLocally:
        submissionOwnedLocally ?? this.submissionOwnedLocally,
  );
}

/// The attempt this installation submitted for irreversible processing.
///
/// Persisted before `submit`, because a lost response is ambiguous and the
/// coordinator may already have deleted the Keycast signer. It deliberately
/// survives sign-out and app restart so ordinary login cannot race a pending
/// deletion (#8583).
final submittedAccountDeletionAttemptProvider =
    NotifierProvider<
      SubmittedAccountDeletionAttemptNotifier,
      SubmittedAccountDeletionAttempt?
    >(SubmittedAccountDeletionAttemptNotifier.new);

class SubmittedAccountDeletionAttemptNotifier
    extends Notifier<SubmittedAccountDeletionAttempt?> {
  static const _storageKey = 'account_deletion_receipt_v1';

  @override
  SubmittedAccountDeletionAttempt? build() {
    final encoded = ref.watch(sharedPreferencesProvider).getString(_storageKey);
    if (encoded == null) return null;
    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final needsBackfill = decoded['recovery_watch_started_at_ms'] == null;
      final receipt = SubmittedAccountDeletionAttempt.fromJson(
        decoded,
        now: ref.read(accountDeletionRecoveryClockProvider),
      );
      // Persist the stamp a legacy receipt was just given, or every read would
      // re-anchor it to now and the budget would never advance.
      if (needsBackfill) unawaited(_persistLegacyWatchStart(receipt));
      return receipt;
    } on Object catch (error) {
      final encodedPubkey = decoded?['pubkey_hex'];
      Log.error(
        'Discarding corrupt account deletion receipt for '
        '${pubkeyForLogs(encodedPubkey is String ? encodedPubkey : null, whenNull: "unknown account")}: '
        '$error',
        name: 'AccountDeletionRecovery',
        category: LogCategory.auth,
      );
      unawaited(_removeCorruptReceipt());
      return null;
    }
  }

  Future<void> _persistLegacyWatchStart(
    SubmittedAccountDeletionAttempt receipt,
  ) async {
    try {
      final saved = await ref
          .read(sharedPreferencesProvider)
          .setString(_storageKey, jsonEncode(receipt.toJson()));
      if (!saved) throw StateError('Could not backfill recovery watch start');
    } on Object catch (error) {
      Log.error(
        'Failed to backfill account deletion recovery watch start for '
        '${pubkeyForLogs(receipt.pubkeyHex)}: $error',
        name: 'AccountDeletionRecovery',
        category: LogCategory.auth,
      );
    }
  }

  Future<void> _removeCorruptReceipt() async {
    try {
      if (!await ref.read(sharedPreferencesProvider).remove(_storageKey)) {
        throw StateError('Could not clear corrupt account deletion receipt');
      }
    } on Object catch (error) {
      Log.error(
        'Failed to clear corrupt account deletion receipt: $error',
        name: 'AccountDeletionRecovery',
        category: LogCategory.auth,
      );
    }
  }

  Future<void> record({
    required String pubkeyHex,
    required AccountDeletionAttempt attempt,
    required String vanishEventId,
    bool submissionOwnedLocally = false,
  }) async {
    final existing = state;
    if (existing != null && existing.pubkeyHex != pubkeyHex) {
      throw StateError(
        'Another account deletion receipt is already pending',
      );
    }
    // Re-recording the SAME attempt keeps its original anchor; a different
    // attempt is a new wait and starts its own.
    final recoveryWatchStartedAt =
        existing != null && existing.attempt.id == attempt.id
        ? existing.recoveryWatchStartedAt
        : ref.read(accountDeletionRecoveryClockProvider)().toUtc();
    await _persist(
      SubmittedAccountDeletionAttempt(
        pubkeyHex: pubkeyHex,
        attempt: attempt,
        vanishEventId: vanishEventId,
        recoveryWatchStartedAt: recoveryWatchStartedAt,
        submissionOwnedLocally: submissionOwnedLocally,
      ),
    );
  }

  Future<void> updateAttempt(AccountDeletionAttempt attempt) async {
    final receipt = state;
    if (receipt == null || receipt.attempt.id != attempt.id) return;
    // copyWith, not record: a status update must not restamp the anchor.
    await _persist(receipt.copyWith(attempt: attempt));
  }

  Future<void> _persist(SubmittedAccountDeletionAttempt receipt) async {
    final saved = await ref
        .read(sharedPreferencesProvider)
        .setString(_storageKey, jsonEncode(receipt.toJson()));
    if (!saved) throw StateError('Could not persist account deletion receipt');
    state = receipt;
  }

  void releaseSubmissionOwnership() {
    final receipt = state;
    if (receipt == null || !receipt.submissionOwnedLocally) return;
    state = receipt.copyWith(submissionOwnedLocally: false);
  }

  Future<void> clear({required String? expectedPubkeyHex}) async {
    final receipt = state;
    if (receipt == null || receipt.pubkeyHex != expectedPubkeyHex) return;
    final removed = await ref
        .read(sharedPreferencesProvider)
        .remove(_storageKey);
    if (!removed) throw StateError('Could not clear account deletion receipt');
    state = null;
  }
}

final currentSubmittedAccountDeletionAttemptProvider =
    Provider<SubmittedAccountDeletionAttempt?>((ref) {
      final submitted = ref.watch(submittedAccountDeletionAttemptProvider);
      if (submitted == null) return null;
      final authState = ref.watch(currentAuthStateProvider);
      if (authState != AuthState.authenticated) return submitted;
      final authService = ref.watch(authServiceProvider);
      return authService.currentPublicKeyHex == submitted.pubkeyHex
          ? submitted
          : null;
    });

/// Keeps a submitted deletion alive independently of the recovery screen.
///
/// The selected identity is stable while polling updates the receipt, so the
/// Cubit is replaced only when the receipt itself changes or is resolved.
final Provider<AccountDeletionRecoveryCubit?>
submittedAccountDeletionMonitorProvider =
    Provider.autoDispose<AccountDeletionRecoveryCubit?>((ref) {
      final receiptIdentity = ref.watch(
        submittedAccountDeletionAttemptProvider.select(
          (receipt) => receipt == null
              ? null
              : (
                  pubkeyHex: receipt.pubkeyHex,
                  attemptId: receipt.attempt.id,
                  vanishEventId: receipt.vanishEventId,
                  submissionOwnedLocally: receipt.submissionOwnedLocally,
                ),
        ),
      );
      if (receiptIdentity == null || receiptIdentity.submissionOwnedLocally) {
        return null;
      }

      final receipt = ref.read(submittedAccountDeletionAttemptProvider)!;
      final receiptNotifier = ref.read(
        submittedAccountDeletionAttemptProvider.notifier,
      );
      var disposed = false;
      final cubit = AccountDeletionRecoveryCubit(
        pollBudgetStore: ref.watch(accountDeletionRecoveryPollBudgetProvider),
        repository: ref.watch(accountDeletionRecoveryRepositoryProvider),
        authService: ref.watch(authServiceProvider),
        onAttemptResolved: () async {
          await receiptNotifier.clear(expectedPubkeyHex: receipt.pubkeyHex);
          if (disposed) return;
          ref.invalidate(currentAccountDeletionAttemptProvider);
        },
        onAttemptUpdated: receiptNotifier.updateAttempt,
        receiptPubkeyHex: receipt.pubkeyHex,
        receiptVanishEventId: receipt.vanishEventId,
      );
      ref.listen(currentAuthStateProvider, (_, next) {
        if (next != AuthState.authenticated) return;
        switch (cubit.state.status) {
          case AccountDeletionRecoveryStatus.completed:
            unawaited(cubit.acknowledgeCompletion());
          case AccountDeletionRecoveryStatus.cleanupFailed:
            unawaited(cubit.completeLocalCleanup());
          default:
            if (cubit.state.pollingPaused) {
              final attempt = cubit.state.attempt;
              if (attempt != null) unawaited(cubit.resume(attempt));
            }
        }
      });
      ref.onDispose(() {
        disposed = true;
        unawaited(cubit.close());
      });
      unawaited(cubit.resume(receipt.attempt));
      return cubit;
    });

final currentAccountDeletionAttemptProvider =
    FutureProvider<AccountDeletionAttempt?>(
      (ref) async {
        final submitted = ref.watch(
          currentSubmittedAccountDeletionAttemptProvider,
        );
        final authState = ref.watch(currentAuthStateProvider);
        final authService = ref.watch(authServiceProvider);
        if (submitted != null) {
          return submitted.attempt;
        }
        if (authState != AuthState.authenticated) {
          return null;
        }
        ref.watch(currentAuthRpcCapabilityProvider);
        switch (authService.signerReadiness) {
          case SignerReadiness.pending:
            // A remote lookup without a durable local receipt is advisory.
            // Let startup continue while the capability provider causes this
            // provider to rerun when signer readiness changes.
            return null;
          case SignerReadiness.unavailable:
            throw const AccountDeletionStatusUnavailable();
          case SignerReadiness.ready:
            return ref
                .watch(accountDeletionRecoveryRepositoryProvider)
                .fetchCurrent();
        }
      },
      retry: (retryCount, error) => error is AccountDeletionStatusUnavailable
          ? null
          : ProviderContainer.defaultRetry(retryCount, error),
    );

class AccountDeletionStatusUnavailable implements Exception {
  const AccountDeletionStatusUnavailable();

  @override
  String toString() => 'AccountDeletionStatusUnavailable';
}
