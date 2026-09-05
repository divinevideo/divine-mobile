// ABOUTME: Model for tracking video uploads to Cloudinary in various states
// ABOUTME: Supports local persistence and state management for async upload flow

import 'dart:convert';
import 'dart:math' as math;

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:unified_logger/unified_logger.dart';

part 'pending_upload.g.dart';

const Object _pendingUploadUnset = Object();

/// Status of a video upload to Cloudinary
@HiveType(typeId: 1)
enum UploadStatus {
  @HiveField(0)
  pending, // Waiting to start upload

  @HiveField(1)
  uploading, // Currently uploading to Cloudinary

  @HiveField(2)
  retrying, // Retrying after failure

  @HiveField(3)
  processing, // Cloudinary is processing the video

  @HiveField(4)
  readyToPublish, // Processing complete, ready for Nostr publishing

  @HiveField(5)
  published, // Successfully published to Nostr

  @HiveField(6)
  failed, // Upload or processing failed
  // Tombstone: no shipped code path writes this. The user-facing pause
  // feature was removed in #6935 (it never had a production caller). The
  // case is retained because it is a persisted Hive field value, so
  // dropping it is a separate storage-migration decision.
  @HiveField(7)
  paused,
}

/// Represents a video upload in progress or completed
@immutable
@HiveType(typeId: 2)
class PendingUpload {
  const PendingUpload({
    required this.id,
    required this.localVideoPath,
    required this.nostrPubkey,
    required this.status,
    required this.createdAt,
    this.thumbnailTimestampMillis,
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
    this.resumableSession,
    this.blurhash,
  });

  /// Create a new pending upload
  factory PendingUpload.create({
    required String localVideoPath,
    required String nostrPubkey,
    Duration? thumbnailTimestamp,
    String? thumbnailPath,
    String? title,
    String? description,
    List<String>? hashtags,
    int? videoWidth,
    int? videoHeight,
    Duration? videoDuration,
    String? proofManifestJson,
  }) => PendingUpload(
    id: '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(999999)}',
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
    thumbnailTimestampMillis: thumbnailTimestamp?.inMilliseconds,
  );
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String localVideoPath;

  @HiveField(2)
  final String nostrPubkey;

  @HiveField(3)
  final UploadStatus status;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final String? cloudinaryPublicId; // Deprecated - use videoId instead

  @HiveField(15)
  final String? videoId; // New field for direct upload

  @HiveField(16)
  final String? cdnUrl; // Direct CDN URL from upload

  @HiveField(6)
  final String? errorMessage;

  @HiveField(7)
  final double? uploadProgress; // 0.0 to 1.0

  @HiveField(8)
  final String? thumbnailPath;

  @HiveField(9)
  final String? title;

  @HiveField(10)
  final String? description;

  @HiveField(11)
  final List<String>? hashtags;

  @HiveField(12)
  final String? nostrEventId; // Set when published to Nostr

  @HiveField(13)
  final DateTime? completedAt;

  @HiveField(14)
  final int? retryCount;

  @HiveField(17)
  final int? videoWidth;

  @HiveField(18)
  final int? videoHeight;

  @HiveField(19)
  final int? videoDurationMillis; // Store as milliseconds for Hive

  @HiveField(20)
  final String? proofManifestJson; // Serialized ProofManifest

  @HiveField(21)
  final String? streamingMp4Url; // BunnyStream MP4 URL from Blossom

  @HiveField(22)
  final String? streamingHlsUrl; // BunnyStream HLS URL from Blossom

  @HiveField(23)
  final String? fallbackUrl; // R2 MP4 fallback URL from Blossom

  @HiveField(24)
  final BlossomResumableUploadSession? resumableSession;

  @HiveField(25)
  final int? thumbnailTimestampMillis; // Store as milliseconds for Hive

  /// Blurhash of the upload's thumbnail frame.
  ///
  /// Computed in the thumbnail leg, which already holds the decoded frame and
  /// runs beside the video transfer. Publishing reads it from here instead of
  /// decoding the video a second time on the critical path. Null on records
  /// written before this field existed — publishing falls back to computing it.
  @HiveField(26)
  final String? blurhash;

