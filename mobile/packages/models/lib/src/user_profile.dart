// ABOUTME: Data model for NIP-01 user profile metadata from kind 0 events.
// ABOUTME: Represents user information like display name, avatar, bio, and
// ABOUTME: social links.

// TODO(any): Replace dynamic row with typed Drift table class to fix
//  avoid_dynamic_calls warnings. Requires coordination with database layer.
// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:nostr_sdk/event.dart';

/// Model representing a Nostr user profile from kind 0 events
@immutable
class UserProfile {
  const UserProfile({
    required this.pubkey,
    required this.rawData,
    required this.createdAt,
    required this.eventId,
    this.name,
    this.displayName,
    this.about,
    this.picture,
    this.banner,
    this.website,
    this.nip05,
    this.lud16,
    this.lud06,
  });

  /// Create UserProfile from a Nostr kind 0 event
  factory UserProfile.fromNostrEvent(Event event) {
    if (event.kind != 0) {
      throw ArgumentError('Event must be kind 0 (user metadata)');
    }

    try {
      // Parse the JSON content
      final content = jsonDecode(event.content) as Map<String, dynamic>;

      return UserProfile(
        pubkey: event.pubkey,
        name: content['name']?.toString(),
        displayName:
            content['display_name']?.toString() ??
            content['displayName']?.toString(),
        about: content['about']?.toString(),
        picture: content['picture']?.toString(),
        banner: content['banner']?.toString(),
        website: content['website']?.toString(),
        nip05: content['nip05']?.toString(),
        lud16: content['lud16']?.toString(),
        lud06: content['lud06']?.toString(),
        rawData: content,
        createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
        eventId: event.id,
      );
    } on FormatException {
      // If JSON parsing fails, create a minimal profile
      return UserProfile(
        pubkey: event.pubkey,
        rawData: const {},
        createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
        eventId: event.id,
      );
    }
  }

  /// Create profile from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    pubkey: json['pubkey'] as String,
    name: json['name'] as String?,
    displayName: json['display_name'] as String?,
    about: json['about'] as String?,
    picture: json['picture'] as String?,
    banner: json['banner'] as String?,
    website: json['website'] as String?,
    nip05: json['nip05'] as String?,
    lud16: json['lud16'] as String?,
    lud06: json['lud06'] as String?,
    rawData: json['raw_data'] as Map<String, dynamic>? ?? {},
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    eventId: json['event_id'] as String,
  );

  /// Create profile from Drift database row
  factory UserProfile.fromDrift(dynamic row) {
    // Parse rawData from JSON string if present
    var parsedRawData = <String, dynamic>{};
    if (row.rawData != null && row.rawData is String) {
      try {
        parsedRawData =
            jsonDecode(row.rawData as String) as Map<String, dynamic>;
      } on FormatException {
        // If JSON parsing fails, use empty map
        parsedRawData = {};
      }
    }

    return UserProfile(
      pubkey: row.pubkey as String,
      name: row.name as String?,
      displayName: row.displayName as String?,
      about: row.about as String?,
      picture: row.picture as String?,
      banner: row.banner as String?,
      website: row.website as String?,
      nip05: row.nip05 as String?,
      lud16: row.lud16 as String?,
      lud06: row.lud06 as String?,
      rawData: parsedRawData,
      createdAt: row.createdAt as DateTime,
      eventId: row.eventId as String,
    );
  }
  final String pubkey;
  final String? name;
  final String? displayName;
  final String? about;
  final String? picture;
  final String? banner;
  final String? website;
  final String? nip05;
  final String? lud16; // Lightning address
  final String? lud06; // LNURL
  final Map<String, dynamic> rawData;
  final DateTime createdAt;
  final String eventId;

  /// Get shortened pubkey for display
  String get shortPubkey {
    if (pubkey.length <= 16) return pubkey;
    return pubkey;
  }

  /// Check if profile has basic information
  bool get hasBasicInfo =>
      (name?.isNotEmpty ?? false) ||
      (displayName?.isNotEmpty ?? false) ||
      (picture?.isNotEmpty ?? false);

  /// Check if profile has avatar
  bool get hasAvatar => picture?.isNotEmpty ?? false;

  /// Check if profile has bio
  bool get hasBio => about?.isNotEmpty ?? false;

  /// Check if profile has verified NIP-05 identifier
  bool get hasNip05 => nip05?.isNotEmpty ?? false;

  /// Check if profile has Lightning support
  bool get hasLightning =>
      (lud16?.isNotEmpty ?? false) || (lud06?.isNotEmpty ?? false);

  /// Get Lightning address (prefers lud16 over lud06)
  String? get lightningAddress {
    if (lud16?.isNotEmpty ?? false) return lud16;
    if (lud06?.isNotEmpty ?? false) return lud06;
    return null;
  }

  /// Vine-specific metadata getters from rawData
  String? get vineUsername => rawData['vine_username'] as String?;
  bool get vineVerified => rawData['vine_verified'] == true;
  int? get vineFollowers {
    final value = rawData['vine_followers'];
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  int? get vineLoops {
    final value = rawData['vine_loops'];
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Check if this is an imported Vine user account
  bool get isVineImport => vineUsername != null;

  /// Get location data if available
  String? get location => rawData['location'] as String?;

  /// Convert profile to JSON
  Map<String, dynamic> toJson() => {
    'pubkey': pubkey,
    'name': name,
    'display_name': displayName,
    'about': about,
    'picture': picture,
    'banner': banner,
    'website': website,
    'nip05': nip05,
    'lud16': lud16,
    'lud06': lud06,
    'created_at': createdAt.millisecondsSinceEpoch,
    'event_id': eventId,
    'raw_data': rawData,
  };

  /// Create copy with updated fields
  UserProfile copyWith({
    String? name,
    String? displayName,
    String? about,
    String? picture,
    String? banner,
    String? website,
    String? nip05,
    String? lud16,
    String? lud06,
    Map<String, dynamic>? rawData,
  }) => UserProfile(
    pubkey: pubkey,
    name: name ?? this.name,
    displayName: displayName ?? this.displayName,
    about: about ?? this.about,
    picture: picture ?? this.picture,
    banner: banner ?? this.banner,
    website: website ?? this.website,
    nip05: nip05 ?? this.nip05,
    lud16: lud16 ?? this.lud16,
    lud06: lud06 ?? this.lud06,
    rawData: rawData ?? this.rawData,
    createdAt: createdAt,
    eventId: eventId,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.pubkey == pubkey &&
        other.eventId == eventId;
  }

  @override
  int get hashCode => Object.hash(pubkey, eventId);

  @override
  String toString() =>
      'UserProfile(pubkey: $shortPubkey, '
      'name: $displayName, hasAvatar: $hasAvatar)';
}
