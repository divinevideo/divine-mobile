// ABOUTME: Model for tracking video uploads to Cloudinary in various states.
// ABOUTME: Supports local persistence and state management for async upload.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:models/src/native_proof_data.dart';

/// Status of a video upload to Cloudinary
enum UploadStatus {
  pending, // Waiting to start upload
  uploading, // Currently uploading to Cloudinary
  retrying, // Retrying after failure
  processing, // Cloudinary is processing the video
  readyToPublish, // Processing complete, ready for Nostr publishing
  published, // Successfully published to Nostr
  failed, // Upload or processing failed
  paused, // Upload paused by user
}

/// Represents a video upload in progress or completed
@immutable
class PendingUpload {
  const PendingUpload({
    required this.id,
    required this.localVideoPath,
    required this.nostrPubkey,
    required this.status,
    required this.createdAt,
    this.cloudinaryPublicId,
    this.videoId,
    this.cdnUrl,
    this.errorMessage,
    this.uploadProgress,
    this.thumbnailPath,
    this.title,
    this.description,
    this.hashtags,
    this.nostrEventId,
    this.completedAt,
    this.retryCount = 0,
    this.videoWidth,
    this.videoHeight,
    this.videoDurationMillis,
    this.proofManifestJson,
    this.streamingMp4Url,
    this.streamingHlsUrl,
    this.fallbackUrl,
  });

