// ABOUTME: Comprehensive unit tests for ProofMode human activity detection algorithms
// ABOUTME: Tests bot detection, timing analysis, and biometric signal detection

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/proofmode_human_detection.dart';
import 'package:openvine/services/proofmode_session_service.dart';
import 'package:openvine/services/proofmode_attestation_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ProofModeHumanDetection', () {
    setUpAll(() async {
      await setupTestEnvironment();
    });

    group('Interaction Analysis', () {
      test('should detect human-like interactions with natural variation', () {
        final interactions = _generateHumanLikeInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          interactions,
        );

        expect(analysis.isHumanLikely, isTrue);
        expect(analysis.confidenceScore, greaterThan(0.6));
        expect(analysis.reasons, isNotEmpty);
        expect(analysis.redFlags, isNull);
      });

      test('should detect bot-like interactions with perfect precision', () {
        final interactions = _generateBotLikeInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          interactions,
        );

        expect(analysis.isHumanLikely, isFalse);
        expect(analysis.confidenceScore, lessThan(0.4));
        expect(analysis.redFlags, isNotEmpty);
        expect(
          analysis.redFlags,
          contains(contains('Perfect coordinate precision')),
        );
      });

      test('should handle empty interaction list', () {
        final analysis = ProofModeHumanDetection.analyzeInteractions([]);

        expect(analysis.isHumanLikely, isFalse);
        expect(analysis.confidenceScore, equals(0.0));
        expect(analysis.reasons, contains('No interactions recorded'));
        expect(analysis.redFlags, contains('Zero user interactions'));
      });

      test('should detect suspicious timing patterns', () {
        final interactions = _generatePerfectTimingInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          interactions,
        );

        expect(analysis.isHumanLikely, isFalse);
        expect(analysis.redFlags, contains(contains('precise timing')));
      });

      test('should reward natural pressure variation', () {
        final interactions = _generatePressureVariationInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          interactions,
        );

        expect(analysis.isHumanLikely, isTrue);
        expect(analysis.reasons, contains(contains('pressure variation')));
        expect(analysis.confidenceScore, greaterThan(0.6));
      });

      test('should penalize identical coordinates', () {
        final interactions = _generateIdenticalCoordinateInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          interactions,
        );

        expect(analysis.isHumanLikely, isFalse);
        expect(analysis.redFlags, contains(contains('impossible for humans')));
      });

      test('should detect biometric micro-signals', () {
        final interactions = _generateTremorLikeInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          interactions,
        );

        expect(analysis.biometricSignals, isNotNull);
        expect(analysis.biometricSignals!['handTremor'], isA<bool>());
      });
    });

    group('Session Validation', () {
      test('should validate human session with multiple segments', () {
        final manifest = _generateHumanLikeSession();

        final analysis = ProofModeHumanDetection.validateRecordingSession(
          manifest,
        );

        expect(analysis.isHumanLikely, isTrue);
        expect(analysis.confidenceScore, greaterThan(0.7));
        expect(
          analysis.reasons,
          contains(contains('Multiple recording segments')),
        );
      });

      test('should validate session with hardware attestation', () {
        final manifest = _generateHardwareAttestedSession();

        final analysis = ProofModeHumanDetection.validateRecordingSession(
          manifest,
        );

        expect(analysis.isHumanLikely, isTrue);
        expect(
          analysis.reasons,
          contains(contains('Hardware-backed device attestation')),
        );
      });

      test('should penalize suspicious session patterns', () {
        final manifest = _generateSuspiciousSession();

        final analysis = ProofModeHumanDetection.validateRecordingSession(
          manifest,
        );

        expect(analysis.isHumanLikely, isFalse);
        expect(analysis.confidenceScore, lessThan(0.5));
      });

      test('should handle sessions with natural pauses', () {
        final manifest = _generateSessionWithPauses();

        final analysis = ProofModeHumanDetection.validateRecordingSession(
          manifest,
        );

        expect(
          analysis.reasons,
          contains(contains('Natural pauses during recording')),
        );
        expect(analysis.confidenceScore, greaterThan(0.6));
      });

      test('should validate natural session duration', () {
        final manifest = _generateNaturalDurationSession();

        final analysis = ProofModeHumanDetection.validateRecordingSession(
          manifest,
        );

        expect(
          analysis.reasons,
          contains(contains('Natural session duration')),
        );
      });
    });

    group('Timing Pattern Analysis', () {
      test('should detect natural timing variation', () {
        final interactions = _generateNaturalTimingInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          interactions,
        );

        expect(
          analysis.reasons,
          contains(contains('Natural timing variation')),
        );
        expect(analysis.confidenceScore, greaterThan(0.5));
      });

      test('should detect robotic timing precision', () {
        final interactions = _generateRoboticTimingInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          interactions,
        );

        expect(analysis.redFlags, contains(contains('precise timing')));
        expect(analysis.confidenceScore, lessThan(0.4));
      });

      test('should analyze interaction frequency correctly', () {
        final highFrequencyInteractions = _generateHighFrequencyInteractions();
        final normalFrequencyInteractions =
            _generateNormalFrequencyInteractions();

        final highAnalysis = ProofModeHumanDetection.analyzeInteractions(
          highFrequencyInteractions,
        );
        final normalAnalysis = ProofModeHumanDetection.analyzeInteractions(
          normalFrequencyInteractions,
        );

        expect(
          normalAnalysis.confidenceScore,
          greaterThan(highAnalysis.confidenceScore),
        );
      });
    });

    group('Coordinate Precision Analysis', () {
      test('should detect natural coordinate imprecision', () {
        final interactions = _generateNaturalCoordinateInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          interactions,
        );

        expect(
          analysis.reasons,
          contains(contains('Natural coordinate imprecision')),
        );
        expect(analysis.confidenceScore, greaterThanOrEqualTo(0.6));
      });

      test('should detect perfect coordinate precision as suspicious', () {
        final interactions = _generatePerfectCoordinateInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          interactions,
        );

        expect(
          analysis.redFlags,
          contains(contains('Perfect coordinate precision')),
        );
        expect(analysis.isHumanLikely, isFalse);
      });

      test('should handle single interaction gracefully', () {
        final singleInteraction = [_createInteraction('touch', 0.5, 0.5)];

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          singleInteraction,
        );

        // Should not crash and should provide some analysis
        expect(analysis, isNotNull);
        expect(analysis.confidenceScore, greaterThan(0.0));
      });
    });

    group('Biometric Signal Detection', () {
      test('should detect hand tremor patterns', () {
        final interactions = _generateHandTremorInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          interactions,
        );

        expect(analysis.biometricSignals, isNotNull);
        expect(analysis.biometricSignals!['handTremor'], isNotNull);
        if (analysis.biometricSignals!['handTremor'] == true) {
          expect(
            analysis.reasons,
            contains(contains('Hand tremor micro-signals detected')),
          );
        }
      });

      test('should detect micro-variations in human behavior', () {
        final interactions = _generateMicroVariationInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          interactions,
        );

        expect(analysis.biometricSignals, isNotNull);
        expect(analysis.biometricSignals!['microVariations'], isA<bool>());
      });

      test('should analyze breathing influence patterns', () {
        final interactions = _generateBreathingInfluenceInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          interactions,
        );

        expect(analysis.biometricSignals, isNotNull);
        expect(analysis.biometricSignals!['breathingInfluence'], isA<bool>());
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle malformed interaction data gracefully', () {
        final malformedInteractions = _generateMalformedInteractions();

        expect(
          () => ProofModeHumanDetection.analyzeInteractions(
            malformedInteractions,
          ),
          returnsNormally,
        );
      });

      test('should handle extreme coordinate values', () {
        final extremeInteractions = _generateExtremeCoordinateInteractions();

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          extremeInteractions,
        );

        expect(analysis, isNotNull);
        expect(analysis.confidenceScore, isA<double>());
      });

      test('should handle very large interaction lists', () {
        final largeInteractionList = _generateLargeInteractionList(1000);

        final analysis = ProofModeHumanDetection.analyzeInteractions(
          largeInteractionList,
        );

        expect(analysis, isNotNull);
        expect(analysis.confidenceScore, isA<double>());
      });
    });
  });
}

