// ABOUTME: Identifies the container of a downloaded audio body from its first
// ABOUTME: bytes, so a local copy is named with an extension players accept

import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Bytes read from the start of a body to identify its container.
const audioContainerSniffLength = 12;

/// The file extension that matches an audio body, so a player or renderer
/// opens it with the right demuxer.
///
/// Divine's Blossom URLs carry no extension, and AVFoundation picks the
/// demuxer by a local file's extension, so a WAV body saved as `.mp3`, or a
/// body saved with no extension at all, may not open.
///
/// The container is read off the first bytes of [head] (RIFF/WAVE, ISO
/// BMFF `ftyp`, Ogg, FLAC, ID3 or a bare MPEG/ADTS frame). When those say
/// nothing, the server's [contentType] decides, then the [url]'s own
/// extension, and finally `.mp3`.
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

/// Whether a body with these first bytes and [contentType] is a text
/// response, such as an error page, rather than audio.
///
/// Bytes that identify an audio container win over a text content type.
bool isClearlyNotAudioBody(Uint8List head, String? contentType) =>
    contentType?.split(';').first.trim().toLowerCase().startsWith('text/') ==
        true &&
    _sniffContainer(head) == null;

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
