// ABOUTME: Events for OtherProfileBloc - viewing another user's profile
// ABOUTME: Handles screen open, pull-to-refresh, and block/unblock actions

part of 'other_profile_bloc.dart';

/// Base class for all other profile events.
sealed class OtherProfileEvent extends Equatable {
  const OtherProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered to load the profile.
///
/// This initiates the profile loading sequence:
/// 1. Emit cached profile immediately (if available)
/// 2. Fetch fresh profile from relay
/// 3. Emit fresh profile when received
final class OtherProfileLoadRequested extends OtherProfileEvent {
  const OtherProfileLoadRequested();
}

/// Event triggered when user pulls to refresh the profile.
///
/// Re-fetches the profile from relay and updates the UI.
final class OtherProfileRefreshRequested extends OtherProfileEvent {
  const OtherProfileRefreshRequested();
}

/// Event triggered when the user confirms blocking this profile.
///
/// The BLoC will:
/// 1. Add user to blocklist
/// 2. Unfollow them if currently following
/// 3. Increment blocklist version to notify other BLoCs
final class OtherProfileBlockRequested extends OtherProfileEvent {
  const OtherProfileBlockRequested();
}

/// Event triggered when the user confirms unblocking this profile.
///
/// The BLoC will:
/// 1. Remove user from blocklist
/// 2. Increment blocklist version to notify other BLoCs
final class OtherProfileUnblockRequested extends OtherProfileEvent {
  const OtherProfileUnblockRequested();
}

/// Event triggered to fetch verifier-confirmed NIP-39 identity claims for
/// the currently loaded profile.
///
/// Auto-dispatched after a successful profile load. Falls back to an empty
/// claim list if the verifier is unreachable or returns an error.
final class VerifiedClaimsRequested extends OtherProfileEvent {
  const VerifiedClaimsRequested();
}

/// Background support metadata for one display request; superseded requests
/// cannot overwrite a newer load or refresh.
final class _SupportLinksRequested extends OtherProfileEvent {
  const _SupportLinksRequested(this.request);

  final int request;

  @override
  List<Object?> get props => [request];
}