// Helper functions to generate test data

List<UserInteractionProof> _generateHumanLikeInteractions() {
  final baseTime = DateTime.now();
  // Natural human timing with variation (80-120ms intervals)
  return [
    _createInteraction(
      'start',
      0.500,
      0.500,
      pressure: 0.7,
      timestamp: baseTime,
    ),
    _createInteraction(
      'touch',
      0.502,
      0.498,
      pressure: 0.6,
      timestamp: baseTime.add(Duration(milliseconds: 95)),
    ),
    _createInteraction(
      'touch',
      0.498,
      0.503,
      pressure: 0.8,
      timestamp: baseTime.add(Duration(milliseconds: 207)),
    ),
    _createInteraction(
      'touch',
      0.501,
      0.497,
      pressure: 0.7,
      timestamp: baseTime.add(Duration(milliseconds: 288)),
    ),
    _createInteraction(
      'stop',
      0.499,
      0.501,
      pressure: 0.5,
      timestamp: baseTime.add(Duration(milliseconds: 405)),
    ),
  ];
}

List<UserInteractionProof> _generateBotLikeInteractions() {
  final baseTime = DateTime.now();
  // Bot-like: perfect coordinates AND perfect timing (100ms exactly)
  return [
    _createInteraction(
      'start',
      0.500,
      0.500,
      pressure: 0.5,
      timestamp: baseTime,
    ),
    _createInteraction(
      'touch',
      0.500,
      0.500,
      pressure: 0.5,
      timestamp: baseTime.add(Duration(milliseconds: 100)),
    ),
    _createInteraction(
      'touch',
      0.500,
      0.500,
      pressure: 0.5,
      timestamp: baseTime.add(Duration(milliseconds: 200)),
    ),
    _createInteraction(
      'touch',
      0.500,
      0.500,
      pressure: 0.5,
      timestamp: baseTime.add(Duration(milliseconds: 300)),
    ),
    _createInteraction(
      'stop',
      0.500,
      0.500,
      pressure: 0.5,
      timestamp: baseTime.add(Duration(milliseconds: 400)),
    ),
  ];
}

