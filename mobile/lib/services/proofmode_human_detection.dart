// ABOUTME: ProofMode human activity detection for distinguishing real users from bots
// ABOUTME: Analyzes interaction patterns, timing variations, and biometric micro-signals

import 'dart:math';
import 'package:openvine/services/proofmode_session_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Human activity analysis result
class HumanActivityAnalysis {
  const HumanActivityAnalysis({
    required this.isHumanLikely,
    required this.confidenceScore,
    required this.reasons,
    this.redFlags,
    this.biometricSignals,
  });

  final bool isHumanLikely;
  final double confidenceScore; // 0.0 to 1.0
  final List<String> reasons;
  final List<String>? redFlags;
  final Map<String, dynamic>? biometricSignals;

  Map<String, dynamic> toJson() => {
        'isHumanLikely': isHumanLikely,
        'confidenceScore': confidenceScore,
        'reasons': reasons,
        'redFlags': redFlags,
        'biometricSignals': biometricSignals,
      };
}

/// Interaction timing analysis
class InteractionTiming {
  const InteractionTiming({
    required this.intervals,
    required this.meanInterval,
    required this.standardDeviation,
    required this.variation,
  });

  final List<Duration> intervals;
  final Duration meanInterval;
  final double standardDeviation;
  final double variation; // Coefficient of variation

  bool get hasNaturalVariation =>
      variation > 0.05; // 5% minimum variation expected for humans
  bool get hasSuspiciousPrecision => variation < 0.01; // Too precise for human
}

/// Coordinate precision analysis
class CoordinatePrecision {
  const CoordinatePrecision({
    required this.coordinates,
    required this.precisionScore,
    required this.hasNaturalImprecision,
  });

  final List<Map<String, double>> coordinates;
  final double
      precisionScore; // 0.0 = perfect precision (suspicious), 1.0 = natural variation
  final bool hasNaturalImprecision;
}

/// ProofMode human activity detection service
class ProofModeHumanDetection {
  /// Analyze interaction patterns to determine if they're human-like
  static HumanActivityAnalysis analyzeInteractions(
      List<UserInteractionProof> interactions) {
    Log.debug(
        'Analyzing ${interactions.length} interactions for human activity patterns',
        name: 'ProofModeHumanDetection',
        category: LogCategory.auth);

    final reasons = <String>[];
    final redFlags = <String>[];
    var confidenceScore = 0.5; // Start neutral

    try {
      if (interactions.isEmpty) {
        return HumanActivityAnalysis(
          isHumanLikely: false,
          confidenceScore: 0.0,
          reasons: ['No interactions recorded'],
          redFlags: ['Zero user interactions'],
        );
      }

      // Insufficient data for analysis (need at least 2 interactions for patterns)
      if (interactions.length < 2) {
        return HumanActivityAnalysis(
          isHumanLikely: false,
          confidenceScore: 0.5, // Neutral - insufficient data
          reasons: ['Insufficient interaction data for analysis'],
        );
      }

      // Analyze timing patterns
      final timingAnalysis = _analyzeTimingPatterns(interactions);
      if (timingAnalysis.hasNaturalVariation) {
        reasons.add('Natural timing variation detected');
        confidenceScore += 0.2;
      } else if (timingAnalysis.hasSuspiciousPrecision) {
        redFlags.add('Suspiciously precise timing intervals');
        confidenceScore -= 0.3;
      }

      // Analyze coordinate precision
      final coordinateAnalysis = _analyzeCoordinatePrecision(interactions);
      if (coordinateAnalysis.hasNaturalImprecision) {
        reasons.add('Natural coordinate imprecision');
        confidenceScore += 0.2;
      } else {
        redFlags.add('Perfect coordinate precision (impossible for humans)');
        confidenceScore -= 0.4;
      }

      // Analyze pressure variation (if available)
      final pressureVariation = _analyzePressureVariation(interactions);
      if (pressureVariation > 0.1) {
        reasons.add('Natural pressure variation');
        confidenceScore += 0.15;
      } else if (pressureVariation == 0.0) {
        redFlags.add('No pressure variation detected');
        confidenceScore -= 0.2;
      }

      // Analyze interaction frequency
      final frequency = _analyzeInteractionFrequency(interactions);
      if (frequency.isHumanLike) {
        reasons.add('Human-like interaction frequency');
        confidenceScore += 0.1;
      } else {
        redFlags.add('Suspicious interaction frequency pattern');
        confidenceScore -= 0.2;
      }

      // Check for biometric micro-signals
      final biometricSignals = _detectBiometricSignals(interactions);
      if (biometricSignals['handTremor'] == true) {
        reasons.add('Hand tremor micro-signals detected');
        confidenceScore += 0.25;
      }

      // Clamp confidence score
      confidenceScore = confidenceScore.clamp(0.0, 1.0);

      final isHumanLikely = confidenceScore > 0.6 && redFlags.isEmpty;

      Log.debug(
          'Human activity analysis complete: '
          'likely=$isHumanLikely, confidence=${(confidenceScore * 100).toInt()}%, '
          'reasons=${reasons.length}, redFlags=${redFlags.length}',
          name: 'ProofModeHumanDetection',
          category: LogCategory.auth);

      return HumanActivityAnalysis(
        isHumanLikely: isHumanLikely,
        confidenceScore: confidenceScore,
        reasons: reasons,
        redFlags: redFlags.isEmpty ? null : redFlags,
        biometricSignals: biometricSignals,
      );
    } catch (e) {
      Log.error('Failed to analyze human activity: $e',
          name: 'ProofModeHumanDetection', category: LogCategory.auth);

      return HumanActivityAnalysis(
        isHumanLikely: false,
        confidenceScore: 0.0,
        reasons: ['Analysis failed'],
        redFlags: ['Error during analysis: $e'],
      );
    }
  }

