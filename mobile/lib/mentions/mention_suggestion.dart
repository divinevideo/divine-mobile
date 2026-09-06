import 'package:equatable/equatable.dart';

/// A mention suggestion for autocomplete.
class MentionSuggestion extends Equatable {
  const MentionSuggestion({
    required this.pubkey,
    this.displayName,
    this.picture,
    this.nip05,
  });

  /// The hex public key of the suggested user.
  final String pubkey;

  /// Optional display name (from cached profile).
  final String? displayName;

  /// Optional profile picture URL.
  final String? picture;

  /// Optional NIP-05 claim from the profile.
  final String? nip05;

  @override
  List<Object?> get props => [pubkey, displayName, picture, nip05];
}
