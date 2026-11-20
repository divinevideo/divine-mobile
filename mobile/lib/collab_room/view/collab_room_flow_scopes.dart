// ABOUTME: Ends a room's part and post flows when their routes are gone, also
// ABOUTME: when a go() replaced the stack instead of popping back to the room

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';

/// Ends [part]'s flow once the route of the recorder filming it is gone,
/// however it went.
///
/// The room awaits a pop, which a `go()` — a notification tap, say — never
/// sends, and a part flow left open would turn the next ordinary video's
/// Done into handing a part in.
class CollabRoomPartFlowScope extends ConsumerStatefulWidget {
  /// Wraps [child], the recorder filming [part].
  const CollabRoomPartFlowScope({
    required this.part,
    required this.child,
    super.key,
  });

  /// The part being filmed.
  final CollabRoomPartContext part;

  /// The recorder.
  final Widget child;

  @override
  ConsumerState<CollabRoomPartFlowScope> createState() =>
      _CollabRoomPartFlowScopeState();
}

class _CollabRoomPartFlowScopeState
    extends ConsumerState<CollabRoomPartFlowScope> {
  late final CollabRoomPartNotifier _parts;
  late final CollabRoomPartContext _part;

  @override
  void initState() {
    super.initState();
    _parts = ref.read(collabRoomPartProvider.notifier);
    _part = widget.part;
  }

  @override
  void dispose() {
    // Providers cannot change while the widget tree is torn down.
    scheduleMicrotask(() => _parts.finish(expected: _part));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Ends [roomId]'s post flow once the room's route is gone, however it went.
///
/// The post flow awaits a pop, which a `go()` never sends, and a post flow
/// left open would tie the next video to this room.
class CollabRoomPostFlowScope extends ConsumerStatefulWidget {
  /// Wraps [child], the screen of the room [roomId].
  const CollabRoomPostFlowScope({
    required this.roomId,
    required this.child,
    super.key,
  });

  /// The room.
  final String roomId;

  /// The room's screen.
  final Widget child;

  @override
  ConsumerState<CollabRoomPostFlowScope> createState() =>
      _CollabRoomPostFlowScopeState();
}

class _CollabRoomPostFlowScopeState
    extends ConsumerState<CollabRoomPostFlowScope> {
  late final CollabRoomPostNotifier _posts;

  @override
  void initState() {
    super.initState();
    _posts = ref.read(collabRoomPostProvider.notifier);
  }

  @override
  void dispose() {
    final roomId = widget.roomId;
    // Providers cannot change while the widget tree is torn down.
    scheduleMicrotask(() => _posts.clearIfRoom(roomId));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