  /// Get video duration as Duration object
  Duration? get videoDuration => videoDurationMillis != null
      ? Duration(milliseconds: videoDurationMillis!)
      : null;

  /// Get thumbnail timestamp as Duration object
  Duration? get thumbnailTimestamp => thumbnailTimestampMillis == null
      ? null
      : Duration(milliseconds: thumbnailTimestampMillis!);

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
    } catch (e) {
      Log.error(
        'Failed to parse NativeProofData: $e',
        name: 'PendingUpload',
        category: LogCategory.system,
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
    Object? cdnUrl = _pendingUploadUnset,
    String? errorMessage,
    double? uploadProgress,
    Object? thumbnailPath = _pendingUploadUnset,
    String? title,
    String? description,
    List<String>? hashtags,
    String? nostrEventId,
    DateTime? completedAt,
    int? retryCount,
    int? videoWidth,
    int? videoHeight,
    Duration? videoDuration,
    Duration? thumbnailTimestamp,
    String? proofManifestJson,
    Object? streamingMp4Url = _pendingUploadUnset,
    Object? streamingHlsUrl = _pendingUploadUnset,
    Object? fallbackUrl = _pendingUploadUnset,
    Object? resumableSession = _pendingUploadUnset,
    String? blurhash,
  }) => PendingUpload(
    id: id ?? this.id,
    localVideoPath: localVideoPath ?? this.localVideoPath,
    nostrPubkey: nostrPubkey ?? this.nostrPubkey,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
    videoId: videoId ?? this.videoId,
    cdnUrl: identical(cdnUrl, _pendingUploadUnset)
        ? this.cdnUrl
        : cdnUrl as String?,
    errorMessage: errorMessage ?? this.errorMessage,
    uploadProgress: uploadProgress ?? this.uploadProgress,
    thumbnailPath: identical(thumbnailPath, _pendingUploadUnset)
        ? this.thumbnailPath
        : thumbnailPath as String?,
    title: title ?? this.title,
    description: description ?? this.description,
    hashtags: hashtags ?? this.hashtags,
    nostrEventId: nostrEventId ?? this.nostrEventId,
    completedAt: completedAt ?? this.completedAt,
    retryCount: retryCount ?? this.retryCount,
    videoWidth: videoWidth ?? this.videoWidth,
    videoHeight: videoHeight ?? this.videoHeight,
    videoDurationMillis: (videoDuration ?? this.videoDuration)?.inMilliseconds,
    thumbnailTimestampMillis:
        (thumbnailTimestamp ?? this.thumbnailTimestamp)?.inMilliseconds,
    proofManifestJson: proofManifestJson ?? this.proofManifestJson,
    streamingMp4Url: identical(streamingMp4Url, _pendingUploadUnset)
        ? this.streamingMp4Url
        : streamingMp4Url as String?,
    streamingHlsUrl: identical(streamingHlsUrl, _pendingUploadUnset)
        ? this.streamingHlsUrl
        : streamingHlsUrl as String?,
    fallbackUrl: identical(fallbackUrl, _pendingUploadUnset)
        ? this.fallbackUrl
        : fallbackUrl as String?,
    resumableSession: identical(resumableSession, _pendingUploadUnset)
        ? this.resumableSession
        : resumableSession as BlossomResumableUploadSession?,
    blurhash: blurhash ?? this.blurhash,
  );

  /// Check if the upload is in a terminal state
  bool get isCompleted =>
      status == UploadStatus.published || status == UploadStatus.failed;

  /// Check if the upload can be retried
  bool get canRetry => status == UploadStatus.failed && (retryCount ?? 0) < 3;

  @override
  String toString() =>
      'PendingUpload{id: $id, status: $status, progress: $uploadProgress, cloudinaryId: $cloudinaryPublicId}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingUpload &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
