// ABOUTME: Data model for NIP-01 user profile metadata from kind 0 events
// ABOUTME: Represents user information like display name, avatar, bio, and social links

import 'dart:convert';
import 'package:hive_ce/hive.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

part 'user_profile.g.dart';

/// Model representing a Nostr user profile from kind 0 events
@HiveType(typeId: 3)
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
    } catch (e) {
      // If JSON parsing fails, create a minimal profile
      return UserProfile(
        pubkey: event.pubkey,
        rawData: {},
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
    Map<String, dynamic> parsedRawData = {};
    if (row.rawData != null && row.rawData is String) {
      try {
        parsedRawData =
            jsonDecode(row.rawData as String) as Map<String, dynamic>;
      } catch (e) {
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
  @HiveField(0)
  final String pubkey;
  @HiveField(1)
  final String? name;
  @HiveField(2)
  final String? displayName;
  @HiveField(3)
  final String? about;
  @HiveField(4)
  final String? picture;
  @HiveField(5)
  final String? banner;
  @HiveField(6)
  final String? website;
  @HiveField(7)
  final String? nip05;
  @HiveField(8)
  final String? lud16; // Lightning address
  @HiveField(9)
  final String? lud06; // LNURL
  @HiveField(10)
  final Map<String, dynamic> rawData;
  @HiveField(11)
  final DateTime createdAt;
  @HiveField(12)
  final String eventId;

  /// Get the best available display name
  String get bestDisplayName {
    if (displayName?.isNotEmpty == true) return displayName!;
    if (name?.isNotEmpty == true) return name!;
    // Fallback to truncated npub (e.g., "npub1abc...xyz")
    return truncatedNpub;
  }

  /// Get shortened pubkey for display
  String get shortPubkey {
    if (pubkey.length <= 16) return pubkey;
    return pubkey;
  }

  /// Get npub encoding of pubkey
  String get npub {
    try {
      return NostrKeyUtils.encodePubKey(pubkey);
    } catch (e) {
      // Fallback to shortened pubkey if encoding fails
      return shortPubkey;
    }
  }

  /// Get truncated npub for display (e.g., "npub1abc...xyz")
  String get truncatedNpub {
    try {
      final fullNpub = NostrKeyUtils.encodePubKey(pubkey);
      if (fullNpub.length <= 16) return fullNpub;
      // Show first 10 chars + "..." + last 6 chars (npub1abc...xyz format)
      return '${fullNpub.substring(0, 10)}...${fullNpub.substring(fullNpub.length - 6)}';
    } catch (e) {
      // Fallback to shortened hex pubkey if encoding fails
      if (pubkey.length <= 16) return pubkey;
      return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 6)}';
    }
  }

  /// Check if profile has basic information
  bool get hasBasicInfo =>
      name?.isNotEmpty == true ||
      displayName?.isNotEmpty == true ||
      picture?.isNotEmpty == true;

  /// Check if profile has avatar
  bool get hasAvatar => picture?.isNotEmpty == true;

  /// Check if profile has bio
  bool get hasBio => about?.isNotEmpty == true;

  /// Check if profile has verified NIP-05 identifier
  bool get hasNip05 => nip05?.isNotEmpty == true;

  /// Check if profile has Lightning support
  bool get hasLightning =>
      lud16?.isNotEmpty == true || lud06?.isNotEmpty == true;

  /// Get Lightning address (prefers lud16 over lud06)
  String? get lightningAddress {
    if (lud16?.isNotEmpty == true) return lud16;
    if (lud06?.isNotEmpty == true) return lud06;
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
      'UserProfile(pubkey: $shortPubkey, name: $bestDisplayName, hasAvatar: $hasAvatar)';
}
