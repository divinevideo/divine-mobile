// ABOUTME: State class for camera operations
// ABOUTME: Holds current camera configuration and status

import 'package:divine_camera/src/models/camera_lens.dart';
import 'package:divine_camera/src/models/camera_lens_metadata.dart';
import 'package:divine_camera/src/models/flash_mode.dart';
import 'package:divine_camera/src/models/secondary_camera_state.dart';
import 'package:divine_camera/src/models/video_stabilization_mode.dart';
import 'package:equatable/equatable.dart';

/// Represents the current state of the camera.
class CameraState extends Equatable {
  /// Creates a new camera state.
  const CameraState({
    this.isInitialized = false,
    this.isRecording = false,
    this.isSwitchingCamera = false,
    this.flashMode = DivineCameraFlashMode.off,
    this.lens = DivineCameraLens.back,
    this.zoomLevel = 1.0,
    this.minZoomLevel = 1.0,
    this.maxZoomLevel = 1.0,
    this.aspectRatio = 9 / 16,
    this.hasFlash = false,
    this.hasFrontCamera = false,
    this.hasBackCamera = false,
    this.isFocusPointSupported = false,
    this.isExposurePointSupported = false,
    this.textureId,
    this.previewRotationDegrees = 0,
    this.previewHandlesTransform = false,
    this.availableLenses = const [DivineCameraLens.back],
    this.currentLensMetadata,
    this.videoStabilizationMode = DivineVideoStabilizationMode.off,
    this.availableVideoStabilizationModes = const [
      DivineVideoStabilizationMode.off,
    ],
    this.isVideoStabilizationSupported = false,
    this.isDualCameraSupported = false,
    this.secondaryCamera,
  });

  /// Creates a [CameraState] from a map.
  factory CameraState.fromMap(Map<dynamic, dynamic> map) {
    return CameraState(
      isInitialized: map['isInitialized'] as bool? ?? false,
      isRecording: map['isRecording'] as bool? ?? false,
      isSwitchingCamera: map['isSwitchingCamera'] as bool? ?? false,
      flashMode: DivineCameraFlashMode.fromNativeString(
        map['flashMode'] as String? ?? 'off',
      ),
      lens: DivineCameraLens.fromNativeString(map['lens'] as String? ?? 'back'),
      zoomLevel: (map['zoomLevel'] as num?)?.toDouble() ?? 1.0,
      minZoomLevel: (map['minZoomLevel'] as num?)?.toDouble() ?? 1.0,
      maxZoomLevel: (map['maxZoomLevel'] as num?)?.toDouble() ?? 1.0,
      aspectRatio: (map['aspectRatio'] as num?)?.toDouble() ?? (9 / 16),
      hasFlash: map['hasFlash'] as bool? ?? false,
      hasFrontCamera: map['hasFrontCamera'] as bool? ?? false,
      hasBackCamera: map['hasBackCamera'] as bool? ?? false,
      isFocusPointSupported: map['isFocusPointSupported'] as bool? ?? false,
      isExposurePointSupported:
          map['isExposurePointSupported'] as bool? ?? false,
      textureId: map['textureId'] as int?,
      previewRotationDegrees: map['previewRotationDegrees'] as int? ?? 0,
      previewHandlesTransform: map['previewHandlesTransform'] as bool? ?? false,
      availableLenses: map['availableLenses'] != null
          ? DivineCameraLens.fromNativeStringList(
              map['availableLenses'] as List<dynamic>,
            )
          : const [DivineCameraLens.back],
      currentLensMetadata: map['currentLensMetadata'] != null
          ? CameraLensMetadata.fromMap(
              map['currentLensMetadata'] as Map<dynamic, dynamic>,
            )
          : null,
      videoStabilizationMode: DivineVideoStabilizationMode.fromNativeString(
        map['videoStabilizationMode'] as String? ?? 'off',
      ),
      availableVideoStabilizationModes:
          map['availableVideoStabilizationModes'] != null
          ? DivineVideoStabilizationMode.fromNativeStringList(
              map['availableVideoStabilizationModes'] as List<dynamic>,
            )
          : const [DivineVideoStabilizationMode.off],
      isVideoStabilizationSupported:
          map['isVideoStabilizationSupported'] as bool? ?? false,
      isDualCameraSupported: map['isDualCameraSupported'] as bool? ?? false,
      secondaryCamera: map['secondaryCamera'] != null
          ? SecondaryCameraState.fromMap(
              map['secondaryCamera'] as Map<dynamic, dynamic>,
            )
          : null,
    );
  }

  /// Whether the camera is initialized.
  final bool isInitialized;

  /// Whether the camera is currently recording.
  final bool isRecording;

  /// Whether the camera is currently switching between front and back.
  final bool isSwitchingCamera;

  /// The current flash mode.
  final DivineCameraFlashMode flashMode;

  /// The current camera lens.
  final DivineCameraLens lens;

  /// The current zoom level.
  final double zoomLevel;

  /// The minimum zoom level.
  final double minZoomLevel;

  /// The maximum zoom level.
  final double maxZoomLevel;

  /// The aspect ratio of the camera preview.
  final double aspectRatio;

