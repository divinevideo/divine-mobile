// ABOUTME: Model representing a NIP-51 kind 30000 user/people list.
// ABOUTME: Contains pubkeys and metadata for lists of people.

import 'package:equatable/equatable.dart';
import 'package:text_sanitizer/text_sanitizer.dart';

/// Represents a user list (NIP-51 kind 30000) containing pubkeys.
class UserList extends Equatable {
  /// Creates a user list, normalizing [name] and [description] to well-formed
  /// UTF-16.
  ///
  /// Both come from a kind-30000 event that any pubkey may author and both
  /// render as plain `Text`; a lone surrogate throws out of Flutter's
  /// paragraph builder. See `CuratedList` for the boundary rationale.
  UserList({
    required this.id,
    required String name,
    required this.pubkeys,
    required this.createdAt,
    required this.updatedAt,
    String? description,
    this.imageUrl,
    this.isPublic = true,
    this.nostrEventId,
    this.isEditable = true,
  }) : name = sanitizeUtf16(name),
       description = sanitizeUtf16OrNull(description);

  factory UserList.fromJson(Map<String, dynamic> json) => UserList(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
    pubkeys: List<String>.from(json['pubkeys'] as Iterable? ?? []),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isPublic: json['isPublic'] as bool? ?? true,
    nostrEventId: json['nostrEventId'] as String?,
    isEditable: json['isEditable'] as bool? ?? true,
  );

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final List<String> pubkeys;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;
  final String? nostrEventId;

  /// Whether the list can be edited by the user.
  ///
  /// `false` for system lists like Divine Team.
  final bool isEditable;

  /// Copy with the given fields replaced.
  ///
  /// [clearDescription] drops the description, which a null [description]
  /// cannot express since null means "keep the current one". Passing both a
  /// [description] and [clearDescription] asks for two things at once and
  /// throws an [ArgumentError] rather than quietly dropping the text.
  UserList copyWith({
    String? id,
    String? name,
    String? description,
    bool clearDescription = false,
    String? imageUrl,
    List<String>? pubkeys,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    String? nostrEventId,
    bool? isEditable,
  }) {
    if (clearDescription && description != null) {
      throw ArgumentError.value(
        description,
        'description',
        'cannot be set while clearDescription is true',
      );
    }
    return UserList(
      id: id ?? this.id,
      name: name ?? this.name,
      description: clearDescription ? null : description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      pubkeys: pubkeys ?? this.pubkeys,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      nostrEventId: nostrEventId ?? this.nostrEventId,
      isEditable: isEditable ?? this.isEditable,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'pubkeys': pubkeys,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isPublic': isPublic,
    'nostrEventId': nostrEventId,
    'isEditable': isEditable,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    imageUrl,
    pubkeys,
    createdAt,
    updatedAt,
    isPublic,
    nostrEventId,
    isEditable,
  ];
}
