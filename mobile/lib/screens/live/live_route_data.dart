import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';

class LiveRoomDetailRouteData {
  const LiveRoomDetailRouteData({
    required this.room,
    this.session,
  });

  final LiveRoom room;
  final LiveSession? session;
}

class LiveRoomRouteData {
  const LiveRoomRouteData({
    required this.room,
    this.session,
  });

  final LiveRoom room;
  final LiveSession? session;
}
