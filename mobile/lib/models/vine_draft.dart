// ABOUTME: Data model for Vine drafts that users save before publishing
// ABOUTME: Includes video file path, metadata, publish status, and timestamps

import 'dart:convert';
import 'dart:io';
import 'package:openvine/models/aspect_ratio.dart';
import 'package:openvine/models/native_proof_data.dart';
import 'package:openvine/utils/unified_logger.dart';

enum PublishStatus { draft, publishing, failed, published }

class VineDraft {
  const VineDraft({
    required this.id,
    required this.videoFile,
    required this.title,
    required this.description,
    required this.hashtags,
    required this.frameCount,
    required this.selectedApproach,
    required this.createdAt,
    required this.lastModified,
    required this.publishStatus,
    this.publishError,
    required this.publishAttempts,
    this.proofManifestJson,
    required this.aspectRatio,
  });

  factory VineDraft.create({
    required File videoFile,
    required String title,
    required String description,
    required List<String> hashtags,
    required int frameCount,
    required String selectedApproach,
    String? proofManifestJson,
    AspectRatio aspectRatio = AspectRatio.square,
  }) {
    final now = DateTime.now();
    return VineDraft(
      id: 'draft_${now.millisecondsSinceEpoch}',
      videoFile: videoFile,
      title: title,
      description: description,
      hashtags: hashtags,
      frameCount: frameCount,
      selectedApproach: selectedApproach,
      createdAt: now,
      lastModified: now,
      publishStatus: PublishStatus.draft,
      publishError: null,
      publishAttempts: 0,
      proofManifestJson: proofManifestJson,
      aspectRatio: aspectRatio,
    );
  }

  factory VineDraft.fromJson(Map<String, dynamic> json) => VineDraft(
    id: json['id'] as String,
    videoFile: File(json['videoFilePath'] as String),
    title: json['title'] as String,
    description: json['description'] as String,
    hashtags: List<String>.from(json['hashtags'] as Iterable),
    frameCount: json['frameCount'] as int,
    selectedApproach: json['selectedApproach'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastModified: DateTime.parse(json['lastModified'] as String),
    publishStatus: json['publishStatus'] != null
        ? PublishStatus.values.byName(json['publishStatus'] as String)
        : PublishStatus.draft, // Migration: default for old drafts
    publishError: json['publishError'] as String?,
    publishAttempts: json['publishAttempts'] as int? ?? 0,
    proofManifestJson: json['proofManifestJson'] as String?,
    aspectRatio: json['aspectRatio'] != null
        ? AspectRatio.values.firstWhere(
            (e) => e.name == json['aspectRatio'],
            orElse: () => AspectRatio.square,
          )
        : AspectRatio.square, // Default for legacy drafts
  );
  final String id;
  final File videoFile;
  final String title;
  final String description;
  final List<String> hashtags;
  final int frameCount;
  final String selectedApproach;
  final DateTime createdAt;
  final DateTime lastModified;
  final PublishStatus publishStatus;
  final String? publishError;
  final int publishAttempts;
  final String? proofManifestJson;
  final AspectRatio aspectRatio;

  /// Check if this draft has ProofMode data
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
        name: 'VineDraft',
        category: LogCategory.system,
      );
      return null;
    }
  }

  VineDraft copyWith({
    String? title,
    String? description,
    List<String>? hashtags,
    PublishStatus? publishStatus,
    Object? publishError = _sentinel,
    int? publishAttempts,
    Object? proofManifestJson = _sentinel,
    AspectRatio? aspectRatio,
  }) => VineDraft(
    id: id,
    videoFile: videoFile,
    title: title ?? this.title,
    description: description ?? this.description,
    hashtags: hashtags ?? this.hashtags,
    frameCount: frameCount,
    selectedApproach: selectedApproach,
    createdAt: createdAt,
    lastModified: DateTime.now(),
    publishStatus: publishStatus ?? this.publishStatus,
    publishError: publishError == _sentinel
        ? this.publishError
        : publishError as String?,
    publishAttempts: publishAttempts ?? this.publishAttempts,
    proofManifestJson: proofManifestJson == _sentinel
        ? this.proofManifestJson
        : proofManifestJson as String?,
    aspectRatio: aspectRatio ?? this.aspectRatio,
  );

  static const _sentinel = Object();

  Map<String, dynamic> toJson() => {
    'id': id,
    'videoFilePath': videoFile.path,
    'title': title,
    'description': description,
    'hashtags': hashtags,
    'frameCount': frameCount,
    'selectedApproach': selectedApproach,
    'createdAt': createdAt.toIso8601String(),
    'lastModified': lastModified.toIso8601String(),
    'publishStatus': publishStatus.name,
    'publishError': publishError,
    'publishAttempts': publishAttempts,
    'proofManifestJson': proofManifestJson,
    'aspectRatio': aspectRatio.name,
  };

  String get displayDuration {
    final duration = DateTime.now().difference(createdAt);
    if (duration.inDays > 0) {
      return '${duration.inDays}d ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  bool get hasTitle => title.trim().isNotEmpty;
  bool get hasDescription => description.trim().isNotEmpty;
  bool get hasHashtags => hashtags.isNotEmpty;
  bool get canRetry => publishStatus == PublishStatus.failed;
  bool get isPublishing => publishStatus == PublishStatus.publishing;
}
