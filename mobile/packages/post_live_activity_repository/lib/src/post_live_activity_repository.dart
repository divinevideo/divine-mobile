import 'dart:async';
import 'dart:typed_data';

import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:post_live_activity_repository/src/live_activity_platform.dart';
import 'package:post_live_activity_repository/src/live_activity_registrar.dart';
import 'package:post_live_activity_repository/src/models/models.dart';
import 'package:post_live_activity_repository/src/post_live_activity_prefs_keys.dart';
import 'package:post_live_activity_repository/src/post_live_activity_reportable_sites.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'PostLiveActivityRepository';

/// Decides when the post Live Activity starts, registers and ends.
///
/// One post activity runs per device. The activity starts at the Post tap,
/// goes live when the publish succeeds, and is registered with the push
/// service so it can show the post's stats for an hour.
///
/// The server is told an activity ended only while its owner is signed in
/// and the app is running: on [end], [stopForPost], [endAll], a newer post,
/// and a Lock Screen dismissal seen by the app. Sign-out, account switch and
/// [sweep] end activities on the device only.
///
/// No method throws: platform and registrar failures are logged, and a
/// rejected registration is reported to the error reporter.
class PostLiveActivityRepository {
  /// Creates a [PostLiveActivityRepository] and starts listening to
  /// [platform]'s events.
  PostLiveActivityRepository({
    required LiveActivityPlatform platform,
    required LiveActivityRegistrar registrar,
    required SharedPreferences sharedPreferences,
    DateTime Function()? now,
    PostLiveActivityErrorReporter? errorReporter,
  }) : _platform = platform,
       _registrar = registrar,
       _prefs = sharedPreferences,
       _now = now ?? DateTime.now,
       _report = errorReporter {
    _events = platform.events.listen(_onEvent);
  }

