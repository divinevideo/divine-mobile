// ABOUTME: Service for aggregating NIP-56 kind 1984 report events from Nostr
// ABOUTME: Implements threshold-based content filtering using community reports

import 'dart:async';
import 'dart:convert';

import 'package:nostr_sdk/event.dart' as nostr_sdk;
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_list_service_mixin.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Moderation action recommendations
enum ModerationAction {
  allow, // No action needed
  blur, // Blur preview
  hide, // Hide completely
  block, // Block permanently
}

/// Moderation recommendation based on report aggregation
class ModerationRecommendation {
  const ModerationRecommendation({
    required this.action,
    required this.confidence,
    required this.reason,
  });

  final ModerationAction action;
  final double confidence; // 0.0 to 1.0
  final String reason;

  bool get shouldHide =>
      action == ModerationAction.hide || action == ModerationAction.block;
  bool get shouldBlur => action == ModerationAction.blur || shouldHide;
}

/// Aggregated report data for content
class ReportAggregation {
  const ReportAggregation({
    required this.targetId,
    required this.totalReports,
    required this.reasonCounts,
    required this.reporterPubkeys,
    required this.trustedReporterCount,
    required this.recentReportCount,
    required this.lastReportedAt,
    required this.recommendation,
  });

  final String targetId; // Event or pubkey
  final int totalReports;
  final Map<String, int> reasonCounts;
  final List<String> reporterPubkeys;
  final int trustedReporterCount; // Reports from trusted network
  final int recentReportCount; // Last 7 days
  final DateTime lastReportedAt;
  final ModerationRecommendation recommendation;

  String get primaryReason {
    if (reasonCounts.isEmpty) return 'unknown';
    return reasonCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}

/// Individual report record
class ReportRecord {
  const ReportRecord({
    required this.reportEventId,
    required this.reporterPubkey,
    required this.reportType,
    required this.timestamp,
    this.targetEventId,
    this.targetPubkey,
  });

  final String reportEventId;
  final String? targetEventId;
  final String? targetPubkey;
  final String reporterPubkey;
  final String reportType;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'reportEventId': reportEventId,
    'targetEventId': targetEventId,
    'targetPubkey': targetPubkey,
    'reporterPubkey': reporterPubkey,
    'reportType': reportType,
    'timestamp': timestamp.toIso8601String(),
  };

