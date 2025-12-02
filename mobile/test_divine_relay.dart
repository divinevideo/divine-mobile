// ABOUTME: Direct test of relay.divine.video divine extensions support
// ABOUTME: Sends REQ with sort and int# filters to verify relay behavior

import 'dart:convert';
import 'dart:io';

void main() async {
  print('🧪 Testing relay.divine.video divine extensions...\n');

  // Connect to relay
  final ws = await WebSocket.connect('wss://relay.divine.video');
  print('✅ Connected to relay.divine.video\n');

  // Listen for responses
  ws.listen(
    (message) {
      final decoded = json.decode(message);
      final type = decoded[0];

      if (type == 'EVENT') {
        final event = decoded[2];
        print('📥 EVENT: ${event['id'].substring(0, 8)}');
        print('   Kind: ${event['kind']}');
        print(
          '   Created: ${DateTime.fromMillisecondsSinceEpoch(event['created_at'] * 1000)}',
        );

        // Check for loop count in tags
        final tags = event['tags'] as List;
        for (final tag in tags) {
          if (tag is List && tag.length >= 2) {
            if (tag[0] == 'loop_count') {
              print('   ⭐ Loop Count: ${tag[1]}');
            }
            if (tag[0] == 'likes') {
              print('   ❤️  Likes: ${tag[1]}');
            }
          }
        }
        print('');
      } else if (type == 'EOSE') {
        print('✅ EOSE received for subscription ${decoded[1]}\n');
      } else if (type == 'CLOSED') {
        print('❌ CLOSED: ${decoded[1]} - ${decoded[2]}\n');
      } else if (type == 'NOTICE') {
        print('📢 NOTICE: ${decoded[1]}\n');
      } else {
        print('📨 ${type}: ${decoded}\n');
      }
    },
    onError: (error) => print('❌ WebSocket error: $error'),
    onDone: () => print('🔌 Connection closed'),
  );

  // Wait for connection to stabilize
  await Future.delayed(Duration(milliseconds: 500));

  // Test 1: Basic REQ without divine extensions (baseline)
  print('━━━ TEST 1: Standard REQ (no divine extensions) ━━━');
  final standardReq = json.encode([
    'REQ',
    'test_standard',
    {
      'kinds': [34236, 22, 21],
      'limit': 5,
    },
  ]);
  print('📤 Sending: $standardReq\n');
  ws.add(standardReq);

  await Future.delayed(Duration(seconds: 3));

  // Close standard subscription
  ws.add(json.encode(['CLOSE', 'test_standard']));
  await Future.delayed(Duration(milliseconds: 500));

  // Test 2: REQ with divine extensions (sort by loop_count)
  print('\n━━━ TEST 2: Divine Extensions REQ (sort by loop_count) ━━━');
  final divineReq = json.encode([
    'REQ',
    'test_divine',
    {
      'kinds': [34236, 22, 21],
      'limit': 5,
      'sort': {'field': 'loop_count', 'dir': 'desc'},
    },
  ]);
  print('📤 Sending: $divineReq\n');
  ws.add(divineReq);

  await Future.delayed(Duration(seconds: 3));

  // Close divine subscription
  ws.add(json.encode(['CLOSE', 'test_divine']));
  await Future.delayed(Duration(milliseconds: 500));

  // Test 3: REQ with int# filter
  print('\n━━━ TEST 3: Divine Extensions with int# filter ━━━');
  final intFilterReq = json.encode([
    'REQ',
    'test_int_filter',
    {
      'kinds': [34236, 22, 21],
      'limit': 5,
      'sort': {'field': 'loop_count', 'dir': 'desc'},
      'int#loop_count': {
        'gte': 100, // Only videos with 100+ loops
      },
    },
  ]);
  print('📤 Sending: $intFilterReq\n');
  ws.add(intFilterReq);

  await Future.delayed(Duration(seconds: 3));

  // Close int filter subscription
  ws.add(json.encode(['CLOSE', 'test_int_filter']));
  await Future.delayed(Duration(milliseconds: 500));

  // Cleanup
  print('\n🧹 Closing connection...');
  await ws.close();

  exit(0);
}