List<UserInteractionProof> _generatePerfectTimingInteractions() {
  final baseTime = DateTime.now();
  return List.generate(
    5,
    (i) => UserInteractionProof(
      timestamp: baseTime.add(
        Duration(milliseconds: i * 100),
      ), // Perfect 100ms intervals
      interactionType: 'touch',
      coordinates: {'x': 0.5 + i * 0.001, 'y': 0.5 + i * 0.001},
    ),
  );
}

List<UserInteractionProof> _generatePressureVariationInteractions() {
  final baseTime = DateTime.now();
  // Realistic human pressure variation: light taps to firm presses
  // Variance: 0.106 > 0.1 threshold
  final pressures = [0.1, 0.9, 0.2, 0.8, 0.3];
  return List.generate(
    5,
    (i) => _createInteraction(
      'touch',
      0.5 + i * 0.01,
      0.5 + i * 0.01,
      pressure: pressures[i],
      timestamp: baseTime.add(
        Duration(milliseconds: i * 110),
      ), // Natural timing
    ),
  );
}

List<UserInteractionProof> _generateIdenticalCoordinateInteractions() {
  final baseTime = DateTime.now();
  return List.generate(
    5,
    (i) => _createInteraction(
      'touch',
      0.5,
      0.5,
      timestamp: baseTime.add(Duration(milliseconds: i * 100)),
    ),
  ); // Regular timing
}

List<UserInteractionProof> _generateTremorLikeInteractions() {
  final baseTime = DateTime.now();
  return List.generate(
    15,
    (i) => _createInteraction(
      'touch',
      0.5 + (i % 2 == 0 ? 0.002 : -0.002), // Small oscillation
      0.5 + (i % 3 == 0 ? 0.001 : -0.001),
      timestamp: baseTime.add(
        Duration(milliseconds: i * 125),
      ), // ~8Hz tremor timing
    ),
  );
}

List<UserInteractionProof> _generateNaturalTimingInteractions() {
  final baseTime = DateTime.now();
  final intervals = [95, 103, 98, 107, 91]; // Natural variation around 100ms
  var currentTime = baseTime;

  return List.generate(5, (i) {
    currentTime = currentTime.add(Duration(milliseconds: intervals[i]));
    return UserInteractionProof(
      timestamp: currentTime,
      interactionType: 'touch',
      coordinates: {
        'x': 0.5 + i * 0.002,
        'y': 0.5 + i * 0.001,
      }, // Natural coordinate variation
    );
  });
}

