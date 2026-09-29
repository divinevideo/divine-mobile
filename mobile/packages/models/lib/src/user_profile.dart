// ABOUTME: Data model for NIP-01 user profile metadata from kind 0 events.
// ABOUTME: Represents user information like display name, avatar, bio, and
// ABOUTME: social links.

// TODO(any): Replace dynamic row with typed Drift table class to fix
//  avoid_dynamic_calls warnings. Requires coordination with database layer.
// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:models/src/monetization_link.dart';
import 'package:models/src/user_profile_result.dart';
import 'package:nostr_sdk/event.dart';
import 'package:text_sanitizer/text_sanitizer.dart';
import 'package:unique_names_generator/unique_names_generator.dart';

/// Model representing a Nostr user profile from kind 0 events
@immutable
class UserProfile {
  /// Normalizes every kind-0 string field to well-formed UTF-16.
  ///
  /// This is the display boundary for profile text: all four factories below
  /// funnel through here, so a lone surrogate in remote kind-0 JSON is
  /// replaced with U+FFFD once, at the point the profile becomes a typed
  /// model, instead of at each of the ~40 widgets that render these fields.
  /// Flutter's paragraph builder throws `Invalid argument(s): string is not
  /// well-formed UTF-16` on a lone surrogate, and the throw is not confined
  /// to `Text` — `TextPainter.layout` used for measurement (as the profile
  /// bio's expand/collapse does), `Semantics` labels, tooltips and
  /// `EditableText` all reach the same native call, so no single widget can
  /// be the chokepoint. The URL and identifier fields are covered too: a lone
  /// surrogate is invalid in all of them, and they render like any other text.
  ///
  /// These values *are* republished. `ProfileRepository.saveProfileEvent`
  /// seeds the new kind-0 content from [rawData] but then overwrites
  /// `display_name`, `about`, `website`, `picture` and `banner` from the
  /// typed model the editor was seeded with — so [rawData] does not shield
  /// them, and any save that carries the typed value through rewrites what
  /// is stored. That is the point rather than a cost: `jsonEncode` escapes an
  /// unpaired surrogate as the six literal characters `\ud83d` instead of
  /// substituting for it, so the value we publish today re-poisons every
  /// client that parses it back, and NIP-01 has no conformant representation
  /// for it either. Sanitizing first stops us being a propagation vector.
  ///
  /// Only well-formedness is enforced here, not the combining-character cap
  /// that [sanitizeForDisplay] applies. An unpaired surrogate is invalid
  /// input being repaired; stacked diacritics are valid text a user may have
  /// typed, and capping those on the republish path would silently rewrite
  /// their own bio — so Zalgo capping stays on the display getters.
  ///
  /// [pubkey] and [eventId] are hex identifiers and are left untouched, as is
  /// [rawData] itself.
  UserProfile({
    required this.pubkey,
    required this.rawData,
    required this.createdAt,
    required this.eventId,
    String? name,
    String? displayName,
    String? about,
    String? picture,
    String? banner,
    String? website,
    String? nip05,
    String? lud16,
    String? lud06,
    this.rawTags = const [],
  }) : name = sanitizeUtf16OrNull(name),
       displayName = sanitizeUtf16OrNull(displayName),
       about = sanitizeUtf16OrNull(about),
       picture = sanitizeUtf16OrNull(picture),
       banner = sanitizeUtf16OrNull(banner),
       website = sanitizeUtf16OrNull(website),
       nip05 = sanitizeUtf16OrNull(nip05),
       lud16 = sanitizeUtf16OrNull(lud16),
       lud06 = sanitizeUtf16OrNull(lud06);

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
        rawTags: List<List<String>>.unmodifiable(
          event.tags.map(List<String>.unmodifiable),
        ),
        createdAt: event.createdAtDateTime,
        eventId: event.id,
      );
    } on FormatException {
      // If JSON parsing fails, create a minimal profile
      return UserProfile(
        pubkey: event.pubkey,
        rawData: const {},
        createdAt: event.createdAtDateTime,
        eventId: event.id,
      );
    }
  }

  /// Create profile from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawTagsJson = json['raw_tags'] as List<dynamic>?;
    final parsedRawTags = rawTagsJson == null
        ? const <List<String>>[]
        : List<List<String>>.unmodifiable(
            rawTagsJson.cast<List<dynamic>>().map(
              (tag) => List<String>.unmodifiable(tag.cast<String>()),
            ),
          );
    return UserProfile(
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
      rawTags: parsedRawTags,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['created_at'] as int,
        isUtc: true,
      ),
      eventId: json['event_id'] as String,
    );
  }

  /// Creates a [UserProfile] from a typed [UserProfileFound] result.
  ///
  /// Use [eventIdPrefix] to distinguish the source (defaults to `'rest'`;
  /// batch callers pass `'rest-bulk'`).
  ///
  /// `rawData` is populated from the typed REST fields so a profile
  /// round-trip through the REST API does not silently drop them on
  /// the next publish. The Funnelcake REST API does not expose the
  /// raw Kind 0 event JSON, so unknown fields (custom client keys,
  /// future NIP additions) cannot be recovered by this factory and
  /// must be re-seeded by `ProfileRepository.saveProfileEvent` from a
  /// relay query before publishing.
  ///
  /// `createdAt` uses the original Kind 0 event timestamp when Funnelcake
  /// provides one (`UserProfileData.createdAt`), falling back to
  /// `DateTime.now()` only when it is absent. The real timestamp lets the
  /// repository run a newest-wins comparison against the local cache instead
  /// of treating every Funnelcake profile as freshly minted.
  factory UserProfile.fromUserProfileFound(
    UserProfileFound result, {
    String? eventIdPrefix,
  }) {
    final p = result.profile;
    final rawData = <String, dynamic>{
      if (p.name != null) 'name': p.name,
      if (p.displayName != null) 'display_name': p.displayName,
      if (p.about != null) 'about': p.about,
      if (p.picture != null) 'picture': p.picture,
      if (p.banner != null) 'banner': p.banner,
      if (p.website != null) 'website': p.website,
      if (p.nip05 != null) 'nip05': p.nip05,
      if (p.lud16 != null) 'lud16': p.lud16,
    };
    return UserProfile(
      pubkey: p.pubkey,
      name: p.name,
      displayName: p.displayName,
      about: p.about,
      picture: p.picture,
      banner: p.banner,
      website: p.website,
      nip05: p.nip05,
      lud16: p.lud16,
      rawData: rawData,
      createdAt: p.createdAt ?? DateTime.now(),
      eventId: '${eventIdPrefix ?? 'rest'}-${p.pubkey}',
    );
  }

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

  /// Whether this profile came from Funnelcake's REST projection instead of a
  /// raw relay Kind 0 event.
  bool get isRestProjection => eventId.startsWith('rest-');

  /// Raw tags from the source kind 0 event, preserved for callers that need
  /// to inspect them (e.g. NIP-39 `i` identity claim parsing).
  ///
  /// Defaults to an empty list when the profile was constructed from a source
  /// that doesn't carry tags (REST API, Drift cache row, malformed event).
  final List<List<String>> rawTags;

  /// Get shortened pubkey for display
  String get shortPubkey {
    if (pubkey.length <= 16) return pubkey;
    return pubkey;
  }

  List<MonetizationLink> get monetizationLinks =>
      parseMonetizationLinks(rawData[divineMonetizationLinksKey]);

  List<MonetizationLink> get enabledMonetizationLinks =>
      monetizationLinks.where((link) => link.enabled).toList(growable: false);

  /// Like [bestDisplayName] but with a custom fallback placeholder.
  ///
  /// If [anonymousPlaceholder] is provided, it takes priority over the
  /// generated name when no display name or name is set.
  String betterDisplayName(String? anonymousPlaceholder) {
    if (displayName?.isNotEmpty ?? false) {
      return sanitizeForDisplay(displayName!);
    }
    if (name?.isNotEmpty ?? false) return sanitizeForDisplay(name!);
    if (anonymousPlaceholder != null) return anonymousPlaceholder;
    return defaultDisplayName;
  }

  /// Normalizes user-controlled display names before passing them to UI text.
  static String sanitizeDisplayName(String value) => sanitizeForDisplay(value);

  /// A display handle for the user, prefixed with `@`.
  ///
  /// Prefers NIP-05 identifier, falls back to [name]. Returns an empty
  /// string when neither is available. Uses [shortDisplayNip05] so
  /// divine.video users render as `@rabble`, not `@rabble.divine.video`.
  ///
  /// Sanitized like [bestDisplayName]: both candidates are raw kind-0 fields,
  /// and an unpaired UTF-16 surrogate in either crashes the paragraph builder
  /// wherever this renders — the DM conversation header, the new-message
  /// sheet, and people-list rows all pass it straight to a plain `Text`.
  String get handle {
    if (nip05 != null && nip05!.isNotEmpty) {
      final dn = shortDisplayNip05!;
      return dn.startsWith('@') ? dn : '@$dn';
    }
    if (name != null && name!.isNotEmpty) {
      return '@${sanitizeForDisplay(name!)}';
    }
    return '';
  }

  /// NIP-05 formatted for display, full form.
  ///
  /// Normalises all divine.video / openvine.co identifiers to the canonical
  /// `@username.divine.video` form. External identifiers (e.g.
  /// `alice@example.com`) are returned unchanged.
  ///
  /// Use this when the domain is meaningful to the user — settings screens,
  /// the share-video watermark, the NIP-05 editor, the find-people sheet —
  /// so people understand what they own. For general UI rendering prefer
  /// [shortDisplayNip05].
  ///
  /// Sanitized: `nip05` is an unverified kind-0 field, and every consumer of
  /// this getter renders it. Verification compares by pubkey, not by this
  /// string, so normalizing it cannot affect a verified badge.
  String? get displayNip05 {
    if (nip05 == null || nip05!.isEmpty) return null;
    // New subdomain format: _@username.divine.video → @username.divine.video
    if (nip05!.startsWith('_@')) {
      return sanitizeForDisplay(nip05!.substring(1));
    }
    // Legacy divine.video/openvine.co → @username.divine.video
    final username = divineUsername;
    if (username != null) {
      return '@${sanitizeForDisplay(username)}.divine.video';
    }
    // External domain: keep as-is
    return sanitizeForDisplay(nip05!);
  }

  /// NIP-05 formatted for display, short form.
  ///
  /// Strips the `.divine.video` suffix for divine-owned subdomains so the
  /// user shows up as `@rabble` instead of `@rabble.divine.video`. External
  /// identifiers (e.g. `alice@example.com`) are returned unchanged because
  /// the domain is the user's own and meaningful.
  ///
  /// Sanitized for the same reason as [displayNip05].
  String? get shortDisplayNip05 {
    if (nip05 == null || nip05!.isEmpty) return null;
    final username = divineUsername;
    if (username != null) return '@${sanitizeForDisplay(username)}';
    return sanitizeForDisplay(nip05!);
  }

  /// Whether the banner field contains a hex color (Vine import).
  bool get hasProfileBackgroundColor {
    final b = banner;
    if (b == null || b.isEmpty) return false;
    return b.startsWith('0x') || b.startsWith('#');
  }

  /// Whether the banner field is an image URL.
  bool get hasBannerImage {
    final b = banner;
    return b != null && b.startsWith('http');
  }

  /// Get the best available display name.
  ///
  /// Falls back to [defaultDisplayName] when no display name or name is set.
  String get bestDisplayName {
    if (displayName?.isNotEmpty ?? false) {
      return sanitizeForDisplay(displayName!);
    }
    if (name?.isNotEmpty ?? false) return sanitizeForDisplay(name!);
    return defaultDisplayName;
  }

  /// A deterministic "Adjective Animal Number" name derived from the pubkey.
  String get generatedName => generatedNameFor(pubkey);

  /// The default display name to show when no profile name is set.
  ///
  /// Delegates to [defaultDisplayNameFor]. Change that single method to
  /// switch the fallback strategy app-wide (e.g. back to truncated npubs).
  String get defaultDisplayName => defaultDisplayNameFor(pubkey);

  /// The default display name for a pubkey that has no profile name set.
  ///
  /// Currently returns a deterministic generated name. To switch the
  /// fallback strategy app-wide, change only this method.
  static String defaultDisplayNameFor(String pubkey) =>
      generatedNameFor(pubkey);

  /// Generate a deterministic "Adjective Animal Number" name for a [pubkey].
  static String generatedNameFor(String pubkey) {
    final seed = pubkey.codeUnits.fold<int>(0, (prev, c) => prev * 31 + c);
    final random = Random(seed);
    final adj = adjectives[random.nextInt(adjectives.length)];
    final animal = animals[random.nextInt(animals.length)];
    final number = random.nextInt(99) + 1;
    return '${adj[0].toUpperCase()}${adj.substring(1)} '
        '${animal[0].toUpperCase()}${animal.substring(1)} $number';
  }

  /// Follower count reported by Funnelcake REST responses only.
  ///
  /// Non-null only on a profile built by `ProfileSearchResult.toUserProfile`,
  /// the sole writer of `follower_count` into [rawData]. `GET /api/users/{pk}`
  /// nests its counts under `social`/`stats`, which the repository routes to
  /// `profile_statistics` rather than here, and a Kind 0 never carries the key
  /// at all — so this is always `null` on a by-pubkey surface (#8403).
  int? get restFollowerCount => _parseRawInt(rawData['follower_count']);

  /// Video count reported by Funnelcake REST responses only.
  ///
  /// Same population rule as [restFollowerCount]: people-search shape only
  /// (#8403).
  int? get restVideoCount => _parseRawInt(rawData['video_count']);

  /// Check if profile has basic information
  bool get hasBasicInfo =>
      (name?.isNotEmpty ?? false) ||
      (displayName?.isNotEmpty ?? false) ||
      (picture?.isNotEmpty ?? false);

  /// Check if profile has avatar
  bool get hasAvatar => picture?.isNotEmpty ?? false;

  /// Check if profile has bio
  bool get hasBio => about?.isNotEmpty ?? false;

  /// Extracts a divine.video username from the NIP-05 identifier.
  ///
  /// Supports:
  /// - New subdomain format: `_@username.divine.video`
  /// - Legacy formats: `username@divine.video`, `username@openvine.co`
  ///
  /// Returns `null` if [nip05] is null, empty, or not a recognized domain.
  String? get divineUsername {
    if (nip05 == null || nip05!.isEmpty) return null;

    // New subdomain format: _@username.divine.video
    final subdomainMatch = RegExp(
      r'^_@([a-z0-9\-_.]+)\.divine\.video$',
    ).firstMatch(nip05!);
    if (subdomainMatch != null) return subdomainMatch.group(1);

    // Legacy format: username@divine.video or username@openvine.co
    if (nip05!.endsWith('@divine.video') || nip05!.endsWith('@openvine.co')) {
      return nip05!.split('@')[0];
    }

    return null;
  }

  /// Whether this profile has an external (non-divine.video) NIP-05 identifier.
  ///
  /// Returns `true` when [nip05] is set and is NOT a divine.video or
  /// openvine.co domain (i.e., [divineUsername] returns `null`).
  bool get hasExternalNip05 {
    if (nip05 == null || nip05!.isEmpty) return false;
    return divineUsername == null;
  }

  /// Returns the external NIP-05 identifier, or `null` if using divine.video.
  ///
  /// Use this to detect and pre-fill external NIP-05 values in the profile
  /// editor. Returns the raw [nip05] value when [hasExternalNip05] is `true`.
  String? get externalNip05 => hasExternalNip05 ? nip05 : null;

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
    'raw_tags': rawTags,
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
    List<List<String>>? rawTags,
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
    rawTags: rawTags ?? this.rawTags,
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

  static int? _parseRawInt(Object? value) {
    if (value == null) return null;
    return value is int ? value : int.tryParse('$value');
  }
}
