// ABOUTME: State for the NewMessageSearchBloc.
// ABOUTME: Tracks contact loading, search status, and display results.

part of 'new_message_search_bloc.dart';

/// The most people one group conversation holds, the sender included.
///
/// NIP-17: "Group chats with more than 10 participants should find a more
/// suitable messaging scheme" — every message costs one gift wrap per member.
const int dmGroupMaxParticipants = 10;

/// The most recipients the picker lets one group hold: every member of a
/// full group except the sender.
const int dmGroupMaxRecipients = dmGroupMaxParticipants - 1;

/// The fewest recipients that make a group. One recipient is a one-to-one
/// conversation, which the picker starts with a single tap instead.
const int dmGroupMinRecipients = 2;

/// Status of the new message search screen.
enum NewMessageSearchStatus {
  /// Contacts are being loaded from the follow list.
  loadingContacts,

  /// Contacts loaded, no active search query.
  idle,

  /// A network search is in progress.
  searching,

  /// Network search completed successfully.
  searchSuccess,

  /// Network search failed.
  searchFailure,
}

/// State for the new message recipient search.
final class NewMessageSearchState extends Equatable {
  const NewMessageSearchState({
    this.status = NewMessageSearchStatus.loadingContacts,
    this.contacts = const [],
    this.query = '',
    this.results = const [],
    this.networkResults = const [],
    this.vanishedPubkeys = const {},
    this.peerLabels,
    this.isGroupMode = false,
    this.selectedRecipients = const [],
  });

  /// Current status of the search flow.
  final NewMessageSearchStatus status;

  /// All followed contacts, sorted alphabetically.
  final List<UserProfile> contacts;

  /// Current search query (trimmed).
  final String query;

  /// Search results: filtered contacts merged with network results.
  final List<UserProfile> results;

  /// Unfiltered candidates returned by the current network query.
  ///
  /// Retained separately so a late tombstone or locale change can re-run the
  /// rendered-name match instead of leaving [results] keyed on stale labels.
  final List<UserProfile> networkResults;

  /// Pubkeys carrying a NIP-62 vanish tombstone, mirrored live from
  /// `ProfileRepository.watchVanishedPubkeys()`.
  ///
  /// Held in state rather than sampled at match time so the sort and the
  /// filter see the same set the row renders with, the way
  /// `ConversationListBloc` holds it for the inbox index.
  final Set<String> vanishedPubkeys;

  /// The substitute strings [dmPeerName] needs, pushed down from the sheet.
  ///
  /// Null until the first `didChangeDependencies` delivers them — matching on
  /// a substitute needs the translated string, and there is nothing better to
  /// match on before it arrives.
  final DmPeerLabels? peerLabels;

  /// Whether the picker is choosing several people for a group rather than
  /// one person for a one-to-one conversation.
  final bool isGroupMode;

  /// The people picked for the group, in the order they were picked and
  /// unique by pubkey. Always empty outside [isGroupMode].
  final List<UserProfile> selectedRecipients;

  /// Whether a search query is active.
  bool get isSearchActive => query.isNotEmpty;

  /// Whether enough people are picked to start a group.
  bool get canStartGroup => selectedRecipients.length >= dmGroupMinRecipients;

  /// Whether the group has no room for another recipient.
  bool get isGroupFull => selectedRecipients.length >= dmGroupMaxRecipients;

  /// Whether [pubkey] is one of [selectedRecipients].
  ///
  /// Case-insensitive, like every other identity check in this picker: a
  /// pubkey that reaches Divine from another client may be upper-case hex.
  bool isSelected(String pubkey) => selectedRecipients.any(
    (recipient) => pubkeysEqual(recipient.pubkey, pubkey),
  );

  NewMessageSearchState copyWith({
    NewMessageSearchStatus? status,
    List<UserProfile>? contacts,
    String? query,
    List<UserProfile>? results,
    List<UserProfile>? networkResults,
    Set<String>? vanishedPubkeys,
    DmPeerLabels? peerLabels,
    bool? isGroupMode,
    List<UserProfile>? selectedRecipients,
  }) {
    return NewMessageSearchState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      query: query ?? this.query,
      results: results ?? this.results,
      networkResults: networkResults ?? this.networkResults,
      vanishedPubkeys: vanishedPubkeys ?? this.vanishedPubkeys,
      peerLabels: peerLabels ?? this.peerLabels,
      isGroupMode: isGroupMode ?? this.isGroupMode,
      selectedRecipients: selectedRecipients ?? this.selectedRecipients,
    );
  }

  @override
  List<Object?> get props => [
    status,
    contacts,
    query,
    results,
    networkResults,
    vanishedPubkeys,
    peerLabels,
    isGroupMode,
    selectedRecipients,
  ];
}
