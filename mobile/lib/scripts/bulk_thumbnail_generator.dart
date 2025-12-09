// ABOUTME: Bulk thumbnail generation script for videos without thumbnails
// ABOUTME: Fetches video events from default relay and generates thumbnails via API service

import 'dart:io';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/thumbnail_api_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Bulk thumbnail generation script
///
/// This script:
/// 1. Connects to default relay to fetch video events
/// 2. Filters events that don't have thumbnails
/// 3. Makes API requests to generate thumbnails via api.openvine.co thumbnail service
/// 4. Reports progress and statistics
class BulkThumbnailGenerator {
  static final String relayUrl = AppConstants.defaultRelayUrl;
  static const String apiBaseUrl = 'https://api.openvine.co';
  static const int batchSize =
      10; // Process videos in batches to avoid overwhelming the server
  static const int maxVideosToProcess = 1000; // Safety limit

  /// Statistics tracking
  static int totalVideosFound = 0;
  static int videosWithoutThumbnails = 0;
  static int thumbnailsGenerated = 0;
  static int thumbnailsFailed = 0;
  static int videosSkipped = 0;

  /// Main entry point for the script
  static Future<void> main(List<String> args) async {
    Log.info(
      '🚀 divine Bulk Thumbnail Generator',
      name: 'BulkThumbnailGenerator',
    );
    Log.info(
      '====================================',
      name: 'BulkThumbnailGenerator',
    );

    // Parse command line arguments
    final options = _parseArguments(args);

    try {
      // Initialize logging - use existing configuration

      Log.info(
        'Starting bulk thumbnail generation...',
        name: 'BulkThumbnailGenerator',
      );

      // Step 1: Fetch video events from relay
      Log.info(
        'Fetching video events from $relayUrl...',
        name: 'BulkThumbnailGenerator',
      );
      final videoEvents = await _fetchVideoEvents(
        options['limit'] ?? maxVideosToProcess,
      );

      if (videoEvents.isEmpty) {
        Log.warning(
          '❌ No video events found. Exiting.',
          name: 'BulkThumbnailGenerator',
        );
        return;
      }

      // Step 2: Filter events without thumbnails
      final eventsWithoutThumbnails = _filterEventsWithoutThumbnails(
        videoEvents,
      );

      // Step 3: Generate thumbnails in batches
      await _generateThumbnailsInBatches(eventsWithoutThumbnails, options);

      // Step 4: Print final statistics
      _printFinalStatistics();
    } catch (e, stackTrace) {
      Log.error('Script failed: $e', name: 'BulkThumbnailGenerator');
      Log.error('Stack trace: $stackTrace', name: 'BulkThumbnailGenerator');
      Log.error('❌ Script failed: $e', name: 'BulkThumbnailGenerator');
      exit(1);
    }
  }

