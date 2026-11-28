// ABOUTME: Reranks approved guest clips from playback observed on this device.
// ABOUTME: Keeps one outcome per clip for the lifetime of the active manifest.

import 'dart:math';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:openvine/features/guest_classics/guest_classics_manifest.dart';

enum _Outcome {
  skip,
  completed,
  repeat,
}

class GuestClassicsAdaptation {
  final _outcomes = <String, (List<String>, _Outcome)>{};
  double _maxProgress = 0;
  double? _previousProgress;
  bool _wrapped = false;
  bool _repeated = false;

  void observe(DivineVideoPlayerState state) {
    final duration = state.duration.inMilliseconds;
    if (!state.isPictureAdvancing || duration <= 0) {
      _previousProgress = null;
      return;
    }
    final progress = (state.shownPosition.inMilliseconds / duration).clamp(
      0.0,
      1.0,
    );
    if ((_previousProgress ?? 0) >= .8 && progress <= .2) {
      _wrapped = true;
    }
    _repeated |= _wrapped && progress >= .25;
    _maxProgress = max(_maxProgress, progress);
    _previousProgress = progress;
  }

  void leave(GuestClassic clip) {
    final outcome = switch ((_repeated, _wrapped, _maxProgress)) {
      (true, _, _) => _Outcome.repeat,
      (_, true, _) || (_, _, >= .9) => _Outcome.completed,
      (_, _, > 0 && < .25) when _previousProgress != null => _Outcome.skip,
      _ => null,
    };
    resetPlayback();
    if (outcome == null || clip.discoveryTags.isEmpty) return;
    final previous = _outcomes[clip.id]?.$2;
    if (previous == null || outcome.index > previous.index) {
      _outcomes[clip.id] = (clip.discoveryTags, outcome);
    }
  }

  void resetPlayback() {
    _maxProgress = 0;
    _previousProgress = null;
    _wrapped = false;
    _repeated = false;
  }

  List<GuestClassic> orderTail(
    List<GuestClassic> clips, {
    required List<GuestClassic> starterOrder,
    required int keep,
  }) {
    if (_outcomes.isEmpty || clips.length - keep < 2) return clips;

    final positive = <String, int>{};
    final support = <String, int>{};
    final skips = <String, int>{};
    for (final (tags, outcome) in _outcomes.values) {
      for (final tag in tags) {
        if (outcome == _Outcome.skip) {
          skips.update(tag, (count) => count + 1, ifAbsent: () => 1);
        } else {
          final weight = outcome == _Outcome.repeat ? 2 : 1;
          support.update(tag, (count) => count + 1, ifAbsent: () => 1);
          positive.update(tag, (sum) => sum + weight, ifAbsent: () => weight);
        }
      }
    }

    final originalRank = {
      for (final (i, clip) in starterOrder.indexed) clip.id: i,
    };
    final scored =
        [
          for (final clip in clips.skip(keep))
            (
              clip: clip,
              score: clip.discoveryTags.fold<int>(0, (score, tag) {
                final gain = (support[tag] ?? 0) >= 2 ? positive[tag]! : 0;
                return score + gain - (skips[tag] ?? 0);
              }),
            ),
        ]..sort((a, b) {
          final score = b.score.compareTo(a.score);
          return score == 0
              ? originalRank[a.clip.id]!.compareTo(originalRank[b.clip.id]!)
              : score;
        });
    return [...clips.take(keep), for (final item in scored) item.clip];
  }
}
