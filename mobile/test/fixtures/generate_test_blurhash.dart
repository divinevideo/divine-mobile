// Script to generate blurhash from test video
// Run with: dart run test/fixtures/generate_test_blurhash.dart

import 'dart:io';

import 'package:openvine/services/blurhash_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';

Future<void> main() async {
  const testVideoPath = 'test/fixtures/test_video.mp4';

  print('Extracting thumbnail from test video...');
  final thumbnailBytes = await VideoThumbnailService.extractThumbnailBytes(
    videoPath: testVideoPath,
    timeMs: 500,
    quality: 75,
  );

  if (thumbnailBytes == null) {
    print('❌ Failed to extract thumbnail');
    exit(1);
  }

  print('✅ Extracted thumbnail: ${thumbnailBytes.length} bytes');

  print('Generating blurhash...');
  final blurhash = await BlurhashService.generateBlurhash(thumbnailBytes);

  if (blurhash == null) {
    print('❌ Failed to generate blurhash');
    exit(1);
  }

  print('✅ Generated blurhash: $blurhash');
  print('');
  print('Use this blurhash in your tests:');
  print('const testBlurhash = \'$blurhash\';');
}
