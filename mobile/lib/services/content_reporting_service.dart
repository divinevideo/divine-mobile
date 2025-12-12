// ABOUTME: Content reporting service for user-generated content violations
// ABOUTME: Implements NIP-56 reporting events (kind 1984) for Apple compliance and community-driven moderation

import 'dart:convert';

import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Report submission result
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ReportResult {
  const ReportResult({
    required this.success,
    required this.timestamp,
    this.error,
    this.reportId,
  });
  final bool success;
  final String? error;
  final String? reportId;
  final DateTime timestamp;

  static ReportResult createSuccess(String reportId) => ReportResult(
    success: true,
    reportId: reportId,
    timestamp: DateTime.now(),
  );

  static ReportResult failure(String error) =>
      ReportResult(success: false, error: error, timestamp: DateTime.now());
}

/// Content report data
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ContentReport {
  const ContentReport({
    required this.reportId,
    required this.eventId,
    required this.reason,
    required this.details,
    required this.createdAt,
    this.authorPubkey,
    this.additionalContext,
    this.tags = const [],
  });
  final String reportId;
  final String eventId;
  final String? authorPubkey;
  final ContentFilterReason reason;
  final String details;
  final DateTime createdAt;
  final String? additionalContext;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
    'reportId': reportId,
    'eventId': eventId,
    'authorPubkey': authorPubkey,
    'reason': reason.name,
    'details': details,
    'createdAt': createdAt.toIso8601String(),
    'additionalContext': additionalContext,
    'tags': tags,
  };

  static ContentReport fromJson(Map<String, dynamic> json) => ContentReport(
    reportId: json['reportId'],
    eventId: json['eventId'],
    authorPubkey: json['authorPubkey'],
    reason: ContentFilterReason.values.firstWhere(
      (r) => r.name == json['reason'],
      orElse: () => ContentFilterReason.other,
    ),
    details: json['details'],
    createdAt: DateTime.parse(json['createdAt']),
    additionalContext: json['additionalContext'],
    tags: List<String>.from(json['tags'] ?? []),
  );
}

