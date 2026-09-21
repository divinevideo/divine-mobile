// ABOUTME: Resolves a render audio source to a local file, downloading a
// ABOUTME: network sound with a stall timeout and retries instead of one get

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:openvine/utils/async_utils.dart';
import 'package:path/path.dart' as p;
import 'package:pro_image_editor/pro_image_editor.dart'
    show EditorAudio, EditorAudioType;
import 'package:unified_logger/unified_logger.dart';

/// Thrown when a network audio source could not be fetched for the render.
///
/// [statusCode] is set when the server answered with a non-success status;
/// it is `null` for a transport failure (no connection, a stall, a body that
/// outgrew [RenderAudioFetcher.maxBytes]).
class RenderAudioFetchException implements Exception {
  const RenderAudioFetchException(
    this.url, {
    this.statusCode,
    this.cause,
    this.permanent = false,
  });

  final Uri url;
  final int? statusCode;
  final Object? cause;

  /// Set for a body the server delivered in full that is still unusable —
  /// empty, or larger than [RenderAudioFetcher.maxBytes]. Fetching it again
  /// yields the same body.
  final bool permanent;

  /// Whether another attempt has a reasonable chance of succeeding.
  ///
  /// A missing or forbidden blob stays missing; a dropped connection, a
  /// stall, a rate limit or a server error is worth trying again.
  bool get isTransient {
    if (permanent) return false;
    final status = statusCode;
    if (status == null) return true;
    return status >= 500 || status == 408 || status == 429;
  }

  @override
  String toString() =>
      'RenderAudioFetchException(${statusCode ?? 'transport'}: $url)'
      '${cause == null ? '' : ': $cause'}';
}

