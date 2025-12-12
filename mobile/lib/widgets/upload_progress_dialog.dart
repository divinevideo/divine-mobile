// ABOUTME: Dialog widget that displays blocking upload progress with polling updates
// ABOUTME: Auto-closes when upload completes, uses Timer.periodic for status polling

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Dialog that shows upload progress and blocks user interaction until complete
///
/// - Displays progress percentage with progress bar
/// - Non-dismissible (barrierDismissible: false)
/// - Polls UploadManager every 500ms for status updates
/// - Auto-closes when upload status becomes readyToPublish
class UploadProgressDialog extends StatefulWidget {
  const UploadProgressDialog({
    super.key,
    required this.uploadId,
    required this.uploadManager,
  });

  final String uploadId;
  final dynamic uploadManager; // Accept any object with getUpload method

  @override
  State<UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<UploadProgressDialog> {
  Timer? _pollTimer;
  double _progress = 0.0;
  UploadStatus _status = UploadStatus.pending;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Initial poll
    _updateProgress();

    // Poll every 500ms
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateProgress();
    });
  }

  void _updateProgress() {
    final upload = widget.uploadManager.getUpload(widget.uploadId);
    if (upload == null) return;

    setState(() {
      _progress = upload.uploadProgress ?? 0.0;
      _status = upload.status;
    });

    // Auto-close when upload is ready to publish
    if (_status == UploadStatus.readyToPublish) {
      _pollTimer?.cancel();
      if (mounted) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final percentageText = '${(_progress * 100).toInt()}%';

    return Dialog(
      backgroundColor: VineTheme.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Uploading video...',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(
                VineTheme.vineGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              percentageText,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
