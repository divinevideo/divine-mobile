import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/widgets.dart';

/// Decoder boundary for consent widget tests; failures remain observable.
class FakeConsentPreviewController extends DivineVideoPlayerController {
  FakeConsentPreviewController({this.failPlayback = false});

  final bool failPlayback;

  @override
  Future<bool> get firstFrameRendered => Future.value(!failPlayback);

  @override
  bool get usesLinuxBackend => true;

  @override
  Widget buildLinuxView() => const SizedBox.expand();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setSource(VideoClip clip) async {
    if (failPlayback) throw StateError('Synthetic decoder failure');
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> dispose() async {}
}
