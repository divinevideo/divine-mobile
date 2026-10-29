// ABOUTME: Loads Noto Color Emoji for sticker text, so a sticker's emoji look
// ABOUTME: the same on every phone: in the editor, the video and its copy.

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextStyle;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/models/video_editor/sticker_text_glyphs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// The family sticker text falls back to for emoji.
const String stickerEmojiFontFamily = 'DivineStickerEmoji';

/// Noto Color Emoji as Google Fonts serves it, by its SHA-256.
const String _fontHash =
    'a98676580777f4f555d83287fb6e515f7450a7eae58466cbd1f4fed32ee03aaa';
const int _fontLength = 24015012;
final Uri _fontUrl = Uri.https('fonts.gstatic.com', '/s/a/$_fontHash.ttf');

/// How long a download may take before it counts as failed.
const Duration _downloadTimeout = Duration(seconds: 60);

bool _loaded = false;
Future<bool>? _loading;

/// Stands in for the whole load in widget tests, which must not download;
/// see [loadStickerEmojiFont].
@visibleForTesting
Future<bool> Function()? debugLoadStickerEmojiFont;

/// Whether [stickerEmojiFontFamily] is loaded, so emoji in sticker text are
/// drawn in it rather than in the phone's own emoji font.
bool get stickerEmojiFontLoaded => _loaded;

/// Loads the sticker emoji font, from the device after the first download,
/// and completes with whether it is loaded. A font that cannot be fetched,
/// checked or read completes with `false` and is logged; the next call tries
/// again.
///
/// [client], [cacheDirectory] and [register] stand in for the network, the
/// directory the font is kept in and the engine's font registry in tests.
Future<bool> loadStickerEmojiFont({
  http.Client? client,
  Future<Directory?> Function()? cacheDirectory,
  Future<void> Function(Uint8List bytes)? register,
}) {
  if (_loaded) return Future.value(true);
  final debugLoad = debugLoadStickerEmojiFont;
  if (debugLoad != null) return debugLoad().then((loaded) => _loaded = loaded);
  return _loading ??= _load(
    client: client,
    cacheDirectory: cacheDirectory ?? _defaultCacheDirectory,
    register: register ?? _registerFont,
  ).whenComplete(() => _loading = null);
}

/// Loads the sticker emoji font when one of [texts] has an emoji to draw in
/// it; see [loadStickerEmojiFont].
Future<void> loadStickerEmojiFontFor(Iterable<String> texts) async {
  if (texts.any((text) => StickerTextGlyphs.of(text) == .emoji)) {
    await loadStickerEmojiFont();
  }
}

/// [style] with its emoji drawn in the sticker emoji font once it is loaded,
/// and in the phone's own until then.
TextStyle withStickerEmojiFont(TextStyle style) =>
    style.copyWith(fontFamilyFallback: const [stickerEmojiFontFamily]);

/// Forgets the loaded font and any stand-in, for tests.
@visibleForTesting
void resetStickerEmojiFontForTesting() {
  _loaded = false;
  _loading = null;
  debugLoadStickerEmojiFont = null;
}

Future<bool> _load({
  required http.Client? client,
  required Future<Directory?> Function() cacheDirectory,
  required Future<void> Function(Uint8List bytes) register,
}) async {
  try {
    final directory = await cacheDirectory();
    final cached = directory == null
        ? null
        : File('${directory.path}/$_fontHash.ttf');
    var bytes = cached != null && cached.existsSync()
        ? await cached.readAsBytes()
        : null;
    if (bytes == null || bytes.length != _fontLength) {
      bytes = await _download(
        client ?? http.Client(),
        ownsClient: client == null,
      );
      if (cached != null) {
        await cached.parent.create(recursive: true);
        // Written aside and moved, so a half-written file is never read back.
        final partial = File('${cached.path}.part');
        await partial.writeAsBytes(bytes, flush: true);
        await partial.rename(cached.path);
      }
    }
    await register(bytes);
    _loaded = true;
    return true;
  } on Exception catch (error, stackTrace) {
    Log.warning(
      'Sticker emoji font not loaded',
      name: 'StickerEmojiFont',
      category: LogCategory.video,
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}

/// The font's bytes from Google Fonts, checked against its length and hash.
///
/// Throws an [HttpException] for a failed request, a [TimeoutException] for
/// one that takes too long and a [FormatException] for bytes that are not the
/// expected file.
Future<Uint8List> _download(
  http.Client client, {
  required bool ownsClient,
}) async {
  try {
    final response = await client.get(_fontUrl).timeout(_downloadTimeout);
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: _fontUrl);
    }
    final bytes = response.bodyBytes;
    if (bytes.length != _fontLength ||
        sha256.convert(bytes).toString() != _fontHash) {
      throw const FormatException('The emoji font does not match its hash');
    }
    return bytes;
  } finally {
    if (ownsClient) client.close();
  }
}

/// Where the font is kept between runs; none on the web, whose browser keeps
/// its own cache.
Future<Directory?> _defaultCacheDirectory() async {
  if (kIsWeb) return null;
  final support = await getApplicationSupportDirectory();
  return Directory('${support.path}/sticker_emoji_font');
}

Future<void> _registerFont(Uint8List bytes) => (FontLoader(
  stickerEmojiFontFamily,
)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
