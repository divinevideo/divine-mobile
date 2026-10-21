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
/// While the app is in the background, the marks of reads under way are left
/// empty: the system kills apps there, and that is no crash. A read past its
/// turn limit hung: its mark names the sender until the read ends, even in
/// the background, and every store skips the sender for the rest of the
/// launch, unless that read returns a frame after all, which forgives a
/// sender once a launch.
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
  bool _appInForeground = true;

  /// The marks of reads under way, by path, with the sender each names.
  final Map<String, String> _running = {};

  /// Senders one of whose frame reads an earlier launch never finished.
  final Set<String> _hungSenders = {};

  /// Whether these marks looked for such reads yet.
  bool _lookedForUnfinishedReads = false;

  /// Senders whose frame read hung in a launch, by launch and folder, so a
  /// store rebuilt in the same launch skips them too.
  static final Map<String, Set<String>> _hungInLaunch = {};

  /// The marks of reads that hung and have not ended, by launch and folder,
  /// then by path, with the sender each names.
  static final Map<String, Map<String, String>> _hung = {};

  /// Senders a hung read of which kept a frame, by launch and folder: each
  /// is read again once a launch, not each time.
  static final Map<String, Set<String>> _forgivenInLaunch = {};

  /// The mark of [messageId]'s frame read in [dir].
  static File readMarkOf(Directory dir, String messageId) =>
      File('${dir.path}/${dmVideoSafeName(messageId)}$_readMarkSuffix');

  /// Whether [file] is the mark of a frame read.
  static bool isReadMark(File file) => file.path.endsWith(_readMarkSuffix);

  /// Whether [file] is the mark of a sender one of whose frame reads an
  /// earlier launch never finished.
  static bool isSenderMark(File file) => file.path.endsWith(_senderMarkSuffix);

  /// Whether the app is in the foreground, which it is until told otherwise.
  /// Going to the background empties the marks of reads under way; coming
  /// back names their senders again.
  bool get appInForeground => _appInForeground;

  set appInForeground(bool inForeground) {
    if (inForeground == _appInForeground) return;
    _appInForeground = inForeground;
    for (final MapEntry(key: path, value: senderPubkey) in _running.entries) {
      _rewrite(File(path), _contentFor(senderPubkey));
    }
  }

  /// Writes [mark] as its frame read starts, naming this launch and
  /// [senderPubkey] while the app is in the foreground. A sender is named in
  /// lowercase, as a seal can spell its signer's key in uppercase and still
  /// verify.
  ///
  /// Throws a [FileSystemException] when the mark cannot be written.
  void readStarted(File mark, String senderPubkey) {
    final sender = senderPubkey.toLowerCase();
    mark.writeAsStringSync(_contentFor(sender));
    _running[mark.path] = sender;
  }

  /// Empties [mark], saying its read ended without a frame. It stays, so the
  /// video is not read again while it is kept, but blames no one.
  void readEnded(File mark) {
    _running.remove(mark.path);
    _hung[_launchKeyOf(mark.parent)]?.remove(mark.path);
    _rewrite(mark, '');
  }

  /// Names [mark]'s sender until the read ends: it outlived its turn, so it
  /// hung, and a kill meanwhile, even in the background, still blames them.
  /// Their other videos are not read by themselves for the rest of the
  /// launch either, unless it returns a frame after all and they were not
  /// forgiven once already. Does nothing once the read ended.
  void readHung(File mark) {
    final senderPubkey = _running.remove(mark.path);
    if (senderPubkey == null) return;
    final key = _launchKeyOf(mark.parent);
    (_hung[key] ??= {})[mark.path] = senderPubkey;
    (_hungInLaunch[key] ??= {}).add(senderPubkey);
    _rewrite(mark, '$_launchId\n$senderPubkey');
  }

  /// Deletes [mark], whose read returned a frame, kept or not. A read that
  /// hung was slow, not stuck: unless another of theirs hangs, its sender is read again, once a
  /// launch, as each such read holds up every other sender's frames for its
  /// whole turn.
  void frameKept(File mark) {
    _running.remove(mark.path);
    final key = _launchKeyOf(mark.parent);
    final hung = _hung[key];
    final hungSender = hung?.remove(mark.path);
    if (hungSender != null &&
        !hung!.containsValue(hungSender) &&
        (_forgivenInLaunch[key] ??= {}).add(hungSender)) {
      _hungInLaunch[key]?.remove(hungSender);
    }
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
          _rememberHungSender(dir, lines.last.toLowerCase());
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
  /// an earlier launch, while the mark that remembers it is kept, or hung in
  /// this one without keeping a frame since.
  bool senderHungTheDecoder(Directory dir, String senderPubkey) {
    final sender = senderPubkey.toLowerCase();
    if (_hungSenders.contains(sender) ||
        (_hungInLaunch[_launchKeyOf(dir)]?.contains(sender) ?? false)) {
      return true;
    }
    if (!_senderMarkOf(dir, sender).existsSync()) return false;
    _hungSenders.add(sender);
    return true;
  }

  String _launchKeyOf(Directory dir) => '$_launchId ${dir.path}';

  String _contentFor(String senderPubkey) =>
      _appInForeground ? '$_launchId\n$senderPubkey' : '';

  /// Rewrites [mark] while it is still there: a mark the system cleared, or
  /// one of an account removed from this device, is not written back.
  void _rewrite(File mark, String content) {
    if (_ownerRemoved() || !mark.existsSync()) return;
    try {
      mark.writeAsStringSync(content);
    } on FileSystemException catch (error) {
      Log.warning(
        'Could not update a video DM frame-read mark: '
        '${dmVideoFileErrorCause(error)}',
        name: _logName,
        category: LogCategory.video,
      );
    }
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
