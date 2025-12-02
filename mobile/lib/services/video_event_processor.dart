// ABOUTME: Service for processing Nostr events into VideoEvent objects
// ABOUTME: Handles event transformation, error recovery, and stream management

import 'dart:async';
import 'dart:convert';

import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service responsible for processing raw Nostr events into VideoEvents
class VideoEventProcessor {
  // Stream controllers for processed events and errors
  final StreamController<VideoEvent> _videoEventController =
      StreamController<VideoEvent>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Active stream subscription
  StreamSubscription<Event>? _eventSubscription;

  // Public streams
  Stream<VideoEvent> get videoEventStream => _videoEventController.stream;
  Stream<String> get errorStream => _errorController.stream;

  /// Process a single event
  void processEvent(Event event) {
    try {
      if (NIP71VideoKinds.isVideoKind(event.kind)) {
        final videoEvent = VideoEvent.fromNostrEvent(event);
        _videoEventController.add(videoEvent);
        Log.debug(
          'Processed video event: ${event.id}',
          name: 'VideoEventProcessor',
          category: LogCategory.video,
        );
      } else if (event.kind == NIP71VideoKinds.repost) {
        // Handle reposts - extract the original video event
        _processRepostEvent(event);
      }
    } catch (e) {
      final errorMessage = 'Error processing video event: $e';
      _errorController.add(errorMessage);
      Log.error(
        errorMessage,
        name: 'VideoEventProcessor',
        category: LogCategory.video,
      );
    }
  }

  /// Connect to a stream of events for processing
  void connectToEventStream(Stream<Event> eventStream) {
    _eventSubscription?.cancel();
    _eventSubscription = eventStream.listen(
      processEvent,
      onError: (error) {
        final errorMessage = error.toString();
        _errorController.add(errorMessage);
        Log.error(
          'Stream error: $errorMessage',
          name: 'VideoEventProcessor',
          category: LogCategory.video,
        );
      },
    );
  }

  /// Disconnect from event stream
  void disconnectFromEventStream() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  void dispose() {
    disconnectFromEventStream();
    _videoEventController.close();
    _errorController.close();
  }

  void _processRepostEvent(Event repostEvent) {
    try {
      // NIP-18: Reposts embed the original event in the content field as JSON
      final originalEventJson = repostEvent.content;

      if (originalEventJson.isEmpty) {
        Log.warning(
          'Repost event ${repostEvent.id} has no content',
          name: 'VideoEventProcessor',
          category: LogCategory.video,
        );
        return;
      }

      // Parse the embedded event JSON
      final Map<String, dynamic> eventData = jsonDecode(originalEventJson);

      // Verify it's a video event kind
      final int kind = eventData['kind'] as int;
      if (!NIP71VideoKinds.isVideoKind(kind)) {
        Log.debug(
          'Repost contains non-video event (kind $kind), skipping',
          name: 'VideoEventProcessor',
          category: LogCategory.video,
        );
        return;
      }

      // Reconstruct the original event from JSON
      final originalEvent = Event.fromJson(eventData);

      // Create VideoEvent from the original event
      final videoEvent = VideoEvent.fromNostrEvent(originalEvent);

      // Create repost version with metadata
      final repostVideoEvent = VideoEvent.createRepostEvent(
        originalEvent: videoEvent,
        repostEventId: repostEvent.id,
        reposterPubkey: repostEvent.pubkey,
        repostedAt: DateTime.fromMillisecondsSinceEpoch(
          repostEvent.createdAt * 1000,
        ),
      );

      // Emit the repost video event
      _videoEventController.add(repostVideoEvent);

      Log.debug(
        'Processed repost ${repostEvent.id} of video ${originalEvent.id}',
        name: 'VideoEventProcessor',
        category: LogCategory.video,
      );
    } catch (e) {
      final errorMessage = 'Error processing repost event: $e';
      _errorController.add(errorMessage);
      Log.error(
        errorMessage,
        name: 'VideoEventProcessor',
        category: LogCategory.video,
      );
    }
  }
}
