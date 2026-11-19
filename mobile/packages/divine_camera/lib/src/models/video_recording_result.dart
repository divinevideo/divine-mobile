// ABOUTME: Result class for video recording operations
// ABOUTME: Contains path, duration, and metadata of recorded video

import 'dart:io';

import 'package:divine_camera/src/models/camera_lens.dart';
import 'package:equatable/equatable.dart';

/// Result of a video recording operation.
class VideoRecordingResult extends Equatable {
  /// Creates a new video recording result.
  const VideoRecordingResult({
    required this.filePath,
    this.durationMs,
    this.width,
    this.height,
    this.lens,
    this.startOffsetMs,
    this.secondary,
  });

  /// Creates a [VideoRecordingResult] from a map.
  factory VideoRecordingResult.fromMap(Map<dynamic, dynamic> map) {
    final lens = map['lens'] as String?;
    final secondary = map['secondary'] as Map<dynamic, dynamic>?;
    return VideoRecordingResult(
      filePath: map['filePath'] as String,
      durationMs: map['durationMs'] as int?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      lens: lens == null ? null : DivineCameraLens.fromNativeString(lens),
      startOffsetMs: map['startOffsetMs'] as int?,
      secondary: secondary?['filePath'] == null
          ? null
          : VideoRecordingResult.fromMap(secondary!),
    );
  }

  /// The path to the recorded video file.
  final String filePath;

  /// The duration of the recorded video in milliseconds.
  final int? durationMs;

  /// The width of the recorded video in pixels.
  final int? width;

  /// The height of the recorded video in pixels.
  final int? height;

  /// The lens that recorded this file, when the platform reports it.
  final DivineCameraLens? lens;

  /// For the second camera's file of a dual-camera take: how far into this
  /// file the main take begins, in milliseconds.
  ///
  /// Android records the two cameras with separate recorders, so the second
  /// one starts a little earlier and runs until the main take is written;
  /// skipping this lead-in lines the files up. Null or 0 when both start on
  /// the same frame (iOS).
  final int? startOffsetMs;

  /// The second camera's file of the same take, recorded while dual-camera
  /// capture was on. It has no sound and covers at least the whole take;
  /// [startOffsetMs] on it says where the take begins. Null for a
  /// single-camera take, or when the second camera captured nothing.
  final VideoRecordingResult? secondary;

  /// [startOffsetMs] as a [Duration], zero when unknown.
  Duration get startOffset => Duration(milliseconds: startOffsetMs ?? 0);

  /// Returns the video file.
  File get file => File(filePath);

  /// Returns the duration as a [Duration] object.
  Duration? get duration =>
      durationMs != null ? Duration(milliseconds: durationMs!) : null;

  /// Converts this result to a map.
  Map<String, dynamic> toMap() {
    return {
      'filePath': filePath,
      'durationMs': durationMs,
      'width': width,
      'height': height,
      'lens': lens?.toNativeString(),
      'startOffsetMs': startOffsetMs,
      'secondary': secondary?.toMap(),
    };
  }

  @override
  String toString() {
    return 'VideoRecordingResult(filePath: $filePath, durationMs: $durationMs, '
        'width: $width, height: $height, lens: $lens, '
        'startOffsetMs: $startOffsetMs, secondary: $secondary)';
  }

  @override
  List<Object?> get props => [
    filePath,
    durationMs,
    width,
    height,
    lens,
    startOffsetMs,
    secondary,
  ];
}