  /// Validate recording session for human authenticity
  static HumanActivityAnalysis validateRecordingSession(
      ProofManifest manifest) {
    Log.info('Validating recording session for human authenticity',
        name: 'ProofModeHumanDetection', category: LogCategory.auth);

    final reasons = <String>[];
    final redFlags = <String>[];
    var confidenceScore = 0.5;

    try {
      // Analyze overall session characteristics
      final sessionDuration = manifest.totalDuration;
      final recordingDuration = manifest.recordingDuration;
      final pauseDuration = sessionDuration - recordingDuration;

      // Check for natural session patterns
      if (sessionDuration.inSeconds > 3 && sessionDuration.inSeconds < 30) {
        reasons.add('Natural session duration');
        confidenceScore += 0.1;
      }

      // Only reward pauses if there's actual recording (can't pause without recording)
      // and pause is meaningful (> 500ms)
      if (pauseDuration.inMilliseconds > 500 &&
          manifest.segments.isNotEmpty) {
        reasons.add('Natural pauses during recording');
        confidenceScore += 0.15;
      }

      // Analyze segments
      if (manifest.segments.length > 1) {
        reasons.add('Multiple recording segments (natural behavior)');
        confidenceScore += 0.1;
      }

      // Check for device attestation
      if (manifest.deviceAttestation?.isHardwareBacked == true) {
        reasons.add('Hardware-backed device attestation');
        confidenceScore += 0.2;
      }

      // Analyze interactions
      final interactionAnalysis = analyzeInteractions(manifest.interactions);
      // Interaction analysis has strong influence on session score
      // Low interaction scores (bot-like) should pull session score down
      // High interaction scores (human-like) should pull session score up
      confidenceScore += (interactionAnalysis.confidenceScore - 0.5) * 1.0;

      if (interactionAnalysis.isHumanLikely) {
        reasons.addAll(interactionAnalysis.reasons);
      } else {
        redFlags.addAll(interactionAnalysis.redFlags ?? []);
      }

      confidenceScore = confidenceScore.clamp(0.0, 1.0);
      final isHumanLikely = confidenceScore > 0.7 && redFlags.length < 2;

      Log.info(
          'Session validation complete: '
          'likely=$isHumanLikely, confidence=${(confidenceScore * 100).toInt()}%',
          name: 'ProofModeHumanDetection',
          category: LogCategory.auth);

      return HumanActivityAnalysis(
        isHumanLikely: isHumanLikely,
        confidenceScore: confidenceScore,
        reasons: reasons,
        redFlags: redFlags.isEmpty ? null : redFlags,
      );
    } catch (e) {
      Log.error('Failed to validate recording session: $e',
          name: 'ProofModeHumanDetection', category: LogCategory.auth);

      return HumanActivityAnalysis(
        isHumanLikely: false,
        confidenceScore: 0.0,
        reasons: ['Validation failed'],
        redFlags: ['Error during validation: $e'],
      );
    }
  }

