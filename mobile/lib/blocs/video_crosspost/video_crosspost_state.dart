// ABOUTME: State for the manual video crosspost flow
// ABOUTME: Tracks connections, platform selection, and job polling progress

import 'package:equatable/equatable.dart';
import 'package:openvine/services/crossposting_api_client.dart';

// The connection model is part of this state's public surface
// (VideoCrosspostState.connections), so UI reaches it through the bloc
// layer rather than importing the service directly.
export 'package:openvine/services/crossposting_api_client.dart'
    show CrosspostingConnection;

enum VideoCrosspostStatus {
  initial,
  loadingConnections,
  ready,
  connectionsFailed,
  submitting,
  polling,
  finished,
  submitFailed,
}

/// Why a submit attempt failed, mapped from crossposter error codes.
enum VideoCrosspostSubmitError {
  notOwner,
  notEligible,
  notConnected,
  unauthorized,
  network,
}

class VideoCrosspostState extends Equatable {
  const VideoCrosspostState({
    this.status = VideoCrosspostStatus.initial,
    this.connections = const [],
    this.selectedPlatforms = const {},
    this.jobs = const [],
    this.submitError,
    this.pollTimedOut = false,
  });

  final VideoCrosspostStatus status;
  final List<CrosspostingConnection> connections;
  final Set<String> selectedPlatforms;
  final List<CrosspostJob> jobs;

  /// Meaningful only while [status] is [VideoCrosspostStatus.submitFailed].
  final VideoCrosspostSubmitError? submitError;

  /// True when polling gave up while jobs were still pending; the jobs
  /// keep processing server-side.
  final bool pollTimedOut;

  List<CrosspostingConnection> get connectedConnections =>
      connections.where((c) => c.isConnected).toList();

  List<String> get connectedPlatforms =>
      connectedConnections.map((c) => c.platform.wireName).toList();

  bool get hasPendingJobs => jobs.any((j) => j.status.isPending);

  VideoCrosspostState copyWith({
    VideoCrosspostStatus? status,
    List<CrosspostingConnection>? connections,
    Set<String>? selectedPlatforms,
    List<CrosspostJob>? jobs,
    VideoCrosspostSubmitError? submitError,
    bool? pollTimedOut,
  }) {
    return VideoCrosspostState(
      status: status ?? this.status,
      connections: connections ?? this.connections,
      selectedPlatforms: selectedPlatforms ?? this.selectedPlatforms,
      jobs: jobs ?? this.jobs,
      submitError: submitError ?? this.submitError,
      pollTimedOut: pollTimedOut ?? this.pollTimedOut,
    );
  }

  @override
  List<Object?> get props => [
    status,
    connections,
    selectedPlatforms,
    jobs,
    submitError,
    pollTimedOut,
  ];
}
