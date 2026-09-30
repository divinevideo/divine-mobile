// ABOUTME: Metadata class for camera lens properties
// ABOUTME: Contains hardware info like focal length, aperture, sensor size

import 'package:equatable/equatable.dart';

/// Contains hardware metadata for a specific camera lens.
///
/// This includes physical characteristics like focal length, aperture,
/// sensor dimensions, and capabilities like minimum focus distance.
class CameraLensMetadata extends Equatable {
  /// Creates camera lens metadata.
  const CameraLensMetadata({
    required this.lensType,
    this.cameraId,
    this.focalLength,
    this.focalLengthEquivalent35mm,
    this.aperture,
    this.sensorWidth,
    this.sensorHeight,
    this.pixelArrayWidth,
    this.pixelArrayHeight,
    this.minFocusDistance,
    this.fieldOfView,
    this.hasOpticalStabilization = false,
    this.isLogicalCamera = false,
    this.physicalCameraIds = const [],
    this.exposureDuration,
    this.exposureTimeMin,
    this.exposureTimeMax,
    this.iso,
    this.isoMin,
    this.isoMax,
  });

  /// Creates [CameraLensMetadata] from a platform map.
  ///
  /// A reading that is not a finite number is taken as unknown (`null`): see
  /// [_finite].
  factory CameraLensMetadata.fromMap(Map<dynamic, dynamic> map) {
    return CameraLensMetadata(
      lensType: map['lensType'] as String? ?? 'unknown',
      cameraId: map['cameraId'] as String?,
      focalLength: _finite(map['focalLength'] as num?),
      focalLengthEquivalent35mm: _finite(
        map['focalLengthEquivalent35mm'] as num?,
      ),
      aperture: _finite(map['aperture'] as num?),
      sensorWidth: _finite(map['sensorWidth'] as num?),
      sensorHeight: _finite(map['sensorHeight'] as num?),
      pixelArrayWidth: map['pixelArrayWidth'] as int?,
      pixelArrayHeight: map['pixelArrayHeight'] as int?,
      minFocusDistance: _finite(map['minFocusDistance'] as num?),
      fieldOfView: _finite(map['fieldOfView'] as num?),
      hasOpticalStabilization: map['hasOpticalStabilization'] as bool? ?? false,
      isLogicalCamera: map['isLogicalCamera'] as bool? ?? false,
      physicalCameraIds:
          (map['physicalCameraIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      exposureDuration: _finite(map['exposureDuration'] as num?),
      exposureTimeMin: _finite(map['exposureTimeMin'] as num?),
      exposureTimeMax: _finite(map['exposureTimeMax'] as num?),
      iso: _finite(map['iso'] as num?),
      isoMin: map['isoMin'] as int?,
      isoMax: map['isoMax'] as int?,
    );
  }

  /// [value] as a double, or `null` when it is absent or not finite.
  ///
  /// iOS reads exposure as `CMTimeGetSeconds(device.exposureDuration)`, which
  /// returns NaN for an invalid time. The metadata rides along on every
  /// recorded clip and `json.encode` rejects NaN, so one such reading made
  /// every draft save and autosave holding that clip fail.
  static double? _finite(num? value) {
    final number = value?.toDouble();
    return number != null && number.isFinite ? number : null;
  }

  /// The lens type identifier (e.g., 'back', 'front', 'ultraWide').
  final String lensType;

  /// Platform-specific camera hardware identifier.
  ///
  /// On iOS: AVCaptureDevice.uniqueID
  /// On Android: Camera ID string (e.g., "0", "1")
  final String? cameraId;

  /// Physical focal length in millimeters.
  ///
  /// Typical values:
  /// - Ultra-wide: ~1.5-2.5mm
  /// - Wide (main): ~4-6mm
  /// - Telephoto: ~6-12mm
  final double? focalLength;

  /// 35mm equivalent focal length.
  ///
  /// This standardized value allows comparison across devices:
  /// - Ultra-wide: ~13-16mm
  /// - Wide (main): ~24-28mm
  /// - Telephoto: ~52-77mm
  final double? focalLengthEquivalent35mm;

  /// Lens aperture (f-number).
  ///
  /// Lower values = wider aperture = more light.
  /// Typical smartphone values: f/1.5 - f/2.8
  final double? aperture;

  /// Physical sensor width in millimeters.
  final double? sensorWidth;

  /// Physical sensor height in millimeters.
  final double? sensorHeight;

  /// Sensor resolution width in pixels.
  final int? pixelArrayWidth;

  /// Sensor resolution height in pixels.
  final int? pixelArrayHeight;

  /// Minimum focus distance in diopters (1/distance in meters).
  ///
  /// Higher values = closer focusing capability.
  /// - Normal lenses: ~10 diopters (~10cm)
  /// - Macro lenses: ~25+ diopters (~4cm or less)
  /// - Fixed-focus front cameras: often 0 (infinity focus)
  final double? minFocusDistance;

  /// Horizontal field of view in degrees.
  ///
  /// Typical values:
  /// - Ultra-wide: ~120°
  /// - Wide (main): ~80°
  /// - Telephoto: ~40°
  final double? fieldOfView;

  /// Whether this lens has optical image stabilization (OIS).
  final bool hasOpticalStabilization;

  /// Whether this is a logical multi-camera
  /// (combines multiple physical cameras).
  final bool isLogicalCamera;

  /// IDs of physical cameras that make up this logical camera.
  final List<String> physicalCameraIds;

  /// Current exposure duration in seconds (iOS only, live value).
  ///
  /// This is the actual exposure time being used for the current frame.
  final double? exposureDuration;

  /// Minimum supported exposure time in seconds (Android only).
  ///
  /// From SENSOR_INFO_EXPOSURE_TIME_RANGE.
  final double? exposureTimeMin;

  /// Maximum supported exposure time in seconds (Android only).
  ///
  /// From SENSOR_INFO_EXPOSURE_TIME_RANGE.
  final double? exposureTimeMax;

  /// Current ISO sensitivity (iOS only, live value).
  ///
  /// This is the actual ISO being used for the current frame.
  final double? iso;

  /// Minimum supported ISO sensitivity (Android only).
  ///
  /// From SENSOR_INFO_SENSITIVITY_RANGE.
  final int? isoMin;

  /// Maximum supported ISO sensitivity (Android only).
  ///
  /// From SENSOR_INFO_SENSITIVITY_RANGE.
  final int? isoMax;

  /// Sensor resolution in megapixels.
  double? get megapixels {
    if (pixelArrayWidth == null || pixelArrayHeight == null) return null;
    return (pixelArrayWidth! * pixelArrayHeight!) / 1e6;
  }

  /// Minimum focus distance in centimeters.
  ///
  /// Returns null if the camera has fixed focus (diopters = 0).
  double? get minFocusDistanceCm {
    if (minFocusDistance == null || minFocusDistance == 0) return null;
    return 100.0 / minFocusDistance!;
  }

  /// Whether this lens can be considered a macro lens.
  ///
  /// Based on minimum focus distance being very close (< 5cm).
  bool get isMacroCapable {
    final distance = minFocusDistanceCm;
    return distance != null && distance < 5.0;
  }

  /// Converts this [CameraLensMetadata] to a map.
  Map<String, dynamic> toMap() {
    return {
      'lensType': lensType,
      'cameraId': cameraId,
      'focalLength': focalLength,
      'focalLengthEquivalent35mm': focalLengthEquivalent35mm,
      'aperture': aperture,
      'sensorWidth': sensorWidth,
      'sensorHeight': sensorHeight,
      'pixelArrayWidth': pixelArrayWidth,
      'pixelArrayHeight': pixelArrayHeight,
      'minFocusDistance': minFocusDistance,
      'fieldOfView': fieldOfView,
      'hasOpticalStabilization': hasOpticalStabilization,
      'isLogicalCamera': isLogicalCamera,
      'physicalCameraIds': physicalCameraIds,
      'exposureDuration': exposureDuration,
      'exposureTimeMin': exposureTimeMin,
      'exposureTimeMax': exposureTimeMax,
      'iso': iso,
      'isoMin': isoMin,
      'isoMax': isoMax,
    };
  }

  @override
  String toString() {
    return 'CameraLensMetadata('
        'lensType: $lensType, '
        'cameraId: $cameraId, '
        'focalLength: ${focalLength}mm, '
        'aperture: f/$aperture, '
        'megapixels: ${megapixels?.toStringAsFixed(1)}MP)';
  }

  @override
  List<Object?> get props => [
    lensType,
    cameraId,
    focalLength,
    focalLengthEquivalent35mm,
    aperture,
    sensorWidth,
    sensorHeight,
    pixelArrayWidth,
    pixelArrayHeight,
    minFocusDistance,
    fieldOfView,
    hasOpticalStabilization,
    isLogicalCamera,
    physicalCameraIds,
    exposureDuration,
    exposureTimeMin,
    exposureTimeMax,
    iso,
    isoMin,
    isoMax,
  ];

  /// Creates a copy of this metadata with the given fields replaced.
  CameraLensMetadata copyWith({
    String? lensType,
    String? cameraId,
    double? focalLength,
    double? focalLengthEquivalent35mm,
    double? aperture,
    double? sensorWidth,
    double? sensorHeight,
    int? pixelArrayWidth,
    int? pixelArrayHeight,
    double? minFocusDistance,
    double? fieldOfView,
    bool? hasOpticalStabilization,
    bool? isLogicalCamera,
    List<String>? physicalCameraIds,
    double? exposureDuration,
    double? exposureTimeMin,
    double? exposureTimeMax,
    double? iso,
    int? isoMin,
    int? isoMax,
  }) {
    return CameraLensMetadata(
      lensType: lensType ?? this.lensType,
      cameraId: cameraId ?? this.cameraId,
      focalLength: focalLength ?? this.focalLength,
      focalLengthEquivalent35mm:
          focalLengthEquivalent35mm ?? this.focalLengthEquivalent35mm,
      aperture: aperture ?? this.aperture,
      sensorWidth: sensorWidth ?? this.sensorWidth,
      sensorHeight: sensorHeight ?? this.sensorHeight,
      pixelArrayWidth: pixelArrayWidth ?? this.pixelArrayWidth,
      pixelArrayHeight: pixelArrayHeight ?? this.pixelArrayHeight,
      minFocusDistance: minFocusDistance ?? this.minFocusDistance,
      fieldOfView: fieldOfView ?? this.fieldOfView,
      hasOpticalStabilization:
          hasOpticalStabilization ?? this.hasOpticalStabilization,
      isLogicalCamera: isLogicalCamera ?? this.isLogicalCamera,
      physicalCameraIds: physicalCameraIds ?? this.physicalCameraIds,
      exposureDuration: exposureDuration ?? this.exposureDuration,
      exposureTimeMin: exposureTimeMin ?? this.exposureTimeMin,
      exposureTimeMax: exposureTimeMax ?? this.exposureTimeMax,
      iso: iso ?? this.iso,
      isoMin: isoMin ?? this.isoMin,
      isoMax: isoMax ?? this.isoMax,
    );
  }
}