  static ReportRecord fromJson(Map<String, dynamic> json) => ReportRecord(
    reportEventId: json['reportEventId'],
    targetEventId: json['targetEventId'],
    targetPubkey: json['targetPubkey'],
    reporterPubkey: json['reporterPubkey'],
    reportType: json['reportType'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

/// Service for aggregating NIP-56 kind 1984 report events
class ReportAggregationService with NostrListServiceMixin {
  ReportAggregationService({
    required INostrService nostrService,
    required AuthService authService,
    required SharedPreferences prefs,
  }) : _nostrService = nostrService,
       _authService = authService,
       _prefs = prefs {
    _loadTrustedReporters();
    _loadReportCache();
  }

  final INostrService _nostrService;
  final AuthService _authService;
  final SharedPreferences _prefs;

  // Mixin interface implementations
  @override
  INostrService get nostrService => _nostrService;
  @override
  AuthService get authService => _authService;

  // Storage keys
  static const String trustedReportersKey = 'trusted_reporters';
  static const String reportCacheKey = 'report_cache';

  // State
  final Set<String> _trustedReporters = {};
  final List<ReportRecord> _reports = [];
  final Map<String, List<ReportRecord>> _eventReports = {};
  final Map<String, List<ReportRecord>> _pubkeyReports = {};

  bool _isInitialized = false;

  // Getters
  bool get isInitialized => _isInitialized;
  Set<String> get trustedReporters => Set.unmodifiable(_trustedReporters);

  /// Initialize the service
  Future<void> initialize() async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot initialize report service - user not authenticated',
          name: 'ReportAggregationService',
          category: LogCategory.system,
        );
        return;
      }

      // Subscribe to reports from trusted network if configured
      if (_trustedReporters.isNotEmpty) {
        await _loadReportsFromNetwork();
      }

      _isInitialized = true;
      Log.info(
        'Report service initialized with ${_trustedReporters.length} trusted reporters, ${_reports.length} reports',
        name: 'ReportAggregationService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize report service: $e',
        name: 'ReportAggregationService',
        category: LogCategory.system,
      );
    }
  }

  /// Subscribe to reports from trusted network (follows)
  Future<void> subscribeToNetworkReports(List<String> trustedPubkeys) async {
    try {
      _trustedReporters.clear();
      _trustedReporters.addAll(trustedPubkeys);
      await _saveTrustedReporters();

      // Load reports from these reporters
      await _loadReportsFromNetwork();

      Log.info(
        'Subscribed to reports from ${trustedPubkeys.length} trusted reporters',
        name: 'ReportAggregationService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to subscribe to network reports: $e',
        name: 'ReportAggregationService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Add a report to the aggregation
  Future<void> addReport({
    required String reportEventId,
    String? targetEventId,
    String? targetPubkey,
    required String reporterPubkey,
    required String reportType,
    required DateTime timestamp,
  }) async {
    try {
      final report = ReportRecord(
        reportEventId: reportEventId,
        targetEventId: targetEventId,
        targetPubkey: targetPubkey,
        reporterPubkey: reporterPubkey,
        reportType: reportType,
        timestamp: timestamp,
      );

      _reports.add(report);

      if (targetEventId != null) {
        _eventReports.putIfAbsent(targetEventId, () => []).add(report);
      }

      if (targetPubkey != null) {
        _pubkeyReports.putIfAbsent(targetPubkey, () => []).add(report);
      }

      await _saveReportCache();

      Log.debug(
        'Added report: ${reportEventId}... for ${targetEventId ?? targetPubkey ?? "unknown"}',
        name: 'ReportAggregationService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to add report: $e',
        name: 'ReportAggregationService',
        category: LogCategory.system,
      );
    }
  }

  /// Get aggregated reports for an event
  ReportAggregation getReportsForEvent(String eventId) {
    final reports = _eventReports[eventId] ?? [];
    return _aggregateReports(eventId, reports);
  }

  /// Get aggregated reports for a pubkey
  ReportAggregation getReportsForPubkey(String pubkey) {
    final reports = _pubkeyReports[pubkey] ?? [];
    return _aggregateReports(pubkey, reports);
  }

  /// Check if content exceeds report threshold
  bool exceedsReportThreshold(String targetId, int threshold) {
    final reports = _eventReports[targetId] ?? _pubkeyReports[targetId] ?? [];
    return reports.length >= threshold;
  }

  /// Clean old reports
  Future<void> cleanOldReports({
    Duration maxAge = const Duration(days: 90),
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(maxAge);
      final initialCount = _reports.length;

      _reports.removeWhere((report) => report.timestamp.isBefore(cutoffDate));

      // Rebuild indexes
      _eventReports.clear();
      _pubkeyReports.clear();

      for (final report in _reports) {
        if (report.targetEventId != null) {
          _eventReports
              .putIfAbsent(report.targetEventId!, () => [])
              .add(report);
        }
        if (report.targetPubkey != null) {
          _pubkeyReports
              .putIfAbsent(report.targetPubkey!, () => [])
              .add(report);
        }
      }

      await _saveReportCache();

      final removedCount = initialCount - _reports.length;
      if (removedCount > 0) {
        Log.debug(
          'Cleaned $removedCount old reports',
          name: 'ReportAggregationService',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Failed to clean old reports: $e',
        name: 'ReportAggregationService',
        category: LogCategory.system,
      );
    }
  }

  /// Get service statistics
  Map<String, dynamic> getStats() {
    return {
      'totalReports': _reports.length,
      'eventsReported': _eventReports.length,
      'pubkeysReported': _pubkeyReports.length,
      'trustedReporters': _trustedReporters.length,
    };
  }

  /// Load reports from trusted network
  Future<void> _loadReportsFromNetwork() async {
    try {
      if (_trustedReporters.isEmpty) return;

      Log.debug(
        'Loading reports from ${_trustedReporters.length} trusted reporters',
        name: 'ReportAggregationService',
        category: LogCategory.system,
      );

      // Query for kind 1984 (report) events from trusted reporters
      final filter = Filter(
        authors: _trustedReporters.toList(),
        kinds: [1984], // NIP-56 report events
      );

      final events = await _nostrService.getEvents(filters: [filter]);

      if (events.isEmpty) {
        Log.debug(
          'No reports found from trusted network',
          name: 'ReportAggregationService',
          category: LogCategory.system,
        );
        return;
      }

      // Parse and store reports
      for (final event in events) {
        await _parseReportEvent(event);
      }

      await _saveReportCache();

      Log.debug(
        'Loaded ${events.length} report events from trusted network',
        name: 'ReportAggregationService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to load reports from network: $e',
        name: 'ReportAggregationService',
        category: LogCategory.system,
      );
    }
  }

  /// Parse NIP-56 kind 1984 report event
  Future<void> _parseReportEvent(nostr_sdk.Event event) async {
    try {
      String? targetEventId;
      String? targetPubkey;
      String reportType = 'other';

      for (final tag in event.tags) {
        if (tag.isEmpty) continue;

        final tagType = tag[0];

        switch (tagType) {
          case 'e': // Reported event
            if (tag.length > 1) {
              targetEventId = tag[1];
            }
            break;
          case 'p': // Reported pubkey
            if (tag.length > 1) {
              targetPubkey = tag[1];
            }
            break;
          case 'report': // Report type
            if (tag.length > 1) {
              reportType = tag[1];
            }
            break;
        }
      }

      // Must have at least one target
      if (targetEventId == null && targetPubkey == null) {
        return;
      }

      await addReport(
        reportEventId: event.id,
        targetEventId: targetEventId,
        targetPubkey: targetPubkey,
        reporterPubkey: event.pubkey,
        reportType: reportType,
        timestamp: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      );
    } catch (e) {
      Log.error(
        'Failed to parse report event: $e',
        name: 'ReportAggregationService',
        category: LogCategory.system,
      );
    }
  }

  /// Aggregate reports and generate recommendation
  ReportAggregation _aggregateReports(
    String targetId,
    List<ReportRecord> reports,
  ) {
    if (reports.isEmpty) {
      return ReportAggregation(
        targetId: targetId,
        totalReports: 0,
        reasonCounts: {},
        reporterPubkeys: [],
        trustedReporterCount: 0,
        recentReportCount: 0,
        lastReportedAt: DateTime.now(),
        recommendation: const ModerationRecommendation(
          action: ModerationAction.allow,
          confidence: 1.0,
          reason: 'No reports',
        ),
      );
    }

    // Count reasons
    final reasonCounts = <String, int>{};
    for (final report in reports) {
      reasonCounts[report.reportType] =
          (reasonCounts[report.reportType] ?? 0) + 1;
    }

    // Count trusted reporters
    final trustedCount = reports
        .where((r) => _trustedReporters.contains(r.reporterPubkey))
        .length;

    // Count recent reports (last 7 days)
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentCount = reports
        .where((r) => r.timestamp.isAfter(weekAgo))
        .length;

    // Generate recommendation
    final recommendation = _generateRecommendation(
      totalReports: reports.length,
      trustedCount: trustedCount,
      recentCount: recentCount,
      reasonCounts: reasonCounts,
    );

    return ReportAggregation(
      targetId: targetId,
      totalReports: reports.length,
      reasonCounts: reasonCounts,
      reporterPubkeys: reports.map((r) => r.reporterPubkey).toList(),
      trustedReporterCount: trustedCount,
      recentReportCount: recentCount,
      lastReportedAt: reports.last.timestamp,
      recommendation: recommendation,
    );
  }

  /// Generate moderation recommendation based on report data
  ModerationRecommendation _generateRecommendation({
    required int totalReports,
    required int trustedCount,
    required int recentCount,
    required Map<String, int> reasonCounts,
  }) {
    // Severe violations (CSAM, illegal) - immediate block
    if (reasonCounts['csam'] != null && reasonCounts['csam']! >= 1) {
      return const ModerationRecommendation(
        action: ModerationAction.block,
        confidence: 1.0,
        reason: 'CSAM reports',
      );
    }

    if (reasonCounts['illegal'] != null && reasonCounts['illegal']! >= 2) {
      return const ModerationRecommendation(
        action: ModerationAction.block,
        confidence: 0.9,
        reason: 'Multiple illegal content reports',
      );
    }

    // High report threshold - hide
    if (totalReports >= 5 || trustedCount >= 3) {
      return ModerationRecommendation(
        action: ModerationAction.hide,
        confidence: 0.8,
        reason: '$totalReports reports ($trustedCount from trusted)',
      );
    }

    // Moderate reports - blur
    if (totalReports >= 2 || trustedCount >= 1) {
      return ModerationRecommendation(
        action: ModerationAction.blur,
        confidence: 0.6,
        reason: '$totalReports reports',
      );
    }

    // Low reports - allow
    return const ModerationRecommendation(
      action: ModerationAction.allow,
      confidence: 1.0,
      reason: 'Insufficient reports',
    );
  }

  /// Load trusted reporters from storage
  void _loadTrustedReporters() {
    final json = _prefs.getString(trustedReportersKey);
    if (json != null) {
      try {
        final List<dynamic> reporters = jsonDecode(json);
        _trustedReporters.clear();
        _trustedReporters.addAll(reporters.cast<String>());
        Log.debug(
          'Loaded ${_trustedReporters.length} trusted reporters',
          name: 'ReportAggregationService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load trusted reporters: $e',
          name: 'ReportAggregationService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Save trusted reporters to storage
  Future<void> _saveTrustedReporters() async {
    try {
      await _prefs.setString(
        trustedReportersKey,
        jsonEncode(_trustedReporters.toList()),
      );
    } catch (e) {
      Log.error(
        'Failed to save trusted reporters: $e',
        name: 'ReportAggregationService',
        category: LogCategory.system,
      );
    }
  }

  /// Load report cache from storage
  void _loadReportCache() {
    final json = _prefs.getString(reportCacheKey);
    if (json != null) {
      try {
        final List<dynamic> reportsJson = jsonDecode(json);
        _reports.clear();
        _eventReports.clear();
        _pubkeyReports.clear();

        for (final reportJson in reportsJson) {
          final report = ReportRecord.fromJson(
            reportJson as Map<String, dynamic>,
          );
          _reports.add(report);

          if (report.targetEventId != null) {
            _eventReports
                .putIfAbsent(report.targetEventId!, () => [])
                .add(report);
          }
          if (report.targetPubkey != null) {
            _pubkeyReports
                .putIfAbsent(report.targetPubkey!, () => [])
                .add(report);
          }
        }

        Log.debug(
          'Loaded ${_reports.length} reports from cache',
          name: 'ReportAggregationService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load report cache: $e',
          name: 'ReportAggregationService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Save report cache to storage
  Future<void> _saveReportCache() async {
    try {
      final reportsJson = _reports.map((r) => r.toJson()).toList();
      await _prefs.setString(reportCacheKey, jsonEncode(reportsJson));
    } catch (e) {
      Log.error(
        'Failed to save report cache: $e',
        name: 'ReportAggregationService',
        category: LogCategory.system,
      );
    }
  }

  void dispose() {
    // Clean up any active subscriptions
  }
}