List<UserInteractionProof> _generateRoboticTimingInteractions() {
  final baseTime = DateTime.now();
  return List.generate(
    5,
    (i) => UserInteractionProof(
      timestamp: baseTime.add(
        Duration(milliseconds: i * 100),
      ), // Perfect timing
      interactionType: 'touch',
      coordinates: {'x': 0.5, 'y': 0.5},
    ),
  );
}

List<UserInteractionProof> _generateHighFrequencyInteractions() {
  final baseTime = DateTime.now();
  return List.generate(
    50,
    (i) => UserInteractionProof(
      timestamp: baseTime.add(
        Duration(milliseconds: i * 10),
      ), // Very high frequency
      interactionType: 'touch',
      coordinates: {
        'x': 0.5 + (i % 10) * 0.001,
        'y': 0.5 + (i % 8) * 0.0015,
      }, // Natural coordinate variation
    ),
  );
}

List<UserInteractionProof> _generateNormalFrequencyInteractions() {
  final baseTime = DateTime.now();
  return List.generate(
    10,
    (i) => UserInteractionProof(
      timestamp: baseTime.add(
        Duration(milliseconds: i * 200),
      ), // Normal frequency
      interactionType: 'touch',
      coordinates: {
        'x': 0.5 + i * 0.002,
        'y': 0.5 + i * 0.0015,
      }, // Natural coordinate variation
    ),
  );
}

List<UserInteractionProof> _generateNaturalCoordinateInteractions() {
  final baseTime = DateTime.now();
  final intervals = [
    0,
    145,
    298,
    452,
    607,
  ]; // Natural timing variation around 150ms
  return List.generate(
    5,
    (i) => _createInteraction(
      'touch',
      0.5 + (i - 2) * 0.001, // Small natural variation
      0.5 + (i - 2) * 0.002,
      timestamp: baseTime.add(Duration(milliseconds: intervals[i])),
    ),
  );
}

List<UserInteractionProof> _generatePerfectCoordinateInteractions() {
  final baseTime = DateTime.now();
  return List.generate(
    5,
    (i) => _createInteraction(
      'touch',
      0.500000,
      0.500000,
      timestamp: baseTime.add(Duration(milliseconds: i * 100)),
    ),
  ); // Perfect timing
}

List<UserInteractionProof> _generateHandTremorInteractions() {
  final baseTime = DateTime.now();
  return List.generate(
    12,
    (i) => _createInteraction(
      'touch',
      0.5 + 0.001 * (i % 2 == 0 ? 1 : -1), // 8Hz-like oscillation
      0.5 + 0.0005 * (i % 3 == 0 ? 1 : -1),
      timestamp: baseTime.add(
        Duration(milliseconds: i * 125),
      ), // ~8Hz oscillation timing
    ),
  );
}

List<UserInteractionProof> _generateMicroVariationInteractions() {
  final baseTime = DateTime.now();
  return List.generate(
    5,
    (i) => _createInteraction(
      'touch',
      0.5 + i * 0.0001, // Very small but distinct variations
      0.5 + i * 0.0002,
      timestamp: baseTime.add(
        Duration(milliseconds: i * 120),
      ), // Natural timing
    ),
  );
}

List<UserInteractionProof> _generateBreathingInfluenceInteractions() {
  final baseTime = DateTime.now();
  return List.generate(
    8,
    (i) => _createInteraction(
      'touch',
      0.5,
      0.5,
      timestamp: baseTime.add(Duration(milliseconds: i * 130)),
    ),
  ); // Natural breathing-influenced timing
}

List<UserInteractionProof> _generateMalformedInteractions() {
  try {
    return [_createInteraction('touch', double.nan, 0.5)];
  } catch (e) {
    return [_createInteraction('touch', 0.5, 0.5)];
  }
}

List<UserInteractionProof> _generateExtremeCoordinateInteractions() {
  return [
    _createInteraction('touch', -1000.0, 1000.0),
    _createInteraction('touch', 0.0, 0.0),
    _createInteraction('touch', 1.0, 1.0),
  ];
}

