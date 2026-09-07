// ABOUTME: Content reporting service for user-generated content violations
// ABOUTME: Implements NIP-56 reporting events (kind 1984) for Apple compliance and community-driven moderation

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/report_retry_service.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Whether a submitted report reached anything outside this device.
///
/// A report is built and signed locally, then pushed to two independent
/// channels. Neither is required to succeed for the report to be recorded,
/// so [ReportResult.success] alone says nothing about delivery.
enum ReportDelivery {
  /// At least one off-device channel accepted the report: the relay took
  /// the kind-1984 (NIP-56) event, or the Zendesk ticket was created.
  reached,

  /// Nothing left the device. The report exists only in local history,
  /// which nothing in the app ever replays — so it is a dead letter
  /// unless the user submits again.
  localOnly,

  /// The report was deliberately refused before anything was built,
  /// published, or recorded — e.g. a self-report (#8352). Distinct from
  /// [localOnly]: there is no local record, and callers must treat it as a
  /// silent no-op, never as a failed delivery to retry or hand to a fallback
  /// channel such as the moderation DM.
  refused,
}

/// Report submission result
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ReportResult {
  const ReportResult({
    required this.success,
    required this.timestamp,
    required this.delivery,
    this.error,
    this.reportId,
  });
  final bool success;
  final String? error;
  final String? reportId;
  final DateTime timestamp;

  /// Whether the report reached any channel off this device. Only
  /// meaningful when [success] is true.
  ///
  /// Required rather than defaulted: this type exists because a default
  /// claimed success, so a caller that forgets to say must not inherit
  /// the optimistic answer.
  final ReportDelivery delivery;

  /// Whether callers should present this result as a successful submission.
  ///
  /// A refusal is intentionally silent, so it has the same user-facing
  /// outcome as a delivered report even though nothing left the device.
  bool get isSilentSuccess =>
      success &&
      (delivery == ReportDelivery.reached ||
          delivery == ReportDelivery.refused);

  factory ReportResult.createSuccess(
    String reportId, {
    required ReportDelivery delivery,
  }) => ReportResult(
    success: true,
    reportId: reportId,
    timestamp: DateTime.now(),
    delivery: delivery,
  );

  factory ReportResult.failure(String error) => ReportResult(
    success: false,
    error: error,
    timestamp: DateTime.now(),
    delivery: ReportDelivery.localOnly,
  );
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

  factory ContentReport.fromJson(Map<String, dynamic> json) => ContentReport(
    reportId: json['reportId'] as String,
    eventId: json['eventId'] as String,
    authorPubkey: json['authorPubkey'] as String?,
    reason: ContentFilterReason.values.firstWhere(
      (r) => r.name == json['reason'],
      orElse: () => ContentFilterReason.other,
    ),
    details: json['details'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    additionalContext: json['additionalContext'] as String?,
    tags: List<String>.from(json['tags'] as Iterable? ?? []),
  );
}

/// Service for reporting inappropriate content
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ContentReportingService implements ReportChannelDriver {
  ContentReportingService({
    required NostrClient nostrService,
    required AuthService authService,
    required SharedPreferences prefs,
    required String moderationRelayUrl,
    PendingReportsDao? pendingReportsDao,
  }) : _nostrService = nostrService,
       _authService = authService,
       _prefs = prefs,
       _moderationRelayUrl = moderationRelayUrl,
       _pendingReportsDao = pendingReportsDao {
    _loadReportHistory();
  }
  final NostrClient _nostrService;
  final AuthService _authService;
  final SharedPreferences _prefs;
  final String _moderationRelayUrl;

  /// Durable outbox for the relay + Zendesk channels. When wired, a channel
  /// that fails the inline drive is retried by `ReportRetryService` instead of
  /// dead-lettered. When null (some tests), reporting falls back to a one-shot
  /// inline drive with the same delivery outcome. #8053.
  final PendingReportsDao? _pendingReportsDao;

  /// In-flight Zendesk POSTs, keyed by report id. The inline first drive and a
  /// background sweep can both pick up the same freshly-enqueued row and file
  /// its ticket concurrently; Zendesk does not dedup, so without this they
  /// would create two tickets. Coalescing by report id makes concurrent
  /// callers share one POST. #8053.
  ///
  /// This only dedups because the inline path and the sweep's driver are the
  /// SAME instance (the keepAlive `reportRetryServiceProvider` pins this
  /// service alive as its driver). If that ever changes so they use different
  /// instances, this map no longer coordinates them and the coalescing breaks.
  final Map<String, Future<bool>> _zendeskInFlight = {};

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

  /// Report content for violation.
  ///
  /// Returns rather than throws for every expected failure — an
  /// uninitialized service, a missing signer, a refused publish — and a
  /// `success` result still needs its [ReportResult.delivery] checked. A
  /// discarded result is therefore indistinguishable from a delivered
  /// report, which is the defect in #6387 and #6595.
  @useResult
  Future<ReportResult> reportContent({
    required String eventId,
    required String authorPubkey,
    required ContentFilterReason reason,
    required String details,
    String? sourceRelay,
    String? additionalContext,
    List<String> hashtags = const [],
    List<String>? nip56EventIds,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
        if (!_isInitialized) {
          return ReportResult.failure('Reporting service not initialized');
        }
      }

      if (!_authService.isAuthenticated) {
        return ReportResult.failure('Not authenticated');
      }

      // Generate report ID
      final reportId = 'report_${DateTime.now().millisecondsSinceEpoch}';

      // Self-report guard (#8352). A bare user report carries only a `p` tag,
      // so when reporter and target are the same pubkey the published kind-1984
      // event names the report's own author as the reported party — a permanent,
      // public record with no signal to a moderator that they are the same
      // person. Refuse it before any report payload or event is built or
      // published. Silent, like
      // the follow/unfollow/mute self-guards: a user who reaches this is not
      // doing it deliberately, so we return success and simply publish nothing.
      final reporterPubkey = _authService.currentPublicKeyHex;
      // Authentication normally guarantees a current public key. If that
      // invariant is temporarily broken, fail open here so unrelated reports
      // are not all mistaken for self-reports and refused.
      if (reporterPubkey != null &&
          reporterPubkey.toLowerCase() == authorPubkey.toLowerCase()) {
        Log.info(
          'Refused a self-report before publishing (target == reporter)',
          name: 'ContentReportingService',
          category: LogCategory.system,
        );
        return ReportResult.createSuccess(
          reportId,
          delivery: ReportDelivery.refused,
        );
      }

      // Redact once, here, so every projection of this report inherits it.
      // The kind-1984 event is published to relays in plaintext and the
      // Zendesk ticket can be mirrored publicly, so a credential pasted into
      // the details field must not survive into either.
      final safeDetails = sanitizeDiagnosticText(details);
      final safeAdditionalContext = additionalContext == null
          ? null
          : sanitizeDiagnosticText(additionalContext);

      // Create and broadcast NIP-56 reporting event (kind 1984)
      final reportEvent = await _createReportingEvent(
        reportId: reportId,
        eventId: eventId,
        authorPubkey: authorPubkey,
        reason: reason,
        details: safeDetails,
        additionalContext: safeAdditionalContext,
        hashtags: hashtags,
        nip56EventIds: nip56EventIds,
      );

      if (reportEvent == null) {
        return ReportResult.failure('Failed to create report event');
      }

      // Build the redacted Zendesk payload once so the inline drive and any
      // retry send an identical ticket.
      final targetRelays = _targetRelaysForReport(sourceRelay);
      final zendeskPayload = _buildZendeskPayload(
        reportId: reportId,
        eventId: eventId,
        authorPubkey: authorPubkey,
        reason: reason,
        details: safeDetails,
        additionalContext: safeAdditionalContext,
      );

      // Enqueue a durable row so a channel that fails now is retried by
      // ReportRetryService rather than lost. The moderation DM keeps its own
      // outbox and is not enqueued here. #8053.
      // The durable queue is enrichment, not the primary path: every DAO call
      // below is best-effort and must never change the delivery outcome the
      // caller sees. A DB failure degrades to the pre-queue one-shot send
      // rather than blocking a (possibly child-safety) report.
      final dao = _pendingReportsDao;
      final reporter = reporterPubkey;
      var queued = false;
      if (dao != null && reporter != null) {
        try {
          await dao.enqueue(
            PendingReport(
              reportId: reportId,
              userPubkey: reporter,
              eventJson: jsonEncode(reportEvent.toJson()),
              targetRelays: jsonEncode(targetRelays),
              zendeskPayload: jsonEncode(zendeskPayload),
              createdAt: DateTime.now(),
            ),
          );
          queued = true;
        } catch (e) {
          Log.error(
            'Failed to enqueue pending report $reportId; delivering without '
            'the durable queue: $e',
            name: 'ContentReportingService',
            category: LogCategory.system,
          );
        }
      }

      // Drive both channels once now. Their outcome is what the UI reports in
      // this change; a channel that fails stays queued for the background
      // sweep. Always continue to local save regardless of the outcome.
      final relayAccepted = await _publishReportEvent(
        reportEvent,
        targetRelays,
      );
      if (queued && dao != null) {
        await _recordDriveOutcome(
          dao,
          reportId,
          ReportChannel.relay,
          relayAccepted,
        );
      }

      final zendeskFiled = await _fileZendeskTicket(
        zendeskPayload,
        externalId: reportId,
      );
      if (queued && dao != null) {
        await _recordDriveOutcome(
          dao,
          reportId,
          ReportChannel.zendesk,
          zendeskFiled,
        );
        // A fully delivered report need not linger in the queue.
        if (relayAccepted && zendeskFiled) {
          try {
            await dao.deleteById(reportId);
          } catch (e) {
            Log.warning(
              'Failed to remove delivered report $reportId from the queue; '
              'the sweep will find both channels done and drop it: $e',
              name: 'ContentReportingService',
              category: LogCategory.system,
            );
          }
        }
      }

      // Save report to local history
      final report = ContentReport(
        reportId: reportId,
        eventId: eventId,
        authorPubkey: authorPubkey,
        reason: reason,
        // The redacted copy, not the raw one. Nothing reads this history
        // today, so keeping the raw text buys nothing and leaves a secret
        // sitting in storage for whoever surfaces, exports or replays it.
        details: safeDetails,
        createdAt: DateTime.now(),
        additionalContext: safeAdditionalContext,
        tags: hashtags,
      );

      _reportHistory.add(report);
      await _saveReportHistory();

      // The report is recorded either way, but only an off-device channel
      // makes it visible to moderation. Treat the two as a disjunction: a
      // filed Zendesk ticket means a human has the report even when every
      // relay refused it, and vice versa.
      final delivery = (relayAccepted || zendeskFiled)
          ? ReportDelivery.reached
          : ReportDelivery.localOnly;
      if (delivery == ReportDelivery.localOnly) {
        Log.error(
          'Report $reportId reached no channel: relay and Zendesk both '
          'failed. Local history is never replayed, so it is lost unless '
          'the user submits again.',
          name: 'ContentReportingService',
          category: LogCategory.system,
        );
      }

      Log.debug(
        'Content report submitted: $reportId',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
      return ReportResult.createSuccess(reportId, delivery: delivery);
    } catch (e) {
      Log.error(
        'Failed to submit content report: $e',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
      return ReportResult.failure('Failed to submit report: $e');
    }
  }

  List<String> _targetRelaysForReport(String? sourceRelay) {
    final relay = _normalizeRelayUrl(sourceRelay);
    return {_moderationRelayUrl, ?relay}.toList();
  }

  String? _normalizeRelayUrl(String? relayUrl) {
    final trimmed = relayUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'wss') return null;
    return trimmed;
  }

  /// Report user for harassment or abuse.
  ///
  /// Same contract as [reportContent]: failures come back as a returned
  /// value, so the result must be read.
  @useResult
  Future<ReportResult> reportUser({
    required String userPubkey,
    required ContentFilterReason reason,
    required String details,
    List<String>? relatedEventIds,
  }) async {
    final validRelatedEventIds = relatedEventIds
        ?.where(_isValidEventId)
        .toList(growable: false);

    // Use first related event or create a user-focused report
    final eventId = (relatedEventIds != null && relatedEventIds.isNotEmpty)
        ? relatedEventIds.first
        : 'user_$userPubkey';

    return reportContent(
      eventId: eventId,
      authorPubkey: userPubkey,
      reason: reason,
      details: details,
      additionalContext: relatedEventIds != null
          ? 'Related events: ${relatedEventIds.join(', ')}'
          : null,
      hashtags: ['user-report'],
      nip56EventIds: validRelatedEventIds ?? const [],
    );
  }

  /// Quick report for common violations.
  ///
  /// Same contract as [reportContent]: failures come back as a returned
  /// value, so the result must be read.
  @useResult
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

  /// The NIP-32 label pair identifying a report's reason on the wire.
  ///
  /// Built once here and emitted by both report channels — the kind-1984
  /// event and the moderation DM — so the two can never resolve to different
  /// report types. These label values are a cross-repo wire contract consumed
  /// by divine-web and divine-relay-manager.
  static List<List<String>> _nip32ReportLabelTags(ContentFilterReason reason) =>
      [
        ['L', kReportLabelNamespace],
        ['l', contentFilterReasonToNip32Label(reason), kReportLabelNamespace],
      ];

  /// Machine-readable report data for divine-moderation-service's dm-reader,
  /// carried as NIP-17 tags on the rumor rather than folded into the DM body —
  /// the content stays plain human-readable prose, which NIP-17 mandates and
  /// the admin Messages UI renders as-is (#6593).
  ///
  /// The `L`/`l` pair is the same one the kind-1984 report carries, so the
  /// backend resolves both channels to one report type. Sending only the
  /// NIP-56 value would let whichever channel ingested first pin a collapsed
  /// type — `other` for an `aiGenerated` report — permanently, because
  /// `user_reports` is written with `INSERT OR IGNORE` on
  /// `(sha256, reporter_pubkey)`.
  ///
  /// `report_type` and [sha256] are DM-only: the kind-1984 event carries the
  /// NIP-56 type as the third element of its `e`/`p` tags and carries no blob
  /// hash.
  ///
  /// [sha256] and [videoUrl] identify the reported video's Blossom blob hash
  /// where one resolves. [VideoEvent.sha256] is nullable because publishers can
  /// omit the `imeta` `x` value; [videoUrl] is the canonical fallback because
  /// Blossom URLs carry the content-addressed hash in their path. User reports
  /// and DM-message reports pass neither. `user_reports.sha256` is `NOT NULL`
  /// server-side, so omitting the tag degrades to no report row rather than a
  /// malformed one — a blank tag must never ship.
  ///
  /// Resolution goes through [VideoModerationStatusService.resolveSha256],
  /// matching the rest of the moderation paths. That normalizes a valid
  /// explicit hash and falls back to extracting the hash from [videoUrl];
  /// anything that is not 64 hex characters is dropped, which makes the
  /// documented degrade explicit rather than something the backend has to
  /// catch.
  ///
  /// Tag order is pinned by divine-moderation-service's
  /// `dm-report-contract.test.mjs` fixture.
  static List<List<String>> moderationDmTags({
    required ContentFilterReason reason,
    String? sha256,
    String? videoUrl,
  }) {
    final blobHash = VideoModerationStatusService.resolveSha256(
      explicitSha256: sha256,
      videoUrl: videoUrl,
    );
    return [
      ..._nip32ReportLabelTags(reason),
      ['report_type', contentFilterReasonToNip56Type(reason)],
      if (blobHash != null) ['sha256', blobHash],
    ];
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
    List<String>? nip56EventIds,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.error(
          'Cannot create report event: not authenticated',
          name: 'ContentReportingService',
          category: LogCategory.system,
        );
        return null;
      }

      // NIP-56 requires the report type as the 3rd element of the e/p tags.
      final nip56Type = contentFilterReasonToNip56Type(reason);
      // Filter at the construction boundary so every report path avoids
      // emitting synthetic or malformed e tags, not just reportUser().
      final eventTagIds = (nip56EventIds ?? [eventId])
          .where(NostrHexUtils.isValidEventId)
          .toList(growable: false);
      final tags = <List<String>>[
        for (final nip56EventId in eventTagIds) ['e', nip56EventId, nip56Type],
        ['p', authorPubkey, nip56Type],
        ..._nip32ReportLabelTags(reason),
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

      // Create and sign event via AuthService
      final signedEvent = await _authService.createAndSignEvent(
        kind: EventKind.report,
        content: reportContent,
        tags: tags,
      );

      if (signedEvent == null) {
        Log.error(
          'Failed to create and sign NIP-56 report event',
          name: 'ContentReportingService',
          category: LogCategory.system,
        );
        return null;
      }

      Log.info(
        'Created NIP-56 report event (kind 1984): ${signedEvent.id}',
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

      return signedEvent;
    } catch (e) {
      Log.error(
        'Failed to create NIP-56 report event: $e',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  static bool _isValidEventId(String eventId) =>
      NostrHexUtils.isValidEventId(eventId);

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
      'Reported via Divine for community safety and Apple App Store compliance',
    );
    return buffer.toString();
  }

  /// Create Zendesk ticket for moderation tracking.
  ///
  /// Returns whether the ticket was actually created. A failure here never
  /// fails the report, but it does count against [ReportDelivery].
  /// Builds the redacted Zendesk ticket fields for a report. Stored in the
  /// durable queue and rebuilt into a ticket on each delivery attempt.
  Map<String, dynamic> _buildZendeskPayload({
    required String reportId,
    required String eventId,
    required String authorPubkey,
    required ContentFilterReason reason,
    required String details,
    String? additionalContext,
  }) {
    // Format ticket description with NIP-56 report details.
    final description = StringBuffer();
    description.writeln('Content Report - NIP-56');
    description.writeln();
    description.writeln('Report ID: $reportId');
    description.writeln('Event ID: $eventId');
    description.writeln('Author Pubkey: $authorPubkey');
    description.writeln();
    description.writeln('Violation Type: ${reason.name}');
    description.writeln();
    description.writeln('Reporter Details:');
    // Per-field, before assembly: redaction spans lines, so sanitizing the
    // finished blob lets one reporter field erase the ones after it.
    description.writeln(sanitizeDiagnosticText(details));

    if (additionalContext != null) {
      description.writeln();
      description.writeln('Additional Context:');
      description.writeln(sanitizeDiagnosticText(additionalContext));
    }

    description.writeln();
    description.writeln('---');
    description.writeln('Reported via Divine mobile app');
    description.writeln('NIP-56 Nostr event created: $eventId');

    return {
      'subject': 'Content Report: ${reason.name}',
      'description': description.toString(),
      'tags': ['mobile', 'content-report', 'nip-56', reason.name.toLowerCase()],
    };
  }

  /// Files a Zendesk ticket from a stored payload, coalescing concurrent calls
  /// for the same [externalId] onto one POST so an inline drive and a sweep
  /// cannot double-file. [externalId] also tags the ticket for best-effort
  /// dedup of a lost-ACK retry (#8053). Never throws; a failure returns false.
  Future<bool> _fileZendeskTicket(
    Map<String, dynamic> payload, {
    required String externalId,
  }) {
    final existing = _zendeskInFlight[externalId];
    if (existing != null) return existing;
    final future = _fileZendeskTicketInner(payload, externalId: externalId);
    _zendeskInFlight[externalId] = future;
    return future.whenComplete(() => _zendeskInFlight.remove(externalId));
  }

  Future<bool> _fileZendeskTicketInner(
    Map<String, dynamic> payload, {
    required String externalId,
  }) async {
    try {
      final success = await ZendeskSupportService.createTicket(
        subject: payload['subject'] as String,
        description: payload['description'] as String,
        tags: (payload['tags'] as List).cast<String>(),
        externalId: externalId,
      );

      if (success) {
        Log.info(
          'Zendesk ticket created for report: $externalId',
          name: 'ContentReportingService',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'Failed to create Zendesk ticket for report: $externalId',
          name: 'ContentReportingService',
          category: LogCategory.system,
        );
      }
      return success;
    } catch (e) {
      Log.error(
        'Error creating Zendesk ticket: $e',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
      // Don't fail the report if Zendesk ticket creation fails
      return false;
    }
  }

  /// Publishes the signed kind-1984 report event. Returns whether the relay
  /// accepted it. Republishing the same stored event is idempotent by id.
  Future<bool> _publishReportEvent(
    Event event,
    List<String> targetRelays,
  ) async {
    final sentEvent = await _nostrService.publishEvent(
      event,
      targetRelays: targetRelays,
    );
    final failureReason = sentEvent.failureReason;
    final relayAccepted = failureReason == null;
    if (!relayAccepted) {
      Log.error(
        'Failed to publish NIP-56 report: $failureReason',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
    } else {
      Log.info(
        'Report published to relays',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
    }
    return relayAccepted;
  }

  Future<void> _recordDriveOutcome(
    PendingReportsDao dao,
    String reportId,
    ReportChannel channel,
    bool delivered,
  ) async {
    // Best-effort bookkeeping: never let a queue write change the delivery
    // outcome already returned to the caller. The sweep reconciles from the
    // persisted row if this fails.
    try {
      if (delivered) {
        await dao.markChannelDone(reportId: reportId, channel: channel);
      } else {
        await dao.recordChannelFailure(
          reportId: reportId,
          channel: channel,
          error: '${channel.name} delivery failed on first attempt',
        );
      }
    } catch (e) {
      Log.warning(
        'Failed to record $reportId ${channel.name} drive outcome: $e',
        name: 'ContentReportingService',
        category: LogCategory.system,
      );
    }
  }

  /// [ReportChannelDriver]: drives one channel of a queued report for the
  /// background retry sweep, from the row's stored event / payload.
  @override
  Future<bool> deliverReportChannel(
    PendingReport report,
    ReportChannel channel,
  ) async {
    switch (channel) {
      case ReportChannel.relay:
        final event = Event.fromJson(
          jsonDecode(report.eventJson) as Map<String, dynamic>,
        );
        final relays = report.targetRelays == null
            ? _targetRelaysForReport(null)
            : (jsonDecode(report.targetRelays!) as List).cast<String>();
        return _publishReportEvent(event, relays);
      case ReportChannel.zendesk:
        final payload =
            jsonDecode(report.zendeskPayload) as Map<String, dynamic>;
        return _fileZendeskTicket(payload, externalId: report.reportId);
    }
  }

  /// Get quick report details for common violations
  String _getQuickReportDetails(ContentFilterReason reason) {
    switch (reason) {
      case ContentFilterReason.spam:
        return 'This content appears to be spam or unwanted promotional material.';
      case ContentFilterReason.harassment:
        return 'This content contains harassment, profanity, or abusive behavior.';
      case ContentFilterReason.violence:
        return 'This content contains violent or extremist material.';
      case ContentFilterReason.sexualContent:
        return 'This content contains nudity, pornography, or sexual material.';
      case ContentFilterReason.copyright:
        return 'This content appears to violate copyright.';
      case ContentFilterReason.falseInformation:
        return 'This content contains misinformation or false claims.';
      case ContentFilterReason.childSafety:
        return 'This content raises child safety concerns.';
      case ContentFilterReason.csam:
        return 'This content depicts child sexual abuse.';
      case ContentFilterReason.underageUser:
        return 'This account holder appears to be under 16 years old.';
      case ContentFilterReason.aiGenerated:
        return 'This content appears to be deceptive AI-generated media.';
      case ContentFilterReason.other:
        return 'This content violates community guidelines.';
    }
  }

  /// Load report history from storage
  void _loadReportHistory() {
    final historyJson = _prefs.getString(reportsStorageKey);
    if (historyJson != null) {
      try {
        final reportsJson = jsonDecode(historyJson) as List<dynamic>;
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
