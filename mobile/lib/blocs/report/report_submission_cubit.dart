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
  });

  /// Event id the kind-1984 names. Synthetic (`user_<pubkey>`) for a user
  /// report.
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

  /// Header used in the moderation DM (e.g. "Content Report"). Internal-only.
  final String moderationKindLabel;

  /// Label preceding the event id in the moderation DM body (e.g. "Event").
  /// Internal-only.
  final String moderationEventLabel;

  bool get isUserReport => userPubkey != null;

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
    moderationKindLabel,
    moderationEventLabel,
  ];
}

enum ReportSubmissionStatus { editing, submitting, submitted, failure }

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

  Future<void> submit({
    required ContentFilterReason reason,
    required String reasonTitle,
    required String details,
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
        ..writeln('${_target.moderationEventLabel}: ${_target.eventId}');
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
            )
          : await service.reportContent(
              eventId: _target.eventId,
              authorPubkey: _target.authorPubkey,
              reason: reason,
              details: details,
              sourceRelay: _target.sourceRelay,
              moderationContent: content.toString().trimRight(),
              moderationTags: tags,
            );
      if (isClosed) return;
      emit(
        ReportSubmissionState(
          status: result.isSilentSuccess
              ? ReportSubmissionStatus.submitted
              : ReportSubmissionStatus.failure,
        ),
      );
    } catch (e, stackTrace) {
      if (isClosed) return;
      addError(e, stackTrace);
      emit(const ReportSubmissionState(status: ReportSubmissionStatus.failure));
    }
  }
}
