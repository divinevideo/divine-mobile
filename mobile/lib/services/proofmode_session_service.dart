// ABOUTME: ProofMode session management for vine recording with segment-based proof generation
// ABOUTME: Handles proof sessions during 6-second vine recording with pause/resume support

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:openvine/services/proofmode_config.dart';
import 'package:openvine/services/proofmode_key_service.dart';
import 'package:openvine/services/proofmode_attestation_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Recording segment within a vine session
class RecordingSegment {
  const RecordingSegment({
    required this.segmentId,
    required this.startTime,
    required this.endTime,
    required this.frameHashes,
    this.frameTimestamps,
    this.sensorData,
  });

  final String segmentId;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> frameHashes;
  final List<DateTime>? frameTimestamps;
  final Map<String, dynamic>? sensorData;

  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
        'segmentId': segmentId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'duration': duration.inMilliseconds,
        'frameHashes': frameHashes,
        'frameTimestamps': frameTimestamps?.map((t) => t.toIso8601String()).toList(),
        'sensorData': sensorData,
      };

  factory RecordingSegment.fromJson(Map<String, dynamic> json) =>
      RecordingSegment(
        segmentId: json['segmentId'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        frameHashes: (json['frameHashes'] as List<dynamic>).cast<String>(),
        frameTimestamps: json['frameTimestamps'] != null
            ? (json['frameTimestamps'] as List<dynamic>)
                .map((t) => DateTime.parse(t as String))
                .toList()
            : null,
        sensorData: json['sensorData'] as Map<String, dynamic>?,
      );
}

/// User interaction during recording
class UserInteractionProof {
  const UserInteractionProof({
    required this.timestamp,
    required this.interactionType,
    required this.coordinates,
    this.pressure,
    this.metadata,
  });

  final DateTime timestamp;
  final String interactionType; // 'start', 'stop', 'touch'
  final Map<String, double> coordinates; // x, y
  final double? pressure;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'interactionType': interactionType,
        'coordinates': coordinates,
        'pressure': pressure,
        'metadata': metadata,
      };

  factory UserInteractionProof.fromJson(Map<String, dynamic> json) =>
      UserInteractionProof(
        timestamp: DateTime.parse(json['timestamp'] as String),
        interactionType: json['interactionType'] as String,
        coordinates: (json['coordinates'] as Map<String, dynamic>)
            .cast<String, double>(),
        pressure: json['pressure'] as double?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}

/// Proof generated during recording pauses
class PauseProof {
  const PauseProof({
    required this.startTime,
    required this.endTime,
    required this.sensorData,
    this.interactions,
  });