/// Service for reporting inappropriate content
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ContentReportingService {
  ContentReportingService({
    required NostrClient nostrService,
    required NostrKeyManager keyManager,
    required SharedPreferences prefs,
  }) : _nostrService = nostrService,
       _keyManager = keyManager,
       _prefs = prefs {
    _loadReportHistory();
  }
  final NostrClient _nostrService;
  final NostrKeyManager _keyManager;
  final SharedPreferences _prefs;

  // divine moderation relay for reports
  static const String moderationRelayUrl =
      'wss://relay.divine.video'; // Divine moderation relay
  static const String reportsStorageKey = 'content_reports_history';

  final List<ContentReport> _reportHistory = [];
  bool _isInitialized = false;

  // Getters
  List<ContentReport> get reportHistory => List.unmodifiable(_reportHistory);
  bool get isInitialized => _isInitialized;

  /// Initialize reporting service
  Future<void> initialize() async {
    try {
      // Ensure Nostr service is initialized
      if (!_nostrService.isInitialized) {
        Log.warning(
          'Nostr service not initialized, cannot setup reporting',
          name: 'ContentReportingService',
          category: LogCategory.system,
        );
        return;
      }

      _isInitialized = true;
      Log.info(
        'Content reporting service initialized',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize content reporting: $e',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
    }
  }

  /// Report content for violation
  Future<ReportResult> reportContent({
    required String eventId,
    required String authorPubkey,
    required ContentFilterReason reason,
    required String details,
    String? additionalContext,
    List<String> hashtags = const [],
  }) async {
    try {
      if (!_isInitialized) {
        return ReportResult.failure('Reporting service not initialized');
      }

      // Generate report ID
      final reportId = 'report_${DateTime.now().millisecondsSinceEpoch}';

      // Create and broadcast NIP-56 reporting event (kind 1984)
      final reportEvent = await _createReportingEvent(
        reportId: reportId,
        eventId: eventId,
        authorPubkey: authorPubkey,
        reason: reason,
        details: details,
        additionalContext: additionalContext,
        hashtags: hashtags,
      );

      if (reportEvent != null) {
        final broadcastResult = await _nostrService.broadcast(reportEvent);
        if (broadcastResult.successCount == 0) {
          Log.error(
            'Failed to broadcast report to relays',
            name: 'ContentReportingService',
            category: LogCategory.system,
          );
          // Still save locally even if broadcast fails
        } else {
          Log.info(
            'Report broadcast to ${broadcastResult.successCount} relays',
            name: 'ContentReportingService',
            category: LogCategory.system,
          );
        }
      }

      // Create Zendesk ticket silently for moderation tracking
      await _createZendeskTicket(
        reportId: reportId,
        eventId: eventId,
        authorPubkey: authorPubkey,
        reason: reason,
        details: details,
        additionalContext: additionalContext,
      );

      // Save report to local history
      final report = ContentReport(
        reportId: reportId,
        eventId: eventId,
        authorPubkey: authorPubkey,
        reason: reason,
        details: details,
        createdAt: DateTime.now(),
        additionalContext: additionalContext,
        tags: hashtags,
      );

      _reportHistory.add(report);
      await _saveReportHistory();

      Log.debug(
        'Content report submitted: $reportId',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
      return ReportResult.createSuccess(reportId);
    } catch (e) {
      Log.error(
        'Failed to submit content report: $e',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
      return ReportResult.failure('Failed to submit report: $e');
    }
  }

  /// Report user for harassment or abuse
  Future<ReportResult> reportUser({
    required String userPubkey,
    required ContentFilterReason reason,
    required String details,
    List<String>? relatedEventIds,
  }) async {
    // Use first related event or create a user-focused report
    final eventId = relatedEventIds?.first ?? 'user_$userPubkey';

    return reportContent(
      eventId: eventId,
      authorPubkey: userPubkey,
      reason: reason,
      details: details,
      additionalContext: relatedEventIds != null
          ? 'Related events: ${relatedEventIds.join(', ')}'
          : null,
      hashtags: ['user-report'],
    );
  }

  /// Quick report for common violations
  Future<ReportResult> quickReport({
    required String eventId,
    required String authorPubkey,
    required ContentFilterReason reason,
  }) async {
    final details = _getQuickReportDetails(reason);

    return reportContent(
      eventId: eventId,
      authorPubkey: authorPubkey,
      reason: reason,
      details: details,
      hashtags: ['quick-report'],
    );
  }

  /// Check if content has been reported before
  bool hasBeenReported(String eventId) =>
      _reportHistory.any((report) => report.eventId == eventId);

  /// Get reports for specific event
  List<ContentReport> getReportsForEvent(String eventId) =>
      _reportHistory.where((report) => report.eventId == eventId).toList();

  /// Get reports by user
  List<ContentReport> getReportsByUser(String authorPubkey) => _reportHistory
      .where((report) => report.authorPubkey == authorPubkey)
      .toList();

  /// Get reporting statistics
  Map<String, dynamic> getReportingStats() {
    final reasonCounts = <String, int>{};
    for (final reason in ContentFilterReason.values) {
      reasonCounts[reason.name] = _reportHistory
          .where((report) => report.reason == reason)
          .length;
    }

    final last30Days = DateTime.now().subtract(const Duration(days: 30));
    final recentReports = _reportHistory
        .where((report) => report.createdAt.isAfter(last30Days))
        .length;

    return {
      'totalReports': _reportHistory.length,
      'recentReports': recentReports,
      'reasonBreakdown': reasonCounts,
      'averageReportsPerDay': recentReports / 30,
    };
  }

  /// Clear old reports (privacy cleanup)
  Future<void> clearOldReports({
    Duration maxAge = const Duration(days: 90),
  }) async {
    final cutoffDate = DateTime.now().subtract(maxAge);
    final initialCount = _reportHistory.length;

    _reportHistory.removeWhere(
      (report) => report.createdAt.isBefore(cutoffDate),
    );

    if (_reportHistory.length != initialCount) {
      await _saveReportHistory();

      final removedCount = initialCount - _reportHistory.length;
      Log.debug(
        '🧹 Cleared $removedCount old reports',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
    }
  }

  /// Create NIP-56 reporting event (kind 1984) for Apple compliance
  Future<Event?> _createReportingEvent({
    required String reportId,
    required String eventId,
    required String authorPubkey,
    required ContentFilterReason reason,
    required String details,
    String? additionalContext,
    List<String> hashtags = const [],
  }) async {
    try {
      if (!_nostrService.hasKeys) {
        Log.error(
          'Cannot create report event: no keys available',
          name: 'ContentReportingService',
          category: LogCategory.system,
        );
        return null;
      }

      // Build NIP-56 compliant tags (kind 1984)
      final tags = <List<String>>[
        ['e', eventId], // Event being reported
        ['p', authorPubkey], // Author of reported content
        ['report', reason.name], // Report reason as per NIP-56
        ['client', 'diVine'], // Reporting client
      ];

      // Add hashtags as 't' tags
      for (final hashtag in hashtags) {
        tags.add(['t', hashtag]);
      }

      // Add additional context as tags if provided
      if (additionalContext != null) {
        tags.add(['alt', additionalContext]); // Alternative description
      }

      // Create NIP-56 compliant content
      final reportContent = _formatNip56ReportContent(
        reason,
        details,
        additionalContext,
      );

      // Create kind 1984 event using nostr_sdk (same pattern as video events)
      final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final event = Event(
        _keyManager.keyPair!.public,
        1984, // NIP-56 reporting event kind
        tags,
        reportContent,
        createdAt: createdAt,
      );

      // Sign the event
      event.sign(_keyManager.keyPair!.private);

      Log.info(
        'Created NIP-56 report event (kind 1984): ${event.id}',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
      Log.verbose(
        'Tags: ${tags.length}, Content length: ${reportContent.length}',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
      Log.debug(
        'Reporting: $eventId for $reason',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );

      return event;
    } catch (e) {
      Log.error(
        'Failed to create NIP-56 report event: $e',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Format report content for NIP-56 compliance (kind 1984)
  String _formatNip56ReportContent(
    ContentFilterReason reason,
    String details,
    String? additionalContext,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('CONTENT REPORT - NIP-56');
    buffer.writeln('Reason: ${reason.name}');
    buffer.writeln('Details: $details');

    if (additionalContext != null) {
      buffer.writeln('Additional Context: $additionalContext');
    }

    buffer.writeln(
      'Reported via divine for community safety and Apple App Store compliance',
    );
    return buffer.toString();
  }

  /// Create metadata for report (for our internal tracking)
  // ignore: unused_element
  dynamic _createReportMetadata(String reportId, ContentFilterReason reason) {
    // This would return proper NIP-94 metadata for the report
    // For now, return a placeholder
    return {
      'reportId': reportId,
      'reason': reason.name,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Create Zendesk ticket for moderation tracking
  Future<void> _createZendeskTicket({
    required String reportId,
    required String eventId,
    required String authorPubkey,
    required ContentFilterReason reason,
    required String details,
    String? additionalContext,
  }) async {
    try {
      // Format ticket description with NIP-56 report details
      final description = StringBuffer();
      description.writeln('Content Report - NIP-56');
      description.writeln('');
      description.writeln('Report ID: $reportId');
      description.writeln('Event ID: $eventId');
      description.writeln('Author Pubkey: $authorPubkey');
      description.writeln('');
      description.writeln('Violation Type: ${reason.name}');
      description.writeln('');
      description.writeln('Reporter Details:');
      description.writeln(details);

      if (additionalContext != null) {
        description.writeln('');
        description.writeln('Additional Context:');
        description.writeln(additionalContext);
      }

      description.writeln('');
      description.writeln('---');
      description.writeln('Reported via diVine mobile app');
      description.writeln('NIP-56 Nostr event created: $eventId');

      // Create Zendesk ticket silently
      final success = await ZendeskSupportService.createTicket(
        subject: 'Content Report: ${reason.name}',
        description: description.toString(),
        tags: ['mobile', 'content-report', 'nip-56', reason.name.toLowerCase()],
      );

      if (success) {
        Log.info(
          'Zendesk ticket created for report: $reportId',
          name: 'ContentReportingService',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'Failed to create Zendesk ticket for report: $reportId',
          name: 'ContentReportingService',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Error creating Zendesk ticket: $e',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
      // Don't fail the report if Zendesk ticket creation fails
    }
  }

  /// Get quick report details for common violations
  String _getQuickReportDetails(ContentFilterReason reason) {
    switch (reason) {
      case ContentFilterReason.spam:
        return 'This content appears to be spam or unwanted promotional material.';
      case ContentFilterReason.harassment:
        return 'This content contains harassment, bullying, or abusive behavior.';
      case ContentFilterReason.violence:
        return 'This content contains violence, threats, or harmful behavior.';
      case ContentFilterReason.sexualContent:
        return 'This content contains inappropriate sexual or adult material.';
      case ContentFilterReason.copyright:
        return 'This content appears to violate copyright or intellectual property rights.';
      case ContentFilterReason.falseInformation:
        return 'This content contains misinformation or deliberately false information.';
      case ContentFilterReason.csam:
        return 'This content violates child safety policies and may contain illegal material.';
      case ContentFilterReason.aiGenerated:
        return 'This content appears to be AI-generated and may violate authenticity policies.';
      case ContentFilterReason.other:
        return 'This content violates community guidelines.';
    }
  }

  /// Load report history from storage
  void _loadReportHistory() {
    final historyJson = _prefs.getString(reportsStorageKey);
    if (historyJson != null) {
      try {
        final List<dynamic> reportsJson = jsonDecode(historyJson);
        _reportHistory.clear();
        _reportHistory.addAll(
          reportsJson.map(
            (json) => ContentReport.fromJson(json as Map<String, dynamic>),
          ),
        );
        Log.debug(
          '📱 Loaded ${_reportHistory.length} reports from history',
          name: 'ContentReportingService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load report history: $e',
          name: 'ContentReportingService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Save report history to storage
  Future<void> _saveReportHistory() async {
    try {
      final reportsJson = _reportHistory
          .map((report) => report.toJson())
          .toList();
      await _prefs.setString(reportsStorageKey, jsonEncode(reportsJson));
    } catch (e) {
      Log.error(
        'Failed to save report history: $e',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
    }
  }

  void dispose() {
    // Clean up any active operations
  }
}
