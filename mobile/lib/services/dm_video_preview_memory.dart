// ABOUTME: One account's in-memory record of the video DMs it has played this
// ABOUTME: session, and of the blurhash read from each kept preview frame.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:blurhash_service/blurhash_service.dart';

/// Encodes image bytes as a blurhash, or returns null when they cannot be.
typedef BlurhashEncoder = Future<String?> Function(Uint8List imageBytes);

/// What this device remembers about one account's video DM previews until
/// the app restarts or the account changes.
///
/// A blurred preview stays blurred until its video is played, which
/// [markWatched] records. When the sender sent no blurhash, a blurred card
/// shows one read from the frame this device keeps instead of the frame
/// itself. Neither the ids nor the blurhashes are ever logged.
class DmVideoPreviewMemory {
  /// Creates an empty memory. [encodeBlurhash] reads a blurhash from a
  /// kept frame's bytes.
  DmVideoPreviewMemory({
    BlurhashEncoder encodeBlurhash = BlurhashService.generateBlurhash,
  }) : _encodeBlurhash = encodeBlurhash;

  final BlurhashEncoder _encodeBlurhash;
  final Set<String> _watched = {};
  final Map<String, Future<String?>> _frameBlurhashes = {};
  final Map<String, String> _knownFrameBlurhashes = {};
  final StreamController<String> _watchedController =
      StreamController<String>.broadcast();

  /// The id of each message as it is first played.
  Stream<String> get watched => _watchedController.stream;

  /// Whether the video DM [messageId] has been played this session.
  bool isWatched(String messageId) => _watched.contains(messageId);

  /// Records that the video DM [messageId] was played, so its preview no
  /// longer needs to be blurred.
  void markWatched(String messageId) {
    if (_watchedController.isClosed || !_watched.add(messageId)) return;
    _watchedController.add(messageId);
  }

  /// The blurhash already read from [messageId]'s kept frame, if any, so a
  /// card built again shows it from its first frame.
  String? knownFrameBlurhashFor(String messageId) =>
      _knownFrameBlurhashes[messageId];

  /// A blurhash read from [framePath], the frame this device keeps for
  /// [messageId], or null when the frame is gone or cannot be encoded.
  ///
  /// Each message's frame is read once.
  Future<String?> frameBlurhashFor({
    required String messageId,
    required String framePath,
  }) => _frameBlurhashes.putIfAbsent(
    messageId,
    () => _readFrameBlurhash(messageId, framePath),
  );

  Future<String?> _readFrameBlurhash(String messageId, String framePath) async {
    final Uint8List bytes;
    try {
      bytes = await File(framePath).readAsBytes();
    } on FileSystemException {
      // The system can clear the cache the frame lives in; the card then
      // shows its placeholder.
      return null;
    }
    final blurhash = await _encodeBlurhash(bytes);
    if (blurhash != null) _knownFrameBlurhashes[messageId] = blurhash;
    return blurhash;
  }

  /// Stops announcing played messages.
  void dispose() => unawaited(_watchedController.close());
}