  final DateTime startTime;
  final DateTime endTime;
  final Map<String, dynamic> sensorData;
  final List<UserInteractionProof>? interactions;

  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'duration': duration.inMilliseconds,
        'sensorData': sensorData,
        'interactions': interactions?.map((i) => i.toJson()).toList(),
      };

  factory PauseProof.fromJson(Map<String, dynamic> json) => PauseProof(
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        sensorData: json['sensorData'] as Map<String, dynamic>,
        interactions: (json['interactions'] as List<dynamic>?)
            ?.map(
                (i) => UserInteractionProof.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

/// Complete proof manifest for a vine session
class ProofManifest {
  const ProofManifest({
    required this.sessionId,
    required this.challengeNonce,
    required this.vineSessionStart,
    required this.vineSessionEnd,
    required this.segments,
    required this.pauseProofs,
    required this.interactions,
    required this.finalVideoHash,
    this.deviceAttestation,
    this.pgpSignature,
  });

  final String sessionId;
  final String challengeNonce;
  final DateTime vineSessionStart;
  final DateTime vineSessionEnd;
  final List<RecordingSegment> segments;
  final List<PauseProof> pauseProofs;
  final List<UserInteractionProof> interactions;
  final String finalVideoHash;
  final DeviceAttestation? deviceAttestation;
  final ProofSignature? pgpSignature;

  Duration get totalDuration => vineSessionEnd.difference(vineSessionStart);
  Duration get recordingDuration => Duration(
        milliseconds: segments.fold(
            0, (sum, segment) => sum + segment.duration.inMilliseconds),
      );

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'challengeNonce': challengeNonce,
        'vineSessionStart': vineSessionStart.toIso8601String(),
        'vineSessionEnd': vineSessionEnd.toIso8601String(),
        'totalDuration': totalDuration.inMilliseconds,
        'recordingDuration': recordingDuration.inMilliseconds,
        'segments': segments.map((s) => s.toJson()).toList(),
        'pauseProofs': pauseProofs.map((p) => p.toJson()).toList(),
        'interactions': interactions.map((i) => i.toJson()).toList(),
        'finalVideoHash': finalVideoHash,
        'deviceAttestation': deviceAttestation?.toJson(),
        'pgpSignature': pgpSignature?.toJson(),
      };

  factory ProofManifest.fromJson(Map<String, dynamic> json) => ProofManifest(
        sessionId: json['sessionId'] as String,
        challengeNonce: json['challengeNonce'] as String,
        vineSessionStart: DateTime.parse(json['vineSessionStart'] as String),
        vineSessionEnd: DateTime.parse(json['vineSessionEnd'] as String),
        segments: (json['segments'] as List<dynamic>)
            .map((s) => RecordingSegment.fromJson(s as Map<String, dynamic>))
            .toList(),
        pauseProofs: (json['pauseProofs'] as List<dynamic>)
            .map((p) => PauseProof.fromJson(p as Map<String, dynamic>))
            .toList(),
        interactions: (json['interactions'] as List<dynamic>)
            .map(
                (i) => UserInteractionProof.fromJson(i as Map<String, dynamic>))
            .toList(),
        finalVideoHash: json['finalVideoHash'] as String,
        deviceAttestation: json['deviceAttestation'] != null
            ? DeviceAttestation.fromJson(
                json['deviceAttestation'] as Map<String, dynamic>)
            : null,
        pgpSignature: json['pgpSignature'] != null
            ? ProofSignature.fromJson(
                json['pgpSignature'] as Map<String, dynamic>)
            : null,
      );
}

/// ProofMode session management service
class ProofModeSessionService {
  final ProofModeKeyService _keyService;
  final ProofModeAttestationService _attestationService;

  ProofModeSessionService(this._keyService, this._attestationService);

  ProofSession? _currentSession;
  Timer? _pauseMonitorTimer;

  /// Get the current active session
  ProofSession? get currentSession => _currentSession;

  /// Start a new proof session for vine recording
  Future<String?> startSession({
    int frameSampleRate = 1,
    int maxFrameHashes = 1000,
  }) async {
    if (!await ProofModeConfig.isCaptureEnabled) {
      Log.info('ProofMode capture disabled, skipping session start',
          name: 'ProofModeSessionService', category: LogCategory.system);
      return null;
    }

    Log.info('Starting ProofMode session',
        name: 'ProofModeSessionService', category: LogCategory.system);

    try {
      // Generate session ID and challenge nonce
      final sessionId = _generateSessionId();
      final challengeNonce = _generateChallengeNonce();

      // Get device attestation (gracefully handle errors)
      DeviceAttestation? attestation;
      try {
        attestation =
            await _attestationService.generateAttestation(challengeNonce);
      } catch (e) {
        Log.warning('Failed to generate device attestation: $e',
            name: 'ProofModeSessionService', category: LogCategory.system);
        // Continue without attestation
      }

      _currentSession = ProofSession(
        sessionId: sessionId,
        challengeNonce: challengeNonce,
        startTime: DateTime.now(),
        deviceAttestation: attestation,
        frameSampleRate: frameSampleRate,
        maxFrameHashes: maxFrameHashes,
      );

      Log.info('Started ProofMode session: $sessionId',
          name: 'ProofModeSessionService', category: LogCategory.system);

      return sessionId;
    } catch (e) {
      Log.error('Failed to start ProofMode session: $e',
          name: 'ProofModeSessionService', category: LogCategory.system);
      return null;
    }
  }

  /// Capture frame data from camera during recording
  Future<void> captureFrame(Uint8List? frameData) async {
    if (frameData == null) {
      throw ArgumentError('Frame data cannot be null');
    }

    final session = _currentSession;
    if (session == null) {
      throw StateError('No active session to capture frame');
    }

    if (!session.isRecording) {
      throw StateError('Cannot capture frame when not recording');
    }

    try {
      session.captureFrame(frameData);
    } catch (e) {
      Log.error('Failed to capture frame: $e',
          name: 'ProofModeSessionService', category: LogCategory.system);
      rethrow;
    }
  }

  /// Pause recording (stop current segment)
  Future<void> pauseRecording() async {
    await stopRecordingSegment();
  }

  /// Resume recording (start new segment)
  Future<void> resumeRecording() async {
    await startRecordingSegment();
  }

  /// End the current session
  Future<void> endSession() async {
    final session = _currentSession;
    if (session == null) {
      throw StateError('No active session to end');
    }

    Log.info('Ending ProofMode session: ${session.sessionId}',
        name: 'ProofModeSessionService', category: LogCategory.system);

    // Stop any active recording
    if (session.isRecording) {
      await stopRecordingSegment();
    }

    _pauseMonitorTimer?.cancel();
    _currentSession = null;
  }

  /// Start recording a segment
  Future<void> startRecordingSegment() async {
    final session = _currentSession;
    if (session == null) {
      Log.warning('No active ProofMode session for recording segment',
          name: 'ProofModeSessionService', category: LogCategory.system);
      return;
    }

    Log.debug('Starting recording segment in session: ${session.sessionId}',
        name: 'ProofModeSessionService', category: LogCategory.system);

    final segmentId = _generateSegmentId(session.segments.length);
    session.startRecordingSegment(segmentId);

    // Stop pause monitoring if active
    _pauseMonitorTimer?.cancel();
  }

  /// Stop recording current segment
  Future<void> stopRecordingSegment() async {
    final session = _currentSession;
    if (session == null || !session.isRecording) {
      Log.warning('No active recording segment to stop',
          name: 'ProofModeSessionService', category: LogCategory.system);
      return;
    }

    Log.debug('Stopping recording segment in session: ${session.sessionId}',
        name: 'ProofModeSessionService', category: LogCategory.system);

    session.stopRecordingSegment();

    // Start pause monitoring
    _startPauseMonitoring();
  }

  /// Add frame hash during recording
  Future<void> addFrameHash(Uint8List frameData) async {
    final session = _currentSession;
    if (session == null || !session.isRecording) return;

    try {
      final hash = sha256.convert(frameData);
      session.addFrameHash(hash.toString());
    } catch (e) {
      Log.error('Failed to add frame hash: $e',
          name: 'ProofModeSessionService', category: LogCategory.system);
    }
  }

  /// Record user interaction
  Future<void> recordInteraction(String type, double x, double y,
      {double? pressure}) async {
    final session = _currentSession;
    if (session == null) return;

    final interaction = UserInteractionProof(
      timestamp: DateTime.now(),
      interactionType: type,
      coordinates: {'x': x, 'y': y},
      pressure: pressure,
    );

    session.addInteraction(interaction);

    Log.debug('Recorded interaction: $type at ($x, $y)',
        name: 'ProofModeSessionService', category: LogCategory.system);
  }

  /// Finalize session and generate proof manifest
  Future<ProofManifest?> finalizeSession(String finalVideoHash) async {
    final session = _currentSession;
    if (session == null) {
      Log.warning('No active ProofMode session to finalize',
          name: 'ProofModeSessionService', category: LogCategory.system);
      return null;
    }

    Log.info('Finalizing ProofMode session: ${session.sessionId}',
        name: 'ProofModeSessionService', category: LogCategory.system);

    try {
      // Stop any active recording or pause monitoring
      if (session.isRecording) {
        session.stopRecordingSegment();
      }
      _pauseMonitorTimer?.cancel();

      // Create proof manifest
      final manifest = ProofManifest(
        sessionId: session.sessionId,
        challengeNonce: session.challengeNonce,
        vineSessionStart: session.startTime,
        vineSessionEnd: DateTime.now(),
        segments: List.from(session.segments),
        pauseProofs: List.from(session.pauseProofs),
        interactions: List.from(session.interactions),
        finalVideoHash: finalVideoHash,
        deviceAttestation: session.deviceAttestation,
      );

      // Sign the manifest (gracefully handle errors)
      ProofSignature? signature;
      try {
        final manifestJson = jsonEncode(manifest.toJson());
        signature = await _keyService.signData(manifestJson);
      } catch (e) {
        Log.warning('Failed to sign manifest: $e',
            name: 'ProofModeSessionService', category: LogCategory.system);
        // Continue without signature
      }

      final signedManifest = ProofManifest(
        sessionId: manifest.sessionId,
        challengeNonce: manifest.challengeNonce,
        vineSessionStart: manifest.vineSessionStart,
        vineSessionEnd: manifest.vineSessionEnd,
        segments: manifest.segments,
        pauseProofs: manifest.pauseProofs,
        interactions: manifest.interactions,
        finalVideoHash: manifest.finalVideoHash,
        deviceAttestation: manifest.deviceAttestation,
        pgpSignature: signature,
      );

      _currentSession = null;

      Log.info(
          'ProofMode session finalized with ${signedManifest.segments.length} segments, '
          '${signedManifest.interactions.length} interactions, duration: ${signedManifest.totalDuration.inSeconds}s',
          name: 'ProofModeSessionService',
          category: LogCategory.system);

      return signedManifest;
    } catch (e) {
      Log.error('Failed to finalize ProofMode session: $e',
          name: 'ProofModeSessionService', category: LogCategory.system);
      return null;
    }
  }

  /// Cancel current session
  Future<void> cancelSession() async {
    final session = _currentSession;
    if (session == null) return;

    Log.info('Cancelling ProofMode session: ${session.sessionId}',
        name: 'ProofModeSessionService', category: LogCategory.system);

    _pauseMonitorTimer?.cancel();
    _currentSession = null;
  }

  /// Get current session info
  String? get currentSessionId => _currentSession?.sessionId;
  bool get hasActiveSession => _currentSession != null;
  bool get isRecording => _currentSession?.isRecording ?? false;

  // Private helper methods

  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000).toString().padLeft(4, '0');
    return 'session_${timestamp}_$random';
  }

  String _generateChallengeNonce() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = 'challenge_$timestamp';
    final hash = sha256.convert(data.codeUnits);
    return hash.toString().substring(0, 16);
  }

  String _generateSegmentId(int index) {
    return 'segment_${index + 1}_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _startPauseMonitoring() {
    _pauseMonitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final session = _currentSession;
      if (session != null && !session.isRecording) {
        session.updatePauseProof(_collectSensorData());
      }
    });
  }

  Map<String, dynamic> _collectSensorData() {
    // Mock sensor data collection
    // In production, this would collect real sensor data
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'accelerometer': {'x': 0.1, 'y': 0.2, 'z': 9.8},
      'gyroscope': {'x': 0.01, 'y': 0.02, 'z': 0.01},
      'magnetometer': {'x': 45.0, 'y': 12.0, 'z': -30.0},
      'light': 150.0,
    };
  }
}

