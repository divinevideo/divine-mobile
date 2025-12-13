// ABOUTME: Data models for video export progress tracking
// ABOUTME: Defines export stages and progress state

enum ExportStage {
  concatenating,
  applyingTextOverlay,
  mixingAudio,
  generatingThumbnail,
  complete,
  error,
}

class ExportProgress {
  final ExportStage stage;
  final double progress; // 0.0 - 1.0
  final String? message;

  const ExportProgress({
    required this.stage,
    required this.progress,
    this.message,
  });

  ExportProgress copyWith({
    ExportStage? stage,
    double? progress,
    String? message,
  }) {
    return ExportProgress(
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      message: message ?? this.message,
    );
  }
}
