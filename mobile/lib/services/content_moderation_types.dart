// ABOUTME: Content-moderation value types shared by the reporting and
// ABOUTME: content-warning flows (report reasons, severity, mute entries).

/// Reasons for content filtering/reporting.
///
/// Categories for content filtering and report flows.
enum ContentFilterReason {
  spam,
  harassment,
  violence,
  sexualContent,
  copyright,
  falseInformation,
  childSafety,
  csam,
  underageUser,
  aiGenerated,
  other,
}

/// The reasons a list can be reported for: 8 of the 11, in display order.
///
/// Left out on purpose:
/// - [ContentFilterReason.underageUser] opens an age review of the reported
///   account, which for a list would be its author, not anyone in it.
/// - [ContentFilterReason.copyright] and [ContentFilterReason.aiGenerated]
///   are about a video itself; a list's videos are reported one by one.
///
/// A list built to target someone files under
/// [ContentFilterReason.harassment].
const List<ContentFilterReason> listReportReasons = [
  ContentFilterReason.spam,
  ContentFilterReason.harassment,
  ContentFilterReason.violence,
  ContentFilterReason.sexualContent,
  ContentFilterReason.falseInformation,
  ContentFilterReason.childSafety,
  ContentFilterReason.csam,
  ContentFilterReason.other,
];

/// NIP-32 namespace for Divine's report labels, used as the `L` tag and as
/// each `l` tag's third element.
const String kReportLabelNamespace = 'social.nos.ontology';

const String _reportLabelPrefix = 'NS-';

/// Maps a [ContentFilterReason] to the canonical NIP-56 (kind 1984) report
/// type strings: nudity, malware, profanity, illegal, spam, impersonation,
/// other.
///
/// NIP-56's vocabulary is coarser than Divine's, so this collapses several
/// reasons (`aiGenerated`/`childSafety`/`underageUser`/`falseInformation` ->
/// `other`; `csam`/`copyright`/`violence` -> `illegal`). Prefer
/// [contentFilterReasonToNip32Label] wherever the granular reason matters —
/// this exists to satisfy the protocol's fixed marker vocabulary.
String contentFilterReasonToNip56Type(ContentFilterReason reason) {
  return switch (reason) {
    ContentFilterReason.spam => 'spam',
    ContentFilterReason.harassment => 'profanity',
    ContentFilterReason.violence => 'illegal',
    ContentFilterReason.sexualContent => 'nudity',
    ContentFilterReason.copyright => 'illegal',
    ContentFilterReason.falseInformation => 'other',
    ContentFilterReason.childSafety => 'other',
    ContentFilterReason.csam => 'illegal',
    ContentFilterReason.underageUser => 'other',
    ContentFilterReason.aiGenerated => 'other',
    ContentFilterReason.other => 'other',
  };
}

/// Maps a [ContentFilterReason] to its NIP-32 label value, the lossless
/// wire form of the reason.
///
/// These values are a cross-repo wire contract: divine-web and
/// divine-relay-manager key display and escalation policy off them (see
/// divine-relay-manager's `CATEGORY_LABELS`, `HIGH_PRIORITY_CATEGORIES`,
/// and `UNDERAGE_REPORT_CATEGORY`), and divine-moderation-service resolves
/// them to `user_reports.report_type`. Renaming one silently reclassifies
/// reports in three services — change it there first.
String contentFilterReasonToNip32Label(ContentFilterReason reason) {
  return switch (reason) {
    ContentFilterReason.spam => '${_reportLabelPrefix}spam',
    ContentFilterReason.harassment => '${_reportLabelPrefix}harassment',
    ContentFilterReason.violence => '${_reportLabelPrefix}violence',
    ContentFilterReason.sexualContent => '${_reportLabelPrefix}sexualContent',
    ContentFilterReason.copyright => '${_reportLabelPrefix}copyright',
    ContentFilterReason.falseInformation =>
      '${_reportLabelPrefix}falseInformation',
    ContentFilterReason.childSafety => '${_reportLabelPrefix}childSafety',
    ContentFilterReason.csam => '${_reportLabelPrefix}csam',
    ContentFilterReason.underageUser => '${_reportLabelPrefix}underageUser',
    ContentFilterReason.aiGenerated => '${_reportLabelPrefix}aiGenerated',
    ContentFilterReason.other => '${_reportLabelPrefix}other',
  };
}

/// Content severity levels for filtering
enum ContentSeverity {
  info, // Informational only
  warning, // Show warning but allow viewing
  hide, // Hide by default, show if requested
  block, // Completely block content
}

/// Mute list entry representing filtered content
class MuteListEntry {
  const MuteListEntry({
    required this.type,
    required this.value,
    required this.reason,
    required this.severity,
    required this.createdAt,
    this.note,
  });
  final String type; // 'pubkey', 'event', 'keyword', 'content-type'
  final String value;
  final ContentFilterReason reason;
  final ContentSeverity severity;
  final DateTime createdAt;
  final String? note;

  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    'reason': reason.name,
    'severity': severity.name,
    'createdAt': createdAt.toIso8601String(),
    'note': note,
  };

  factory MuteListEntry.fromJson(Map<String, dynamic> json) => MuteListEntry(
    type: json['type'] as String,
    value: json['value'] as String,
    reason: ContentFilterReason.values.firstWhere(
      (r) => r.name == json['reason'],
      orElse: () => ContentFilterReason.other,
    ),
    severity: ContentSeverity.values.firstWhere(
      (s) => s.name == json['severity'],
      orElse: () => ContentSeverity.hide,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    note: json['note'] as String?,
  );

  /// Convert to NIP-51 list entry tag format
  List<String> toNIP51Tag() {
    final tag = [type, value];
    if (note != null) tag.add(note!);
    return tag;
  }
}

/// Content moderation result
class ModerationResult {
  const ModerationResult({
    required this.shouldFilter,
    required this.severity,
    required this.reasons,
    required this.matchingEntries,
    this.warningMessage,
  });
  final bool shouldFilter;
  final ContentSeverity severity;
  final List<ContentFilterReason> reasons;
  final String? warningMessage;
  final List<MuteListEntry> matchingEntries;

  static const ModerationResult clean = ModerationResult(
    shouldFilter: false,
    severity: ContentSeverity.info,
    reasons: [],
    matchingEntries: [],
  );
}
