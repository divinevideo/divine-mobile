// ABOUTME: The limits on video DM downloads nobody tapped for: how many may
// ABOUTME: start a session, and when one may start again after a failure.

import 'dart:io';

import 'package:openvine/services/dm_video_files.dart';
import 'package:unified_logger/unified_logger.dart';

/// What the video DM store remembers of the downloads it makes by itself, so
/// a card fetches a video by itself neither too often nor too soon after a
/// failure, nor, until its mark ages out, once one failed in a way that would
/// repeat. Each try tells the sender's media server that the thread is open.
class DmVideoAutoDownloadLimits {
  /// Creates the limits of one store: at most [maxTries] downloads start for
  /// a message a session, and one that may pass waits [retryAfter].
  /// [ownerRemoved] says whether the account was removed from the device.
  DmVideoAutoDownloadLimits({
    required int maxTries,
    required Duration retryAfter,
    required DateTime Function() now,
    required bool Function() ownerRemoved,
  }) : _maxTries = maxTries,
       _retryAfter = retryAfter,
       _now = now,
       _ownerRemoved = ownerRemoved;

  /// Left for a message whose download failed in a way that would repeat, so
  /// no later session fetches it by itself either. Empty; it goes with its
  /// message, or once past the store's age limit, and is never trimmed.
  static const String _suffix = '.failed';

  // The marks are the store's files, so they log under its name.
  static const String _logName = 'DmVideoStore';

  /// Whether [file] marks a download that failed in a way that would repeat.
  static bool isFailureMark(File file) => file.path.endsWith(_suffix);

  final int _maxTries;
  final Duration _retryAfter;
  final DateTime Function() _now;
  final bool Function() _ownerRemoved;

  /// Downloads that failed, by message id, with when one may start again by
  /// itself, or null when none may this session.
  final Map<String, DateTime?> _failures = {};

  /// How many downloads started this session, by message id. A withdrawn
  /// request still reached the sender's server and counts too.
  final Map<String, int> _attempts = {};

  /// Counts a download of [messageId]'s video that starts.
  void started(String messageId) =>
      _attempts.update(messageId, (count) => count + 1, ifAbsent: () => 1);

  /// Whether a download of [messageId]'s video, kept in [dir], may start by
  /// itself now.
  bool mayStart(Directory dir, String messageId) {
    if ((_attempts[messageId] ?? 0) >= _maxTries) return false;
    if (!_failures.containsKey(messageId)) {
      if (!_markOf(dir, messageId).existsSync()) return true;
      // An earlier session's download failed in a way that would repeat.
      _failures[messageId] = null;
      return false;
    }
    final retryAt = _failures[messageId];
    return retryAt != null && !_now().isBefore(retryAt);
  }

  /// Remembers that a download of [messageId]'s video failed. One that would
  /// fail again does not start by itself this session, nor, through a mark in
  /// [dir], a later one; one that [mayPass] waits before it starts again, if
  /// a card still [wanted] it.
  Future<void> failed(
    Directory dir,
    String messageId, {
    required bool mayPass,
    required bool wanted,
  }) async {
    if (!mayPass) {
      // It would fail again, for whichever card asks next, in this session
      // or a later one.
      _failures[messageId] = null;
      await _rememberLastingFailure(dir, messageId);
    } else if (wanted) {
      _failures[messageId] = _now().add(_retryAfter);
    }
  }

  static File _markOf(Directory dir, String messageId) =>
      File('${dir.path}/${dmVideoSafeName(messageId)}$_suffix');

  Future<void> _rememberLastingFailure(Directory dir, String messageId) async {
    // Writing it would bring a removed account's folder back.
    if (_ownerRemoved()) return;
    final mark = _markOf(dir, messageId);
    try {
      await mark.create(recursive: true);
      // Removed while it was written: keep nothing for that account.
      if (_ownerRemoved() && mark.existsSync()) await mark.delete();
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not remember a failed video DM download: '
        '${dmVideoFileErrorCause(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }
}
