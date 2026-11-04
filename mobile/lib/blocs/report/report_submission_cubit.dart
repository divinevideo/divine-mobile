// ABOUTME: Cubit owning one report sheet's submission across both channels.
// ABOUTME: Constructor-injected services, no Riverpod at submit time.

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/content_reporting_service.dart';

/// What a report targets, and how its moderation DM is labelled.
///
/// A user report targets the account, not one of its videos: the report
/// sheet's constructor allows a video and a `userPubkey` together, so the
/// blob-hash accessors gate on the routing decision rather than on a video
/// being present — otherwise the backend files an account-level report
/// against that one blob.
class ReportTarget extends Equatable {
  const ReportTarget({
    required this.eventId,
    required this.authorPubkey,
    required this.moderationKindLabel,
    required this.moderationEventLabel,
    this.userPubkey,
    this.sourceRelay,
    this.sha256,
    this.videoUrl,
    this.additionalContext,
    this.addressableCoordinate,
    this.publishesPublicReport = true,
    this.messageExcerpt,
  }) : assert(
         messageExcerpt == null || !publishesPublicReport,
         'a message excerpt is only ever sent with a private report',
       );

  /// Id of the reported event. Synthetic (`user_<pubkey>`) for a user
  /// report, which names no event: only local report history keys on it.
  final String eventId;

  final String authorPubkey;

  /// Pubkey of the reported account, when this report targets a user rather
  /// than one piece of content.
  final String? userPubkey;

  final String? sourceRelay;

  /// The reported video's Blossom blob hash, where the publisher supplied one.
  final String? sha256;

  /// Canonical fallback for [sha256] — Blossom URLs carry the
  /// content-addressed hash in their path.
  final String? videoUrl;

  /// Extra text for the report, such as the title of a reported list, so a
  /// moderator can tell what was reported without opening it.
  final String? additionalContext;

  /// The `<kind>:<pubkey>:<d>` coordinate of a reported addressable event,
  /// such as a list. Published as an `a` tag beside the NIP-56 targets.
  final String? addressableCoordinate;

  /// Whether the report also goes out as a public NIP-56 event. False for a
  /// report made from a direct message: that event is signed by the reporter
  /// and names the reported account, so it would tie the reporter to the
  /// person they message (#7340).
  final bool publishesPublicReport;

  /// The reported message as the reporter's device shows it, which the
  /// reporter may choose to send privately to moderators. Only a private
  /// report carries one.
  final String? messageExcerpt;

  /// Header used in the moderation DM (e.g. "Content Report"). Internal-only.
  final String moderationKindLabel;

  /// Label preceding [moderationSubject] in the moderation DM body (e.g.
  /// "Event", "User Pubkey"). Internal-only.
  final String moderationEventLabel;

  bool get isUserReport => userPubkey != null;

  /// What the moderation DM names: the reported account's pubkey for a user
  /// report, the reported event's id otherwise.
  String get moderationSubject => userPubkey ?? eventId;

  /// Blob hash for the moderation DM, or null when the report targets an
  /// account rather than a video.
  String? get moderationSha256 => isUserReport ? null : sha256;

  /// Blob-hash fallback URL for the moderation DM, gated exactly as
  /// [moderationSha256] is.
  String? get moderationVideoUrl => isUserReport ? null : videoUrl;

  @override
  List<Object?> get props => [
    eventId,
    authorPubkey,
    userPubkey,
    sourceRelay,
    sha256,
    videoUrl,
    additionalContext,
    addressableCoordinate,
    publishesPublicReport,
    messageExcerpt,
    moderationKindLabel,
    moderationEventLabel,
  ];
}

enum ReportSubmissionStatus {
  editing,
  submitting,
  submitted,
  failure,

  /// The report with the included message is larger than its moderation DM
  /// can carry; sending it without the message would fit.
  tooLong,

