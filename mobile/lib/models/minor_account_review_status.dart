// ABOUTME: Server-backed restriction and case models for parental consent /
// ABOUTME: minor-account review. Used by router gating and restricted UX.

import 'package:openvine/constants/app_constants.dart';

enum AccountRestrictionStatus {
  active,
  restrictedMinorReview;

  static AccountRestrictionStatus fromJsonValue(String? value) {
    return switch (value) {
      'restricted_minor_review' => restrictedMinorReview,
      _ => active,
    };
  }
}

enum MinorReviewCaseState {
  openReported,
  underModeratorReview,
  restrictedPendingUserResponse,
  restrictedPendingParentalConsent,
  restrictedPendingSupportEmail,
  submittedForReview,
  needsFollowUp,
  cleared,
  deniedClosed,
  unknown;

  static MinorReviewCaseState fromJsonValue(String? value) {
    return switch (value) {
      'open_reported' => openReported,
      'under_moderator_review' => underModeratorReview,
      'restricted_pending_user_response' => restrictedPendingUserResponse,
      'restricted_pending_parental_consent' => restrictedPendingParentalConsent,
      'restricted_pending_support_email' => restrictedPendingSupportEmail,
      'submitted_for_review' => submittedForReview,
      'needs_follow_up' => needsFollowUp,
      'cleared' => cleared,
      'denied_closed' => deniedClosed,
      _ => unknown,
    };
  }
}

enum MinorReviewResponseClock {
  running,
  paused,
  expired,
  notApplicable,
  unavailable;

  static MinorReviewResponseClock fromJsonValue(String? value) {
    return switch (value) {
      'running' => running,
      'paused' => paused,
      'expired' => expired,
      'not_applicable' => notApplicable,
      _ => unavailable,
    };
  }

  String get jsonValue => switch (this) {
    running => 'running',
    paused => 'paused',
    expired => 'expired',
    notApplicable => 'not_applicable',
    unavailable => 'unknown',
  };
}

class MinorReviewResponseDeadline {
  const MinorReviewResponseDeadline({
    required this.clock,
    this.serverNow,
    this.deadlineAt,
    this.pausedAt,
    this.remainingDaysWhenPaused,
  });

  const MinorReviewResponseDeadline.unavailable()
    : clock = MinorReviewResponseClock.unavailable,
      serverNow = null,
      deadlineAt = null,
      pausedAt = null,
      remainingDaysWhenPaused = null;

  factory MinorReviewResponseDeadline.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MinorReviewResponseDeadline.unavailable();

    final clock = MinorReviewResponseClock.fromJsonValue(
      json['clock'] is String ? json['clock'] as String : null,
    );
    final serverNow = _parseDateTime(json['serverNow']);
    final deadlineAt = _parseDateTime(json['deadlineAt']);
    final pausedAt = _parseDateTime(json['pausedAt']);
    final remainingDays = json['remainingDaysWhenPaused'] is num
        ? (json['remainingDaysWhenPaused'] as num).toDouble()
        : null;

    final valid = switch (clock) {
      MinorReviewResponseClock.running || MinorReviewResponseClock.expired =>
        serverNow != null && deadlineAt != null,
      MinorReviewResponseClock.paused =>
        pausedAt != null && remainingDays != null && remainingDays >= 0,
      MinorReviewResponseClock.notApplicable => true,
      MinorReviewResponseClock.unavailable => false,
    };

    return valid
        ? MinorReviewResponseDeadline(
            clock: clock,
            serverNow: serverNow,
            deadlineAt: deadlineAt,
            pausedAt: pausedAt,
            remainingDaysWhenPaused: remainingDays,
          )
        : const MinorReviewResponseDeadline.unavailable();
  }

  final MinorReviewResponseClock clock;
  final DateTime? serverNow;
  final DateTime? deadlineAt;
  final DateTime? pausedAt;
  final double? remainingDaysWhenPaused;

  Duration? get remaining {
    if (clock != MinorReviewResponseClock.running ||
        serverNow == null ||
        deadlineAt == null) {
      return null;
    }
    final duration = deadlineAt!.difference(serverNow!);
    return duration.isNegative ? Duration.zero : duration;
  }

  Map<String, dynamic> toJson() => {
    'clock': clock.jsonValue,
    'serverNow': serverNow?.toUtc().toIso8601String(),
    'deadlineAt': deadlineAt?.toUtc().toIso8601String(),
    'pausedAt': pausedAt?.toUtc().toIso8601String(),
    'remainingDaysWhenPaused': remainingDaysWhenPaused,
  };

  static DateTime? _parseDateTime(Object? value) {
    return value is String ? DateTime.tryParse(value)?.toUtc() : null;
  }
}

