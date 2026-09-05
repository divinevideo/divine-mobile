// ABOUTME: BLoC for welcome screen returning-user state
// ABOUTME: Loads known accounts list for multi-account sign-in support

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:db_client/db_client.dart';
import 'package:equatable/equatable.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/utils/npub_hex.dart';
import 'package:unified_logger/unified_logger.dart';

part 'welcome_event.dart';
part 'welcome_state.dart';

/// BLoC for managing the welcome screen state.
///
/// Handles:
/// - Loading known accounts from the AuthService registry + SQLite cache
/// - Selecting which account to sign back in with
/// - Removing accounts from the known list
/// - Triggering auth actions (log back in, create new account, login options)
class WelcomeBloc extends Bloc<WelcomeEvent, WelcomeState> {
  WelcomeBloc({
    required UserProfilesDao userProfilesDao,
    required AuthService authService,
    this.deletionPendingPubkeyHex,
  }) : _userProfilesDao = userProfilesDao,
       _authService = authService,
       super(const WelcomeState()) {
    on<WelcomeStarted>(_onStarted, transformer: droppable());
    on<WelcomeLastUserDismissed>(
      _onLastUserDismissed,
      transformer: droppable(),
    );
    on<WelcomeLogBackInRequested>(_onLogBackIn, transformer: droppable());
    on<WelcomeCancelSwitchRequested>(_onCancelSwitch, transformer: droppable());
    on<WelcomeAccountSelected>(_onAccountSelected);
    on<WelcomeCreateAccountRequested>(
      _onCreateAccountRequested,
      transformer: droppable(),
    );
    on<WelcomeLoginOptionsRequested>(
      _onLoginOptionsRequested,
      transformer: droppable(),
    );
    on<WelcomeProfilesHydrated>(_onProfilesHydrated);
  }

  final UserProfilesDao _userProfilesDao;
  final AuthService _authService;
  final String? deletionPendingPubkeyHex;

