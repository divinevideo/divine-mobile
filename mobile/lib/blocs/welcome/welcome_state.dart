// ABOUTME: State for WelcomeBloc
// ABOUTME: Immutable state with list-based multi-account support

part of 'welcome_bloc.dart';

/// Status of welcome screen operations.
enum WelcomeStatus {
  /// Initial state, data not yet loaded.
  initial,

  /// Returning-user data loaded (or confirmed absent).
  loaded,

  /// An auth action (log back in / create account) is in progress.
  accepting,

  /// An auth action failed due to expired session.
  sessionExpired,

  /// An auth action failed because stored local account keys could not restore.
  accountRestoreFailed,

  /// Previous account data still needs safe cleanup; the action can retry.
  accountCleanupFailed,

  /// An auth action failed for a generic reason.
  error,

  /// Transient: navigate to login options, then auto-resets to [loaded].
  navigatingToLoginOptions,

  /// Transient: navigate to create account, then auto-resets to [loaded].
  navigatingToCreateAccount,

  /// Transient: show the selected account's pending deletion attempt.
  navigatingToAccountDeletionRecovery,
}

/// A previously used account with its cached profile data.
class PreviousAccount extends Equatable {
  const PreviousAccount({
    required this.pubkeyHex,
    required this.authSource,
    this.profile,
  });

  /// Full 64-character hex public key.
  final String pubkeyHex;

  /// Which authentication method was used for this identity.
  final AuthenticationSource authSource;

  /// Cached profile from SQLite, if available.
  final UserProfile? profile;

  @override
  List<Object?> get props => [pubkeyHex, authSource, profile];
}

/// State for the welcome BLoC.
final class WelcomeState extends Equatable {
  const WelcomeState({
    this.status = WelcomeStatus.initial,
    this.previousAccounts = const [],
    this.selectedPubkeyHex,
    this.signingInPubkeyHex,
    this.recoveryAnchorPubkeyHex,
  });

  /// Current status of welcome operations.
  final WelcomeStatus status;

  /// List of previously used accounts, sorted by most recently used first.
  final List<PreviousAccount> previousAccounts;

  /// The pubkey of the currently selected account in the dropdown.
  /// Defaults to the most recently used account (first in list).
  final String? selectedPubkeyHex;

  /// The pubkey of the account currently being signed into (for loading state).
  final String? signingInPubkeyHex;

  /// The pubkey (hex) that was actively signed in at the time of the most
  /// recent sign-out. Set from the session-recovery anchor written by
  /// [AuthService.signOut] and decoded from npub to hex by [WelcomeBloc].
  ///
  /// Null when no anchor was recorded (clean install, or sign-in has already
  /// cleared the anchor, or the anchor npub could not be decoded).
  final String? recoveryAnchorPubkeyHex;

  /// Whether any returning users were detected.
  bool get hasReturningUsers => previousAccounts.isNotEmpty;

  /// The currently selected account, or null if none selected.
  PreviousAccount? get selectedAccount {
    if (previousAccounts.isEmpty) return null;
    if (selectedPubkeyHex == null) return previousAccounts.first;
    return previousAccounts
            .where((a) => a.pubkeyHex == selectedPubkeyHex)
            .firstOrNull ??
        previousAccounts.first;
  }

  /// Whether an auth action is in progress.
  bool get isAccepting => status == WelcomeStatus.accepting;

  /// Whether the welcome screen should show session-recovery context.
  ///
  /// When present, the user most recently signed out of this account and the
  /// welcome screen should explain which account owns local drafts/clips.
  bool get hasRecoveryAnchor => recoveryAnchorPubkeyHex != null;

  /// True when the session recovery anchor points to a different account than
  /// the one currently selected for sign-in.
  ///
  /// This happens when the user switches away from the anchored account on the
  /// welcome screen. The banner flips from reassurance to a warning explaining
  /// that local drafts/clips belong to the anchored account and will be hidden
  /// after sign-in.
  bool get hasCrossAccountMismatch {
    if (recoveryAnchorPubkeyHex == null) return false;
    final selected = selectedAccount;
    if (selected == null) return false;
    return recoveryAnchorPubkeyHex != selected.pubkeyHex;
  }

  /// Creates a copy of this state with the given fields replaced.
  WelcomeState copyWith({
    WelcomeStatus? status,
    List<PreviousAccount>? previousAccounts,
    String? selectedPubkeyHex,
    String? signingInPubkeyHex,
    String? recoveryAnchorPubkeyHex,
    bool clearAccounts = false,
    bool clearSigningIn = false,
    bool clearSelectedPubkey = false,
    bool clearRecoveryAnchor = false,
  }) {
    return WelcomeState(
      status: status ?? this.status,
      previousAccounts: clearAccounts
          ? const []
          : (previousAccounts ?? this.previousAccounts),
      selectedPubkeyHex: clearSelectedPubkey
          ? null
          : (selectedPubkeyHex ?? this.selectedPubkeyHex),
      signingInPubkeyHex: clearSigningIn
          ? null
          : (signingInPubkeyHex ?? this.signingInPubkeyHex),
      recoveryAnchorPubkeyHex: clearRecoveryAnchor
          ? null
          : (recoveryAnchorPubkeyHex ?? this.recoveryAnchorPubkeyHex),
    );
  }

  @override
  List<Object?> get props => [
    status,
    previousAccounts,
    selectedPubkeyHex,
    signingInPubkeyHex,
    recoveryAnchorPubkeyHex,
  ];
}
