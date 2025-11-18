// ABOUTME: Custom WebSocket-based profile fetcher with authors filter
// ABOUTME: Bypasses nostr_sdk for direct relay communication to ensure authors filter works

import 'dart:async';
import 'dart:convert';
import 'package:nostr_sdk/nostr_sdk.dart' as sdk;
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CustomProfileFetcher {
  static const String DEFAULT_RELAY = 'wss://relay.divine.video';

  /// Fetch user profiles (Kind 0 events) from specific authors
  /// Returns a Future with map of pubkey -> UserProfile
  static Future<Map<String, UserProfile>> fetchProfiles({
    required List<String> authorPubkeys,
    String relayUrl = DEFAULT_RELAY,
    int limit = 100,
  }) async {
    if (authorPubkeys.isEmpty) {
      Log.warning(
        '⚠️ CustomProfileFetcher: No authors provided, returning empty map',
        name: 'CustomProfileFetcher',
        category: LogCategory.system,
      );
      return {};
    }

    final profiles = <String, UserProfile>{};

    Log.debug(
      '👤 CustomProfileFetcher: Connecting to $relayUrl for ${authorPubkeys.length} profiles',
      name: 'CustomProfileFetcher',
      category: LogCategory.system,
    );

    WebSocketChannel? channel;
    StreamSubscription? subscription;

    try {
      // Connect to relay
      final uri = Uri.parse(relayUrl);
      channel = WebSocketChannel.connect(uri);

      await channel.ready;

      Log.debug(
        '✅ CustomProfileFetcher: Connected to $relayUrl',
        name: 'CustomProfileFetcher',
        category: LogCategory.system,
      );

      // Generate subscription ID
      final subId = 'profiles_${DateTime.now().millisecondsSinceEpoch}';

      // Create REQ message with authors filter for Kind 0 (user metadata)
      final reqMessage = [
        'REQ',
        subId,
        {
          'kinds': [0], // Kind 0 = user metadata
          'authors': authorPubkeys, // Filter by authors
          'limit': limit,
        }
      ];

      final reqJson = jsonEncode(reqMessage);
      Log.debug(
        '📨 CustomProfileFetcher: Sending REQ for ${authorPubkeys.length} profiles',
        name: 'CustomProfileFetcher',
        category: LogCategory.system,
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
                '📥 CustomProfileFetcher: Received profile event #$eventCount from ${eventJson['pubkey']?.toString().substring(0, 16)}',
                name: 'CustomProfileFetcher',
                category: LogCategory.system,
              );

              // Verify event is from one of the requested authors (client-side validation)
              final eventAuthor = eventJson['pubkey'] as String?;
              if (eventAuthor == null || !authorPubkeys.contains(eventAuthor)) {
                Log.warning(
                  '🚫 CustomProfileFetcher: Filtering out profile from unauthorized author ${eventAuthor?.substring(0, 16)}',
                  name: 'CustomProfileFetcher',
                  category: LogCategory.system,
                );
                return;
              }

              // Parse as UserProfile
              try {
                final sdkEvent = sdk.Event.fromJson(eventJson);
                final profile = UserProfile.fromNostrEvent(sdkEvent);

                // Store the most recent profile for each pubkey
                // (Nostr replaceable events - only keep latest)
                final existing = profiles[profile.pubkey];
                if (existing == null || profile.createdAt.isAfter(existing.createdAt)) {
                  profiles[profile.pubkey] = profile;

                  Log.debug(
                    '✅ CustomProfileFetcher: Parsed profile for ${profile.pubkey.substring(0, 16)}: ${profile.bestDisplayName}',
                    name: 'CustomProfileFetcher',
                    category: LogCategory.system,
                  );
                }
              } catch (e) {
                Log.error(
                  'Failed to parse profile event: $e',
                  name: 'CustomProfileFetcher',
                  category: LogCategory.system,
                );
              }
            } else if (messageType == 'EOSE') {
              final eoseSubId = decoded[1] as String;
              if (eoseSubId == subId) {
                Log.debug(
                  '🏁 CustomProfileFetcher: EOSE received, got $eventCount profile events',
                  name: 'CustomProfileFetcher',
                  category: LogCategory.system,
                );
                completer.complete();
              }
            }
          } catch (e) {
            Log.error(
              'Error processing message: $e',
              name: 'CustomProfileFetcher',
              category: LogCategory.system,
            );
          }
        },
        onError: (error) {
          Log.error(
            'WebSocket error: $error',
            name: 'CustomProfileFetcher',
            category: LogCategory.system,
          );
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () {
          Log.info(
            '🔌 CustomProfileFetcher: WebSocket closed',
            name: 'CustomProfileFetcher',
            category: LogCategory.system,
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
            '⏱️ CustomProfileFetcher: Timeout waiting for EOSE, got $eventCount profile events',
            name: 'CustomProfileFetcher',
            category: LogCategory.system,
          );
        },
      );

      // Send CLOSE message
      final closeMessage = jsonEncode(['CLOSE', subId]);
      channel.sink.add(closeMessage);

      Log.info(
        '✅ CustomProfileFetcher: Fetch complete - received ${profiles.length} profiles from ${authorPubkeys.length} requested',
        name: 'CustomProfileFetcher',
        category: LogCategory.system,
      );

      return profiles;
    } catch (e) {
      Log.error(
        '❌ CustomProfileFetcher: Error fetching profiles: $e',
        name: 'CustomProfileFetcher',
        category: LogCategory.system,
      );
      rethrow;
    } finally {
      // Clean up
      await subscription?.cancel();
      await channel?.sink.close();
    }
  }
}
