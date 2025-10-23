// ABOUTME: Dialog widget for submitting bug reports via email
// ABOUTME: Collects user description, gathers diagnostics, and opens pre-filled email

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Dialog for collecting and submitting bug reports
class BugReportDialog extends StatefulWidget {
  const BugReportDialog({
    super.key,
    required this.bugReportService,
    this.currentScreen,
    this.userPubkey,
    this.testMode = false, // If true, sends to yourself instead of support
  });

  final BugReportService bugReportService;
  final String? currentScreen;
  final String? userPubkey;
  final bool testMode;

  @override
  State<BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<BugReportDialog> {
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String? _resultMessage;
  bool? _isSuccess;
  bool _isDisposed = false;
  Timer? _closeTimer;

  @override
  void dispose() {
    _isDisposed = true;
    _closeTimer?.cancel();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_isSubmitting;

  Future<void> _submitReport() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
      _resultMessage = null;
      _isSuccess = null;
    });

    try {
      // Collect diagnostics
      final description = _descriptionController.text.trim();
      final reportData = await widget.bugReportService.collectDiagnostics(
        userDescription: description.isEmpty
            ? 'User reported an issue (no description provided)'
            : description,
        currentScreen: widget.currentScreen,
        userPubkey: widget.userPubkey,
      );

      // Send bug report via email
      final result = await widget.bugReportService.sendBugReportViaEmail(reportData);

      if (!_isDisposed && mounted) {
        setState(() {
          _isSubmitting = false;
          _isSuccess = result.success;
          if (result.success) {
            _resultMessage =
                'File downloaded/ready! Opening email to contact@divine.video - please attach the file.';
          } else {
            _resultMessage = 'Failed to create bug report: ${result.error}';
          }
        });

        // Close dialog after delay if successful
        if (result.success) {
          _closeTimer = Timer(const Duration(seconds: 3), () {
            if (!_isDisposed && mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      }
    } catch (e, stackTrace) {
      Log.error('Error submitting bug report: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace);

      if (!_isDisposed && mounted) {
        setState(() {
          _isSubmitting = false;
          _isSuccess = false;
          _resultMessage = 'Bug report failed to send: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        'Report a Bug',
        style: TextStyle(color: VineTheme.whiteText),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Description field
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              enabled: !_isSubmitting,
              style: const TextStyle(color: VineTheme.whiteText),
              decoration: InputDecoration(
                hintText: 'Describe the issue (optional)...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: VineTheme.vineGreen),
                ),
                helperText: 'Diagnostic info will be sent automatically',
                helperStyle: TextStyle(color: Colors.grey.shade600),
              ),
              onChanged: (_) => setState(() {}), // Rebuild to update button state
            ),

            const SizedBox(height: 16),

            // Loading indicator
            if (_isSubmitting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: VineTheme.vineGreen),
                ),
              ),

            // Result message
            if (_resultMessage != null && !_isSubmitting)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSuccess == true
                      ? VineTheme.vineGreen.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSuccess == true ? VineTheme.vineGreen : Colors.red,
                    width: 1,
                  ),
                ),
                child: Text(
                  _resultMessage!,
                  style: TextStyle(
                    color: _isSuccess == true ? VineTheme.vineGreen : Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),

        // Send button
        ElevatedButton(
          onPressed: _canSubmit ? _submitReport : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.vineGreen,
            foregroundColor: VineTheme.whiteText,
          ),
          child: const Text('Send Report'),
        ),
      ],
    );
  }
}
