// ABOUTME: Events for the NewMessageSearchBloc.
// ABOUTME: Covers contact loading, query changes, and clearing search.

part of 'new_message_search_bloc.dart';

/// Base class for new message search events.
sealed class NewMessageSearchEvent extends Equatable {
  const NewMessageSearchEvent();

  @override
  List<Object?> get props => [];
}

/// Load followed contacts from the repository.
final class NewMessageSearchStarted extends NewMessageSearchEvent {
  const NewMessageSearchStarted();
}

/// User typed or changed the search query.
final class NewMessageSearchQueryChanged extends NewMessageSearchEvent {
  const NewMessageSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// User cleared the search field.
final class NewMessageSearchCleared extends NewMessageSearchEvent {
  const NewMessageSearchCleared();
}

/// The localized [DmPeerLabels] the sheet resolved from its `BuildContext`.
///
/// Pushed down rather than read here, for the same reason
/// `ConversationListPeerLabelsChanged` exists: the substitutes are ARB
/// strings, the matcher is a BLoC, and only one of them can see a
/// `BuildContext`.
final class NewMessageSearchPeerLabelsChanged extends NewMessageSearchEvent {
  const NewMessageSearchPeerLabelsChanged(this.labels);

  final DmPeerLabels labels;

  @override
  List<Object?> get props => [labels];
}

/// User entered or left group mode, where the picker chooses several people
/// instead of closing on the first tap. Leaving discards the selection.
final class NewMessageSearchGroupModeChanged extends NewMessageSearchEvent {
  const NewMessageSearchGroupModeChanged({required this.enabled});

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

/// User tapped a candidate in group mode, or the chip of one already picked:
/// picks [profile] when they are not selected, drops them when they are.
final class NewMessageSearchRecipientToggled extends NewMessageSearchEvent {
  const NewMessageSearchRecipientToggled(this.profile);

  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}

/// The live vanished set changed. Private: only this BLoC's own subscription
/// to `ProfileRepository.watchVanishedPubkeys()` raises it.
final class _NewMessageSearchVanishedPubkeysChanged
    extends NewMessageSearchEvent {
  const _NewMessageSearchVanishedPubkeysChanged(this.pubkeys);

  final Set<String> pubkeys;

  @override
  List<Object?> get props => [pubkeys];
}
