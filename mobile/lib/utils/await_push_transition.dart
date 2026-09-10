// ABOUTME: Awaits the current route's push transition so heavy resources (the
// ABOUTME: camera, a video decoder) are released only after the cover animation.

import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Waits for the current route's push transition to finish before returning.
///
/// Releasing a heavy resource (camera, video decoder) while the pushed route is
/// still animating in would reveal the placeholder behind it; this defers until
/// the route's [ModalRoute.secondaryAnimation] reaches
/// [AnimationStatus.completed]. Returns immediately only when a screen already
/// fully covers the current route (its secondary animation is already
/// `completed`).
///
/// Intended to be called right after a `push`, where the secondary animation is
/// mid-transition. A route that never becomes covered — no push, or the push is
/// dismissed again — leaves the animation `dismissed`, so the wait resolves only
/// via [timeout]. Pass [timeout] to bound the wait; on timeout the listener is
/// detached and the future resolves. With no [timeout] the wait resolves only
/// once the transition genuinely completes.
Future<void> awaitPushTransition(
  BuildContext context, {
  Duration? timeout,
}) async {
  await WidgetsBinding.instance.endOfFrame;

  if (!context.mounted) return;

  final route = ModalRoute.of(context);
  if (route == null) return;

  final secondary = route.secondaryAnimation;
  if (secondary == null || secondary.status == AnimationStatus.completed) {
    return;
  }

  final completer = Completer<void>();
  void onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !completer.isCompleted) {
      secondary.removeStatusListener(onStatus);
      completer.complete();
    }
  }

  secondary.addStatusListener(onStatus);
  await (timeout == null
      ? completer.future
      : completer.future.timeout(
          timeout,
          onTimeout: () => secondary.removeStatusListener(onStatus),
        ));
}