  Future<void> _onStarted(
    WelcomeStarted event,
    Emitter<WelcomeState> emit,
  ) async {
    Log.info(
      'WelcomeBloc: loading known accounts...',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );

    // Consume any pending account-switch selection set before sign-out.
    final pendingPubkey = _authService.pendingAccountSwitchPubkey;
    _authService.pendingAccountSwitchPubkey = null;

    // Load known accounts and the session-recovery anchor in parallel.
    final accountsFuture = _authService.getKnownAccounts();
    final anchorFuture = _authService.getSessionRecoveryAnchorNpub();
    final knownAccounts = await accountsFuture;
    final anchorNpub = await anchorFuture;

    // Decode the npub anchor to hex so it can be compared with pubkeyHex
    // fields in the account list. Use null on any decode failure so the
    // mismatch detection degrades gracefully rather than crashing.
    final anchorPubkeyHex = npubToHexOrNull(anchorNpub);

    if (knownAccounts.isEmpty) {
      Log.info(
        'WelcomeBloc: no known accounts — showing fresh welcome',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      emit(state.copyWith(status: WelcomeStatus.loaded));
      return;
    }

    Log.info(
      'WelcomeBloc: found ${knownAccounts.length} known account(s)'
      '${anchorPubkeyHex != null ? ", recovery anchor=${pubkeyForLogs(anchorPubkeyHex)}" : ""}',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );

    // Emit accounts immediately WITHOUT profiles so the screen renders fast.
    final accountsWithoutProfiles = knownAccounts
        .map(
          (known) => PreviousAccount(
            pubkeyHex: known.pubkeyHex,
            authSource: known.authSource,
          ),
        )
        .toList();

    // Determine the initial selection:
    //
    // Priority order:
    //   1. pendingPubkey — explicit account-switch from settings (highest priority)
    //   2. event.initialSelectedPubkeyHex — router deep-link pre-selection
    //   3. anchorPubkeyHex — the account the user was signed into at sign-out
    //      (avoids defaulting to a different account that was just restored
    //      via _redirectRecoveryToRemainingAccount and may show as "most recent")
    //   4. null — falls back to previousAccounts.first (most recently used)
    //
    // Using the anchor as the default pre-selection ensures the welcome screen
    // highlights the account the user was actually on, not the one that cold-
    // start recovery would have silently switched to.
    final initialSelection =
        pendingPubkey ?? event.initialSelectedPubkeyHex ?? anchorPubkeyHex;

    emit(
      state.copyWith(
        status: WelcomeStatus.loaded,
        previousAccounts: accountsWithoutProfiles,
        selectedPubkeyHex: initialSelection,
        recoveryAnchorPubkeyHex: anchorPubkeyHex,
      ),
    );

    // Hydrate profiles from SQLite in parallel, then update state.
    _hydrateProfiles(knownAccounts);
  }

  /// Loads cached profiles for each known account in parallel and fires
  /// [WelcomeProfilesHydrated] to update the account list.
  Future<void> _hydrateProfiles(List<KnownAccount> knownAccounts) async {
    final futures = <Future<PreviousAccount>>[];
    for (final known in knownAccounts) {
      futures.add(_hydrateAccount(known));
    }
    final results = await Future.wait(futures);

    final withProfiles = results.where((a) => a.profile != null).length;
    Log.info(
      'WelcomeBloc: hydrated ${results.length} account(s) '
      '($withProfiles with cached profiles)',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );

    // Only update if any profiles were actually found. Guard because this
    // method runs fire-and-forget from _onWelcomeStarted, so the bloc may
    // already be closed by the time the parallel hydration finishes.
    if (withProfiles > 0 && !isClosed) {
      add(WelcomeProfilesHydrated(results));
    }
  }

  Future<PreviousAccount> _hydrateAccount(KnownAccount known) async {
    UserProfile? profile;
    try {
      profile = await _userProfilesDao.getProfile(known.pubkeyHex);
    } catch (e, stackTrace) {
      Log.warning(
        'Failed to load cached profile for ${pubkeyForLogs(known.pubkeyHex)}: $e',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      // Matrix-NO (Drift IO). Guarded because _hydrateAccount is reached
      // via a fire-and-forget _hydrateProfiles call; the bloc may close
      // before the await resolves, and post-close addError throws.
      if (!isClosed) {
        addError(e, stackTrace);
      }
    }
    return PreviousAccount(
      pubkeyHex: known.pubkeyHex,
      authSource: known.authSource,
      profile: profile,
    );
  }

  void _onLastUserDismissed(
    WelcomeLastUserDismissed event,
    Emitter<WelcomeState> emit,
  ) {
    emit(
      state.copyWith(
        status: WelcomeStatus.loaded,
        clearAccounts: true,
        clearSelectedPubkey: true,
      ),
    );
  }

  Future<void> _onLogBackIn(
    WelcomeLogBackInRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    final account = state.selectedAccount;
    if (account == null) {
      Log.warning(
        'WelcomeBloc: log back in requested but no account selected',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      return;
    }
    if (_redirectPendingDeletion(account, emit)) return;

    Log.info(
      'WelcomeBloc: logging back in as '
      'pubkey=${pubkeyForLogs(account.pubkeyHex)}, '
      'source=${account.authSource.name}',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );

    emit(
      state.copyWith(
        status: WelcomeStatus.accepting,
        signingInPubkeyHex: account.pubkeyHex,
      ),
    );

    try {
      await _authService.signInForAccount(
        account.pubkeyHex,
        account.authSource,
      );
      Log.info(
        'WelcomeBloc: sign-in completed for ${pubkeyForLogs(account.pubkeyHex)}',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
    } on SessionExpiredException catch (e, stackTrace) {
      Log.warning(
        'WelcomeBloc: session expired for ${pubkeyForLogs(account.pubkeyHex)} '
        '— redirecting to login options',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      await _recoverToLoginOptions(
        emit,
        e,
        stackTrace,
        recoveryStatus: WelcomeStatus.sessionExpired,
      );
    } on AccountRestoreFailedException catch (e, stackTrace) {
      Log.warning(
        'WelcomeBloc: restore failed for ${pubkeyForLogs(account.pubkeyHex)} '
        '(${e.resolvedState}) — redirecting to login options',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      await _recoverToLoginOptions(
        emit,
        e,
        stackTrace,
        recoveryStatus: WelcomeStatus.accountRestoreFailed,
      );
    } catch (e, stackTrace) {
      Log.error(
        'WelcomeBloc: failed to log back in as ${pubkeyForLogs(account.pubkeyHex)}: $e',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      // Auth-flow failures dominate (OAuth/network) — matrix-NO.
      // YES-narrowing for invariant types deferred per #4592; analogous
      // to #4597's `_onMessageSent` deferral.
      addError(e, stackTrace);
      emit(state.copyWith(status: WelcomeStatus.error, clearSigningIn: true));
    }
  }

  Future<void> _recoverToLoginOptions(
    Emitter<WelcomeState> emit,
    Object error,
    StackTrace stackTrace, {
    required WelcomeStatus? recoveryStatus,
  }) async {
    // Recoverable auth-flow failure — matrix-NO (Auth/session row).
    addError(error, stackTrace);
    if (recoveryStatus != null) {
      emit(state.copyWith(status: recoveryStatus, clearSigningIn: true));
    }
    await _authService.acceptTerms();
    emit(
      state.copyWith(
        status: WelcomeStatus.navigatingToLoginOptions,
        clearSigningIn: true,
      ),
    );
    emit(state.copyWith(status: WelcomeStatus.loaded));
  }

  /// Cancels an account switch and restores the previous (most-recently-used)
  /// account — i.e. [WelcomeState.previousAccounts.first], regardless of
  /// [WelcomeState.selectedPubkeyHex].
  Future<void> _onCancelSwitch(
    WelcomeCancelSwitchRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    final previous = state.previousAccounts.firstOrNull;
    if (previous == null) return;
    if (_redirectPendingDeletion(previous, emit)) return;

    Log.info(
      'WelcomeBloc: cancel switch — restoring previous account '
      'pubkey=${pubkeyForLogs(previous.pubkeyHex)}',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );

    emit(
      state.copyWith(
        status: WelcomeStatus.accepting,
        signingInPubkeyHex: previous.pubkeyHex,
      ),
    );

    try {
      await _authService.signInForAccount(
        previous.pubkeyHex,
        previous.authSource,
      );
    } on SessionExpiredException catch (e, stackTrace) {
      await _recoverToLoginOptions(
        emit,
        e,
        stackTrace,
        recoveryStatus: null,
      );
    } on AccountRestoreFailedException catch (e, stackTrace) {
      Log.warning(
        'WelcomeBloc: restore failed while cancelling account switch for '
        '${pubkeyForLogs(previous.pubkeyHex)} (${e.resolvedState}) — redirecting to '
        'login options',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      await _recoverToLoginOptions(
        emit,
        e,
        stackTrace,
        recoveryStatus: null,
      );
    } catch (e, stackTrace) {
      // Same auth/network/IO failure surface as `_onLogBackIn` —
      // matrix-NO. YES-narrowing deferred per #4592.
      addError(e, stackTrace);
      emit(state.copyWith(status: WelcomeStatus.error, clearSigningIn: true));
    }
  }

  bool _redirectPendingDeletion(
    PreviousAccount account,
    Emitter<WelcomeState> emit,
  ) {
    if (account.pubkeyHex != deletionPendingPubkeyHex) return false;
    emit(
      state.copyWith(
        status: WelcomeStatus.navigatingToAccountDeletionRecovery,
      ),
    );
    emit(state.copyWith(status: WelcomeStatus.loaded));
    return true;
  }

  void _onAccountSelected(
    WelcomeAccountSelected event,
    Emitter<WelcomeState> emit,
  ) {
    Log.debug(
      'WelcomeBloc: account selected — pubkey=${pubkeyForLogs(event.pubkeyHex)}',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );
    emit(state.copyWith(selectedPubkeyHex: event.pubkeyHex));
  }

  Future<void> _onCreateAccountRequested(
    WelcomeCreateAccountRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    Log.info(
      'WelcomeBloc: create account requested — accepting terms and '
      'navigating',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );
    await _authService.acceptTerms();
    emit(state.copyWith(status: WelcomeStatus.navigatingToCreateAccount));
    emit(state.copyWith(status: WelcomeStatus.loaded));
  }

  Future<void> _onLoginOptionsRequested(
    WelcomeLoginOptionsRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    Log.info(
      'WelcomeBloc: login options requested — accepting terms and '
      'navigating',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );
    await _authService.acceptTerms();
    emit(state.copyWith(status: WelcomeStatus.navigatingToLoginOptions));
    emit(state.copyWith(status: WelcomeStatus.loaded));
  }

  void _onProfilesHydrated(
    WelcomeProfilesHydrated event,
    Emitter<WelcomeState> emit,
  ) {
    // Only update if we're still on the loaded screen — don't clobber
    // an in-progress sign-in or navigation.
    if (state.status != WelcomeStatus.loaded) return;

    emit(state.copyWith(previousAccounts: event.accounts));
  }
}
