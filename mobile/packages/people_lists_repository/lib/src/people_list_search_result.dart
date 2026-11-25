// ABOUTME: Public-search result type for kind 30000 people lists.
// ABOUTME: Preserves the list owner pubkey alongside the decoded UserList.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart' show UserList;
import 'package:people_lists_repository/src/nip51_people_list_codec.dart';

/// Public-search result preserving the list owner's pubkey alongside the
/// decoded [UserList].
///
/// A [UserList.id] (the NIP-33 `d` tag) is **not** globally unique — two
/// different owners can each publish a list with `d=friends`. Consumers of
/// public search must key on the full addressable coordinate
/// (`kind:ownerPubkey:d-tag`), exposed here as [addressableId], rather than
/// on [UserList.id] alone.
class PeopleListSearchResult extends Equatable {
  /// Creates a search result wrapping a decoded [list] published by
  /// [ownerPubkey].
  ///
  /// [memberCount] is for a [list] that holds a preview of its members, as a
  /// list found in FunnelCake's list index does; it defaults to the members
  /// [list] holds.
  const PeopleListSearchResult({
    required this.ownerPubkey,
    required this.list,
    int? memberCount,
  }) : _memberCount = memberCount;

  /// Full 64-char hex pubkey of the list owner. Never truncated.
  final String ownerPubkey;

  /// Decoded people list as produced by [Nip51PeopleListCodec.decode].
  ///
  /// A list found in FunnelCake's list index holds at most five of its
  /// members; [memberCount] counts them all.
  final UserList list;

  final int? _memberCount;

  /// How many members the list has.
  int get memberCount => _memberCount ?? list.pubkeys.length;

  /// Addressable coordinate (`kind:ownerPubkey:d-tag`) that uniquely
  /// identifies this list across all owners.
  String get addressableId =>
      '${Nip51PeopleListCodec.kind}:$ownerPubkey:${list.id}';

  @override
  List<Object?> get props => [ownerPubkey, list, memberCount];
}
