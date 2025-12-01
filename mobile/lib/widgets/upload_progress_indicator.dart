// ABOUTME: Widget for displaying video upload progress with status indicators
// ABOUTME: Shows upload progress, processing state, and error handling UI

import 'package:flutter/material.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Widget that displays upload progress for a video
class UploadProgressIndicator extends StatelessWidget {
  const UploadProgressIndicator({
    required this.upload,
    super.key,
    this.onRetry,
    this.onCancel,
    this.onDelete,
    this.onPause,
    this.onResume,
    this.onTap,
    this.showActions = true,
  });
  final PendingUpload upload;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onTap;
  final bool showActions;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        upload.title ?? 'Video Upload',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        upload.statusText,
                        style: TextStyle(
                          color: _getStatusColor(context),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusIcon(),
              ],
            ),
            const SizedBox(height: 8),
            _buildProgressBar(),
            if (showActions &&
                (upload.canRetry ||
                    upload.status == UploadStatus.uploading ||
                    upload.status == UploadStatus.paused ||
                    upload.status == UploadStatus.failed))
              const SizedBox(height: 8),
            if (showActions &&
                (upload.canRetry ||
                    upload.status == UploadStatus.uploading ||
                    upload.status == UploadStatus.paused ||
                    upload.status == UploadStatus.failed))
              _buildActionButtons(),
          ],
        ),
      ),
    ),
  );

  Widget _buildStatusIcon() {
    switch (upload.status) {
      case UploadStatus.pending:
        return const Icon(Icons.schedule, color: Colors.orange);
      case UploadStatus.uploading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case UploadStatus.retrying:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.orange,
          ),
        );
      case UploadStatus.processing:
        return const Icon(Icons.settings, color: Colors.blue);
      case UploadStatus.readyToPublish:
        return Icon(Icons.publish, color: VineTheme.vineGreen);
      case UploadStatus.published:
        return Icon(Icons.check_circle, color: VineTheme.vineGreen);
      case UploadStatus.failed:
        return const Icon(Icons.error, color: Colors.red);
      case UploadStatus.paused:
        return const Icon(Icons.pause_circle, color: Colors.orange);
    }
  }

  Widget _buildProgressBar() {
    final progress = upload.progressValue;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              _getTimeInfo(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      if (upload.status == UploadStatus.uploading && onPause != null)
        ElevatedButton.icon(
          onPressed: onPause,
          icon: const Icon(Icons.pause),
          label: const Text('Pause'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      if (upload.status == UploadStatus.paused && onResume != null)
        ElevatedButton.icon(
          onPressed: onResume,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Resume'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      if (upload.status == UploadStatus.failed) ...[
        if (onCancel != null) ...[
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Go Back'),
          ),
        ],
        if (onRetry != null && upload.canRetry) ...[
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Retry (${3 - (upload.retryCount ?? 0)} left)'),
          ),
        ],
        if (onDelete != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onDelete,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ] else if (upload.canRetry && onRetry != null) ...[
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: Text('Retry (${3 - (upload.retryCount ?? 0)} left)'),
        ),
      ],
    ],
  );

  Color _getStatusColor(BuildContext context) {
    switch (upload.status) {
      case UploadStatus.pending:
        return Colors.orange;
      case UploadStatus.uploading:
        return Colors.blue;
      case UploadStatus.retrying:
        return Colors.orange;
      case UploadStatus.processing:
        return Colors.blue;
      case UploadStatus.readyToPublish:
        return VineTheme.vineGreen;
      case UploadStatus.published:
        return VineTheme.vineGreen;
      case UploadStatus.failed:
        return Colors.red;
      case UploadStatus.paused:
        return Colors.orange;
    }
  }

  Color _getProgressColor() {
    switch (upload.status) {
      case UploadStatus.pending:
        return Colors.orange;
      case UploadStatus.uploading:
        return Colors.blue;
      case UploadStatus.retrying:
        return Colors.orange;
      case UploadStatus.processing:
        return Colors.blue;
      case UploadStatus.readyToPublish:
        return VineTheme.vineGreen;
      case UploadStatus.published:
        return VineTheme.vineGreen;
      case UploadStatus.failed:
        return Colors.red;
      case UploadStatus.paused:
        return Colors.orange;
    }
  }

  String _getTimeInfo() {
    final now = DateTime.now();
    final diff = now.difference(upload.createdAt);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Compact version of upload progress for notifications
class CompactUploadProgress extends StatelessWidget {
  const CompactUploadProgress({required this.upload, super.key, this.onTap});
  final PendingUpload upload;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              value: upload.progressValue,
              strokeWidth: 2,
              backgroundColor: Colors.grey[600],
              valueColor: AlwaysStoppedAnimation<Color>(
                upload.status == UploadStatus.failed
                    ? Colors.red
                    : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            upload.status == UploadStatus.uploading
                ? 'Uploading ${(upload.progressValue * 100).toInt()}%'
                : upload.status == UploadStatus.paused
                ? 'Paused ${(upload.progressValue * 100).toInt()}%'
                : upload.statusText,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