List<UserInteractionProof> _generateLargeInteractionList(int count) {
  final baseTime = DateTime.now();
  return List.generate(
    count,
    (i) => _createInteraction(
      'touch',
      0.5 + (i % 100) * 0.001,
      0.5 + (i % 100) * 0.001,
      timestamp: baseTime.add(
        Duration(milliseconds: i * 100),
      ), // Regular timing
    ),
  );
}

UserInteractionProof _createInteraction(
  String type,
  double x,
  double y, {
  double? pressure,
  DateTime? timestamp,
}) {
  return UserInteractionProof(
    timestamp: timestamp ?? DateTime.now(),
    interactionType: type,
    coordinates: {'x': x, 'y': y},
    pressure: pressure,
  );
}

ProofManifest _generateHumanLikeSession() {
  return ProofManifest(
    sessionId: 'test_session',
    challengeNonce: 'test_nonce',
    vineSessionStart: DateTime.now().subtract(Duration(seconds: 10)),
    vineSessionEnd: DateTime.now(),
    segments: [
      RecordingSegment(
        segmentId: 'seg1',
        startTime: DateTime.now().subtract(Duration(seconds: 8)),
        endTime: DateTime.now().subtract(Duration(seconds: 6)),
        frameHashes: ['hash1', 'hash2'],
      ),
      RecordingSegment(
        segmentId: 'seg2',
        startTime: DateTime.now().subtract(Duration(seconds: 4)),
        endTime: DateTime.now().subtract(Duration(seconds: 2)),
        frameHashes: ['hash3', 'hash4'],
      ),
    ],
    pauseProofs: [],
    interactions: _generateHumanLikeInteractions(),
    finalVideoHash: 'final_hash',
  );
}

ProofManifest _generateHardwareAttestedSession() {
  return ProofManifest(
    sessionId: 'test_session',
    challengeNonce: 'test_nonce',
    vineSessionStart: DateTime.now().subtract(Duration(seconds: 5)),
    vineSessionEnd: DateTime.now(),
    segments: [],
    pauseProofs: [],
    interactions: [],
    finalVideoHash: 'final_hash',
    deviceAttestation: DeviceAttestation(
      token: 'test_token',
      platform: 'iOS',
      deviceId: 'test_device',
      isHardwareBacked: true,
      createdAt: DateTime.now(),
    ),
  );
}

ProofManifest _generateSuspiciousSession() {
  return ProofManifest(
    sessionId: 'test_session',
    challengeNonce: 'test_nonce',
    vineSessionStart: DateTime.now().subtract(Duration(milliseconds: 100)),
    vineSessionEnd: DateTime.now(),
    segments: [],
    pauseProofs: [],
    interactions: _generateBotLikeInteractions(),
    finalVideoHash: 'final_hash',
  );
}

ProofManifest _generateSessionWithPauses() {
  return ProofManifest(
    sessionId: 'test_session',
    challengeNonce: 'test_nonce',
    vineSessionStart: DateTime.now().subtract(Duration(seconds: 10)),
    vineSessionEnd: DateTime.now(),
    segments: [
      RecordingSegment(
        segmentId: 'seg1',
        startTime: DateTime.now().subtract(Duration(seconds: 8)),
        endTime: DateTime.now().subtract(Duration(seconds: 6)),
        frameHashes: ['hash1'],
      ),
    ],
    pauseProofs: [
      PauseProof(
        startTime: DateTime.now().subtract(Duration(seconds: 6)),
        endTime: DateTime.now().subtract(Duration(seconds: 4)),
        sensorData: {'test': 'data'},
      ),
    ],
    interactions: [],
    finalVideoHash: 'final_hash',
  );
}

ProofManifest _generateNaturalDurationSession() {
  return ProofManifest(
    sessionId: 'test_session',
    challengeNonce: 'test_nonce',
    vineSessionStart: DateTime.now().subtract(Duration(seconds: 8)),
    vineSessionEnd: DateTime.now(),
    segments: [],
    pauseProofs: [],
    interactions: [],
    finalVideoHash: 'final_hash',
  );
}
