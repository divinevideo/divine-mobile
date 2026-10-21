// ABOUTME: The record the video DM store keeps beside each kept video, naming
// ABOUTME: its conversation and send time, so a removal still finds the files.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:models/models.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/dm_video_files.dart';
import 'package:unified_logger/unified_logger.dart';

/// The conversation a message is in and when it was sent.
typedef DmVideoMessageLocation = ({String conversationId, int sentAt});

/// Writes bytes to a file so a reader never sees half of them, throwing a
/// [DmVideoUnavailableException] when it cannot.
typedef DmVideoAtomicWriter = Future<void> Function(File file, Uint8List bytes);

/// The records beside one account's kept video DMs: each names the
/// conversation its message came from and when it was sent, and stays for as
/// long as anything kept for the message does, so removing that conversation
/// deletes them even once the message row is gone.
class DmVideoConversationRecords {
  /// Creates the records of one store, written through [writeAtomically].
  DmVideoConversationRecords({required DmVideoAtomicWriter writeAtomically})
    : _writeAtomically = writeAtomically;

  static const String _suffix = '.conversation';

  // The records are the store's files, so they log under its name.
  static const String _logName = 'DmVideoStore';

  /// Whether [file] is a conversation record.
  static bool isRecord(File file) => file.path.endsWith(_suffix);

  /// The record of the message [messageId] in [dir].
  static File recordOf(Directory dir, String messageId) =>
      File('${dir.path}/${dmVideoSafeName(messageId)}$_suffix');

  /// The conversation and send time [record] names, or null when it does not
  /// hold both. Throws a [FileSystemException] when it cannot be read, a
  /// [PathNotFoundException] once it is gone.
  static Future<DmVideoMessageLocation?> read(File record) async {
    final lines = (await record.readAsString()).split('\n');
    final sentAt = lines.length == 2 ? int.tryParse(lines[1]) : null;
    return sentAt == null ? null : (conversationId: lines[0], sentAt: sentAt);
  }

  final DmVideoAtomicWriter _writeAtomically;

  /// What each message's record says, by message id, once these records
  /// wrote it or found it current.
  final Map<String, String> _current = {};

  /// Writes [message]'s record in [dir], unless these records know it
  /// already says the same or, without [force], find that it does: a repair
  /// can move a message to another conversation after its video was kept,
  /// and a removal must still find the video.
  ///
  /// Throws a [DmVideoUnavailableException] when the record cannot be
  /// written.
  Future<void> write(
    DmMessage message,
    Directory dir, {
    bool force = false,
  }) async {
    final content = _contentOf(message.conversationId, message.createdAt);
    final record = recordOf(dir, message.id);
    // What was written can still be deleted from outside the store: the
    // launch sweep, or the system clearing the cache folder.
    final known = _current[message.id] == content && record.existsSync();
    if (force || (!known && await _readQuietly(record) != content)) {
      await _writeAtomically(record, utf8.encode(content));
    }
    _current[message.id] = content;
  }

  /// [write], logging rather than throwing: a video or frame already kept is
  /// still handed out when its record cannot be written.
  Future<void> writeQuietly(DmMessage message, Directory dir) async {
    try {
      await write(message, dir);
    } on DmVideoUnavailableException catch (error) {
      Log.warning(
        "Could not record a kept video DM's conversation: ${error.message}",
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  /// Rewrites [record], of the message [messageId], to name [location] when
  /// it says otherwise: a group repair can move a message after its video
  /// was kept, and its record must say where it is before an account switch
  /// drops its row. Read from disk rather than trusted from memory, as
  /// another store of the same account can write it. One that cannot be
  /// written is logged and tried again by the next write or refresh.
  Future<void> refresh(
    File record,
    String messageId,
    DmVideoMessageLocation location,
  ) async {
    final content = _contentOf(location.conversationId, location.sentAt);
    if (await _readQuietly(record) != content) {
      try {
        await _writeAtomically(record, utf8.encode(content));
      } on DmVideoUnavailableException catch (error) {
        // The message is not gone; only its record is out of date.
        Log.warning(
          'Could not refresh a kept video DM conversation record: '
          '${error.message}',
          name: _logName,
          category: LogCategory.video,
        );
        return;
      }
    }
    _current[messageId] = content;
  }

  static Future<String?> _readQuietly(File file) async {
    try {
      return await file.readAsString();
    } on FileSystemException {
      return null;
    }
  }

  static String _contentOf(String conversationId, int sentAt) =>
      '$conversationId\n$sentAt';
}
