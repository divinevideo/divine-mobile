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

final accountDeletionRecoveryPollBudgetProvider =
    Provider<AccountDeletionRecoveryPollBudgetStore>(
      (ref) => SharedPreferencesAccountDeletionRecoveryPollBudgetStore(
        ref.watch(sharedPreferencesProvider),
      ),
    );

/// Durable receipt for a deletion this installation submitted.
final class SubmittedAccountDeletionAttempt {
  const SubmittedAccountDeletionAttempt({
    required this.pubkeyHex,
    required this.attempt,
    required this.vanishEventId,
  });

  factory SubmittedAccountDeletionAttempt.fromJson(Map<String, dynamic> json) =>
      SubmittedAccountDeletionAttempt(
        pubkeyHex: json['pubkey_hex'] as String,
        vanishEventId: json['vanish_event_id'] as String,
        attempt: AccountDeletionAttempt.fromJson(
          json['attempt'] as Map<String, dynamic>,
        ),
      );

  final String pubkeyHex;
  final AccountDeletionAttempt attempt;
  final String vanishEventId;

  Map<String, dynamic> toJson() => {
    'pubkey_hex': pubkeyHex,
    'vanish_event_id': vanishEventId,
    'attempt': attempt.toJson(),
  };

  SubmittedAccountDeletionAttempt copyWith({
    AccountDeletionAttempt? attempt,
  }) => SubmittedAccountDeletionAttempt(
    pubkeyHex: pubkeyHex,
    attempt: attempt ?? this.attempt,
    vanishEventId: vanishEventId,
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
      return SubmittedAccountDeletionAttempt.fromJson(decoded);
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
  }) async {
    final existing = state;
    if (existing != null && existing.pubkeyHex != pubkeyHex) {
      throw StateError(
        'Another account deletion receipt is already pending',
      );
    }
    final receipt = SubmittedAccountDeletionAttempt(
      pubkeyHex: pubkeyHex,
      attempt: attempt,
      vanishEventId: vanishEventId,
    );
    await _persist(receipt);
  }

  Future<void> updateAttempt(AccountDeletionAttempt attempt) async {
    final receipt = state;
    if (receipt == null || receipt.attempt.id != attempt.id) return;
    await _persist(receipt.copyWith(attempt: attempt));
  }

  Future<void> _persist(SubmittedAccountDeletionAttempt receipt) async {
    final saved = await ref
        .read(sharedPreferencesProvider)
        .setString(_storageKey, jsonEncode(receipt.toJson()));
    if (!saved) throw StateError('Could not persist account deletion receipt');
    state = receipt;
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

/// App-scoped owner for a submitted deletion's receipt polling.
///
/// Keep-alive so status polling outlives the recovery route. The Cubit is a
/// UI adapter over this owner: the screen never creates a second submitter.
final Provider<AccountDeletionRecoveryCubit?>
submittedAccountDeletionMonitorProvider =
    Provider<AccountDeletionRecoveryCubit?>((ref) {
      final receiptIdentity = ref.watch(
        submittedAccountDeletionAttemptProvider.select(
          (receipt) => receipt == null
              ? null
              : (
                  pubkeyHex: receipt.pubkeyHex,
                  attemptId: receipt.attempt.id,
                  vanishEventId: receipt.vanishEventId,
                ),
        ),
      );
      if (receiptIdentity == null) {
        return null;
      }

      final receipt = ref.read(submittedAccountDeletionAttemptProvider)!;
      final receiptNotifier = ref.read(
        submittedAccountDeletionAttemptProvider.notifier,
      );
      var disposed = false;
      final cubit = AccountDeletionRecoveryCubit(
        pollBudgetStore: ref.watch(
          accountDeletionRecoveryPollBudgetProvider,
        ),
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