  static const _retryBackoff = [
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 120),
  ];
  static const _steadyRetry = Duration(seconds: 300);
  static const _summaryPeriod = Duration(minutes: 30);
  static const _unidentifiedTimeout = Duration(minutes: 15);

  final LiveActivityPlatform _platform;
  final LiveActivityRegistrar _registrar;
  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final PostLiveActivityErrorReporter? _report;
  late final StreamSubscription<LiveActivityPlatformEvent> _events;
  final _systemEnabled = StreamController<bool>.broadcast();

  final _pending = <String, _PendingStart>{};
  final _byKey = <String, _Tracked>{};
  final _byId = <String, _Tracked>{};
  final _bufferedTokens = <String, String>{};
  final _endedIds = <String>{};
  Future<void> _queue = Future.value();
  bool _disposed = false;

  /// Whether the feature flag allows the activity. When false nothing
  /// starts, and [sweep] ends the current owner's activity instead of
  /// re-adopting it.
  bool featureEnabled = true;

  /// Whether the in-app toggle is on. On by default.
  bool get isToggleOn =>
      _prefs.getBool(PostLiveActivityPrefsKeys.enabled) ?? true;

  /// Turns the in-app toggle on or off.
  ///
  /// Turning it off ends every running activity, as [endAll] does. Turning
  /// it on starts nothing: the next post starts the next activity.
  // The interface the settings screen calls; a named flag would read worse.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setToggleOn(bool on) async {
    // endAll cancels pending starts before its first await, so a start in
    // flight cannot be tracked while the preference is written.
    final ending = on ? null : endAll();
    await _prefs.setBool(PostLiveActivityPrefsKeys.enabled, on);
    await ending;
  }

  /// Whether the system switch allows Live Activities. An error reads as
  /// off.
  Future<bool> isSystemEnabled() async {
    try {
      return await _platform.isEnabled();
    } on Object catch (error, stack) {
      Log.warning(
        'Could not read the Live Activities switch',
        name: _logName,
        error: error,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// The system switch's changes.
  Stream<bool> get systemEnabledChanges => _systemEnabled.stream;

  /// Starts the activity for the post drafted under [key].
  ///
  /// Synchronous: the start is recorded under [key] before anything is
  /// awaited, so a [markLive] or [end] that follows at once waits for it.
  /// A newer post supersedes every earlier one. Nothing network-bound runs
  /// before the platform start; ended registrations for the activities it
  /// replaces are sent detached.
  void startPosting({
    required String key,
    required String ownerPubkey,
    required Future<Uint8List?> thumbnail,
  }) {
    if (_disposed || !featureEnabled || !isToggleOn) {
      thumbnail.ignore();
      return;
    }
    _cancelPending((_) => true);
    _byKey.clear();
    final pending = _PendingStart(ownerPubkey);
    _pending[key] = pending;
    unawaited(_runStart(key, pending, thumbnail));
  }

  /// Moves the activity for [key] to live once the publish succeeded, and
  /// registers it as soon as it has a push token.
  ///
  /// Waits for a start still in flight for [key]. Does nothing for a key
  /// that never started, was superseded, or has ended.
  Future<void> markLive({
    required String key,
    required String postCoordinate,
    required String postEventId,
  }) async {
    final tracked = await _trackedForKey(key);
    if (tracked == null || tracked.dropped) return;
    tracked
      ..postCoordinate = postCoordinate
      ..postEventIds = [postEventId]
      ..postedAt = _now();
    await _update(tracked, postCoordinate, postEventId);
    _register(tracked);
  }

  /// Ends the activity for [key] because the publish failed or is still
  /// scheduled, telling the server if it had registered.
  ///
  /// Waits for a start still in flight for [key].
  Future<void> end({required String key}) async {
    final tracked = await _trackedForKey(key);
    if (tracked == null || tracked.dropped) return;
    await _endActivity(tracked.activityId, tellServer: true);
  }

  /// Ends the activity for the post at [postCoordinate], telling the server
  /// if it had registered.
  Future<void> stopForPost(String postCoordinate) async {
    final tracked = _trackedForCoordinate(postCoordinate);
    if (tracked != null) {
      await _endActivity(tracked.activityId, tellServer: true);
      return;
    }
    for (final activity in await _list() ?? const <RunningLiveActivity>[]) {
      if (activity.postCoordinate == postCoordinate) {
        await _endActivity(activity.id, tellServer: true);
      }
    }
  }

  /// Whether an activity for the post at [postCoordinate] is running.
  ///
  /// Falls back to the platform's list when the activity is not tracked
  /// yet, such as on a cold start before [sweep], or past its window, when
  /// state events are ignored and the server's summary end is not seen.
  /// False when that fails.
  Future<bool> isRunningFor(String postCoordinate) async {
    final windowEnd = _trackedForCoordinate(postCoordinate)?.windowEndsAt;
    if (windowEnd != null && _now().isBefore(windowEnd)) return true;
    final listed = await _list() ?? const <RunningLiveActivity>[];
    return listed.any(
      (activity) =>
          activity.postCoordinate == postCoordinate &&
          (activity.state == LiveActivityState.active ||
              activity.state == LiveActivityState.stale),
    );
  }

  /// When the post at [postCoordinate] was published, as its activity
  /// knows it.
  ///
  /// Falls back to the listed activity's `startedAt` when it is not
  /// tracked. Null when no activity matches or the list fails.
  Future<DateTime?> postedAtFor(String postCoordinate) async {
    final tracked = _trackedForCoordinate(postCoordinate);
    if (tracked != null) return tracked.postedAt;
    final listed = await _list() ?? const <RunningLiveActivity>[];
    for (final activity in listed) {
      if (activity.postCoordinate == postCoordinate) return activity.startedAt;
    }
    return null;
  }

  /// Re-registers the post at [postCoordinate] with [newEventId] appended
  /// after an edit.
  Future<void> noteEdited({
    required String postCoordinate,
    required String newEventId,
  }) async {
    final tracked = _trackedForCoordinate(postCoordinate);
    if (tracked == null || tracked.postEventIds.contains(newEventId)) return;
    tracked.postEventIds = [...tracked.postEventIds, newEventId];
    _register(tracked);
  }

  /// Ends every running activity and tells the server about each one that
  /// registered. Used when the toggle is turned off.
  Future<void> endAll() async {
    _cancelPending((_) => true);
    final tracked = _byId.values.toList();
    for (final t in tracked) {
      _drop(t, tellServer: true);
    }
    final listed = await _list() ?? const <RunningLiveActivity>[];
    final ids = {
      for (final t in tracked) t.activityId,
      for (final a in listed) a.id,
    };
    for (final id in ids) {
      await _endActivity(id, tellServer: true);
    }
  }

  /// Ends [ownerPubkey]'s activities on the device only, for sign-out and
  /// account switch.
  ///
  /// Cancels that owner's pending starts, retries and tracking at once,
  /// then ends every listed activity of that owner, tracked or not. Never
  /// tells the server.
  Future<void> endLocally({required String ownerPubkey}) async {
    bool owned(String owner) => pubkeysEqual(owner, ownerPubkey);
    _cancelPending((pending) => owned(pending.ownerPubkey));
    final mine = _byId.values.where((t) => owned(t.ownerPubkey)).toList();
    for (final t in mine) {
      _drop(t, tellServer: false);
    }
    Log.info(
      'Ending Live Activities on the device for '
      '${pubkeyForLogs(ownerPubkey)}',
      name: _logName,
    );
    final listed = await _list() ?? const <RunningLiveActivity>[];
    final ids = {
      for (final t in mine) t.activityId,
      for (final a in listed)
        if (owned(a.ownerPubkey)) a.id,
    };
    for (final id in ids) {
      await _endActivity(id, tellServer: false);
    }
  }

  /// Reconciles the platform's activities with [currentOwnerPubkey], on
  /// every app foreground.
  ///
  /// Ends on the device another owner's activities, all of them when
  /// signed out (null), and any past `startedAt` + 90 minutes. Re-adopts
  /// the current owner's untracked live activity while the toggle and the
  /// feature allow it and its window has not passed, and ends it otherwise.
  /// Ends an untracked activity with no post identity that started over 15
  /// minutes ago. Never tells the server.
  Future<void> sweep({required String? currentOwnerPubkey}) async {
    if (_disposed) return;
    final listed = await _list();
    if (listed == null) return;
    final now = _now();
    for (final activity in listed) {
      final current =
          currentOwnerPubkey != null &&
          pubkeysEqual(activity.ownerPubkey, currentOwnerPubkey);
      final windowEnd = activity.startedAt.add(LiveActivityRegistration.window);
      if (!current || !now.isBefore(windowEnd.add(_summaryPeriod))) {
        await _endActivity(activity.id, tellServer: false);
      } else if (!_byId.containsKey(activity.id) &&
          !_endedIds.contains(activity.id)) {
        await _sweepUntracked(activity, now: now, windowEnd: windowEnd);
      }
    }
  }

  /// Stops listening, cancels every timer and pending start, and forgets
  /// all tracking. Running activities stay on the device.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelPending((_) => true);
    for (final t in _byId.values) {
      t
        ..dropped = true
        ..retryTimer?.cancel();
    }
    _byId.clear();
    _byKey.clear();
    _bufferedTokens.clear();
    await _events.cancel();
    await _systemEnabled.close();
  }

  Future<void> _runStart(
    String key,
    _PendingStart pending,
    Future<Uint8List?> thumbnail,
  ) async {
    final bytes = thumbnail.then<Uint8List?>(
      (value) => value,
      onError: (Object error, StackTrace stack) {
        Log.warning(
          'Live Activity thumbnail failed; starting without one',
          name: _logName,
          error: error,
          stackTrace: stack,
        );
        return null;
      },
    );
    try {
      if (!await isSystemEnabled() || pending.cancelled) return;
      await _endForNewPost();
      if (pending.cancelled) return;
      final fileName = await _writeThumbnail(await bytes);
      if (pending.cancelled) return;
      final showNote =
          !(_prefs.getBool(PostLiveActivityPrefsKeys.firstRunNoteShown) ??
              false);
      final id = await _serial(
        () => _platform.start(
          ownerPubkey: pending.ownerPubkey,
          showFirstRunNote: showNote,
          thumbnailFileName: fileName,
        ),
      );
      if (pending.cancelled) {
        Log.info(
          'Live Activity $id started after its post was replaced or '
          'cancelled; ending it',
          name: _logName,
        );
        await _endActivity(id, tellServer: false);
        return;
      }
      final tracked = _Tracked(
        key: key,
        ownerPubkey: pending.ownerPubkey,
        activityId: id,
        showFirstRunNote: showNote,
      )..token = _bufferedTokens.remove(id);
      _byKey[key] = tracked;
      _byId[id] = tracked;
      pending.finish(tracked);
      Log.info(
        'Started Live Activity $id for ${pubkeyForLogs(pending.ownerPubkey)}',
        name: _logName,
      );
      if (showNote) {
        await _prefs.setBool(PostLiveActivityPrefsKeys.firstRunNoteShown, true);
      }
    } on Object catch (error, stack) {
      Log.warning(
        'Live Activity start failed',
        name: _logName,
        error: error,
        stackTrace: stack,
      );
    } finally {
      if (identical(_pending[key], pending)) _pending.remove(key);
      pending.finish(null);
    }
  }

  /// Ends everything running before a new post's activity starts, sending
  /// ended registrations detached.
  Future<void> _endForNewPost() async {
    final tracked = _byId.values.toList();
    for (final t in tracked) {
      _drop(t, tellServer: true);
    }
    final listed = await _list() ?? const <RunningLiveActivity>[];
    final ids = {
      for (final t in tracked) t.activityId,
      for (final a in listed) a.id,
    };
    for (final id in ids) {
      await _endActivity(id, tellServer: true);
    }
  }

  Future<String?> _writeThumbnail(Uint8List? bytes) async {
    if (bytes == null) return null;
    try {
      return await _serial(() => _platform.writeThumbnail(bytes));
    } on Object catch (error, stack) {
      Log.warning(
        'Could not write the Live Activity thumbnail',
        name: _logName,
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }

  Future<void> _sweepUntracked(
    RunningLiveActivity activity, {
    required DateTime now,
    required DateTime windowEnd,
  }) async {
    final coordinate = activity.postCoordinate;
    final eventId = activity.postEventId;
    if (coordinate == null || eventId == null) {
      if (now.difference(activity.startedAt) > _unidentifiedTimeout) {
        await _endActivity(activity.id, tellServer: false);
      }
      return;
    }
    // An ended activity is showing its summary, and a dismissed one is
    // already leaving; both go on their own.
    if (activity.state == LiveActivityState.ended ||
        activity.state == LiveActivityState.dismissed) {
      return;
    }
    if (featureEnabled && isToggleOn && now.isBefore(windowEnd)) {
      _adopt(activity, coordinate, eventId);
    } else {
      await _endActivity(activity.id, tellServer: false);
    }
  }

  void _adopt(RunningLiveActivity activity, String coordinate, String eventId) {
    // postedAt is approximated by startedAt, which is earlier by the
    // upload time; the server's window ends correspondingly early.
    final tracked =
        _Tracked(
            key: null,
            ownerPubkey: activity.ownerPubkey,
            activityId: activity.id,
            showFirstRunNote: false,
          )
          ..postCoordinate = coordinate
          ..postEventIds = [eventId]
          ..postedAt = activity.startedAt
          ..token = _bufferedTokens.remove(activity.id);
    _byId[activity.id] = tracked;
    Log.info('Re-adopted Live Activity ${activity.id}', name: _logName);
    _register(tracked);
  }

  void _onEvent(LiveActivityPlatformEvent event) {
    switch (event) {
      case EnablementChanged(:final enabled):
        _systemEnabled.add(enabled);
      case PushTokenChanged(:final activityId, :final token):
        _onToken(activityId, token);
      case ActivityStateChanged(:final activityId, :final state):
        _onState(activityId, state);
    }
  }

  void _onToken(String activityId, String token) {
    final tracked = _byId[activityId];
    if (tracked == null) {
      if (!_endedIds.contains(activityId)) {
        _bufferedTokens[activityId] = token;
      }
      return;
    }
    // The platform replays the current token on listen and again through
    // its updates stream; only a changed token re-registers.
    if (tracked.token == token) return;
    tracked.token = token;
    _register(tracked);
  }

  void _onState(String activityId, LiveActivityState state) {
    final tracked = _byId[activityId];
    if (tracked == null) return;
    final windowEnd = tracked.windowEndsAt;
    if (windowEnd != null && !_now().isBefore(windowEnd)) return;
    switch (state) {
      case LiveActivityState.dismissed:
        Log.info('Live Activity $activityId dismissed', name: _logName);
        _drop(tracked, tellServer: true);
      case LiveActivityState.ended:
        // The server's own end produces this, so it already knows.
        _drop(tracked, tellServer: false);
      case LiveActivityState.active:
      case LiveActivityState.stale:
        break;
    }
  }

  Future<_Tracked?> _trackedForKey(String key) async {
    final pending = _pending[key];
    if (pending != null) return pending.future;
    return _byKey[key];
  }

  _Tracked? _trackedForCoordinate(String postCoordinate) {
    for (final tracked in _byId.values) {
      if (tracked.postCoordinate == postCoordinate) return tracked;
    }
    return null;
  }

  void _cancelPending(bool Function(_PendingStart pending) where) {
    _pending.removeWhere((_, pending) {
      if (!where(pending)) return false;
      pending
        ..cancelled = true
        ..finish(null);
      return true;
    });
  }

  /// Stops tracking [tracked] before anything ends it on the platform, so
  /// the platform's echo of the end finds nothing to act on.
  void _drop(_Tracked tracked, {required bool tellServer}) {
    if (tracked.dropped) return;
    tracked.dropped = true;
    tracked.retryTimer?.cancel();
    tracked.retryTimer = null;
    _byId.remove(tracked.activityId);
    if (identical(_byKey[tracked.key], tracked)) _byKey.remove(tracked.key);
    _bufferedTokens.remove(tracked.activityId);
    if (tellServer) unawaited(_sendEnded(tracked));
  }

  Future<void> _endActivity(String id, {required bool tellServer}) async {
    final tracked = _byId[id];
    if (tracked != null) _drop(tracked, tellServer: tellServer);
    _bufferedTokens.remove(id);
    _endedIds.add(id);
    try {
      await _serial(() => _platform.end(id, immediate: true));
    } on Object catch (error, stack) {
      Log.warning(
        'Could not end Live Activity $id',
        name: _logName,
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<void> _update(
    _Tracked tracked,
    String postCoordinate,
    String postEventId,
  ) async {
    try {
      await _serial(
        () => _platform.update(
          tracked.activityId,
          phase: LiveActivityPhase.live,
          showFirstRunNote: tracked.showFirstRunNote,
          postCoordinate: postCoordinate,
          postEventId: postEventId,
        ),
      );
    } on Object catch (error, stack) {
      Log.warning(
        'Could not move Live Activity ${tracked.activityId} to live',
        name: _logName,
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<List<RunningLiveActivity>?> _list() async {
    try {
      return await _serial(_platform.list);
    } on Object catch (error, stack) {
      Log.warning(
        'Could not list Live Activities',
        name: _logName,
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Runs [operation] after every platform operation queued before it.
  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Queues an active registration after any send already in flight for
  /// [tracked], so sends for one activity never overlap or reorder. Nothing
  /// is sent once the window has ended, which is also what stops retries.
  void _register(_Tracked tracked, {bool isRetry = false}) {
    if (tracked.dropped || tracked.registration() == null) return;
    if (!_now().isBefore(tracked.windowEndsAt!)) return;
    final previous = tracked.inFlight ?? Future<void>.value();
    tracked.inFlight = previous.then((_) => _sendActive(tracked, isRetry));
  }

  Future<void> _sendActive(_Tracked tracked, bool isRetry) async {
    if (tracked.dropped) return;
    tracked.retryTimer?.cancel();
    tracked.retryTimer = null;
    if (!isRetry) tracked.retryAttempt = 0;
    final registration = tracked.registration()!;
    final result = await _send(registration);
    if (result == LiveActivityRegistrarResult.published ||
        result == LiveActivityRegistrarResult.uncertain) {
      // The relay may have stored it, so ending it must tell the server.
      tracked.registered = true;
    }
    if (tracked.dropped) return;
    if (result == LiveActivityRegistrarResult.retryLater ||
        result == LiveActivityRegistrarResult.uncertain) {
      _scheduleRetry(tracked);
    }
  }

  void _scheduleRetry(_Tracked tracked) {
    final attempt = tracked.retryAttempt;
    final delay = attempt < _retryBackoff.length
        ? _retryBackoff[attempt]
        : _steadyRetry;
    tracked
      ..retryAttempt = attempt + 1
      ..retryTimer = Timer(delay, () {
        tracked.retryTimer = null;
        _register(tracked, isRetry: true);
      });
  }

  /// Sends the ended registration once any active send has settled. Its
  /// retry timer was cancelled when tracking was dropped.
  Future<void> _sendEnded(_Tracked tracked) async {
    await tracked.inFlight;
    if (!tracked.registered) return;
    final ended = tracked.registration()!.ended();
    final result = await _send(ended);
    if (result == LiveActivityRegistrarResult.retryLater ||
        result == LiveActivityRegistrarResult.uncertain) {
      Log.warning(
        'Ended registration for Live Activity ${tracked.activityId} was not '
        'confirmed; the server stops at the window end',
        name: _logName,
      );
    }
  }

  /// Sends [registration], reporting a rejection or a thrown error. Returns
  /// null when the registrar threw.
  Future<LiveActivityRegistrarResult?> _send(
    LiveActivityRegistration registration,
  ) async {
    try {
      final result = await _registrar.register(registration);
      if (result == LiveActivityRegistrarResult.failed) {
        _report?.call(
          _RegistrationFailed(registration.activityId, registration.state),
          StackTrace.current,
          site: PostLiveActivityReportableSites.register,
        );
      }
      return result;
    } on Object catch (error, stack) {
      _report?.call(
        error,
        stack,
        site: PostLiveActivityReportableSites.register,
      );
      return null;
    }
  }
}

/// A start recorded synchronously by `startPosting`, before it returns.
class _PendingStart {
  _PendingStart(this.ownerPubkey);

  final String ownerPubkey;
  final _completer = Completer<_Tracked?>();
  bool cancelled = false;

  Future<_Tracked?> get future => _completer.future;

  void finish(_Tracked? tracked) {
    if (!_completer.isCompleted) _completer.complete(tracked);
  }
}

/// What the repository knows about one activity it started or re-adopted.
class _Tracked {
  _Tracked({
    required this.key,
    required this.ownerPubkey,
    required this.activityId,
    required this.showFirstRunNote,
  });

  /// The draft key, or null for an activity re-adopted by the sweep.
  final String? key;
  final String ownerPubkey;
  final String activityId;
  final bool showFirstRunNote;
  String? token;
  String? postCoordinate;
  List<String> postEventIds = const [];
  DateTime? postedAt;
  bool registered = false;
  bool dropped = false;
  int retryAttempt = 0;
  Timer? retryTimer;
  Future<void>? inFlight;

  DateTime? get windowEndsAt => postedAt?.add(LiveActivityRegistration.window);

  /// The active registration, or null until the token and the post's
  /// identity are both known.
  LiveActivityRegistration? registration() {
    final token = this.token;
    final postCoordinate = this.postCoordinate;
    final postedAt = this.postedAt;
    if (token == null || postCoordinate == null || postedAt == null) {
      return null;
    }
    return LiveActivityRegistration.forPost(
      activityId: activityId,
      ownerPubkey: ownerPubkey,
      activityPushToken: token,
      postCoordinate: postCoordinate,
      postEventIds: postEventIds,
      postedAt: postedAt,
      showFirstRunNote: showFirstRunNote,
    );
  }
}

class _RegistrationFailed implements Exception {
  const _RegistrationFailed(this.activityId, this.state);

  final String activityId;
  final LiveActivityRegistrationState state;

  @override
  String toString() =>
      'Live Activity registration failed: $activityId (${state.name})';
}
