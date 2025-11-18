// ABOUTME: Custom WebSocket-based home feed fetcher with authors filter
// ABOUTME: Bypasses nostr_sdk for direct relay communication to ensure authors filter works

import 'dart:async';
import 'dart:convert';
import 'package:nostr_sdk/nostr_sdk.dart' as sdk;
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CustomHomeFeedFetcher {
  static const String DEFAULT_RELAY = 'wss://relay.divine.video';

  /// Fetch videos from authors you follow
  /// Returns a Future with list of VideoEvent objects
  static Future<List<VideoEvent>> fetchHomeFeedVideos({
    required List<String> authorPubkeys,
    String relayUrl = DEFAULT_RELAY,
    int limit = 100,
  }) async {
    if (authorPubkeys.isEmpty) {
      Log.warning(
        '⚠️ CustomHomeFeedFetcher: No authors provided, returning empty list',
        name: 'CustomHomeFeedFetcher',
        category: LogCategory.video,
      );
      return [];
    }

    final videos = <VideoEvent>[];

    Log.debug(
      '🔍 CustomHomeFeedFetcher: Connecting to $relayUrl for ${authorPubkeys.length} authors',
      name: 'CustomHomeFeedFetcher',
      category: LogCategory.video,
    );

    WebSocketChannel? channel;
    StreamSubscription? subscription;

    try {
      // Connect to relay
      final uri = Uri.parse(relayUrl);
      channel = WebSocketChannel.connect(uri);

      await channel.ready;

      Log.debug(
        '✅ CustomHomeFeedFetcher: Connected to $relayUrl',
        name: 'CustomHomeFeedFetcher',
        category: LogCategory.video,
      );

      // Generate subscription ID
      final subId = 'homefeed_${DateTime.now().millisecondsSinceEpoch}';

      // Create REQ message with authors filter
      final reqMessage = [
        'REQ',
        subId,
        {
          'kinds': [34236], // Only addressable video events
          'authors': authorPubkeys, // Filter by authors
          'limit': limit,
        }
      ];

      final reqJson = jsonEncode(reqMessage);
      Log.debug(
        '📨 CustomHomeFeedFetcher: Sending REQ with ${authorPubkeys.length} authors',
        name: 'CustomHomeFeedFetcher',
        category: LogCategory.video,
      );

      channel.sink.add(reqJson);

      // Listen for events
      int eventCount = 0;
      final completer = Completer<void>();

      subscription = channel.stream.listen(
        (message) {
          try {
            final decoded = jsonDecode(message as String) as List;
            final messageType = decoded[0] as String;

            if (messageType == 'EVENT') {
              final eventSubId = decoded[1] as String;
              if (eventSubId != subId) return;

              final eventJson = decoded[2] as Map<String, dynamic>;
              eventCount++;

              Log.debug(
                '📥 CustomHomeFeedFetcher: Received event #$eventCount from author ${eventJson['pubkey']?.toString().substring(0, 16)}',
                name: 'CustomHomeFeedFetcher',
                category: LogCategory.video,
              );

              // Verify event is from one of the requested authors (client-side validation)
              final eventAuthor = eventJson['pubkey'] as String?;
              if (eventAuthor == null || !authorPubkeys.contains(eventAuthor)) {
                Log.warning(
                  '🚫 CustomHomeFeedFetcher: Filtering out event from unauthorized author ${eventAuthor?.substring(0, 16)}',
                  name: 'CustomHomeFeedFetcher',
                  category: LogCategory.video,
                );
                return;
              }

              // Parse as VideoEvent and add to list
              try {
                final sdkEvent = sdk.Event.fromJson(eventJson);
                final videoEvent = VideoEvent.fromNostrEvent(sdkEvent);
                videos.add(videoEvent);

                Log.debug(
                  '✅ CustomHomeFeedFetcher: Parsed video event: ${videoEvent.id.substring(0, 16)} from ${videoEvent.pubkey.substring(0, 16)}',
                  name: 'CustomHomeFeedFetcher',
                  category: LogCategory.video,
                );
              } catch (e) {
                Log.error(
                  'Failed to parse video event: $e',
                  name: 'CustomHomeFeedFetcher',
                  category: LogCategory.video,
                );
              }
            } else if (messageType == 'EOSE') {
              final eoseSubId = decoded[1] as String;
              if (eoseSubId == subId) {
                Log.debug(
                  '🏁 CustomHomeFeedFetcher: EOSE received, got $eventCount events',
                  name: 'CustomHomeFeedFetcher',
                  category: LogCategory.video,
                );
                completer.complete();
              }
            }
          } catch (e) {
            Log.error(
              'Error processing message: $e',
              name: 'CustomHomeFeedFetcher',
              category: LogCategory.video,
            );
          }
        },
        onError: (error) {
          Log.error(
            'WebSocket error: $error',
            name: 'CustomHomeFeedFetcher',
            category: LogCategory.video,
          );
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () {
          Log.info(
            '🔌 CustomHomeFeedFetcher: WebSocket closed',
            name: 'CustomHomeFeedFetcher',
            category: LogCategory.video,
          );
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Wait for EOSE or timeout (10 seconds)
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Log.warning(
            '⏱️ CustomHomeFeedFetcher: Timeout waiting for EOSE, got $eventCount events',
            name: 'CustomHomeFeedFetcher',
            category: LogCategory.video,
          );
        },
      );

      // Send CLOSE message
      final closeMessage = jsonEncode(['CLOSE', subId]);
      channel.sink.add(closeMessage);

      Log.info(
        '✅ CustomHomeFeedFetcher: Fetch complete - received $eventCount valid events from ${authorPubkeys.length} authors',
        name: 'CustomHomeFeedFetcher',
        category: LogCategory.video,
      );

      return videos;
    } catch (e) {
      Log.error(
        '❌ CustomHomeFeedFetcher: Error fetching home feed: $e',
        name: 'CustomHomeFeedFetcher',
        category: LogCategory.video,
      );
      rethrow;
    } finally {
      // Clean up
      await subscription?.cancel();
      await channel?.sink.close();
    }
  }
}
