import 'dart:typed_data';

import 'package:post_live_activity_repository/src/models/models.dart';

/// The native side of the Live Activity.
abstract interface class LiveActivityPlatform {
  /// Whether the user has Live Activities enabled.
  Future<bool> isEnabled();

  /// Events the platform raises about activities.
  Stream<LiveActivityPlatformEvent> get events;

  /// Writes the thumbnail the activity shows and returns its file name.
  Future<String> writeThumbnail(Uint8List bytes);

  /// Starts an activity for [ownerPubkey] and returns its id.
  Future<String> start({
    required String ownerPubkey,
    required bool showFirstRunNote,
    String? thumbnailFileName,
  });

  /// Moves the activity [id] to [phase].
  Future<void> update(
    String id, {
    required LiveActivityPhase phase,
    required bool showFirstRunNote,
    String? postCoordinate,
    String? postEventId,
  });

  /// Ends the activity [id], removing it at once when [immediate].
  Future<void> end(String id, {required bool immediate});

  /// The activities currently running.
  Future<List<RunningLiveActivity>> list();
}
