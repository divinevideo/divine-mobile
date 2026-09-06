// ABOUTME: Wire models for crosspost jobs from the crossposter service
// ABOUTME: Job lifecycle statuses and the per-video job record

/// Lifecycle states reported by the crossposter for a single job.
enum CrosspostJobStatus {
  queued,
  uploading,
  dispatching,
  processing,
  posted,
  failed,
  needsReauth,
  skipped,
  unknown;

  factory CrosspostJobStatus.fromWire(String? value) => switch (value) {
    'queued' => CrosspostJobStatus.queued,
    'uploading' => CrosspostJobStatus.uploading,
    'dispatching' => CrosspostJobStatus.dispatching,
    'processing' => CrosspostJobStatus.processing,
    'posted' => CrosspostJobStatus.posted,
    'failed' => CrosspostJobStatus.failed,
    'needs_reauth' => CrosspostJobStatus.needsReauth,
    'skipped' => CrosspostJobStatus.skipped,
    _ => CrosspostJobStatus.unknown,
  };

  /// Whether the crossposter is still working on the job.
  bool get isPending =>
      this == CrosspostJobStatus.queued ||
      this == CrosspostJobStatus.uploading ||
      this == CrosspostJobStatus.dispatching ||
      this == CrosspostJobStatus.processing ||
      this == CrosspostJobStatus.unknown;
}

/// One crosspost job as returned by the crossposter API.
class CrosspostJob {
  const CrosspostJob({
    required this.id,
    required this.platform,
    required this.status,
    this.externalPostUrl,
    this.errorCode,
    this.errorMessage,
  });

  factory CrosspostJob.fromJson(Map<String, dynamic> json) {
    return CrosspostJob(
      id: json['id'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      status: CrosspostJobStatus.fromWire(json['status'] as String?),
      externalPostUrl: json['externalPostUrl'] as String?,
      errorCode: json['errorCode'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  final String id;
  final String platform;
  final CrosspostJobStatus status;

  /// Platform permalink, present once [status] is
  /// [CrosspostJobStatus.posted].
  final String? externalPostUrl;
  final String? errorCode;
  final String? errorMessage;
}
