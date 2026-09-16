// ABOUTME: Resolves moderation decisions for a video hash to improve playback UX.
// ABOUTME: Used to distinguish missing media from moderation-blocked content.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/utils/blossom_blob_hash.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service provider for moderation status lookups.
final videoModerationStatusServiceProvider =
    Provider<VideoModerationStatusService>((ref) {
      final service = VideoModerationStatusService(
        httpClient: ref.watch(instrumentedHttpClientFactoryProvider)(),
      );
      ref.onDispose(service.dispose);
      return service;
    });

/// Fetch moderation status for a sha256 hash.
// ignore: specify_nonobvious_property_types
final videoModerationStatusProvider =
    FutureProvider.family<VideoModerationStatus?, String?>((ref, sha256) {
      final normalized = VideoModerationStatusService.normalizeSha256(sha256);
      if (normalized == null) {
        return null;
      }

      final service = ref.watch(videoModerationStatusServiceProvider);
      return service.fetchStatus(normalized);
    });

/// Parsed moderation status returned by the check-result endpoint.
class VideoModerationStatus {
  const VideoModerationStatus({
    required this.moderated,
    required this.blocked,
    required this.quarantined,
    required this.ageRestricted,
    required this.needsReview,
    required this.aiGenerated,
    this.action,
    this.aiScore,
  });

  final bool moderated;
  final bool blocked;
  final bool quarantined;
  final bool ageRestricted;
  final bool needsReview;
  final bool aiGenerated;
  final String? action;

  /// Raw AI generation score (0.0–1.0) from the moderation service, if any.
  final double? aiScore;

  bool get isUnavailableDueToModeration =>
      blocked || quarantined || ageRestricted;

  bool get isAiGeneratedBlocked => isUnavailableDueToModeration && aiGenerated;

  factory VideoModerationStatus.fromCheckResultJson(Map<String, dynamic> json) {
    final action = json['action']?.toString();
    final normalizedAction = action?.toUpperCase();
    final blocked = json['blocked'] == true;
    final quarantined =
        json['quarantined'] == true || normalizedAction == 'QUARANTINE';
    final ageRestricted = json['age_restricted'] == true;
    final moderated = json['moderated'] == true;
    final needsReview = json['needs_review'] == true;
    final categories = json['categories'];
    final scores = json['scores'];

    final rawAiScore = _extractAiScore(scores);
    final aiGenerated =
        _containsAiSignal(categories) ||
        (rawAiScore != null && rawAiScore >= 0.8);

    return VideoModerationStatus(
      moderated: moderated,
      blocked: blocked,
      quarantined: quarantined,
      ageRestricted: ageRestricted,
      needsReview: needsReview,
      aiGenerated: aiGenerated,
      action: action,
      aiScore: rawAiScore,
    );
  }

  static bool _containsAiSignal(dynamic categories) {
    if (categories == null) return false;

    bool containsAiText(String text) {
      final lower = text.toLowerCase();
      return lower.contains('ai_generated') ||
          lower.contains('ai-generated') ||
          lower.contains('deepfake');
    }

    if (categories is String) {
      return containsAiText(categories);
    }

    if (categories is Iterable) {
      for (final value in categories) {
        if (value is String && containsAiText(value)) {
          return true;
        }
      }
    }

    if (categories is Map) {
      for (final entry in categories.entries) {
        if (entry.key is String && containsAiText(entry.key as String)) {
          return true;
        }
        final value = entry.value;
        if (value is String && containsAiText(value)) {
          return true;
        }
      }
    }

    return false;
  }

  static double? _extractAiScore(dynamic scores) {
    if (scores is! Map) return null;
    final aiScore = scores['ai_generated'];
    if (aiScore is num) {
      return aiScore.toDouble();
    }
    return null;
  }
}

class _CachedModerationStatus {
  const _CachedModerationStatus({required this.status, required this.cachedAt});

  final VideoModerationStatus? status;
  final DateTime cachedAt;
}

/// Service that fetches moderation decision from public check-result endpoint.
class VideoModerationStatusService {
  VideoModerationStatusService({
    http.Client? httpClient,
    List<Uri>? endpointBases,
    Duration? cacheTtl,
    Duration? requestTimeout,
  }) : _httpClient = httpClient ?? http.Client(),
       _endpointBases =
           endpointBases ??
           [
             EnvironmentConfig.production.moderationApiBaseUrl,
           ].map(Uri.parse).toList(),
       _cacheTtl = cacheTtl ?? const Duration(minutes: 10),
       _requestTimeout = requestTimeout ?? _defaultRequestTimeout;

  static const _defaultRequestTimeout = Duration(seconds: 3);
  static const _userAgent = 'DivineMobile/1.0';

  final http.Client _httpClient;
  final List<Uri> _endpointBases;
  final Duration _cacheTtl;
  final Duration _requestTimeout;

  final Map<String, _CachedModerationStatus> _cache = {};
  final Map<String, Future<VideoModerationStatus?>> _inflight = {};

  Future<VideoModerationStatus?> fetchStatus(String sha256) async {
    final normalized = normalizeSha256(sha256);
    if (normalized == null) return null;

    final now = DateTime.now();
    final cached = _cache[normalized];
    if (cached != null && now.difference(cached.cachedAt) < _cacheTtl) {
      return cached.status;
    }

    final pending = _inflight[normalized];
    if (pending != null) return pending;

    final request = _fetchAndClear(normalized);
    _inflight[normalized] = request;
    return request;
  }

  Future<VideoModerationStatus?> _fetchAndClear(String sha256) async {
    try {
      return await _fetchFresh(sha256);
    } finally {
      final _ = _inflight.remove(sha256);
    }
  }

  Future<VideoModerationStatus?> _fetchFresh(String sha256) async {
    for (final base in _endpointBases) {
      final uri = base.resolve('/check-result/$sha256');
      try {
        final response = await _httpClient
            .get(
              uri,
              headers: const {'user-agent': _userAgent},
            )
            .timeout(_requestTimeout);
        if (response.statusCode != 200) {
          continue;
        }

        final payload = jsonDecode(response.body);
        if (payload is! Map<String, dynamic>) {
          continue;
        }

        final status = VideoModerationStatus.fromCheckResultJson(payload);
        _cache[sha256] = _CachedModerationStatus(
          status: status,
          cachedAt: DateTime.now(),
        );
        return status;
      } catch (e) {
        Log.debug(
          'Moderation status lookup failed for $sha256 via $uri: $e',
          name: 'VideoModerationStatusService',
          category: LogCategory.video,
        );
      }
    }

    _cache[sha256] = _CachedModerationStatus(
      status: null,
      cachedAt: DateTime.now(),
    );
    return null;
  }

  void dispose() {
    _httpClient.close();
    _cache.clear();
    _inflight.clear();
  }

  static String? normalizeSha256(String? sha256) {
    return normalizeSha256Hash(sha256);
  }

  static bool shouldCheckModeration(String? videoUrl) {
    if (videoUrl == null || videoUrl.isEmpty) return false;
    try {
      final uri = Uri.parse(videoUrl);
      final host = uri.host.toLowerCase();
      return host.endsWith('divine.video') || host.endsWith('openvine.co');
    } catch (_) {
      return false;
    }
  }

  static String? extractSha256FromVideoUrl(String? videoUrl) {
    return extractSha256FromBlossomUrl(videoUrl);
  }

  static String? resolveSha256({String? explicitSha256, String? videoUrl}) {
    return normalizeSha256(explicitSha256) ??
        extractSha256FromVideoUrl(videoUrl);
  }
}
