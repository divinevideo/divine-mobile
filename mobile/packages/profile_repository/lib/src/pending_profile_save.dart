// ABOUTME: Serializable payload for a queued profile/username save (#3161).
// ABOUTME: Captures the user's raw save intent so a failed kind-0 publish can
// ABOUTME: be re-driven in the background when connectivity returns.

import 'dart:convert';

import 'package:models/models.dart';

/// The raw intent of a single profile/username save, persisted in the
/// durable pending-save slot so `ProfileRepository.drivePendingSave` can
/// replay it after a transient relay outage.
///
/// Mirrors the editable parameters of `ProfileRepository.saveProfileEvent`.
/// The current profile is intentionally NOT stored — the re-drive re-reads the
/// freshest cached profile and re-seeds from relays at drive time so unknown
/// kind-0 fields are preserved.
class PendingProfileSave {
  /// Creates a save payload from the user's raw edit intent.
  const PendingProfileSave({
    required this.pubkey,
    required this.displayName,
    this.about,
    this.website,
    this.username,
    this.nip05,
    this.clearNip05 = false,
    this.picture,
    this.banner,
    this.monetizationLinks,
    this.allowVideoReuse,
  });

  /// Reconstructs a payload from its [toJson] map.
  factory PendingProfileSave.fromJson(Map<String, dynamic> json) {
    final links = json['monetizationLinks'] as List<dynamic>?;
    return PendingProfileSave(
      pubkey: json['pubkey'] as String,
      displayName: json['displayName'] as String,
      about: json['about'] as String?,
      website: json['website'] as String?,
      username: json['username'] as String?,
      nip05: json['nip05'] as String?,
      clearNip05: json['clearNip05'] as bool? ?? false,
      picture: json['picture'] as String?,
      banner: json['banner'] as String?,
      monetizationLinks: links
          ?.map((e) => MonetizationLink.fromJson(e as Map<String, dynamic>))
          .toList(),
      allowVideoReuse: json['allowVideoReuse'] as bool?,
    );
  }

  /// Decodes a payload from the JSON string stored in the slot's
  /// `payload_json` column.
  factory PendingProfileSave.decode(String encoded) =>
      PendingProfileSave.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

  /// Hex pubkey of the account whose profile is being saved.
  final String pubkey;

  /// The kind-0 `display_name`.
  final String displayName;

  /// The kind-0 `about` (bio), or null to clear it.
  final String? about;

  /// The kind-0 `website`, or null to clear it.
  final String? website;

  /// The divine.video username to claim, or null when none is requested.
  final String? username;

  /// An external NIP-05 identifier (takes precedence over [username]).
  final String? nip05;

  /// Whether to explicitly remove the existing NIP-05 from the profile.
  final bool clearNip05;

  /// The kind-0 `picture` URL, or null to clear it.
  final String? picture;

  /// The kind-0 `banner` (URL or hex color), or null to clear it.
  final String? banner;

  /// Enabled monetization links to encode into the profile, or null to leave
  /// them untouched.
  final List<MonetizationLink>? monetizationLinks;

  /// Whether others may use this account's videos as clips, or null to leave
  /// the profile's current answer untouched.
  final bool? allowVideoReuse;

  /// Whether this save requests a divine.video username that must be claimed
  /// on the name server before the kind-0 publish.
  bool get requiresClaim => username != null && username!.trim().isNotEmpty;

  /// Serializes the payload to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    'pubkey': pubkey,
    'displayName': displayName,
    if (about != null) 'about': about,
    if (website != null) 'website': website,
    if (username != null) 'username': username,
    if (nip05 != null) 'nip05': nip05,
    'clearNip05': clearNip05,
    if (picture != null) 'picture': picture,
    if (banner != null) 'banner': banner,
    if (monetizationLinks != null)
      'monetizationLinks': monetizationLinks!
          .map((link) => link.toJson())
          .toList(),
    if (allowVideoReuse != null) 'allowVideoReuse': allowVideoReuse,
  };

  /// Encodes the payload to the JSON string stored in the slot.
  String encode() => jsonEncode(toJson());
}

/// Outcome of a single `ProfileRepository.drivePendingSave` attempt.
///
/// The retry service maps this onto its slot bookkeeping: [confirmed] means
/// the slot was already cleared; [retryableFailure] means increment-and-retry;
/// [permanentFailure] means mark-failed and stop; [noPendingSave] is a no-op.
enum PendingSaveDriveOutcome {
  /// A relay confirmed the kind-0 (NIP-20 OK). The slot has been cleared and
  /// the profile cached locally.
  confirmed,

  /// The publish did not land (no relays connected, relay rejected, or a
  /// transient claim network error). Safe to retry later — the slot is kept.
  retryableFailure,

  /// The divine.video username claim failed terminally (taken / reserved), so
  /// re-driving cannot succeed. The slot should be marked failed and abandoned.
  permanentFailure,

  /// No pending save exists for the pubkey.
  noPendingSave,
}
