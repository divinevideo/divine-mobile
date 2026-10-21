// ABOUTME: Marks the video DM store leaves while reading a video's frame, so a
// ABOUTME: decode that crashed the app is not tried again, nor its sender's.

import 'dart:io';
import 'dart:math' show Random;

import 'package:openvine/services/dm_video_files.dart';
import 'package:unified_logger/unified_logger.dart';

/// The marks that keep a frame read which crashed the app, as a decoder can,
/// from being tried again, in one account's folder of kept video DMs.
///
/// A read's mark sits beside its video from the start of the read until a
/// frame is kept. While the read runs it names the launch and the sender; a
/// read that ends without a frame empties it. One a later launch finds still
/// naming them never finished, and its sender is remembered with an empty
/// mark named after them, so one sender cannot crash the app once per video.
class DmVideoFrameReadMarks {
  /// Creates the marks of one store, whose account [ownerRemoved] says was
  /// removed from this device: a sender is then not remembered on disk, as
  /// writing would bring the account's folder back. [launchId] defaults to
  /// this launch of the app's; tests pass another for an earlier launch.
  DmVideoFrameReadMarks({
    required bool Function() ownerRemoved,
    String? launchId,
  }) : _ownerRemoved = ownerRemoved,
       _launchId = launchId ?? _thisLaunch;

  static const String _readMarkSuffix = '.frame-attempt';
  static const String _senderMarkPrefix = 'sender-';
  static const String _senderMarkSuffix = '.decoder-hung';

  // The marks are the store's files, so they log under its name.
  static const String _logName = 'DmVideoStore';

  /// Names this launch of the app in the marks its stores write.
  static final String _thisLaunch = _newLaunchId();

  static String _newLaunchId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  final bool Function() _ownerRemoved;
  final String _launchId;

  /// Senders one of whose frame reads an earlier launch never finished, and
  /// whether these marks looked for such reads yet.
  final Set<String> _hungSenders = {};
  bool _lookedForUnfinishedReads = false;

  /// The mark of [messageId]'s frame read in [dir].
  static File readMarkOf(Directory dir, String messageId) =>
      File('${dir.path}/${dmVideoSafeName(messageId)}$_readMarkSuffix');

  /// Whether [file] is the mark of a frame read.
  static bool isReadMark(File file) => file.path.endsWith(_readMarkSuffix);

  /// Whether [file] is the mark of a sender one of whose frame reads an
  /// earlier launch never finished.
  static bool isSenderMark(File file) => file.path.endsWith(_senderMarkSuffix);

  /// Writes [mark] as its frame read starts, naming this launch and
  /// [senderPubkey].
  ///
  /// Throws a [FileSystemException] when the mark cannot be written.
  void readStarted(File mark, String senderPubkey) =>
      mark.writeAsStringSync('$_launchId\n$senderPubkey');

  /// Empties [mark], saying its read ended without a frame. It stays, so the
  /// video is not read again while it is kept, but blames no one.
  void readEnded(File mark) {
    try {
      mark.writeAsStringSync('');
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not record that a video DM frame read ended: '
        '${dmVideoFileErrorCause(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  /// Deletes [mark], whose read kept a frame.
  void frameKept(File mark) {
    try {
      mark.deleteSync();
    } on PathNotFoundException {
      // Already gone, which is all that was wanted.
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not delete a kept video DM file: '
        '${dmVideoFileErrorCause(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  /// Remembers, the first time only, the senders of frame reads in [dir] an
  /// earlier launch never finished. Asked before anything is fetched or read
  /// for a card, and before a prune can delete such a read's mark unread.
  void lookForUnfinishedReads(Directory dir) {
    if (_lookedForUnfinishedReads) return;
    _lookedForUnfinishedReads = true;
    final List<File> files;
    try {
      if (!dir.existsSync()) return;
      files = dir.listSync().whereType<File>().toList();
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not look for video DM frame reads an earlier launch left: '
        '${dmVideoFileErrorCause(error)}',
        name: _logName,
        category: LogCategory.video,
      );
      return;
    }
    for (final file in files) {
      if (!isReadMark(file)) continue;
      try {
        final lines = file.readAsLinesSync();
        if (lines.length == 2 && lines.first != _launchId) {
          _rememberHungSender(dir, lines.last);
        }
      } on PathNotFoundException {
        // Deleted since the listing, with its video: nothing to remember.
      } on FileSystemException catch (error) {
        Log.warning(
          'Could not read a video DM frame-read mark: '
          '${dmVideoFileErrorCause(error)}',
          name: _logName,
          category: LogCategory.video,
        );
      }
    }
  }

  /// Whether one of [senderPubkey]'s frame reads in [dir] never finished in
  /// an earlier launch, while the mark that remembers it is kept.
  bool senderHungTheDecoder(Directory dir, String senderPubkey) {
    if (_hungSenders.contains(senderPubkey)) return true;
    if (!_senderMarkOf(dir, senderPubkey).existsSync()) return false;
    _hungSenders.add(senderPubkey);
    return true;
  }

  void _rememberHungSender(Directory dir, String senderPubkey) {
    _hungSenders.add(senderPubkey);
    // Writing it would bring a removed account's folder back.
    if (_ownerRemoved()) return;
    try {
      _senderMarkOf(dir, senderPubkey).createSync();
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not remember a sender whose video DM frame read never '
        'finished: ${dmVideoFileErrorCause(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  static File _senderMarkOf(Directory dir, String senderPubkey) => File(
    '${dir.path}/$_senderMarkPrefix${dmVideoSafeName(senderPubkey)}'
    '$_senderMarkSuffix',
  );
}
