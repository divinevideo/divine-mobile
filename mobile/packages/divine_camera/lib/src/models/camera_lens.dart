// ABOUTME: Enum for camera lens types
// ABOUTME: Defines all available camera lens options

import 'package:flutter/foundation.dart';

/// Available camera lens types.
///
/// Modern smartphones have multiple camera lenses. This enum represents
/// all possible lens types that can be used for video recording.
enum DivineCameraLens {
  /// Front-facing camera (selfie camera).
  front,

  /// Front-facing ultra-wide camera (for group selfies, wider field of view).
  frontUltraWide,

  /// Back-facing main/wide angle camera (default back camera).
  back,

  /// Ultra-wide angle camera (typically 0.5x zoom).
  ultraWide,

  /// Telephoto camera (typically 2x-5x optical zoom).
  telephoto,

  /// Macro camera for close-up shots.
  macro,
  ;

  /// Converts the lens type to a string for platform communication.
  String toNativeString() {
    switch (this) {
      case DivineCameraLens.front:
        return 'front';
      case DivineCameraLens.frontUltraWide:
        return 'frontUltraWide';
      case DivineCameraLens.back:
        return 'back';
      case DivineCameraLens.ultraWide:
        return 'ultraWide';
      case DivineCameraLens.telephoto:
        return 'telephoto';
      case DivineCameraLens.macro:
        return 'macro';
    }
  }

  /// Creates a lens type from a native string.
  static DivineCameraLens fromNativeString(String? value) {
    switch (value) {
      case 'front':
        return DivineCameraLens.front;
      case 'frontUltraWide':
        return DivineCameraLens.frontUltraWide;
      case 'back':
        return DivineCameraLens.back;
      case 'ultraWide':
        return DivineCameraLens.ultraWide;
      case 'telephoto':
        return DivineCameraLens.telephoto;
      case 'macro':
        return DivineCameraLens.macro;
      default:
        return DivineCameraLens.back;
    }
  }

  /// Returns whether the given lens type string represents a front-facing
  /// camera.
  ///
  /// This includes both [front] and [frontUltraWide] lenses.
  static bool isFrontCameraLens(String? value) {
    return fromNativeString(value).isFrontFacing;
  }

  /// Parses a list of native strings to a list of lens types.
  static List<DivineCameraLens> fromNativeStringList(List<dynamic> values) {
    return values.whereType<String>().map(fromNativeString).toList();
  }

  /// Returns the opposite lens direction (front/back toggle).
  /// For specialized lenses (macro, ultraWide, telephoto), returns back.
  /// For front lenses, returns back.
  DivineCameraLens get opposite {
    switch (this) {
      case DivineCameraLens.front:
      case DivineCameraLens.frontUltraWide:
        return DivineCameraLens.back;
      case DivineCameraLens.back:
      case DivineCameraLens.ultraWide:
      case DivineCameraLens.telephoto:
      case DivineCameraLens.macro:
        return DivineCameraLens.front;
    }
  }

  /// Whether this lens is a front-facing camera.
  bool get isFrontFacing =>
      this == DivineCameraLens.front || this == DivineCameraLens.frontUltraWide;

  /// Whether this lens is a back-facing camera (including specialized lenses).
  bool get isBackFacing => !isFrontFacing;

  /// Whether this lens looks at the user, so its preview reads like a mirror.
  ///
  /// True for the front lenses, and for every lens where
  /// [allCamerasFaceUser] holds, including the one reported as [back].
  bool get facesUser => isFrontFacing || allCamerasFaceUser;

  /// Whether every camera on the current platform looks at the user.
  ///
  /// A Mac's cameras (built-in, USB webcam, Continuity Camera) all do, so the
  /// second one, which the plugin reports as [back], is no rear camera.
  static bool get allCamerasFaceUser =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// Returns a human-readable display name for the lens type.
  String get displayName {
    switch (this) {
      case DivineCameraLens.front:
        return 'Front';
      case DivineCameraLens.frontUltraWide:
        return 'Front Wide';
      case DivineCameraLens.back:
        return 'Wide';
      case DivineCameraLens.ultraWide:
        return 'Ultra Wide';
      case DivineCameraLens.telephoto:
        return 'Telephoto';
      case DivineCameraLens.macro:
        return 'Macro';
    }
  }

  /// Returns a short label for UI display (e.g., zoom indicator).
  String get shortLabel {
    switch (this) {
      case DivineCameraLens.front:
        return '1x';
      case DivineCameraLens.frontUltraWide:
        return '0.5x';
      case DivineCameraLens.back:
        return '1x';
      case DivineCameraLens.ultraWide:
        return '0.5x';
      case DivineCameraLens.telephoto:
        return '2x';
      case DivineCameraLens.macro:
        return 'Macro';
    }
  }
}