  /// The details alone make the report larger than its moderation DM can
  /// carry, so the reporter has to shorten them.
  detailsTooLong,
}

class ReportSubmissionState extends Equatable {
  const ReportSubmissionState({this.status = ReportSubmissionStatus.editing});
  final ReportSubmissionStatus status;
  bool get isSubmitting => status == ReportSubmissionStatus.submitting;
  @override
  List<Object?> get props => [status];
}

typedef ContentReportingServiceResolver =
    Future<ContentReportingService> Function();

/// Accepts a snapshot into the durable outbox. Network delivery never belongs
/// to the screen lifecycle; closing the sheet cannot cancel a saved report.
class ReportSubmissionCubit extends Cubit<ReportSubmissionState> {
  ReportSubmissionCubit({
    required ContentReportingServiceResolver resolveContentReportingService,
    required ReportTarget target,
  }) : _resolveContentReportingService = resolveContentReportingService,
       _target = target,
       super(const ReportSubmissionState());

  final ContentReportingServiceResolver _resolveContentReportingService;
  final ReportTarget _target;

  /// [includeMessage] sends the target's [ReportTarget.messageExcerpt] to
  /// moderators, which the reporter has to opt into.
  Future<void> submit({
    required ContentFilterReason reason,
    required String reasonTitle,
    required String details,
    bool includeMessage = false,
  }) async {
    if (state.status
        case ReportSubmissionStatus.submitting ||
            ReportSubmissionStatus.submitted) {
      return;
    }
    emit(
      const ReportSubmissionState(status: ReportSubmissionStatus.submitting),
    );
    try {
      final service = await _resolveContentReportingService();
      final content = StringBuffer()
        ..writeln(_target.moderationKindLabel)
        ..writeln('Reason: $reasonTitle')
        ..writeln(
          '${_target.moderationEventLabel}: ${_target.moderationSubject}',
        );
      // A private message report has no public event or ticket to name the
      // sender, and moderators can't resolve a message ID, so the DM says.
      // A `p` tag would make the sender a member of the moderation room.
      if (!_target.isUserReport && !_target.publishesPublicReport) {
        content.writeln('Sender Pubkey: ${_target.authorPubkey}');
      }
      if (details.isNotEmpty) content.writeln('Details: $details');
      final tags = ContentReportingService.moderationDmTags(
        reason: reason,
        sha256: _target.moderationSha256,
        videoUrl: _target.moderationVideoUrl,
      );
      final result = _target.userPubkey != null
          ? await service.reportUser(
              userPubkey: _target.userPubkey!,
              reason: reason,
              details: details,
              moderationContent: content.toString().trimRight(),
              moderationTags: tags,
              publishToRelays: _target.publishesPublicReport,
            )
          : await service.reportContent(
              eventId: _target.eventId,
              authorPubkey: _target.authorPubkey,
              reason: reason,
              details: details,
              sourceRelay: _target.sourceRelay,
              moderationContent: content.toString().trimRight(),
              moderationTags: tags,
              additionalContext: _target.additionalContext,
              addressableCoordinate: _target.addressableCoordinate,
              publishToRelays: _target.publishesPublicReport,
              unverifiedMessageExcerpt: includeMessage
                  ? _target.messageExcerpt
                  : null,
            );
      if (isClosed) return;
      emit(
        ReportSubmissionState(
          status: switch (result) {
            _ when result.isSilentSuccess => ReportSubmissionStatus.submitted,
            ReportResult(delivery: ReportDelivery.tooLong) =>
              ReportSubmissionStatus.tooLong,
            ReportResult(delivery: ReportDelivery.detailsTooLong) =>
              ReportSubmissionStatus.detailsTooLong,
            _ => ReportSubmissionStatus.failure,
          },
        ),
      );
    } catch (e, stackTrace) {
      if (isClosed) return;
      addError(e, stackTrace);
      emit(const ReportSubmissionState(status: ReportSubmissionStatus.failure));
    }
  }
}