  /// Create a new pending upload
  factory PendingUpload.create({
    required String localVideoPath,
    required String nostrPubkey,
    String? thumbnailPath,
    String? title,
    String? description,
    List<String>? hashtags,
    int? videoWidth,
    int? videoHeight,
    Duration? videoDuration,
    String? proofManifestJson,
  }) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomSuffix = math.Random().nextInt(999999);
    return PendingUpload(
      id: '${timestamp}_$randomSuffix',
      localVideoPath: localVideoPath,
      nostrPubkey: nostrPubkey,
      status: UploadStatus.pending,
      createdAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
      title: title,
      description: description,
      hashtags: hashtags,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      videoDurationMillis: videoDuration?.inMilliseconds,
      proofManifestJson: proofManifestJson,
    );
  }
  final String id;
  final String localVideoPath;
  final String nostrPubkey;
  final UploadStatus status;
  final DateTime createdAt;
  final String? cloudinaryPublicId; // Deprecated - use videoId instead
  final String? videoId;
  final String? cdnUrl;
  final String? errorMessage;
  final double? uploadProgress; // 0.0 to 1.0
  final String? thumbnailPath;
  final String? title;
  final String? description;
  final List<String>? hashtags;
  final String? nostrEventId; // Set when published to Nostr
  final DateTime? completedAt;
  final int? retryCount;
  final int? videoWidth;
  final int? videoHeight;
  final int? videoDurationMillis;
  final String? proofManifestJson; // Serialized ProofManifest
  final String? streamingMp4Url; // BunnyStream MP4 URL from Blossom
  final String? streamingHlsUrl; // BunnyStream HLS URL from Blossom
  final String? fallbackUrl; // R2 MP4 fallback URL from Blossom

  /// Get video duration as Duration object
  Duration? get videoDuration => videoDurationMillis != null
      ? Duration(milliseconds: videoDurationMillis!)
      : null;

  /// Check if this upload has ProofMode data
  bool get hasProofMode => proofManifestJson != null;

  /// Get deserialized NativeProofData (null if not present or invalid JSON)
  /// This is the new ProofMode format using native libraries
  NativeProofData? get nativeProof {
    if (proofManifestJson == null) return null;
    try {
      final json = jsonDecode(proofManifestJson!);
      // Check if this is native proof data (has 'videoHash' field)
      if (json is Map<String, dynamic> && json.containsKey('videoHash')) {
        return NativeProofData.fromJson(json);
      }
      return null;
    } on Exception catch (e) {
      developer.log(
        'Failed to parse NativeProofData: $e',
        name: 'PendingUpload',
        level: 1000, // Error level
      );
      return null;
    }
  }

  /// Copy with updated fields
  PendingUpload copyWith({
    String? id,
    String? localVideoPath,
    String? nostrPubkey,
    UploadStatus? status,
    DateTime? createdAt,
    String? cloudinaryPublicId,
    String? videoId,
    String? cdnUrl,
    String? errorMessage,
    double? uploadProgress,
    String? thumbnailPath,
    String? title,
    String? description,
    List<String>? hashtags,
    String? nostrEventId,
    DateTime? completedAt,
    int? retryCount,
    int? videoWidth,
    int? videoHeight,
    Duration? videoDuration,
    String? proofManifestJson,
    String? streamingMp4Url,
    String? streamingHlsUrl,
    String? fallbackUrl,
  }) => PendingUpload(
    id: id ?? this.id,
    localVideoPath: localVideoPath ?? this.localVideoPath,
    nostrPubkey: nostrPubkey ?? this.nostrPubkey,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
    videoId: videoId ?? this.videoId,
    cdnUrl: cdnUrl ?? this.cdnUrl,
    errorMessage: errorMessage ?? this.errorMessage,
    uploadProgress: uploadProgress ?? this.uploadProgress,
    thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    title: title ?? this.title,
    description: description ?? this.description,
    hashtags: hashtags ?? this.hashtags,
    nostrEventId: nostrEventId ?? this.nostrEventId,
    completedAt: completedAt ?? this.completedAt,
    retryCount: retryCount ?? this.retryCount,
    videoWidth: videoWidth ?? this.videoWidth,
    videoHeight: videoHeight ?? this.videoHeight,
    videoDurationMillis: (videoDuration ?? this.videoDuration)?.inMilliseconds,
    proofManifestJson: proofManifestJson ?? this.proofManifestJson,
    streamingMp4Url: streamingMp4Url ?? this.streamingMp4Url,
    streamingHlsUrl: streamingHlsUrl ?? this.streamingHlsUrl,
    fallbackUrl: fallbackUrl ?? this.fallbackUrl,
  );

  /// Check if the upload is in a terminal state
  bool get isCompleted =>
      status == UploadStatus.published || status == UploadStatus.failed;

  /// Check if the upload can be retried
  bool get canRetry => status == UploadStatus.failed && (retryCount ?? 0) < 3;

  /// Get display-friendly status text
  String get statusText {
    switch (status) {
      case UploadStatus.pending:
        return 'Waiting to upload...';
      case UploadStatus.uploading:
        if (uploadProgress != null) {
          return 'Uploading ${(uploadProgress! * 100).toInt()}%...';
        }
        return 'Uploading...';
      case UploadStatus.retrying:
        return 'Retrying upload...';
      case UploadStatus.processing:
        return 'Processing video...';
      case UploadStatus.readyToPublish:
        return 'Ready to publish';
      case UploadStatus.published:
        return 'Published';
      case UploadStatus.failed:
        return 'Failed: ${errorMessage ?? 'Unknown error'}';
      case UploadStatus.paused:
        return 'Upload paused';
    }
  }

  /// Get progress value for UI (0.0 to 1.0)
  double get progressValue {
    switch (status) {
      case UploadStatus.pending:
        return 0;
      case UploadStatus.uploading:
        return uploadProgress ?? 0.0;
      case UploadStatus.retrying:
        return uploadProgress ?? 0.0;
      case UploadStatus.processing:
        return 0.8; // Show 80% when processing
      case UploadStatus.readyToPublish:
        return 0.9; // Show 90% when ready
      case UploadStatus.published:
        return 1;
      case UploadStatus.failed:
        return 0;
      case UploadStatus.paused:
        return uploadProgress ?? 0.0; // Preserve current progress
    }
  }

  @override
  String toString() =>
      'PendingUpload{id: $id, status: $status, '
      'progress: $uploadProgress, cloudinaryId: $cloudinaryPublicId}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingUpload &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