enum SuspectedAgeBand {
  under13,
  age13To15,
  age16PlusClaimed,
  unknown;

  static SuspectedAgeBand fromJsonValue(String? value) {
    return switch (value) {
      'under_13' => under13,
      'age_13_15' => age13To15,
      'age_16_plus_claimed' => age16PlusClaimed,
      _ => unknown,
    };
  }
}

enum MinorReviewResolutionType {
  supportEmailOnly,
  parentVideoOrEmail,
  supportReviewOnly,
  unknown;

  static MinorReviewResolutionType fromJsonValue(String? value) {
    return switch (value) {
      'support_email_only' => supportEmailOnly,
      'parent_video_or_email' => parentVideoOrEmail,
      'support_review_only' => supportReviewOnly,
      _ => unknown,
    };
  }
}

class MinorReviewInstructions {
  const MinorReviewInstructions({required this.title, required this.body});

  factory MinorReviewInstructions.fromJson(Map<String, dynamic>? json) {
    return MinorReviewInstructions(
      title: json?['title'] as String? ?? '',
      body: json?['body'] as String? ?? '',
    );
  }

  final String title;
  final String body;

  Map<String, dynamic> toJson() => {'title': title, 'body': body};

  MinorReviewInstructions copyWith({String? title, String? body}) {
    return MinorReviewInstructions(
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }
}

String _caseStateToJson(MinorReviewCaseState state) => switch (state) {
  MinorReviewCaseState.openReported => 'open_reported',
  MinorReviewCaseState.underModeratorReview => 'under_moderator_review',
  MinorReviewCaseState.restrictedPendingUserResponse =>
    'restricted_pending_user_response',
  MinorReviewCaseState.restrictedPendingParentalConsent =>
    'restricted_pending_parental_consent',
  MinorReviewCaseState.restrictedPendingSupportEmail =>
    'restricted_pending_support_email',
  MinorReviewCaseState.submittedForReview => 'submitted_for_review',
  MinorReviewCaseState.needsFollowUp => 'needs_follow_up',
  MinorReviewCaseState.cleared => 'cleared',
  MinorReviewCaseState.deniedClosed => 'denied_closed',
  MinorReviewCaseState.unknown => 'unknown',
};

String _ageBandToJson(SuspectedAgeBand ageBand) => switch (ageBand) {
  SuspectedAgeBand.under13 => 'under_13',
  SuspectedAgeBand.age13To15 => 'age_13_15',
  SuspectedAgeBand.age16PlusClaimed => 'age_16_plus_claimed',
  SuspectedAgeBand.unknown => 'unknown',
};

String _resolutionToJson(MinorReviewResolutionType resolution) =>
    switch (resolution) {
      MinorReviewResolutionType.supportEmailOnly => 'support_email_only',
      MinorReviewResolutionType.parentVideoOrEmail => 'parent_video_or_email',
      MinorReviewResolutionType.supportReviewOnly => 'support_review_only',
      MinorReviewResolutionType.unknown => 'unknown',
    };

class MinorReviewCase {
  const MinorReviewCase({
    required this.id,
    required this.state,
    required this.suspectedAgeBand,
    required this.allowedResolution,
    required this.instructions,
    required this.supportEmail,
    this.responseDeadline = const MinorReviewResponseDeadline.unavailable(),
    this.moderationConversationPubkey,
    this.moderationConversationId,
  });

  factory MinorReviewCase.fromJson(Map<String, dynamic> json) {
    return MinorReviewCase(
      id: json['id'] as String? ?? '',
      state: MinorReviewCaseState.fromJsonValue(json['state'] as String?),
      suspectedAgeBand: SuspectedAgeBand.fromJsonValue(
        json['suspectedAgeBand'] as String?,
      ),
      allowedResolution: MinorReviewResolutionType.fromJsonValue(
        json['allowedResolution'] as String?,
      ),
      instructions: MinorReviewInstructions.fromJson(
        json['instructions'] as Map<String, dynamic>?,
      ),
      supportEmail:
          json['supportEmail'] as String? ?? AppConstants.supportEmail,
      responseDeadline: MinorReviewResponseDeadline.fromJson(
        _asJsonMap(json['responseDeadline']),
      ),
      moderationConversationPubkey:
          json['moderationConversationPubkey'] as String?,
      moderationConversationId: json['moderationConversationId'] as String?,
    );
  }

  final String id;
  final MinorReviewCaseState state;
  final SuspectedAgeBand suspectedAgeBand;
  final MinorReviewResolutionType allowedResolution;
  final MinorReviewInstructions instructions;
  final String supportEmail;
  final MinorReviewResponseDeadline responseDeadline;
  final String? moderationConversationPubkey;
  final String? moderationConversationId;

