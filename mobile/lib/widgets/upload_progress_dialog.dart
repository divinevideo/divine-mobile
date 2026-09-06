// ABOUTME: Dialog widget that displays blocking upload progress with polling updates
// ABOUTME: Auto-closes when upload completes, uses Timer.periodic for status polling

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/upload_progress/upload_progress_cubit.dart';
import 'package:openvine/blocs/upload_progress/upload_progress_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/pending_upload.dart';

/// Dialog that shows upload progress and blocks user interaction until complete.
///
/// - Displays progress percentage with progress bar.
/// - Non-dismissible (barrierDismissible: false).
/// - Polls the upload manager every 500ms via [UploadProgressCubit].
/// - Auto-closes when upload status becomes `readyToPublish`.
class UploadProgressDialog extends StatelessWidget {
  const UploadProgressDialog({
    required this.uploadId,
    required this.uploadManager,
    super.key,
  });

  final String uploadId;
  final dynamic uploadManager; // Accept any object with getUpload method.

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UploadProgressCubit(
        uploadId: uploadId,
        lookup: (id) => uploadManager.getUpload(id) as PendingUpload?,
      ),
      child: const _UploadProgressView(),
    );
  }
}

class _UploadProgressView extends StatefulWidget {
  const _UploadProgressView();

  @override
  State<_UploadProgressView> createState() => _UploadProgressViewState();
}

class _UploadProgressViewState extends State<_UploadProgressView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<UploadProgressCubit>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UploadProgressCubit, UploadProgressState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          curr.status == UploadStatus.readyToPublish,
      listener: (context, _) => context.pop(),
      builder: (context, state) {
        final percentageText = '${(state.progress * 100).toInt()}%';
        return Dialog(
          backgroundColor: context.vineColors.card,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.uploadUploadingVideo,
                  style: TextStyle(
                    color: context.vineColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                DivineLinearProgressIndicator(
                  value: state.progress,
                  backgroundColor: context.vineColors.card,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    VineTheme.vineGreen,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  percentageText,
                  style: TextStyle(
                    color: context.vineColors.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
