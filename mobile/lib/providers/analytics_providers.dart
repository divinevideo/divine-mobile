// ABOUTME: Riverpod providers for analytics service with reactive state management
// ABOUTME: Replaces Provider-based AnalyticsService with StateNotifier pattern

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/models/video_event.dart';
import 'package:openvine/state/analytics_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'analytics_providers.g.dart';

// HTTP client provider for dependency injection
@riverpod
http.Client httpClient(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
}

// SharedPreferences provider
@riverpod
Future<SharedPreferences> sharedPreferences(Ref ref) =>
    SharedPreferences.getInstance();

// Analytics service provider with state management
@riverpod
class Analytics extends _$Analytics {
  static const String _analyticsEndpoint =
      'https://api.openvine.co/analytics/view';
  static const String _analyticsEnabledKey = 'analytics_enabled';
  static const Duration _requestTimeout = Duration(seconds: 10);

  // Track recent views to prevent duplicate tracking
  final Set<String> _recentlyTrackedViews = {};
  Timer? _cleanupTimer;

  @override
  AnalyticsState build() {
    // Set up periodic cleanup of tracked views
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _recentlyTrackedViews.clear();
    });

    ref.onDispose(() {
      _cleanupTimer?.cancel();
    });

    return const AnalyticsState();
  }

  /// Initialize the analytics service
  Future<void> initialize() async {
    if (state.isInitialized) return;

    state = state.copyWith(isLoading: true);

    try {
      // Load analytics preference from storage
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final analyticsEnabled = prefs.getBool(_analyticsEnabledKey) ?? true;

      state = state.copyWith(
        analyticsEnabled: analyticsEnabled,
        isInitialized: true,
        isLoading: false,
        error: null,
      );

      Log.info(
        'Analytics service initialized (enabled: $analyticsEnabled)',
        name: 'AnalyticsProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize analytics service: $e',
        name: 'AnalyticsProvider',
        category: LogCategory.system,
      );
      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Set analytics enabled state
  Future<void> setAnalyticsEnabled(bool enabled) async {
    if (state.analyticsEnabled == enabled) return;

    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setBool(_analyticsEnabledKey, enabled);

      state = state.copyWith(analyticsEnabled: enabled, error: null);

      Log.info(
        'Analytics ${enabled ? 'enabled' : 'disabled'} by user',
        name: 'AnalyticsProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to save analytics preference: $e',
        name: 'AnalyticsProvider',
        category: LogCategory.system,
      );
      state = state.copyWith(error: e.toString());
    }
  }

  /// Track a video view
  Future<void> trackVideoView(
    VideoEvent video, {
    String source = 'mobile',
  }) async {
    // Check if analytics is enabled
    if (!state.analyticsEnabled) {
      Log.debug(
        'Analytics disabled - not tracking view',
        name: 'AnalyticsProvider',
        category: LogCategory.system,
      );
      return;
    }

    final client = ref.read(httpClientProvider);

    try {
      // Prepare view data with hashtags and title
      final viewData = {
        'eventId': video.id,
        'source': source,
        'creatorPubkey': video.pubkey,
        'hashtags': video.hashtags.isNotEmpty ? video.hashtags : null,
        'title': video.title,
      };

      // Log the request details for debugging
      Log.info(
        '📊 Sending analytics request:',
        name: 'AnalyticsProvider',
        category: LogCategory.system,
      );
      Log.info(
        '  URL: $_analyticsEndpoint',
        name: 'AnalyticsProvider',
        category: LogCategory.system,
      );
      Log.info(
        '  Data: ${jsonEncode(viewData)}',
        name: 'AnalyticsProvider',
        category: LogCategory.system,
      );

      // Send view tracking request
      final response = await client
          .post(
            Uri.parse(_analyticsEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'divine-Mobile/1.0',
            },
            body: jsonEncode(viewData),
          )
          .timeout(_requestTimeout);

      // Log the response details
      Log.info(
        '📊 Analytics response:',
        name: 'AnalyticsProvider',
        category: LogCategory.system,
      );
      Log.info(
        '  Status: ${response.statusCode}',
        name: 'AnalyticsProvider',
        category: LogCategory.system,
      );
      Log.info(
        '  Body: ${response.body}',
        name: 'AnalyticsProvider',
        category: LogCategory.system,
      );

      if (response.statusCode == 200) {
        // Update state with successful tracking
        state = state.copyWith(lastEvent: video.id, error: null);

        Log.debug(
          '✅ Successfully tracked view for video ${video.id.length > 8 ? video.id : video.id}...',
          name: 'AnalyticsProvider',
          category: LogCategory.system,
        );
      } else if (response.statusCode == 429) {
        Log.warning(
          '⚠️ Rate limited by analytics service',
          name: 'AnalyticsProvider',
          category: LogCategory.system,
        );
      } else {
        Log.error(
          '❌ Failed to track view: ${response.statusCode} - ${response.body}',
          name: 'AnalyticsProvider',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      // Don't crash the app if analytics fails
      Log.error(
        'Analytics tracking error: $e',
        name: 'AnalyticsProvider',
        category: LogCategory.system,
      );
      // Don't update state with errors to avoid UI disruption
    }
  }

  /// Track multiple video views in batch (for feed loading)
  Future<void> trackVideoViews(
    List<VideoEvent> videos, {
    String source = 'mobile',
  }) async {
    if (!state.analyticsEnabled || videos.isEmpty) return;

    // Track each video view with a small delay between them
    for (final video in videos) {
      await trackVideoView(video, source: source);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Clear tracked views cache
  void clearTrackedViews() {
    _recentlyTrackedViews.clear();
  }
}