  // Private analysis methods

  /// Analyze timing patterns between interactions
  static InteractionTiming _analyzeTimingPatterns(
      List<UserInteractionProof> interactions) {
    if (interactions.length < 2) {
      return InteractionTiming(
        intervals: [],
        meanInterval: Duration.zero,
        standardDeviation: 0.0,
        variation: 0.0,
      );
    }

    final intervals = <Duration>[];
    for (int i = 1; i < interactions.length; i++) {
      final interval =
          interactions[i].timestamp.difference(interactions[i - 1].timestamp);
      intervals.add(interval);
    }

    final meanMs =
        intervals.map((d) => d.inMilliseconds).reduce((a, b) => a + b) /
            intervals.length;
    final meanInterval = Duration(milliseconds: meanMs.round());

    // Calculate standard deviation
    final variance = intervals
            .map((d) => pow(d.inMilliseconds - meanMs, 2))
            .reduce((a, b) => a + b) /
        intervals.length;
    final stdDev = sqrt(variance);

    // Coefficient of variation (CV = stdDev / mean)
    final variation = meanMs > 0 ? stdDev / meanMs : 0.0;

    return InteractionTiming(
      intervals: intervals,
      meanInterval: meanInterval,
      standardDeviation: stdDev,
      variation: variation,
    );
  }

  /// Analyze coordinate precision and natural variation
  static CoordinatePrecision _analyzeCoordinatePrecision(
      List<UserInteractionProof> interactions) {
    final coordinates = interactions.map((i) => i.coordinates).toList();

    if (coordinates.isEmpty) {
      return CoordinatePrecision(
        coordinates: [],
        precisionScore: 0.0,
        hasNaturalImprecision: false,
      );
    }

    // Check for identical coordinates (major red flag)
    final uniqueCoords = <String>{};
    for (final coord in coordinates) {
      final key = '${coord['x']}_${coord['y']}';
      uniqueCoords.add(key);
    }

    if (uniqueCoords.length == 1 && coordinates.length > 1) {
      // All coordinates are identical - major bot indicator
      return CoordinatePrecision(
        coordinates: coordinates,
        precisionScore: 0.0,
        hasNaturalImprecision: false,
      );
    }

    // Analyze coordinate variance
    final xValues = coordinates.map((c) => c['x']!).toList();
    final yValues = coordinates.map((c) => c['y']!).toList();

    final xVariance = _calculateVariance(xValues);
    final yVariance = _calculateVariance(yValues);

    // Higher variance indicates more natural human imprecision
    final precisionScore = (xVariance + yVariance).clamp(0.0, 1.0);
    final hasNaturalImprecision =
        precisionScore > 0.000001; // Minimum expected for human touch (adjusted for normalized 0-1 coordinates)

    return CoordinatePrecision(
      coordinates: coordinates,
      precisionScore: precisionScore,
      hasNaturalImprecision: hasNaturalImprecision,
    );
  }

