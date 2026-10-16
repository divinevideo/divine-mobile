// ABOUTME: Asserts feed presentation without losing intermediate UI changes.
// ABOUTME: Keeps operation ordering snapshots separate from rendered transitions.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';

// These scenarios assert the exact presentation transitions. Operation-only
// snapshots are tested separately and must not hide any presentation changes.
void feedBlocTest(
  String description, {
  required VideoFeedBloc Function() build,
  FutureOr<void> Function()? setUp,
  VideoFeedBlocState Function()? seed,
  dynamic Function(VideoFeedBloc)? act,
  Duration? wait,
  int skip = 0,
  dynamic Function()? expect,
  dynamic Function()? errors,
  dynamic Function(VideoFeedBloc)? verify,
}) {
  var initial = const VideoFeedBlocState();
  blocTest<VideoFeedBloc, VideoFeedBlocState>(
    description,
    build: () {
      final bloc = build();
      initial = bloc.state;
      return bloc;
    },
    setUp: setUp,
    seed: seed == null ? null : () => initial = seed(),
    act: act,
    wait: wait,
    expect: expect == null
        ? null
        : () => _FeedPresentationMatcher(expect(), skip, initial),
    errors: errors,
    verify: verify,
  );
}

class _FeedPresentationMatcher extends Matcher {
  _FeedPresentationMatcher(dynamic expected, this.skip, this.initial)
    : expected = equals(expected);
  final Matcher expected;
  final int skip;
  final VideoFeedBlocState initial;

  List<VideoFeedBlocState> project(dynamic actual) {
    final presentation = <VideoFeedBlocState>[];
    var previous = initial;
    for (final state in actual as Iterable<VideoFeedBlocState>) {
      final next = state.copyWith(coordination: const VideoFeedCoordination());
      final operationOnly =
          next ==
              previous.copyWith(coordination: const VideoFeedCoordination()) &&
          state.coordination != previous.coordination;
      previous = state;
      if (operationOnly) continue;
      if (presentation.isEmpty || presentation.last != next) {
        presentation.add(next);
      }
    }
    return presentation.skip(skip).toList();
  }

  @override
  bool matches(dynamic actual, Map matchState) =>
      expected.matches(project(actual), matchState);

  @override
  Description describe(Description description) =>
      expected.describe(description);

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) => expected.describeMismatch(
    project(item),
    mismatchDescription,
    matchState,
    verbose,
  );
}
