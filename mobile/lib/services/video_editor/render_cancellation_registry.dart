// ABOUTME: Tracks cancellation requests for video render task generations
// ABOUTME: Preserves user cancels issued before native render registration

import 'package:pro_video_editor/pro_video_editor.dart'
    show RenderCanceledException;

/// Registry of cancellation requests for app-owned video render tasks.
///
/// A render id can be reused across attempts and sessions, so each render mints
/// a generation token. Cancellation only applies to the generation that was
/// current when the user asked to cancel; starting a newer generation clears
/// stale requests without erasing a cancel that arrived just before native
/// registration.
class RenderCancellationRegistry {
  RenderCancellationRegistry._();

  static final Map<String, Object> _activeTokens = <String, Object>{};
  static final Map<String, Object> _cancelledTokens = <String, Object>{};

  /// Starts a new render generation for [id].
  static Object start(String id) {
    final token = Object();
    _activeTokens[id] = token;
    _cancelledTokens.remove(id);
    return token;
  }

  /// Starts a render generation only when [id] is not already active.
  static ({Object token, bool started}) startIfIdle(String id) {
    final activeToken = _activeTokens[id];
    if (activeToken != null) return (token: activeToken, started: false);
    return (token: start(id), started: true);
  }

  /// Marks the current generation for [id] as cancelled.
  static void cancel(String id) {
    final token = _activeTokens[id];
    if (token == null) return;
    _cancelledTokens[id] = token;
  }

  /// Whether cancellation is pending for [id]'s current generation.
  static bool isCancellationRequested(String id) {
    final token = _activeTokens[id];
    return token != null && identical(_cancelledTokens[id], token);
  }

  /// Consumes a pending cancellation for [id]'s current generation.
  static bool consumeCancellation(String id) {
    final token = _activeTokens[id];
    if (token == null || !identical(_cancelledTokens[id], token)) return false;
    _cancelledTokens.remove(id);
    return true;
  }

  /// Throws [RenderCanceledException] when a cancel is pending for [taskId]
  /// or for [ownerTaskId], consuming the request.
  ///
  /// Intermediate passes render under their own ids, so a user cancel — which
  /// targets the export's id — is invisible to them unless they also consult
  /// the owner.
  static void throwIfRequested(
    String taskId, [
    String? ownerTaskId,
  ]) {
    final cancelled = consumeCancellation(taskId);
    final ownerCancelled =
        ownerTaskId != null &&
        ownerTaskId != taskId &&
        consumeCancellation(ownerTaskId);
    if (cancelled || ownerCancelled) {
      throw const RenderCanceledException();
    }
  }

  /// Ends [id]'s render generation if [token] still owns it.
  static void finish(String id, Object token) {
    if (!identical(_activeTokens[id], token)) return;
    _activeTokens.remove(id);
    _cancelledTokens.remove(id);
  }

  /// Drops all tracking without cancelling anything.
  ///
  /// Test teardown only - production render generations should finish
  /// themselves so old cancellations do not leak into later renders.
  static void reset() {
    _activeTokens.clear();
    _cancelledTokens.clear();
  }
}
