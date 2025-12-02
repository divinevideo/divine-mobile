// ABOUTME: Test script to debug subscription ID mismatch issue
// ABOUTME: Connects to relay and tracks subscription IDs

import 'dart:convert';
import 'dart:io';

import 'package:openvine/utils/unified_logger.dart';
import 'package:web_socket_channel/io.dart';

void main() async {
  Log.debug('=== Relay Subscription Test ===\n');

  // Track subscriptions we create
  final ourSubscriptions = <String>{};

  try {
    final wsUrl = Uri.parse('wss://staging-relay.divine.video');
    final channel = IOWebSocketChannel.connect(wsUrl);

    Log.debug('1. Connecting to $wsUrl...');

    // Listen for messages
    channel.stream.listen(
      (message) {
        final data = jsonDecode(message);

        if (data is List && data.isNotEmpty) {
          final messageType = data[0];

          if (messageType == 'AUTH') {
            Log.debug('\n🔐 AUTH challenge: ${data[1]}');
            // For this test, we won't authenticate
          } else if (messageType == 'EVENT' && data.length >= 3) {
            final subId = data[1];
            Log.debug('\n📨 EVENT for subscription: $subId');
            if (ourSubscriptions.contains(subId)) {
              Log.debug('   ✅ This is OUR subscription!');
            } else {
              Log.debug('   ⚠️ Unknown subscription ID');
            }
          } else if (messageType == 'EOSE' && data.length >= 2) {
            final subId = data[1];
            Log.debug('\n📭 EOSE for subscription: $subId');
          } else if (messageType == 'NOTICE') {
            Log.debug('\n📢 NOTICE: ${data[1]}');
          }
        }
      },
      onError: (error) => Log.debug('❌ Error: $error'),
      onDone: () => Log.debug('🔌 Connection closed'),
    );

    // Wait for AUTH challenges
    await Future.delayed(const Duration(seconds: 2));

    // Create a subscription
    final subId = 'test_${DateTime.now().millisecondsSinceEpoch}';
    ourSubscriptions.add(subId);

    Log.debug('\n2. Creating subscription with ID: $subId');

    final req = jsonEncode([
      'REQ',
      subId,
      {
        'kinds': [32222],
        'limit': 5,
      },
    ]);

    Log.debug('   Sending: $req');
    channel.sink.add(req);

    // Wait for events
    await Future.delayed(const Duration(seconds: 5));

    // Close subscription
    Log.debug('\n3. Closing subscription...');
    channel.sink.add(jsonEncode(['CLOSE', subId]));

    await Future.delayed(const Duration(seconds: 1));
    await channel.sink.close();
  } catch (e) {
    Log.debug('Error: $e');
  }

  exit(0);
}