  /// Analyze pressure variation in touch interactions
  static double _analyzePressureVariation(
      List<UserInteractionProof> interactions) {
    final pressures = interactions
        .where((i) => i.pressure != null)
        .map((i) => i.pressure!)
        .toList();

    if (pressures.length < 2) return 0.0;

    return _calculateVariance(pressures);
  }

  /// Analyze interaction frequency patterns
  static ({bool isHumanLike, double frequency}) _analyzeInteractionFrequency(
      List<UserInteractionProof> interactions) {
    if (interactions.length < 2) {
      return (isHumanLike: false, frequency: 0.0);
    }

    final totalDuration =
        interactions.last.timestamp.difference(interactions.first.timestamp);

    // Use milliseconds to avoid division by zero for sub-second durations
    final durationMs = totalDuration.inMilliseconds;
    if (durationMs == 0) {
      return (isHumanLike: false, frequency: 0.0);
    }

    // Calculate interactions per second
    final frequency = (interactions.length / durationMs) * 1000.0;

    // Human interaction frequency: 0.1-20.0 interactions per second
    // (allows for rapid tapping during short video recordings)
    final isHumanLike = frequency >= 0.1 && frequency <= 20.0;

    return (isHumanLike: isHumanLike, frequency: frequency);
  }

  /// Detect biometric micro-signals in interaction patterns
  static Map<String, dynamic> _detectBiometricSignals(
      List<UserInteractionProof> interactions) {
    final signals = <String, dynamic>{};

    // Detect hand tremor patterns (8-12 Hz natural frequency)
    signals['handTremor'] = _detectHandTremor(interactions);

    // Detect breathing influence on touch patterns
    signals['breathingInfluence'] = _detectBreathingInfluence(interactions);

    // Detect natural micro-variations
    signals['microVariations'] = _detectMicroVariations(interactions);

    return signals;
  }

  /// Detect hand tremor patterns in touch coordinates
  static bool _detectHandTremor(List<UserInteractionProof> interactions) {
    if (interactions.length < 10) return false;

    // Look for subtle oscillations in coordinate data
    // Real implementation would use FFT analysis for 8-12 Hz detection
    // For now, just check for small but consistent variations

    final coordinates = interactions.map((i) => i.coordinates).toList();
    var hasConsistentVariation = false;

    for (int i = 2; i < coordinates.length; i++) {
      final prev2 = coordinates[i - 2];
      final prev1 = coordinates[i - 1];
      final curr = coordinates[i];

      final dx1 = (prev1['x']! - prev2['x']!).abs();
      final dx2 = (curr['x']! - prev1['x']!).abs();

      // Look for consistent small movements (tremor-like)
      if (dx1 > 0.001 && dx1 < 0.01 && dx2 > 0.001 && dx2 < 0.01) {
        hasConsistentVariation = true;
        break;
      }
    }

    return hasConsistentVariation;
  }

  /// Detect breathing influence on interaction timing
  static bool _detectBreathingInfluence(
      List<UserInteractionProof> interactions) {
    // Breathing typically affects interaction timing in subtle ways
    // Real implementation would analyze for ~0.2-0.5 Hz patterns
    return interactions.length > 5; // Simplified placeholder
  }

  /// Detect natural micro-variations that bots can't replicate
  static bool _detectMicroVariations(List<UserInteractionProof> interactions) {
    if (interactions.length < 3) return false;

    // Check if any two interactions are exactly identical (suspicious)
    for (int i = 0; i < interactions.length - 1; i++) {
      for (int j = i + 1; j < interactions.length; j++) {
        final coord1 = interactions[i].coordinates;
        final coord2 = interactions[j].coordinates;

        if (coord1['x'] == coord2['x'] && coord1['y'] == coord2['y']) {
          // Identical coordinates found - suspicious
          return false;
        }
      }
    }

    return true; // No identical coordinates found - good sign
  }

  /// Calculate variance of a list of numbers
  static double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) /
            values.length;

    return variance;
  }
}
