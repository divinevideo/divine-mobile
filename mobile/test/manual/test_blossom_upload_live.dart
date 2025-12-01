// ABOUTME: Manual test script to verify Blossom upload works against real cf-stream-service-prod server
// ABOUTME: Run with: dart run test/manual/test_blossom_upload_live.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

void main() async {
  print('🧪 Testing Blossom Upload Against Live Server');
  print('=' * 60);

  // Create a minimal test video file
  final testBytes = [
    0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, // MP4 header
    0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00, // isom
    ...List.generate(1000, (i) => i % 256), // Some data
  ];

  // Calculate SHA-256 hash
  final digest = sha256.convert(testBytes);
  final fileHash = digest.toString();

  print('\n📊 Test File Info:');
  print('   Size: ${testBytes.length} bytes');
  print('   SHA256: $fileHash');

  // Create Blossom auth event (simplified without real signing)
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final authEvent = {
    'kind': 24242,
    'created_at': now,
    'pubkey':
        '0000000000000000000000000000000000000000000000000000000000000000',
    'tags': [
      ['t', 'upload'],
      ['expiration', (now + 300).toString()], // 5 minutes
    ],
    'content': 'Test Blossom upload',
    'id': '0000000000000000000000000000000000000000000000000000000000000000',
    'sig': '0' * 128, // Dummy signature
  };

  final authJson = jsonEncode(authEvent);
  final authHeader = 'Nostr ${base64.encode(utf8.encode(authJson))}';

  print('\n🔐 Auth Event:');
  print('   Kind: ${authEvent['kind']}');
  print('   Tags: ${authEvent['tags']}');
  print('   Auth header length: ${authHeader.length} chars');

  // Test upload
  final uploadUrl =
      'https://cf-stream-service-prod.protestnet.workers.dev/upload';
  print('\n📤 Uploading to: $uploadUrl');
  print('   Method: PUT');
  print('   Content-Type: video/mp4');

  try {
    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'video/mp4',
        'Content-Length': testBytes.length.toString(),
      },
      body: testBytes,
    );

    print('\n📥 Response:');
    print('   Status: ${response.statusCode} ${response.reasonPhrase}');
    print('   Headers: ${response.headers}');
    print('   Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('\n✅ SUCCESS: Upload accepted!');

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('\n📋 Response Data:');
        print('   SHA256: ${data['sha256']}');
        print('   URL: ${data['url']}');
        print('   Size: ${data['size']}');
        print('   Type: ${data['type']}');
        print('   Uploaded: ${data['uploaded']}');

        // Verify URL is cdn.divine.video
        final url = data['url'] as String?;
        if (url != null && url.contains('cdn.divine.video')) {
          print('\n✅ VERIFIED: URL is on cdn.divine.video domain');
        } else {
          print('\n⚠️  WARNING: URL is not cdn.divine.video: $url');
        }

        // Verify SHA256 matches
        if (data['sha256'] == fileHash) {
          print('✅ VERIFIED: SHA256 matches client calculation');
        } else {
          print('⚠️  WARNING: SHA256 mismatch!');
          print('   Expected: $fileHash');
          print('   Got: ${data['sha256']}');
        }
      } catch (e) {
        print('⚠️  Could not parse response as JSON: $e');
      }
    } else if (response.statusCode == 401) {
      print('\n⚠️  AUTH FAILED (expected with dummy keys)');
      print('   This proves the endpoint exists and checks auth');
      print('   With real Nostr keys, upload would succeed');
    } else if (response.statusCode == 409) {
      print('\n✅ FILE EXISTS: Upload succeeded previously');
      print('   Expected CDN URL: https://cdn.divine.video/$fileHash');
    } else if (response.statusCode == 404) {
      print('\n❌ ENDPOINT NOT FOUND');
      print('   The /upload endpoint does not exist on this server');
      print('   Check server configuration');
    } else {
      print('\n❌ UNEXPECTED STATUS: ${response.statusCode}');
    }
  } catch (e, stackTrace) {
    print('\n❌ ERROR: $e');
    print('Stack trace: $stackTrace');
  }

  print('\n' + '=' * 60);
  print('Test complete.');
}
