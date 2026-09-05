// ABOUTME: Helper predicates for deciding whether persisted upload state can publish
// ABOUTME: Keeps upload-state validation out of the already oversized UploadManager

import 'package:upload_repository/src/pending_upload.dart';

bool readyUploadIsPublishable(PendingUpload upload) =>
    upload.status == UploadStatus.readyToPublish &&
    upload.videoId != null &&
    upload.videoId!.isNotEmpty &&
    _isHttpUrl(upload.cdnUrl) &&
    _isHttpUrl(upload.thumbnailPath);

bool _isHttpUrl(String? url) {
  final value = url?.trim();
  if (value == null || value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return false;
  return uri.scheme == 'http' || uri.scheme == 'https';
}
