// ABOUTME: Tells the video DM store which kept videos' messages are gone,
// ABOUTME: retracted by their sender or removed with their conversation.

import 'dart:async';
import 'dart:io';

import 'package:models/models.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/dm_video_conversation_records.dart';
import 'package:unified_logger/unified_logger.dart';

/// Thrown by [DmVideoGoneLookups.isGone] when a message's row is missing and
/// the record kept beside its video and the caller's copy of it disagree on
/// whether its conversation was removed: either can predate a repair.
class DmVideoGoneUndecided implements Exception {
  /// Creates a [DmVideoGoneUndecided].
  const DmVideoGoneUndecided();

  @override
  String toString() => 'DmVideoGoneUndecided';
}

/// Whether the messages of one account's kept video DMs are gone: retracted
/// by their sender, or removed with their conversation. Answered by the
/// lookups the store was given; without them, nothing is gone.
class DmVideoGoneLookups {
  /// Creates the lookups of one store. [records] are the conversation
  /// records beside its kept videos, which [goneAmong] reads when a message's
  /// row is missing and refreshes when a repair moved the message.
  /// [crashReporter] hears of a lookup that fails for a bug.
  DmVideoGoneLookups({
    required DmVideoConversationRecords records,
    CrashReporter crashReporter = const SilentCrashReporter(),
    Future<bool> Function(String messageId)? isMessageGone,
    Future<bool> Function(String conversationId, int sentAt)?
    isConversationRemoved,
    Future<DmVideoMessageLocation?> Function(String messageId)?
    findMessageLocation,
  }) : _records = records,
       _crashReporter = crashReporter,
       _isMessageGone = isMessageGone,
       _isConversationRemoved = isConversationRemoved,
       _findMessageLocation = findMessageLocation;

  // The lookups decide what the store deletes, so they log under its name.
  static const String _logName = 'DmVideoStore';

  final DmVideoConversationRecords _records;
  final CrashReporter _crashReporter;
  final Future<bool> Function(String messageId)? _isMessageGone;
  final Future<bool> Function(String conversationId, int sentAt)?
  _isConversationRemoved;
  final Future<DmVideoMessageLocation?> Function(String messageId)?
  _findMessageLocation;

  /// Messages a retraction or their row showed gone, which stay gone once
  /// the rows that said so are cleared, as an account switch clears them.
  /// What a record or a caller's copy says is not kept: either can predate a
  /// repair.
  final Set<String> _known = {};

  /// Whether [message], kept in [dir], was retracted or removed with its
  /// conversation: the one its row is in now, as a caller can hold a message
  /// from before a repair moved it. Without a row, the record kept beside
  /// its video and the caller's copy must agree, as either can predate a
  /// repair; when they do not, it throws [DmVideoGoneUndecided]. Only a
  /// retraction or a row is remembered. Throws what a lookup throws.
  Future<bool> isGone(DmMessage message, Directory dir) async {
    try {
      return await _isGone(message, dir);
    } on Object catch (error, stackTrace) {
      _reportIfBug(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> _isGone(DmMessage message, Directory dir) async {
    if (_known.contains(message.id)) return true;
    if (await _isMessageGone?.call(message.id) == true) {
      _known.add(message.id);
      return true;
    }
    final isRemoved = _isConversationRemoved;
    if (isRemoved == null) return false;
    final current = await _findMessageLocation?.call(message.id);
    if (current != null) {
      final gone = await isRemoved(current.conversationId, current.sentAt);
      if (gone) _known.add(message.id);
      return gone;
    }
    final byCopy = await isRemoved(message.conversationId, message.createdAt);
    final said = await _recordedLocation(dir, message.id);
    if (said == null ||
        said.conversationId == message.conversationId &&
            said.sentAt == message.createdAt) {
      return byCopy;
    }
    if (await isRemoved(said.conversationId, said.sentAt) != byCopy) {
      throw const DmVideoGoneUndecided();
    }
    return byCopy;
  }

  /// Reports [error] when it is a bug rather than a lookup that failed, as
  /// one would fail every time and keep a gone message's files.
  void _reportIfBug(Object error, StackTrace stackTrace) {
    final reportable = asReportableError(error, context: 'DmVideoGoneLookups');
    if (reportable == null) return;
    unawaited(
      _crashReporter.recordError(
        reportable,
        stackTrace,
        reason: 'Could not tell whether a kept video DM message is gone',
      ),
    );
  }

  Future<DmVideoMessageLocation?> _recordedLocation(
    Directory dir,
    String messageId,
  ) async {
    try {
      return await DmVideoConversationRecords.read(
        DmVideoConversationRecords.recordOf(dir, messageId),
      );
    } on PathNotFoundException {
      return null;
    }
  }

  /// The ids among [ids], of messages kept in [dir] or, as [inFlight] are,
  /// still being fetched into it, that are gone, with [records] their
  /// conversation records by message id, and whether every message was
  /// decided: a lookup that fails keeps its message's files. On the way, the
  /// record of a kept message a repair moved is rewritten; one being fetched
  /// writes its own when it lands.
  Future<({Set<String> gone, bool decided})> goneAmong(
    Set<String> ids,
    Directory dir,
    Map<String, File> records, {
    Set<String> inFlight = const {},
  }) async {
    final isGone = _isMessageGone;
    final isRemoved = _isConversationRemoved;
    if (isGone == null && isRemoved == null) {
      return (gone: const <String>{}, decided: true);
    }
    final gone = <String>{};
    var decided = true;
    for (final id in ids) {
      try {
        if (_known.contains(id) || isGone != null && await isGone(id)) {
          gone.add(id);
          _known.add(id);
          continue;
        }
        if (isRemoved == null) continue;
        final current = await _findMessageLocation?.call(id);
        if (current != null) {
          if (await isRemoved(current.conversationId, current.sentAt)) {
            gone.add(id);
            _known.add(id);
          } else if (!inFlight.contains(id)) {
            // A group repair may have moved this message since it was kept.
            await _records.refresh(
              records[id] ?? DmVideoConversationRecords.recordOf(dir, id),
              id,
              current,
            );
          }
          continue;
        }
        final record = records[id];
        if (record == null) continue;
        final said = await DmVideoConversationRecords.read(record);
        if (said != null && await isRemoved(said.conversationId, said.sentAt)) {
          gone.add(id);
        }
      } on PathNotFoundException {
        // Deleted since the listing, as the launch sweep deletes an expired
        // video's files: there is nothing left to decide.
      } on Object catch (error, stackTrace) {
        decided = false;
        Log.warning(
          'Could not tell whether a kept video DM message is gone: '
          '${error.runtimeType}',
          name: _logName,
          category: LogCategory.video,
          stackTrace: stackTrace,
        );
        _reportIfBug(error, stackTrace);
      }
    }
    return (gone: gone, decided: decided);
  }
}
