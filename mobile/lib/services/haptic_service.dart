// ABOUTME: Centralized haptic feedback service.
// ABOUTME: Single place to change haptic feedback types across the app.

import 'package:flutter/services.dart';

/// Centralized service for triggering haptic feedback.
///
/// All haptic feedback in the app should go through this service.
/// Semantic methods provide meaningful names at call sites, while
/// delegating to core methods that control the actual intensity.
///
/// To change the intensity for a specific interaction, update the
/// semantic method. To change the intensity globally, update the
/// core method it delegates to.
abstract class HapticService {
  // -- Core methods (control intensity) --

  /// Light haptic feedback for standard interactions.
  static Future<void> lightImpact() => HapticFeedback.lightImpact();

  /// Heavy haptic feedback for significant interactions.
  static Future<void> heavyImpact() => HapticFeedback.heavyImpact();

  // -- Semantic methods (meaningful names at call sites) --

  /// Haptic feedback for recording state changes.
  ///
  /// Triggered when recording starts, stops, or a countdown finishes.
  static Future<void> recordingFeedback() => lightImpact();

  /// Haptic feedback when a layer snaps to a helper line.
  static Future<void> snapFeedback() => lightImpact();

  /// Haptic feedback when a press-and-hold enters immersive viewing.
  ///
  /// The gesture hides the chrome rather than showing anything new, so this
  /// is the only confirmation that the hold registered.
  static Future<void> immersiveModeFeedback() => lightImpact();

  /// Haptic feedback when entering a destructive zone.
  ///
  /// Triggered when dragging a layer or clip over a delete/remove area
  /// to warn the user about the pending destructive action.
  static Future<void> destructiveZoneFeedback() => heavyImpact();
}
