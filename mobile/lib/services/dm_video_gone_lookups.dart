// ABOUTME: Tells the video DM store which kept videos' messages are gone,
// ABOUTME: retracted by their sender or removed with their conversation.

import 'dart:io';

import 'package:models/models.dart';
import 'package:openvine/services/dm_video_conversation_records.dart';
import 'package:unified_logger/unified_logger.dart';

/// Whether the messages of one account's kept video DMs are gone: retracted
/// by their sender, or removed with their conversation. Answered by the
/// lookups the store was given; without them, nothing is gone.
class DmVideoGoneLookups {
  /// Creates the lookups of one store. [records] are the conversation
  /// records beside its kept videos, which [goneAmong] reads when a message's
  /// row is missing and refreshes when a repair moved the message.
  DmVideoGoneLookups({
    required DmVideoConversationRecords records,
    Future<bool> Function(String messageId)? isMessageGone,
    Future<bool> Function(String conversationId, int sentAt)?
    isConversationRemoved,
    Future<DmVideoMessageLocation?> Function(String messageId)?
    findMessageLocation,
  }) : _records = records,
       _isMessageGone = isMessageGone,
       _isConversationRemoved = isConversationRemoved,
       _findMessageLocation = findMessageLocation;

  // The lookups decide what the store deletes, so they log under its name.
  static const String _logName = 'DmVideoStore';

  final DmVideoConversationRecords _records;
  final Future<bool> Function(String messageId)? _isMessageGone;
  final Future<bool> Function(String conversationId, int sentAt)?
  _isConversationRemoved;
  final Future<DmVideoMessageLocation?> Function(String messageId)?
  _findMessageLocation;

  /// Messages found gone, which stay gone once the rows that said so are
  /// cleared, as an account switch clears them.
  final Set<String> _known = {};

  /// Whether [message], kept in [dir], was retracted or removed with its
  /// conversation: the one its row is in now, as a caller can hold a message
  /// from before a repair moved it, else the one its record names, else the
  /// caller's. Only a retraction or a row is remembered, since a record or a
  /// caller's copy can predate a repair. Throws what a lookup throws.
  Future<bool> isGone(DmMessage message, Directory dir) async {
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
    final said = await _recordedLocation(dir, message.id);
    return isRemoved(
      said?.conversationId ?? message.conversationId,
      said?.sentAt ?? message.createdAt,
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
          continue;
        }
        if (isRemoved == null) continue;
        final current = await _findMessageLocation?.call(id);
        if (current != null) {
          if (await isRemoved(current.conversationId, current.sentAt)) {
            gone.add(id);
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
      } on Object catch (error) {
        decided = false;
        Log.warning(
          'Could not tell whether a kept video DM message is gone: '
          '${error.runtimeType}',
          name: _logName,
          category: LogCategory.video,
        );
      }
    }
    _known.addAll(gone);
    return (gone: gone, decided: decided);
  }
}