  bool get isUnder13Path =>
      suspectedAgeBand == SuspectedAgeBand.under13 ||
      allowedResolution == MinorReviewResolutionType.supportEmailOnly;

  bool get allowsParentVideoOrEmail =>
      allowedResolution == MinorReviewResolutionType.parentVideoOrEmail &&
      !isUnder13Path;

  /// The status endpoint returns openReported only for voluntary applications.
  /// Follow-up cases must be advanced by a moderator before another upload.
  bool get canSubmitParentConsent =>
      allowsParentVideoOrEmail &&
      switch (state) {
        MinorReviewCaseState.openReported ||
        MinorReviewCaseState.restrictedPendingUserResponse ||
        MinorReviewCaseState.restrictedPendingParentalConsent ||
        MinorReviewCaseState.restrictedPendingSupportEmail => true,
        _ => false,
      };

  bool get isAwaitingModeratorDecision =>
      state == MinorReviewCaseState.underModeratorReview ||
      state == MinorReviewCaseState.submittedForReview;

  bool get needsUserAction =>
      state == MinorReviewCaseState.restrictedPendingUserResponse ||
      state == MinorReviewCaseState.restrictedPendingParentalConsent ||
      state == MinorReviewCaseState.restrictedPendingSupportEmail ||
      state == MinorReviewCaseState.needsFollowUp;

  MinorReviewCase copyWith({
    String? id,
    MinorReviewCaseState? state,
    SuspectedAgeBand? suspectedAgeBand,
    MinorReviewResolutionType? allowedResolution,
    MinorReviewInstructions? instructions,
    String? supportEmail,
    MinorReviewResponseDeadline? responseDeadline,
    String? moderationConversationPubkey,
    String? moderationConversationId,
  }) {
    return MinorReviewCase(
      id: id ?? this.id,
      state: state ?? this.state,
      suspectedAgeBand: suspectedAgeBand ?? this.suspectedAgeBand,
      allowedResolution: allowedResolution ?? this.allowedResolution,
      instructions: instructions ?? this.instructions,
      supportEmail: supportEmail ?? this.supportEmail,
      responseDeadline: responseDeadline ?? this.responseDeadline,
      moderationConversationPubkey:
          moderationConversationPubkey ?? this.moderationConversationPubkey,
      moderationConversationId:
          moderationConversationId ?? this.moderationConversationId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'state': _caseStateToJson(state),
    'suspectedAgeBand': _ageBandToJson(suspectedAgeBand),
    'allowedResolution': _resolutionToJson(allowedResolution),
    'instructions': instructions.toJson(),
    'supportEmail': supportEmail,
    'responseDeadline': responseDeadline.toJson(),
    'moderationConversationPubkey': moderationConversationPubkey,
    'moderationConversationId': moderationConversationId,
  };
}

Map<String, dynamic>? _asJsonMap(Object? value) {
  if (value is! Map) return null;
  if (value.keys.any((key) => key is! String)) return null;
  return value.map<String, dynamic>(
    (key, value) => MapEntry(key as String, value),
  );
}

class MinorAccountReviewStatus {
  const MinorAccountReviewStatus({
    required this.restrictionStatus,
    this.currentCase,
  });

  factory MinorAccountReviewStatus.active() {
    return const MinorAccountReviewStatus(
      restrictionStatus: AccountRestrictionStatus.active,
    );
  }

  factory MinorAccountReviewStatus.fromJson(Map<String, dynamic> json) {
    final restriction =
        json['restriction'] as Map<String, dynamic>? ?? const {};
    final currentCaseJson = json['minorReviewCase'] as Map<String, dynamic>?;

    return MinorAccountReviewStatus(
      restrictionStatus: AccountRestrictionStatus.fromJsonValue(
        restriction['status'] as String?,
      ),
      currentCase: currentCaseJson == null
          ? null
          : MinorReviewCase.fromJson(currentCaseJson),
    );
  }

  final AccountRestrictionStatus restrictionStatus;
  final MinorReviewCase? currentCase;

  Map<String, dynamic> toJson() => {
    'restriction': {
      'status': restrictionStatus == AccountRestrictionStatus.active
          ? 'active'
          : 'restricted_minor_review',
    },
    'minorReviewCase': currentCase?.toJson(),
  };

  bool get isRestricted =>
      restrictionStatus == AccountRestrictionStatus.restrictedMinorReview;

  MinorAccountReviewStatus copyWith({
    AccountRestrictionStatus? restrictionStatus,
    MinorReviewCase? currentCase,
  }) {
    return MinorAccountReviewStatus(
      restrictionStatus: restrictionStatus ?? this.restrictionStatus,
      currentCase: currentCase ?? this.currentCase,
    );
  }
}
