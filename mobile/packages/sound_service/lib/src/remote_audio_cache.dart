// ABOUTME: Downloads remote sounds to local files and keeps them, so a failed
// ABOUTME: download is an error the caller can catch and a replay is offline

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sound_service/src/audio_container.dart';

/// Thrown when a remote sound could not be downloaded.
///
/// [statusCode] is set when the server answered with a non-success status.
/// It is `null` when the download failed otherwise: no connection, a stall,
/// a body that outgrew [RemoteAudioCache.maxBytes] or is not audio, or a
/// cache directory that could not be written.
class RemoteAudioDownloadException implements Exception {
  /// Creates a [RemoteAudioDownloadException] for [uri].
  const RemoteAudioDownloadException(this.uri, {this.statusCode, this.cause});

  /// The sound that could not be downloaded.
  final Uri uri;

  /// The HTTP status the server answered with, when it answered.
  final int? statusCode;

  /// What made the download fail, when it was not the status code.
  final Object? cause;

  @override
  String toString() =>
      'RemoteAudioDownloadException(${statusCode ?? 'transport'}: $uri)'
      '${cause == null ? '' : ': $cause'}';
}

/// Downloads remote sounds to local files and keeps them, so a sound played
/// again (previewed, then recorded with) is not downloaded again.
///
/// The download happens before playback starts, so a server error or a
/// dropped connection is thrown to the caller of [fileFor] instead of
/// failing inside the player, where nothing could catch it.
///
/// Each sound is kept as `<directory>/<sha256 of the URL>/sound<ext>`, the
/// extension read off the body's first bytes: Divine's Blossom URLs carry
/// none, and AVFoundation picks the demuxer by a local file's extension.
class RemoteAudioCache {
  /// Creates a [RemoteAudioCache] that keeps its files in [directory],
  /// by default `sound_cache` in the system temp directory.
  RemoteAudioCache({
    HttpClient Function()? httpClientFactory,
    Directory? directory,
    this.connectionTimeout = const Duration(seconds: 10),
    this.stallTimeout = const Duration(seconds: 20),
    this.maxBytes = 50 * 1024 * 1024,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new,
       _directory =
           directory ??
           Directory(p.join(Directory.systemTemp.path, 'sound_cache'));

  static const _fileName = 'sound';
  static int _sequence = 0;

  final HttpClient Function() _httpClientFactory;
  final Directory _directory;

  /// The downloads running, by cache key, so a second request for a sound
  /// waits for the download already under way instead of starting another.
  final _downloads = <String, Future<File>>{};

  /// How long connecting to the server may take.
  final Duration connectionTimeout;

  /// How long the response headers or any single chunk of the body may
  /// take before the download counts as stalled. A slow download that keeps
  /// delivering bytes is not a stall.
  final Duration stallTimeout;

  /// Largest body accepted. A sound is a few megabytes; anything bigger is
  /// not the file we asked for.
  final int maxBytes;

  /// A local file holding the sound at [uri], downloading it unless an
  /// earlier call already did. A call while this cache is downloading the
  /// sound waits for that download.
  ///
  /// Throws [RemoteAudioDownloadException] when the download fails. Nothing
  /// is kept for a failed download, so the next call tries again.
  Future<File> fileFor(Uri uri) {
    final key = _keyFor(uri);
    final entry = Directory(p.join(_directory.path, key));
    final cached = _cachedFileIn(entry);
    if (cached != null) return Future.value(cached);
    // removeWhere, not remove: remove returns the removed future, this
    // one, and whenComplete would wait for it, so for itself, forever.
    return _downloads[key] ??=
        _downloadOrThrow(
          uri,
          entry,
        ).whenComplete(
          () => _downloads.removeWhere((pending, _) => pending == key),
        );
  }

  Future<File> _downloadOrThrow(Uri uri, Directory entry) async {
    try {
      return await _download(uri, entry);
    } on RemoteAudioDownloadException {
      rethrow;
    } on Exception catch (error) {
      throw RemoteAudioDownloadException(uri, cause: error);
    }
  }

  /// The local file holding the sound at [uri] if an earlier [fileFor]
  /// downloaded it, or `null`. Never touches the network.
  File? cachedFileFor(Uri uri) => _cachedFileIn(_entryFor(uri));

  /// Whether this cache is downloading the sound at [uri] right now.
  bool isDownloading(Uri uri) => _downloads.containsKey(_keyFor(uri));

  /// Asks the server for the first byte of the sound at [uri] and keeps
  /// nothing, so the CDN in front of it has the sound ready when it plays.
  ///
  /// A CDN edge that has not served a sound yet fetches it from the origin
  /// first, which takes about half a second longer than an edge that has.
  /// A network or server failure is not thrown: it only means the sound is
  /// fetched cold later. A [uri] with no host throws [ArgumentError].
  Future<void> warm(Uri uri) async {
    final client = _httpClientFactory()..connectionTimeout = connectionTimeout;
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final response = await request.close().timeout(stallTimeout);
      await response.drain<void>().timeout(stallTimeout);
    } on Exception {
      // Warming is only a head start; playing the sound fetches it anyway.
    } finally {
      client.close(force: true);
    }
  }

  Directory _entryFor(Uri uri) =>
      Directory(p.join(_directory.path, _keyFor(uri)));

  static String _keyFor(Uri uri) =>
      sha256.convert(utf8.encode(uri.toString())).toString();

  File? _cachedFileIn(Directory entry) {
    try {
      for (final entity in entry.listSync(followLinks: false)) {
        if (entity is File &&
            p.basenameWithoutExtension(entity.path) == _fileName) {
          return entity;
        }
      }
    } on FileSystemException {
      // No entry yet, or the system purged it while it was read: either way
      // the sound is downloaded.
    }
    return null;
  }

  Future<File> _download(Uri uri, Directory entry) async {
    final client = _httpClientFactory()..connectionTimeout = connectionTimeout;
    File? partial;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(stallTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RemoteAudioDownloadException(
          uri,
          statusCode: response.statusCode,
        );
      }

      await entry.create(recursive: true);
      // A name of its own, so a concurrent download of the same sound never
      // writes into or deletes this one's file.
      final part = partial = File(
        p.join(
          entry.path,
          '${DateTime.now().microsecondsSinceEpoch}_${_sequence++}.part',
        ),
      );
      final head = BytesBuilder(copy: false);
      var written = 0;
      final out = part.openWrite();
      try {
        await for (final chunk in response.timeout(stallTimeout)) {
          written += chunk.length;
          if (written > maxBytes) {
            throw RemoteAudioDownloadException(
              uri,
              cause: 'body exceeds $maxBytes bytes',
            );
          }
          if (head.length < audioContainerSniffLength) head.add(chunk);
          out.add(chunk);
        }
      } finally {
        await out.close();
      }

      if (written == 0) {
        throw RemoteAudioDownloadException(uri, cause: 'empty body');
      }
      final headBytes = head.takeBytes();
      final contentType = response.headers.value(
        HttpHeaders.contentTypeHeader,
      );
      if (isClearlyNotAudioBody(headBytes, contentType)) {
        throw RemoteAudioDownloadException(
          uri,
          cause: 'text response for an audio request',
        );
      }
      final extension = audioFileExtensionFor(
        headBytes,
        url: uri,
        contentType: contentType,
      );
      // A rename within one directory is atomic, so a reader never finds a
      // half-written sound under the final name.
      return await part.rename(p.join(entry.path, '$_fileName$extension'));
    } catch (_) {
      // Nothing is kept for a failed download, so the next call tries again.
      if (partial != null && partial.existsSync()) partial.deleteSync();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }
}
