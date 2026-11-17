// ABOUTME: State of the second camera while dual-camera capture is on
// ABOUTME: Carries its lens and the preview texture the UI draws it from

import 'package:divine_camera/src/models/camera_lens.dart';
import 'package:equatable/equatable.dart';

/// The second camera of a dual-camera session.
///
/// While dual-camera capture is on, the platform runs the front and the back
/// camera at once. `CameraState.lens` is the camera that fills the viewfinder
/// and records with sound; this one runs beside it, feeds a preview texture
/// of its own and records a second, silent file of every take.
class SecondaryCameraState extends Equatable {
  /// Creates the state of the second camera.
  const SecondaryCameraState({
    required this.lens,
    this.textureId,
    this.aspectRatio = 9 / 16,
    this.previewRotationDegrees = 0,
    this.previewHandlesTransform = false,
  });

  /// Creates a [SecondaryCameraState] from a platform map.
  factory SecondaryCameraState.fromMap(Map<dynamic, dynamic> map) {
    return SecondaryCameraState(
      lens: DivineCameraLens.fromNativeString(map['lens'] as String?),
      textureId: map['textureId'] as int?,
      aspectRatio: (map['aspectRatio'] as num?)?.toDouble() ?? 9 / 16,
      previewRotationDegrees: map['previewRotationDegrees'] as int? ?? 0,
      previewHandlesTransform: map['previewHandlesTransform'] as bool? ?? false,
    );
  }

  /// The lens of the second camera.
  final DivineCameraLens lens;

  /// The texture the second camera's preview is drawn into.
  final int? textureId;

  /// The portrait aspect ratio (width / height) of the second preview.
  final double aspectRatio;

  /// Clockwise rotation to apply to the second preview so it renders upright.
  /// See `CameraState.previewRotationDegrees`.
  final int previewRotationDegrees;

  /// Whether the platform already applies the second preview's rotation and
  /// mirror. See `CameraState.previewHandlesTransform`.
  final bool previewHandlesTransform;

  /// Converts this state to a map.
  Map<String, dynamic> toMap() {
    return {
      'lens': lens.toNativeString(),
      'textureId': textureId,
      'aspectRatio': aspectRatio,
      'previewRotationDegrees': previewRotationDegrees,
      'previewHandlesTransform': previewHandlesTransform,
    };
  }

  @override
  List<Object?> get props => [
    lens,
    textureId,
    aspectRatio,
    previewRotationDegrees,
    previewHandlesTransform,
  ];
}