/// Internal proof session state
class ProofSession {
  ProofSession({
    required this.sessionId,
    required this.challengeNonce,
    required this.startTime,
    this.deviceAttestation,
    this.frameSampleRate = 1,
    this.maxFrameHashes = 1000,
  });

  final String sessionId;
  final String challengeNonce;
  final DateTime startTime;
  final DeviceAttestation? deviceAttestation;
  final int frameSampleRate;
  final int maxFrameHashes;

  final List<RecordingSegment> segments = [];
  final List<PauseProof> pauseProofs = [];
  final List<UserInteractionProof> interactions = [];

  RecordingSegment? _currentSegment;
  DateTime? _currentSegmentStart;
  List<String> _currentFrameHashes = [];
  List<DateTime> _currentFrameTimestamps = [];

  PauseProof? _currentPauseProof;
  DateTime? _currentPauseStart;

  int _frameCounter = 0;

  bool get isRecording => _currentSegment != null;

  /// Get all frame hashes across all segments
  List<String> get frameHashes {
    final allHashes = <String>[];
    for (final segment in segments) {
      allHashes.addAll(segment.frameHashes);
    }
    if (_currentFrameHashes.isNotEmpty) {
      allHashes.addAll(_currentFrameHashes);
    }
    return allHashes;
  }

