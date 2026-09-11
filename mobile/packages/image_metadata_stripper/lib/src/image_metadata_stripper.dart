import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:unified_logger/unified_logger.dart';

/// Strips EXIF metadata (GPS, device info, timestamps) from images.
///
/// Path-based APIs ([stripMetadata], [stripMetadataInPlace]) use platform
/// channels and are native-only — `dart:io` `File` cannot be constructed
/// from an `image_picker` blob URL on web. Web callers must use
/// [stripMetadataBytes], which runs in pure Dart over raw bytes.
class ImageMetadataStripper {
  static const _channel = MethodChannel('image_metadata_stripper');

  /// Strips all EXIF metadata from the image at [inputPath] and writes
  /// the cleaned image to [outputPath]. Native-only — use
  /// [stripMetadataBytes] on web.
  ///
  /// Throws [PlatformException] if the native call fails.
  static Future<void> stripMetadata({
    required String inputPath,
    required String outputPath,
  }) async {
    await _channel.invokeMethod<void>('stripImageMetadata', {
      'inputPath': inputPath,
      'outputPath': outputPath,
    });
  }

  /// Convenience: strips metadata in-place by writing to a temp file
  /// and replacing the original.
  ///
  /// Non-PNG images are re-encoded as JPEG by the native strippers, so
  /// this method also renames the file to `.jpg` when the original
  /// extension is not `.png` to keep the extension consistent with the
  /// actual content.
  ///
  /// Returns the resulting [File] (path may differ from input).
  /// On failure, logs the error and returns the unmodified [imageFile]
  /// so the upload can proceed with metadata intact rather than crashing.
  /// Callers that must not send the original on failure must use
  /// [stripMetadataInPlaceOrThrow] instead.
  static Future<File> stripMetadataInPlace(File imageFile) async {
    try {
      return await stripMetadataInPlaceOrThrow(imageFile);
    } on Exception catch (e, stackTrace) {
      Log.error(
        'Failed to strip image metadata',
        name: 'ImageMetadataStripper',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
      return imageFile;
    }
  }

  /// Fail-closed variant of [stripMetadataInPlace].
  ///
  /// Throws instead of returning the original when stripping fails, so a
  /// privacy-sensitive caller can drop the attachment rather than send bytes
  /// whose metadata it could not confirm was removed. Never returns the
  /// original once stripping has failed.
  static Future<File> stripMetadataInPlaceOrThrow(File imageFile) async {
    final tempPath = '${imageFile.path}.stripped';
    try {
      await stripMetadata(inputPath: imageFile.path, outputPath: tempPath);
      final tempFile = File(tempPath);
      if (!tempFile.existsSync()) {
        throw FileSystemException(
          'Metadata stripper produced no output for ${imageFile.path}',
        );
      }

      // The native strippers output JPEG for every format except PNG.
      // Rename the file so the extension matches the actual content.
      final isPng = imageFile.path.toLowerCase().endsWith('.png');
      final targetFile = isPng
          ? await tempFile.rename(imageFile.path)
          : await tempFile.rename('${withoutExtension(imageFile.path)}.jpg');

      // Remove the original if it had a different path.
      if (targetFile.path != imageFile.path && imageFile.existsSync()) {
        await imageFile.delete();
      }

      return targetFile;
    } on Exception {
      await _deleteTempFile(tempPath);
      rethrow;
    }
  }

  static Future<void> _deleteTempFile(String tempPath) async {
    try {
      final tempFile = File(tempPath);
      if (tempFile.existsSync()) await tempFile.delete();
    } on Exception catch (_) {
      // Best-effort cleanup of a partially written temp file.
    }
  }

  /// Strips EXIF metadata from raw image bytes using pure Dart.
  ///
  /// Designed for the web upload path where `dart:io` `File` cannot be used
  /// against an `image_picker` blob URL. Native callers that already hold a
  /// real filesystem path should prefer [stripMetadataInPlace] so the
  /// hardware-accelerated platform stripper runs.
  ///
  /// JPEG EXIF is replaced losslessly (only orientation is preserved).
  /// PNG is decoded and re-encoded (lossless). Other formats fall through to
  /// a generic decode → JPEG re-encode, which discards metadata at the cost
  /// of a re-encode. If decoding fails entirely, the original bytes are
  /// returned unchanged so the upload can still proceed.
  ///
  /// The returned `filename` mirrors [stripMetadataInPlace]'s rename rule:
  /// PNG keeps its `.png` extension; everything that is re-encoded as JPEG
  /// switches to `.jpg`.
  static ({Uint8List bytes, String filename}) stripMetadataBytes({
    required Uint8List bytes,
    required String filename,
  }) {
    final lower = filename.toLowerCase();

    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return (bytes: stripJpegExif(bytes), filename: filename);
    }

    if (lower.endsWith('.png')) {
      final decoded = img.decodePng(bytes);
      if (decoded != null) {
        return (
          bytes: Uint8List.fromList(img.encodePng(decoded)),
          filename: filename,
        );
      }
    }

    // Generic fallback: decode whatever the image package can recognise
    // and re-encode as JPEG. This drops EXIF/XMP/etc. as a side-effect of
    // the round-trip. `decodeImage` panics on some malformed inputs (e.g.
    // PSD's signature probe) instead of returning null, so swallow any
    // throw and fall through to returning the original bytes.
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final reencoded = Uint8List.fromList(
          img.encodeJpg(decoded, quality: 95),
        );
        return (
          bytes: reencoded,
          filename: '${withoutExtension(filename)}.jpg',
        );
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to decode image bytes for stripping; returning original',
        name: 'ImageMetadataStripper',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
    }

    return (bytes: bytes, filename: filename);
  }

  /// Replaces all JPEG EXIF data with a minimal block that only
  /// contains the orientation tag (if present). No re-encoding,
  /// no quality loss.
  @visibleForTesting
  static Uint8List stripJpegExif(Uint8List bytes) {
    if (bytes.length < 2 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      return bytes;
    }

    final originalExif = img.decodeJpgExif(bytes);
    final orientation = originalExif?.imageIfd.orientation;

    final cleanExif = img.ExifData();
    if (orientation != null) {
      cleanExif.imageIfd.orientation = orientation;
    }

    return img.injectJpgExif(bytes, cleanExif) ?? bytes;
  }

  /// Returns [path] without its file extension (including the dot).
  @visibleForTesting
  static String withoutExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0) return path;
    return path.substring(0, dotIndex);
  }
}