  /// Whether the camera has a flash.
  final bool hasFlash;

  /// Whether the device has a front camera.
  final bool hasFrontCamera;

  /// Whether the device has a back camera.
  final bool hasBackCamera;

  /// Whether manual focus point selection is supported.
  final bool isFocusPointSupported;

  /// Whether manual exposure point selection is supported.
  final bool isExposurePointSupported;

  /// Opaque preview handle passed to the platform's preview builder.
  ///
  /// Native mobile/Apple implementations use a texture ID. Desktop backends
  /// may use a camera ID that their builder resolves to a texture.
  final int? textureId;

  /// Clockwise rotation (degrees) to apply to the preview texture so it renders
  /// upright. Non-zero on Android when the Flutter surface producer does not
  /// handle crop/rotation itself, in which case the raw camera frames arrive in
  /// sensor orientation and the UI must rotate them.
  final int previewRotationDegrees;

  /// Whether the native surface producer already applies its transform matrix
  /// to the preview (the Android API<29 SurfaceTexture path). When `true`, that
  /// matrix carries both the rotation and the front-camera mirror, so the UI
  /// must apply neither; when `false` (API 29+ ImageReader path) the UI
  /// reconstructs both. Always `false` on non-Android platforms.
  final bool previewHandlesTransform;

  /// List of all available camera lenses on this device.
  /// Includes front, back, ultraWide, telephoto, and macro if supported.
  final List<DivineCameraLens> availableLenses;

  /// Metadata for the currently active camera lens.
  ///
  /// Contains hardware info like focal length, aperture, sensor size.
  final CameraLensMetadata? currentLensMetadata;

  /// The currently requested video stabilization mode.
  final DivineVideoStabilizationMode videoStabilizationMode;

  /// The stabilization modes supported by the active camera/lens.
  /// Always contains at least [DivineVideoStabilizationMode.off].
  final List<DivineVideoStabilizationMode> availableVideoStabilizationModes;

  /// Whether the active camera supports any video stabilization beyond off.
  final bool isVideoStabilizationSupported;

  /// Whether the device can run its front and back camera at the same time.
  ///
  /// iOS reports it on devices with a multi-camera session (iPhone XS / XR
  /// and later), Android on devices that list a concurrent front and back
  /// pair. Never on macOS.
  final bool isDualCameraSupported;

  /// The second camera while dual-camera capture is on, null otherwise.
  ///
  /// [lens] is the camera that fills the viewfinder and records with sound;
  /// this one records a second, silent file of every take.
  final SecondaryCameraState? secondaryCamera;

  /// Whether dual-camera capture is on.
  bool get isDualCameraEnabled => secondaryCamera != null;

  /// Whether the camera can record video.
  bool get canRecord => isInitialized && !isRecording;

  /// Returns all available back-facing lenses (excludes front camera).
  List<DivineCameraLens> get availableBackLenses =>
      availableLenses.where((l) => l.isBackFacing).toList();

  /// Returns all available front-facing lenses.
  List<DivineCameraLens> get availableFrontLenses =>
      availableLenses.where((l) => l.isFrontFacing).toList();

  /// Whether the device has an ultra-wide camera.
  bool get hasUltraWideCamera =>
      availableLenses.contains(DivineCameraLens.ultraWide);

  /// Whether the device has a front ultra-wide camera (for group selfies).
  bool get hasFrontUltraWideCamera =>
      availableLenses.contains(DivineCameraLens.frontUltraWide);

  /// Whether the device has a telephoto camera.
  bool get hasTelephotoCamera =>
      availableLenses.contains(DivineCameraLens.telephoto);

  /// Whether the device has a macro camera.
  bool get hasMacroCamera => availableLenses.contains(DivineCameraLens.macro);

  /// Whether the camera can switch between front and back.
  bool get canSwitchCamera => hasFrontCamera && hasBackCamera;