  void startRecordingSegment(String segmentId) {
    _currentSegmentStart = DateTime.now();
    _currentFrameHashes = [];
    _currentFrameTimestamps = [];
    _frameCounter = 0;
    // Set current segment to indicate recording is active
    _currentSegment = RecordingSegment(
      segmentId: segmentId,
      startTime: _currentSegmentStart!,
      endTime: _currentSegmentStart!, // Will be updated on stop
      frameHashes: [],
    );

    // End current pause proof if active
    if (_currentPauseProof != null && _currentPauseStart != null) {
      final pauseProof = PauseProof(
        startTime: _currentPauseStart!,
        endTime: DateTime.now(),
        sensorData: {'ended': 'recording_started'},
      );
      pauseProofs.add(pauseProof);
      _currentPauseProof = null;
      _currentPauseStart = null;
    }
  }

  void stopRecordingSegment() {
    if (_currentSegmentStart == null) return;

    final segment = RecordingSegment(
      segmentId: 'segment_${segments.length + 1}',
      startTime: _currentSegmentStart!,
      endTime: DateTime.now(),
      frameHashes: List.from(_currentFrameHashes),
      frameTimestamps: List.from(_currentFrameTimestamps),
    );

    segments.add(segment);
    _currentSegment = null;
    _currentSegmentStart = null;
    _currentFrameHashes = [];
    _currentFrameTimestamps = [];

    // Start new pause proof
    _currentPauseStart = DateTime.now();
  }

  void addFrameHash(String hash) {
    if (isRecording) {
      _currentFrameHashes.add(hash);
    }
  }

  /// Capture frame data and hash it
  void captureFrame(Uint8List frameData) {
    if (!isRecording) {
      throw StateError('Cannot capture frame when not recording');
    }

    _frameCounter++;

    // Apply frame sampling - only capture every Nth frame
    if (_frameCounter % frameSampleRate != 0) {
      return;
    }

    // Check if we've hit the max frame hash limit
    final totalHashes = frameHashes.length;
    if (totalHashes >= maxFrameHashes) {
      return;
    }

    // Generate SHA256 hash
    final hash = sha256.convert(frameData);
    final hashString = hash.toString();

    // Store hash and timestamp
    _currentFrameHashes.add(hashString);
    _currentFrameTimestamps.add(DateTime.now());
  }

  void addInteraction(UserInteractionProof interaction) {
    interactions.add(interaction);
  }

  void updatePauseProof(Map<String, dynamic> sensorData) {
    // Update current pause proof with new sensor data
    // This would accumulate sensor readings during pauses
  }
}
