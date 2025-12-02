// ABOUTME: Test data builder for creating UserProfile instances for testing
// ABOUTME: Provides flexible factory methods for various user profile scenarios

import 'package:openvine/models/user_profile.dart';

/// Builder class for creating test UserProfile instances
class UserProfileBuilder {
  UserProfileBuilder({
    this.pubkey = 'test-pubkey',
    this.name = 'testuser',
    this.displayName = 'Test User',
    this.picture = 'https://example.com/avatar.jpg',
    this.banner = 'https://example.com/banner.jpg',
    this.about = 'Test user profile',
    this.website = 'https://example.com',
    this.nip05 = 'test@example.com',
    this.lud16 = 'test@walletofsatoshi.com',
    int? createdAt,
    Map<String, dynamic>? metadata,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
       metadata = metadata ?? {};
  String pubkey;
  String? name;
  String? displayName;
  String? picture;
  String? banner;
  String? about;
  String? website;
  String? nip05;
  String? lud16;
  int createdAt;
  Map<String, dynamic> metadata;

  /// Build the UserProfile instance
  UserProfile build() => UserProfile(
    pubkey: pubkey,
    eventId: 'test-event-id-${DateTime.now().millisecondsSinceEpoch}',
    rawData: {
      'name': name,
      'display_name': displayName,
      'picture': picture,
      'banner': banner,
      'about': about,
      'website': website,
      'nip05': nip05,
      'lud16': lud16,
    },
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    name: name,
    displayName: displayName,
    picture: picture,
    banner: banner,
    about: about,
    website: website,
    nip05: nip05,
    lud16: lud16,
  );

  /// Create a minimal profile (only required fields)
  UserProfileBuilder minimal() {
    name = null;
    displayName = null;
    picture = null;
    banner = null;
    about = null;
    website = null;
    nip05 = null;
    lud16 = null;
    return this;
  }

  /// Create a verified profile
  UserProfileBuilder verified() {
    nip05 = '$name@verified.com';
    return this;
  }

  /// Create a profile with custom metadata
  UserProfileBuilder withMetadata(Map<String, dynamic> newMetadata) {
    metadata = newMetadata;
    return this;
  }

  /// Create a profile with specific pubkey
  UserProfileBuilder withPubkey(String newPubkey) {
    pubkey = newPubkey;
    return this;
  }

  /// Create multiple profiles with sequential data
  static List<UserProfile> buildMany({
    required int count,
    String Function(int index)? pubkeyGenerator,
    String Function(int index)? nameGenerator,
  }) => List.generate(
    count,
    (index) => UserProfileBuilder(
      pubkey: pubkeyGenerator?.call(index) ?? 'pubkey-$index',
      name: nameGenerator?.call(index) ?? 'user$index',
      displayName: 'User $index',
    ).build(),
  );
}
