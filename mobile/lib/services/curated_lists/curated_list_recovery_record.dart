// ABOUTME: Minimal accepted permission and event-specific recovery evidence.
// ABOUTME: Tracks coordinate lifetimes without private list payloads.

import 'package:models/models.dart';

/// Minimal recovery data, never the name, description, item payload or keys.
class CuratedListRecoveryRecord {
  /// Creates a record belonging to the owner named by its storage bucket.
  const CuratedListRecoveryRecord({
    this.plaintextEventIds = const [],
    this.visibility,
    this.acceptedEventId,
    this.acceptedAt,
    this.requiresPrivateCommit = false,
    this.permissionEpoch = 0,
    this.permissionsRetired = false,
  });

  /// Event-specific deletion requests still awaiting at least one relay ACK.
  final List<String> plaintextEventIds;

  /// A relay-confirmed permission target awaiting the local final commit.
  final CuratedListVisibility? visibility;

  /// Identity and timestamp of the accepted replacement, when known.
  final String? acceptedEventId;
  final DateTime? acceptedAt;

  /// An unpublished private union must commit before deleting its public copy.
  final bool requiresPrivateCommit;

  /// Distinguishes accepted permissions across deletion and recreation.
  final int permissionEpoch;

  /// A deleted coordinate cannot reattach its old accepted permission target.
  final bool permissionsRetired;

  bool get isEmpty =>
      plaintextEventIds.isEmpty && visibility == null && !permissionsRetired;

  Map<String, dynamic> toJson() => {
    'plaintextEventIds': plaintextEventIds,
    if (visibility != null) 'visibility': visibility!.toJson(),
    if (acceptedEventId != null) 'acceptedEventId': acceptedEventId,
    if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
    if (requiresPrivateCommit) 'requiresPrivateCommit': true,
    if (permissionEpoch != 0) 'permissionEpoch': permissionEpoch,
    if (permissionsRetired) 'permissionsRetired': true,
  };

  factory CuratedListRecoveryRecord.fromJson(Map<String, dynamic> json) {
    final visibility = json['visibility'] == null
        ? null
        : CuratedListVisibility.fromJson(
            json['visibility'] as Map<String, dynamic>,
          );
    return CuratedListRecoveryRecord(
      plaintextEventIds: List<String>.from(
        json['plaintextEventIds'] as List? ?? const [],
      ),
      // Ambiguous legacy proposals never become a recovery permission target.
      visibility: visibility?.relayAccepted == true ? visibility : null,
      acceptedEventId: json['acceptedEventId'] as String?,
      permissionEpoch: json['permissionEpoch'] as int? ?? 0,
      permissionsRetired: json['permissionsRetired'] as bool? ?? false,
      requiresPrivateCommit: json['requiresPrivateCommit'] as bool? ?? false,
      acceptedAt: json['acceptedAt'] == null
          ? null
          : DateTime.parse(json['acceptedAt'] as String),
    );
  }
}