/// Resolves an [EditorAudio] to a path the native renderer can open.
///
/// File, asset and in-memory sources go through [EditorAudio.safeFilePath]
/// unchanged. A network source is downloaded here instead, for two reasons:
///
/// 1. `safeFilePath` is a single `http.get` with no timeout and no retry, so
///    one dropped connection on a 5 MB sound lost the whole track — and the
///    export used to carry on without it.
/// 2. It names the temp file after the URL's extension, defaulting to
///    `.mp3`. Divine's Blossom URLs carry no extension at all, so an MP4
///    video blob (an "original sound" with no audio event of its own) or a
///    WAV audio event was handed to AVFoundation as a `.mp3`. The container
///    is sniffed from the first bytes instead, so the name matches the data.
class RenderAudioFetcher {
  RenderAudioFetcher({
    http.Client Function()? clientFactory,
    Directory? tempDirectory,
    this.maxRetries = 2,
    this.baseDelay = const Duration(seconds: 1),
    this.stallTimeout = const Duration(seconds: 20),
    this.maxBytes = 50 * 1024 * 1024,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _tempDirectory = tempDirectory;

  static const _logName = 'RenderAudioFetcher';
  static int _sequence = 0;

  final http.Client Function() _clientFactory;
  final Directory? _tempDirectory;

  /// Further attempts after the first failed one.
  final int maxRetries;

  /// Wait before the first retry; doubles on each further one.
  final Duration baseDelay;

  /// How long the connection or any single chunk may take before the
  /// attempt counts as stalled. A slow download that keeps delivering bytes
  /// is not a stall.
  final Duration stallTimeout;

  /// Largest body accepted. A sound is a few megabytes; anything bigger is
  /// not the blob we asked for.
  final int maxBytes;

  /// A local path for [audio], downloading it when it lives on the network.
  ///
  /// Throws [RenderAudioFetchException] when every download attempt failed,
  /// and whatever [EditorAudio.safeFilePath] throws for the other sources.
  /// Downloaded files land in the temp directory and are the caller's to
  /// delete once the render is done.
  Future<String> localPathFor(
    EditorAudio audio, {
    required String logName,
  }) async {
    if (audio.type != EditorAudioType.network) return audio.safeFilePath();

    final url = Uri.parse(audio.networkUrl!);
    final scope = AsyncScope(debugName: _logName);
    try {
      return await scope.retryWithBackoff(
        operation: () => _download(url, logName: logName),
        maxRetries: maxRetries,
        baseDelay: baseDelay,
        maxDelay: baseDelay * 4,
        retryWhen: (error) =>
            error is RenderAudioFetchException && error.isTransient,
        debugName: 'render audio download',
      );
    } finally {
      scope.dispose();
    }
  }

  Future<String> _download(Uri url, {required String logName}) async {
    final client = _clientFactory();
    final directory = _tempDirectory ?? Directory.systemTemp;
    final base = p.join(
      directory.path,
      'render_audio_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}',
    );
    final partial = File('$base.part');
    IOSink? sink;
    try {
      final http.StreamedResponse response;
      try {
        response = await client
            .send(http.Request('GET', url))
            .timeout(stallTimeout);
      } on RenderAudioFetchException {
        rethrow;
      } catch (error) {
        throw RenderAudioFetchException(url, cause: error);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RenderAudioFetchException(url, statusCode: response.statusCode);
      }

      sink = partial.openWrite();
      final head = BytesBuilder(copy: false);
      var written = 0;
      try {
        await for (final chunk in response.stream.timeout(stallTimeout)) {
          written += chunk.length;
          if (written > maxBytes) {
            throw RenderAudioFetchException(
              url,
              cause: 'body exceeds $maxBytes bytes',
              permanent: true,
            );
          }
          if (head.length < _sniffLength) head.add(chunk);
          sink.add(chunk);
        }
      } on RenderAudioFetchException {
        rethrow;
      } catch (error) {
        throw RenderAudioFetchException(url, cause: error);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (written == 0) {
        throw RenderAudioFetchException(
          url,
          cause: 'empty body',
          permanent: true,
        );
      }

      final headBytes = head.takeBytes();
      final contentType = response.headers[HttpHeaders.contentTypeHeader];
      if (_isClearlyNotAudioBody(headBytes, contentType)) {
        throw RenderAudioFetchException(
          url,
          cause: 'text response for an audio request',
          permanent: true,
        );
      }
      final extension = audioFileExtensionFor(
        headBytes,
        url: url,
        contentType: contentType,
      );
      final file = await partial.rename('$base$extension');
      Log.info(
        'Fetched render audio ($written bytes, $extension) for $logName',
        name: _logName,
        category: LogCategory.video,
      );
      return file.path;
    } catch (error) {
      try {
        await sink?.close();
      } catch (closeError, closeStackTrace) {
        Log.warning(
          'Could not close a failed render-audio download',
          name: _logName,
          category: LogCategory.video,
          error: closeError,
          stackTrace: closeStackTrace,
        );
      }
      try {
        if (partial.existsSync()) {
          partial.deleteSync();
        }
      } on FileSystemException {
        // Best-effort: a stranded .part file costs disk, not correctness.
      }
      if (error is RenderAudioFetchException) rethrow;
      throw RenderAudioFetchException(
        url,
        cause: error,
        permanent: error is FileSystemException,
      );
    } finally {
      client.close();
    }
  }
}

/// Bytes read from the start of the body to identify its container.
const _sniffLength = 12;

/// The file extension that matches an audio body, so the native renderer
/// opens it with the right demuxer.
///
/// The container is read off the first bytes of [head] (RIFF/WAVE, ISO
/// BMFF `ftyp`, Ogg, FLAC, ID3 or a bare MPEG/ADTS frame). When those say
/// nothing, the server's [contentType] decides, then the [url]'s own
/// extension, and finally `.mp3` — the guess `EditorAudio.safeFilePath`
/// always made.
String audioFileExtensionFor(
  Uint8List head, {
  required Uri url,
  String? contentType,
}) {
  final sniffed = _sniffContainer(head);
  if (sniffed != null) return sniffed;

  final mime = contentType?.split(';').first.trim().toLowerCase();
  final fromMime = switch (mime) {
    'audio/wav' || 'audio/x-wav' || 'audio/wave' || 'audio/vnd.wave' => '.wav',
    'audio/mp4' || 'audio/x-m4a' || 'video/mp4' => '.mp4',
    'audio/mpeg' || 'audio/mp3' => '.mp3',
    'audio/aac' || 'audio/aacp' => '.aac',
    'audio/ogg' || 'application/ogg' => '.ogg',
    'audio/flac' || 'audio/x-flac' => '.flac',
    _ => null,
  };
  if (fromMime != null) return fromMime;

  final fromUrl = p.extension(url.path);
  if (fromUrl.length > 1 && fromUrl.length <= 5) return fromUrl;
  return '.mp3';
}

String? _sniffContainer(Uint8List head) {
  bool ascii(int offset, String text) {
    if (head.length < offset + text.length) return false;
    for (var i = 0; i < text.length; i++) {
      if (head[offset + i] != text.codeUnitAt(i)) return false;
    }
    return true;
  }

  if (ascii(0, 'RIFF') && ascii(8, 'WAVE')) return '.wav';
  if (ascii(4, 'ftyp')) return '.mp4';
  if (ascii(0, 'OggS')) return '.ogg';
  if (ascii(0, 'fLaC')) return '.flac';
  if (ascii(0, 'ID3')) return '.mp3';
  if (head.length >= 2 && head[0] == 0xFF && (head[1] & 0xE0) == 0xE0) {
    // A frame sync with the layer bits clear is ADTS (raw AAC); any other
    // layer is an MPEG audio frame.
    return (head[1] & 0x06) == 0 ? '.aac' : '.mp3';
  }
  return null;
}

/// A text response cannot be muxed as audio, unless its bytes identify an
/// audio container despite an incorrect content type.
bool _isClearlyNotAudioBody(Uint8List head, String? contentType) =>
    contentType?.split(';').first.trim().toLowerCase().startsWith('text/') ==
        true &&
    _sniffContainer(head) == null;
