// ABOUTME: Stream form of VideoEventService's update callbacks, so a repository
// ABOUTME: can hand republished videos to feeds the service does not hold.

import 'dart:async';

import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/services/video_event_service.dart';

/// Each video [service] reports updated, as a broadcast stream. The callback
/// is registered while the stream has a listener and removed when the last
/// one cancels.
Stream<VideoEvent> videoUpdatesOf(VideoEventService service) {
  void Function()? unregister;
  late final StreamController<VideoEvent> controller;
  controller = StreamController<VideoEvent>.broadcast(
    onListen: () => unregister = service.addVideoUpdateListener(controller.add),
    onCancel: () {
      unregister?.call();
      unregister = null;
    },
  );
  return controller.stream;
}
