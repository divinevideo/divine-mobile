import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_metadata_stripper/image_metadata_stripper.dart';

/// Generates a minimal JPEG with EXIF containing orientation + GPS.
Uint8List _jpegWithExif() {
  final image = img.Image(width: 2, height: 2);
  final jpgBytes = img.encodeJpg(image, quality: 95);
  final exif = img.ExifData()
    ..imageIfd.orientation = 6
    ..gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
  return img.injectJpgExif(jpgBytes, exif) ?? Uint8List.fromList(jpgBytes);
}

/// Generates a minimal JPEG without meaningful EXIF.
Uint8List _jpegNoExif() =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: 2, height: 2)));

/// Generates a minimal PNG.
Uint8List _pngBytes() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));

/// Generates a minimal BMP.
Uint8List _bmpBytes() =>
    Uint8List.fromList(img.encodeBmp(img.Image(width: 2, height: 2)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(ImageMetadataStripper, () {
    const channel = MethodChannel('image_metadata_stripper');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    group('stripMetadata', () {
      test('invokes stripImageMetadata with correct arguments', () async {
        await ImageMetadataStripper.stripMetadata(
          inputPath: '/tmp/input.jpg',
          outputPath: '/tmp/output.jpg',
        );

        expect(calls, hasLength(1));
        expect(calls.first.method, equals('stripImageMetadata'));
        expect(
          calls.first.arguments,
          equals({
            'inputPath': '/tmp/input.jpg',
            'outputPath': '/tmp/output.jpg',
          }),
        );
      });

      test('throws PlatformException on native error', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              throw PlatformException(
                code: 'FILE_NOT_FOUND',
                message: 'Input file does not exist',
              );
            });

        expect(
          () => ImageMetadataStripper.stripMetadata(
            inputPath: '/nonexistent.jpg',
            outputPath: '/tmp/output.jpg',
          ),
          throwsA(isA<PlatformException>()),
        );
      });
    });

    group('stripMetadataInPlace', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'image_metadata_stripper_unit_test_',
        );
      });

      tearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('calls stripMetadata and renames temp file back', () async {
        final imageFile = File('${tempDir.path}/photo.jpg');
        await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);

        // Mock creates the .stripped output file
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              final args = call.arguments as Map;
              final outputPath = args['outputPath'] as String;
              await File(outputPath).writeAsBytes([0xFF, 0xD8, 0xFF, 0xDB]);
              return null;
            });

        final result = await ImageMetadataStripper.stripMetadataInPlace(
          imageFile,
        );

        // Verify channel was called with correct paths
        expect(calls, hasLength(1));
        expect(
          calls.first.arguments,
          equals({
            'inputPath': imageFile.path,
            'outputPath': '${imageFile.path}.stripped',
          }),
        );

        // Verify the original file was replaced
        expect(result.path, equals(imageFile.path));
        expect(result.existsSync(), isTrue);
        expect(
          await result.readAsBytes(),
          equals([0xFF, 0xD8, 0xFF, 0xDB]),
        );

        // Verify temp file no longer exists
        expect(
          File('${imageFile.path}.stripped').existsSync(),
          isFalse,
        );
      });

      test('renames non-PNG to .jpg and deletes original', () async {
        final imageFile = File('${tempDir.path}/photo.webp');
        await imageFile.writeAsBytes([0x52, 0x49, 0x46, 0x46]);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              final args = call.arguments as Map;
              final outputPath = args['outputPath'] as String;
              await File(outputPath).writeAsBytes([0xFF, 0xD8, 0xFF, 0xDB]);
              return null;
            });

        final result = await ImageMetadataStripper.stripMetadataInPlace(
          imageFile,
        );

        expect(result.path, equals('${tempDir.path}/photo.jpg'));
        expect(result.existsSync(), isTrue);
        expect(imageFile.existsSync(), isFalse);
      });

      test('keeps .png extension for PNG files', () async {
        final imageFile = File('${tempDir.path}/photo.png');
        await imageFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              final args = call.arguments as Map;
              final outputPath = args['outputPath'] as String;
              await File(outputPath).writeAsBytes([0x89, 0x50, 0x4E, 0x47]);
              return null;
            });

        final result = await ImageMetadataStripper.stripMetadataInPlace(
          imageFile,
        );

        expect(result.path, equals(imageFile.path));
        expect(result.existsSync(), isTrue);
      });

      test('returns original file when stripMetadata throws', () async {
        final imageFile = File('${tempDir.path}/photo.jpg');
        final originalBytes = [0xFF, 0xD8, 0xFF, 0xE0];
        await imageFile.writeAsBytes(originalBytes);

        // Mock throws an exception
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              throw PlatformException(
                code: 'DECODE_ERROR',
                message: 'Failed to decode image',
              );
            });

        final result = await ImageMetadataStripper.stripMetadataInPlace(
          imageFile,
        );

        // Verify original file is returned unchanged
        expect(result.path, equals(imageFile.path));
        expect(await result.readAsBytes(), equals(originalBytes));
      });

      test('cleans up partial temp file on failure', () async {
        final imageFile = File('${tempDir.path}/photo.jpg');
        await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
        final tempPath = '${imageFile.path}.stripped';

        // Simulate partial write by creating temp file, then mock throws
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              // Write partial temp file before throwing
              await File(tempPath).writeAsBytes([0xFF, 0xD8]);
              throw PlatformException(
                code: 'WRITE_ERROR',
                message: 'Failed to write output',
              );
            });

        await ImageMetadataStripper.stripMetadataInPlace(imageFile);

        // Verify temp file was cleaned up
        expect(File(tempPath).existsSync(), isFalse);
      });

      test('silently handles temp file deletion failure', () async {
        final imageFile = File('${tempDir.path}/photo.jpg');
        await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
        final tempPath = '${imageFile.path}.stripped';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              // Create temp file, then make parent readonly so delete fails
              await File(tempPath).writeAsBytes([0xFF, 0xD8]);
              await Process.run('chmod', ['a-w', tempDir.path]);
              throw PlatformException(
                code: 'DECODE_ERROR',
                message: 'Failed to decode',
              );
            });

        // Should complete without throwing despite deletion failure
        final result = await ImageMetadataStripper.stripMetadataInPlace(
          imageFile,
        );

        // Restore permissions for tearDown cleanup
        await Process.run('chmod', ['a+w', tempDir.path]);

        expect(result.path, equals(imageFile.path));
        // Temp file still exists because deletion failed
        expect(File(tempPath).existsSync(), isTrue);
      });
    });

    group('stripMetadataBytes', () {
      test('strips JPEG EXIF and preserves orientation', () {
        final input = _jpegWithExif();

        final result = ImageMetadataStripper.stripMetadataBytes(
          bytes: input,
          filename: 'photo.jpg',
        );

        expect(result.filename, equals('photo.jpg'));
        final exif = img.decodeJpgExif(result.bytes);
        expect(exif?.imageIfd.orientation, equals(6));
        expect(exif?.gpsIfd['GPSLatitudeRef'], isNull);
      });

      test('handles .jpeg extension', () {
        final result = ImageMetadataStripper.stripMetadataBytes(
          bytes: _jpegWithExif(),
          filename: 'photo.jpeg',
        );

        expect(result.filename, equals('photo.jpeg'));
        expect(
          img.decodeJpgExif(result.bytes)?.gpsIfd['GPSLatitudeRef'],
          isNull,
        );
      });

      test('re-encodes PNG and keeps the .png extension', () {
        final result = ImageMetadataStripper.stripMetadataBytes(
          bytes: _pngBytes(),
          filename: 'avatar.png',
        );

        expect(result.filename, equals('avatar.png'));
        final decoded = img.decodePng(result.bytes);
        expect(decoded, isNotNull);
        expect(decoded!.width, equals(2));
      });

      test(
        'falls back to JPEG re-encode for recognised non-JPEG/PNG formats',
        () {
          final input = _bmpBytes();

          final result = ImageMetadataStripper.stripMetadataBytes(
            bytes: input,
            filename: 'photo.bmp',
          );

          // BMP is decoded then re-encoded as JPEG; extension switches.
          expect(result.filename, equals('photo.jpg'));
          // The first two bytes of a JPEG SOI marker.
          expect(result.bytes[0], equals(0xFF));
          expect(result.bytes[1], equals(0xD8));
        },
      );

      test('returns bytes unchanged when decoding fails entirely', () {
        final input = Uint8List.fromList([0x00, 0x01, 0x02]);

        final result = ImageMetadataStripper.stripMetadataBytes(
          bytes: input,
          filename: 'broken.xyz',
        );

        expect(result.bytes, same(input));
        expect(result.filename, equals('broken.xyz'));
      });

      test('case-insensitive on the filename extension', () {
        final result = ImageMetadataStripper.stripMetadataBytes(
          bytes: _jpegWithExif(),
          filename: 'PHOTO.JPG',
        );

        expect(result.filename, equals('PHOTO.JPG'));
        expect(
          img.decodeJpgExif(result.bytes)?.gpsIfd['GPSLatitudeRef'],
          isNull,
        );
      });
    });

    group('stripJpegExif', () {
      test('strips GPS but preserves orientation', () {
        final result = ImageMetadataStripper.stripJpegExif(_jpegWithExif());

        final exif = img.decodeJpgExif(result);
        expect(exif?.imageIfd.orientation, equals(6));
        expect(exif?.gpsIfd['GPSLatitudeRef'], isNull);
      });

      test('handles JPEG without orientation', () {
        final result = ImageMetadataStripper.stripJpegExif(_jpegNoExif());

        expect(result[0], equals(0xFF));
        expect(result[1], equals(0xD8));
      });

      test('returns non-JPEG bytes unchanged', () {
        final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

        final result = ImageMetadataStripper.stripJpegExif(pngBytes);

        expect(result, equals(pngBytes));
      });

      test('returns too-short bytes unchanged', () {
        final tinyBytes = Uint8List.fromList([0xFF]);

        final result = ImageMetadataStripper.stripJpegExif(tinyBytes);

        expect(result, equals(tinyBytes));
      });
    });

    group('withoutExtension', () {
      test('removes .jpg extension', () {
        expect(
          ImageMetadataStripper.withoutExtension('/path/to/photo.jpg'),
          equals('/path/to/photo'),
        );
      });

      test('removes only last extension', () {
        expect(
          ImageMetadataStripper.withoutExtension('/path/to/file.tar.gz'),
          equals('/path/to/file.tar'),
        );
      });

      test('returns path unchanged when no extension', () {
        expect(
          ImageMetadataStripper.withoutExtension('/path/to/noext'),
          equals('/path/to/noext'),
        );
      });
    });

    group('stripMetadataInPlaceOrThrow', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'image_metadata_stripper_fail_closed_test_',
        );
      });

      tearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('returns the stripped file when the native call succeeds', () async {
        final imageFile = File('${tempDir.path}/photo.jpg');
        await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              final args = call.arguments as Map;
              await File(args['outputPath'] as String).writeAsBytes([
                0xFF,
                0xD8,
                0xFF,
                0xDB,
              ]);
              return null;
            });

        final result = await ImageMetadataStripper.stripMetadataInPlaceOrThrow(
          imageFile,
        );

        expect(result.existsSync(), isTrue);
        expect(await result.readAsBytes(), equals([0xFF, 0xD8, 0xFF, 0xDB]));
      });

      test('throws instead of returning the original when no output is '
          'produced', () async {
        final imageFile = File('${tempDir.path}/photo.jpg');
        await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
        // Handler reports success but creates no output file.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async => null);

        await expectLater(
          () => ImageMetadataStripper.stripMetadataInPlaceOrThrow(imageFile),
          throwsA(isA<FileSystemException>()),
        );
        // The original is left on disk; the caller owns not sending it.
        expect(imageFile.existsSync(), isTrue);
      });

      test('stripMetadataInPlace still fails open and returns the '
          'original', () async {
        final imageFile = File('${tempDir.path}/photo.jpg');
        await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async => null);

        final result = await ImageMetadataStripper.stripMetadataInPlace(
          imageFile,
        );

        expect(result.path, equals(imageFile.path));
      });
    });
  });
}