  /// Parse command line arguments
  static Map<String, dynamic> _parseArguments(List<String> args) {
    final options = <String, dynamic>{};

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--limit':
        case '-l':
          if (i + 1 < args.length) {
            options['limit'] = int.tryParse(args[i + 1]) ?? maxVideosToProcess;
            i++; // Skip next argument
          }
        case '--dry-run':
        case '-d':
          options['dryRun'] = true;
        case '--batch-size':
        case '-b':
          if (i + 1 < args.length) {
            options['batchSize'] = int.tryParse(args[i + 1]) ?? batchSize;
            i++; // Skip next argument
          }
        case '--time-offset':
        case '-t':
          if (i + 1 < args.length) {
            options['timeOffset'] = double.tryParse(args[i + 1]) ?? 2.5;
            i++; // Skip next argument
          }
        case '--help':
        case '-h':
          _printUsage();
          return options; // Return instead of exit
      }
    }

    return options;
  }

  /// Print usage information
  static void _printUsage() {
    Log.info('''
Usage: dart bulk_thumbnail_generator.dart [options]

Options:
  -l, --limit <number>       Maximum number of videos to process (default: $maxVideosToProcess)
  -d, --dry-run             Don't actually generate thumbnails, just report what would be done
  -b, --batch-size <number>  Number of videos to process in each batch (default: $batchSize)
  -t, --time-offset <number> Time offset in seconds for thumbnail extraction (default: 2.5)
  -h, --help                Show this help message

Examples:
  dart bulk_thumbnail_generator.dart --limit 100 --dry-run
  dart bulk_thumbnail_generator.dart --batch-size 5 --time-offset 3.0
    ''');
  }

  /// Fetch video events from the relay using Nostr WebSocket connection
  static Future<List<VideoEvent>> _fetchVideoEvents(int limit) async {
    final videoEvents = <VideoEvent>[];

    try {
      Log.info(
        'Connecting to Nostr relay to fetch video events...',
        name: 'BulkThumbnailGenerator',
      );

      // Create Nostr service to connect to relay
      final keyManager = NostrKeyManager();
      final nostrService = NostrService(keyManager);

      // Initialize with only the relay we want to query
      await nostrService.initialize(customRelays: [relayUrl]);

      // Create filter for video events
      final filter = Filter(
        kinds: [34236], // Kind 34236 addressable short video events
        limit: limit,
      );

      Log.info(
        'Subscribing to video events with limit: $limit',
        name: 'BulkThumbnailGenerator',
      );

      // Subscribe to events and collect them
      final subscription = nostrService.subscribeToEvents(filters: [filter]);
      final eventCount = <int>[0]; // Use list to allow modification in callback

      await for (final event in subscription) {
        try {
          final videoEvent = VideoEvent.fromNostrEvent(event);
          videoEvents.add(videoEvent);
          eventCount[0]++;

          Log.info(
            'Received event ${eventCount[0]}/$limit: ${event.id}',
            name: 'BulkThumbnailGenerator',
          );

          // Stop when we reach the limit
          if (eventCount[0] >= limit) {
            break;
          }
        } catch (e) {
          Log.warning(
            'Failed to parse event ${event.id}: $e',
            name: 'BulkThumbnailGenerator',
          );
        }
      }

      // Clean up
      await nostrService.closeAllSubscriptions();
      nostrService.dispose();
    } catch (e) {
      Log.error(
        'Failed to fetch events from relay: $e',
        name: 'BulkThumbnailGenerator',
      );

      // Fallback: return sample events for testing
      Log.info(
        'Using fallback sample events for testing...',
        name: 'BulkThumbnailGenerator',
      );
      return _getSampleVideoEvents();
    }

    return videoEvents;
  }

  /// Filter events that don't have thumbnails
  static List<VideoEvent> _filterEventsWithoutThumbnails(
    List<VideoEvent> events,
  ) {
    final filtered = <VideoEvent>[];

    for (final event in events) {
      if (event.effectiveThumbnailUrl == null) {
        filtered.add(event);
        videosWithoutThumbnails++;
      }
    }

    Log.info(
      '📊 Found $totalVideosFound total video events',
      name: 'BulkThumbnailGenerator',
    );
    Log.info(
      '📊 $videosWithoutThumbnails videos without thumbnails',
      name: 'BulkThumbnailGenerator',
    );
    Log.info(
      '📊 ${totalVideosFound - videosWithoutThumbnails} videos already have thumbnails',
      name: 'BulkThumbnailGenerator',
    );

    return filtered;
  }

  /// Generate thumbnails in batches
  static Future<void> _generateThumbnailsInBatches(
    List<VideoEvent> events,
    Map<String, dynamic> options,
  ) async {
    final isDryRun = options['dryRun'] == true;
    final batchSizeToUse = (options['batchSize'] as int?) ?? batchSize;
    final timeOffset = options['timeOffset'] ?? 2.5;

    if (isDryRun) {
      Log.info(
        '🔍 DRY RUN: Would generate thumbnails for ${events.length} videos',
      );
      return;
    }

    Log.info(
      '🎬 Generating thumbnails for ${events.length} videos...',
      name: 'BulkThumbnailGenerator',
    );
    Log.info('⚙️ Batch size: $batchSizeToUse', name: 'BulkThumbnailGenerator');
    Log.info('⏱️ Time offset: ${timeOffset}s', name: 'BulkThumbnailGenerator');

    for (var i = 0; i < events.length; i += batchSizeToUse) {
      final batch = events.skip(i).take(batchSizeToUse).toList();
      final batchNumber = (i ~/ batchSizeToUse) + 1;
      final totalBatches = (events.length / batchSizeToUse).ceil();

      Log.info(
        '\n📦 Processing batch $batchNumber/$totalBatches (${batch.length} videos)...',
      );

      // Process batch concurrently but with limited concurrency
      final futures = batch.map(
        (event) => _generateThumbnailForEvent(event, timeOffset),
      );
      await Future.wait(futures);

      // Brief pause between batches to avoid overwhelming the server
      if (i + batchSizeToUse < events.length) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  /// Generate thumbnail for a single video event
  static Future<void> _generateThumbnailForEvent(
    VideoEvent event,
    double timeOffset,
  ) async {
    try {
      Log.info(
        'Generating thumbnail for video ${event.id}...',
        name: 'BulkThumbnailGenerator',
      );

      final thumbnailUrl = await ThumbnailApiService.getThumbnailWithFallback(
        event.id,
        timeSeconds: timeOffset,
        size: ThumbnailSize.medium,
      );

      if (thumbnailUrl != null) {
        thumbnailsGenerated++;
        Log.info('✅ Generated thumbnail for ${event.id}: $thumbnailUrl');
      } else {
        thumbnailsFailed++;
        Log.info('❌ Failed to generate thumbnail for ${event.id}');
      }
    } catch (e) {
      thumbnailsFailed++;
      Log.error(
        'Failed to generate thumbnail for ${event.id}: $e',
        name: 'BulkThumbnailGenerator',
      );
      Log.info('❌ Error generating thumbnail for ${event.id}: $e');
    }
  }

  /// Print final statistics
  static void _printFinalStatistics() {
    Log.info('\n📈 FINAL STATISTICS', name: 'BulkThumbnailGenerator');
    Log.info('===================', name: 'BulkThumbnailGenerator');
    Log.info(
      'Total videos found: $totalVideosFound',
      name: 'BulkThumbnailGenerator',
    );
    Log.info(
      'Videos without thumbnails: $videosWithoutThumbnails',
      name: 'BulkThumbnailGenerator',
    );
    Log.info(
      'Thumbnails generated: $thumbnailsGenerated',
      name: 'BulkThumbnailGenerator',
    );
    Log.info(
      'Thumbnails failed: $thumbnailsFailed',
      name: 'BulkThumbnailGenerator',
    );
    Log.info('Videos skipped: $videosSkipped', name: 'BulkThumbnailGenerator');

    final successRate = videosWithoutThumbnails > 0
        ? (thumbnailsGenerated / videosWithoutThumbnails * 100.0)
              .toStringAsFixed(1)
        : '0.0';
    Log.info('Success rate: $successRate%', name: 'BulkThumbnailGenerator');

    if (thumbnailsGenerated > 0) {
      Log.info(
        '🎉 Successfully generated $thumbnailsGenerated thumbnails!',
        name: 'BulkThumbnailGenerator',
      );
    }

    if (thumbnailsFailed > 0) {
      Log.info(
        '⚠️ $thumbnailsFailed thumbnails failed to generate',
        name: 'BulkThumbnailGenerator',
      );
    }
  }

  /// Get sample video events for testing when relay is unavailable
  static List<VideoEvent> _getSampleVideoEvents() => [
    VideoEvent(
      id: '87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344',
      pubkey:
          '0461fcbecc4c3374439932d6b8f11269ccdb7cc973ad7a50ae362db135a474dd',
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      content: 'Sample video without thumbnail',
      timestamp: DateTime.now(),
      videoUrl:
          'https://blossom.primal.net/87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344.mp4',
      thumbnailUrl: null, // No thumbnail
      duration: 5,
      hashtags: ['sample', 'test'],
    ),
  ];
}

/// Mock Nostr event for testing

/// Entry point when run as script
void main(List<String> args) async {
  await BulkThumbnailGenerator.main(args);
}
