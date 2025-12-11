// Standalone script to test Blossom upload with real HTTP
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/event.dart';

Future<void> main() async {
  print('🧪 Testing Blossom Upload to Real Server\n');

  // Create test video file
  final testFile = File('/tmp/test_video_upload.mp4');
  final testData = Uint8List.fromList([
    0x00,
    0x00,
    0x00,
    0x20,
    0x66,
    0x74,
    0x79,
    0x70,
    0x69,
    0x73,
    0x6F,
    0x6D,
    0x00,
    0x00,
    0x02,
    0x00,
    ...List.filled(1000, 0x00),
  ]);
  await testFile.writeAsBytes(testData);
  print('📁 Created test file: ${testFile.path} (${testData.length} bytes)');

  // Generate test keys
  final keychain = Keychain.generate();
  print('🔑 Generated keypair: ${keychain.public.substring(0, 16)}...\n');

  // Calculate file hash
  final fileBytes = await testFile.readAsBytes();
  final fileHash = sha256.convert(fileBytes).toString();
  final fileSize = fileBytes.length;
  print('📊 File hash: $fileHash');
  print('📊 File size: $fileSize bytes\n');

  // Create auth event
  final now = DateTime.now();
  final expiration = now.add(Duration(minutes: 5));
  final event = Event(
    keychain.public,
    24242, // Blossom auth kind
    [
      ['t', 'upload'],
      ['expiration', '${expiration.millisecondsSinceEpoch ~/ 1000}'],
      ['x', fileHash],
    ],
    'Upload video to Blossom server',
  );

  // Sign event
  event.sign(keychain.private);
  print('🔐 Created and signed auth event: ${event.id}\n');

  // Prepare upload
  final serverUrl = 'https://cf-stream-service-prod.protestnet.workers.dev';
  final authHeader =
      'Nostr ${base64.encode(utf8.encode(jsonEncode(event.toJson())))}';

  print('📤 Uploading to: $serverUrl/upload');
  print('🔐 Auth header length: ${authHeader.length} chars\n');

  // Upload with PUT raw bytes
  final dio = Dio();
  try {
    final response = await dio.put(
      '$serverUrl/upload',
      data: Stream.fromIterable(fileBytes.map((e) => [e])),
      options: Options(
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'video/mp4',
          'Content-Length': '$fileSize',
        },
      ),
    );

    print('✅ Response: ${response.statusCode}');
    print('📦 Data: ${response.data}\n');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final url = response.data['url'];
      print('🎉 SUCCESS! Video uploaded to: $url');
    } else {
      print('❌ Upload failed with status ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    // Cleanup
    if (await testFile.exists()) {
      await testFile.delete();
    }
  }
}
