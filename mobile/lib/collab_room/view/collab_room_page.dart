// ABOUTME: A collaborative room's screen: the layout with everyone's cell,
// ABOUTME: who is in, and the next step for the host or a member

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/collab_room/bloc/collab_room_cubit.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/collab_room/view/collab_room_view.dart';
import 'package:openvine/router/route_paths.dart';

/// Wires a [CollabRoomCubit] for [roomId] and shows the room.
class CollabRoomPage extends ConsumerWidget {
  /// Creates the room page.
  const CollabRoomPage({required this.roomId, super.key});

  /// Route name for this screen.
  static const String routeName = 'collab-room';

  /// Path pattern for this route.
  static const String path = RoutePaths.collabRoom;

  /// The room to show.
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(collabRoomServiceProvider);
    return BlocProvider(
      key: ValueKey((service, roomId)),
      create: (_) => CollabRoomCubit(service: service, roomId: roomId),
      child: const CollabRoomView(),
    );
  }
}
