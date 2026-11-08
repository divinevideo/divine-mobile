// ABOUTME: Lightweight Library state that cannot retain editor histories.
// ABOUTME: Full drafts are loaded separately when an action needs their content.

import 'package:equatable/equatable.dart';
import 'package:openvine/models/divine_video_draft.dart';

class DraftSummary extends Equatable {
  const DraftSummary({
    required this.id,
    required this.title,
    required this.lastModified,
    required this.publishStatus,
    required this.clipCount,
    this.coverThumbnailPath,
  });

  factory DraftSummary.fromDraft(DivineVideoDraft draft) => DraftSummary(
    id: draft.id,
    title: draft.title,
    lastModified: draft.lastModified,
    publishStatus: draft.publishStatus,
    clipCount: draft.clips.length,
    coverThumbnailPath: draft.coverThumbnailPath,
  );

  final String id;
  final String title;
  final DateTime lastModified;
  final PublishStatus publishStatus;
  final int clipCount;
  final String? coverThumbnailPath;

  bool get canPost => clipCount > 0 && publishStatus != PublishStatus.published;

  @override
  List<Object?> get props => [
    id,
    title,
    lastModified,
    publishStatus,
    clipCount,
    coverThumbnailPath,
  ];
}
