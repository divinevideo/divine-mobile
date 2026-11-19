// ABOUTME: Riverpod wiring for collaborative rooms: the service, and the room a
// ABOUTME: part is filmed or a post is made for while the camera flow runs

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/collab_room/collab_room_service.dart';
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/utils/path_resolver.dart';

/// The signed-in account's collaborative rooms.
final collabRoomServiceProvider = Provider<CollabRoomService>((ref) {
  return CollabRoomService(
    dmRepository: ref.watch(dmRepositoryProvider),
    videoSendService: ref.watch(dmVideoSendServiceProvider),
    decryptPart: CollabRoomService.decryptWith(
      ref.watch(dmVideoDecryptorProvider),
    ),
    l10n: currentAppL10n(ref.watch(sharedPreferencesProvider)),
    storageDirectory: () async => Directory(await getDocumentsPath()),
  );
});

/// The room part the camera flow is filming, while it runs.
class CollabRoomPartContext {
  /// Creates a part context.
  const CollabRoomPartContext({
    required this.roomId,
    required this.cellAspectRatio,
    this.cellShape = SplitScreenCellShape.rectangle,
  });

  /// The room the part belongs to.
  final String roomId;

  /// Width / height of the person's layout cell: the recorder and the editor
  /// show what of the frame the cell keeps.
  final double cellAspectRatio;

  /// The shape of that cell, such as the circle of a round window.
  final SplitScreenCellShape cellShape;
}

/// The room part the recorder and editor are filming and editing.
///
/// Set by the room before it opens the recorder, read by the recorder for the
/// cell's crop and by the editor to hand the finished part back to the room
/// instead of opening the post screen. Cleared once the part is sent or the
/// flow is abandoned.
final collabRoomPartProvider =
    NotifierProvider<CollabRoomPartNotifier, CollabRoomPartContext?>(
      CollabRoomPartNotifier.new,
    );

/// Holds the [CollabRoomPartContext] of the running camera flow.
class CollabRoomPartNotifier extends Notifier<CollabRoomPartContext?> {
  @override
  CollabRoomPartContext? build() => null;

  /// Starts filming a part.
  void set(CollabRoomPartContext context) => state = context;

  /// Ends the part flow.
  void clear() => state = null;
}

/// The room whose video the post being prepared is, so publishing it can
/// tell the room it was posted.
final collabRoomPostProvider =
    NotifierProvider<CollabRoomPostNotifier, String?>(
      CollabRoomPostNotifier.new,
    );

/// Holds the id of the room the post being prepared belongs to.
class CollabRoomPostNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Marks the post being prepared as [roomId]'s video.
  void set(String roomId) => state = roomId;

  /// Ends the room post flow.
  void clear() => state = null;
}