  /// Creates a copy of this state with the given fields replaced.
  CameraState copyWith({
    bool? isInitialized,
    bool? isRecording,
    bool? isSwitchingCamera,
    DivineCameraFlashMode? flashMode,
    DivineCameraLens? lens,
    double? zoomLevel,
    double? minZoomLevel,
    double? maxZoomLevel,
    double? aspectRatio,
    bool? hasFlash,
    bool? hasFrontCamera,
    bool? hasBackCamera,
    bool? isFocusPointSupported,
    bool? isExposurePointSupported,
    int? textureId,
    int? previewRotationDegrees,
    bool? previewHandlesTransform,
    List<DivineCameraLens>? availableLenses,
    CameraLensMetadata? currentLensMetadata,
    DivineVideoStabilizationMode? videoStabilizationMode,
    List<DivineVideoStabilizationMode>? availableVideoStabilizationModes,
    bool? isVideoStabilizationSupported,
    bool? isDualCameraSupported,
    SecondaryCameraState? secondaryCamera,
    bool clearSecondaryCamera = false,
  }) {
    return CameraState(
      isInitialized: isInitialized ?? this.isInitialized,
      isRecording: isRecording ?? this.isRecording,
      isSwitchingCamera: isSwitchingCamera ?? this.isSwitchingCamera,
      flashMode: flashMode ?? this.flashMode,
      lens: lens ?? this.lens,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      minZoomLevel: minZoomLevel ?? this.minZoomLevel,
      maxZoomLevel: maxZoomLevel ?? this.maxZoomLevel,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      hasFlash: hasFlash ?? this.hasFlash,
      hasFrontCamera: hasFrontCamera ?? this.hasFrontCamera,
      hasBackCamera: hasBackCamera ?? this.hasBackCamera,
      isFocusPointSupported:
          isFocusPointSupported ?? this.isFocusPointSupported,
      isExposurePointSupported:
          isExposurePointSupported ?? this.isExposurePointSupported,
      textureId: textureId ?? this.textureId,
      previewRotationDegrees:
          previewRotationDegrees ?? this.previewRotationDegrees,
      previewHandlesTransform:
          previewHandlesTransform ?? this.previewHandlesTransform,
      availableLenses: availableLenses ?? this.availableLenses,
      currentLensMetadata: currentLensMetadata ?? this.currentLensMetadata,
      videoStabilizationMode:
          videoStabilizationMode ?? this.videoStabilizationMode,
      availableVideoStabilizationModes:
          availableVideoStabilizationModes ??
          this.availableVideoStabilizationModes,
      isVideoStabilizationSupported:
          isVideoStabilizationSupported ?? this.isVideoStabilizationSupported,
      isDualCameraSupported:
          isDualCameraSupported ?? this.isDualCameraSupported,
      secondaryCamera: clearSecondaryCamera
          ? null
          : secondaryCamera ?? this.secondaryCamera,
    );
  }

  /// Converts this [CameraState] to a map.
  Map<String, dynamic> toMap() {
    return {
      'isInitialized': isInitialized,
      'isRecording': isRecording,
      'isSwitchingCamera': isSwitchingCamera,
      'flashMode': flashMode.name,
      'lens': lens.name,
      'zoomLevel': zoomLevel,
      'minZoomLevel': minZoomLevel,
      'maxZoomLevel': maxZoomLevel,
      'aspectRatio': aspectRatio,
      'hasFlash': hasFlash,
      'hasFrontCamera': hasFrontCamera,
      'hasBackCamera': hasBackCamera,
      'isFocusPointSupported': isFocusPointSupported,
      'isExposurePointSupported': isExposurePointSupported,
      'textureId': textureId,
      'previewRotationDegrees': previewRotationDegrees,
      'previewHandlesTransform': previewHandlesTransform,
      'availableLenses': availableLenses
          .map((l) => l.toNativeString())
          .toList(),
      'currentLensMetadata': currentLensMetadata?.toMap(),
      'videoStabilizationMode': videoStabilizationMode.toNativeString(),
      'availableVideoStabilizationModes': availableVideoStabilizationModes
          .map((m) => m.toNativeString())
          .toList(),
      'isVideoStabilizationSupported': isVideoStabilizationSupported,
      'isDualCameraSupported': isDualCameraSupported,
      'secondaryCamera': secondaryCamera?.toMap(),
    };
  }

  @override
  String toString() {
    return 'CameraState(isInitialized: $isInitialized, '
        'isRecording: $isRecording, '
        'isSwitchingCamera: $isSwitchingCamera, '
        'flashMode: $flashMode, '
        'lens: $lens, '
        'zoomLevel: $zoomLevel, '
        'minZoomLevel: $minZoomLevel, '
        'maxZoomLevel: $maxZoomLevel, '
        'aspectRatio: $aspectRatio, '
        'hasFlash: $hasFlash, '
        'hasFrontCamera: $hasFrontCamera, '
        'hasBackCamera: $hasBackCamera, '
        'isFocusPointSupported: $isFocusPointSupported, '
        'isExposurePointSupported: $isExposurePointSupported, '
        'textureId: $textureId, '
        'previewRotationDegrees: $previewRotationDegrees, '
        'previewHandlesTransform: $previewHandlesTransform, '
        'availableLenses: $availableLenses, '
        'currentLensMetadata: $currentLensMetadata, '
        'videoStabilizationMode: $videoStabilizationMode, '
        'availableVideoStabilizationModes: '
        '$availableVideoStabilizationModes, '
        'isVideoStabilizationSupported: $isVideoStabilizationSupported, '
        'isDualCameraSupported: $isDualCameraSupported, '
        'secondaryCamera: $secondaryCamera)';
  }

  @override
  List<Object?> get props => [
    isInitialized,
    isRecording,
    isSwitchingCamera,
    flashMode,
    lens,
    zoomLevel,
    minZoomLevel,
    maxZoomLevel,
    aspectRatio,
    hasFlash,
    hasFrontCamera,
    hasBackCamera,
    isFocusPointSupported,
    isExposurePointSupported,
    textureId,
    previewRotationDegrees,
    previewHandlesTransform,
    availableLenses,
    currentLensMetadata,
    videoStabilizationMode,
    availableVideoStabilizationModes,
    isVideoStabilizationSupported,
    isDualCameraSupported,
    secondaryCamera,
  ];
}
