// ABOUTME: Progress bottom sheet for saving original video (no watermark)
// ABOUTME: Shows downloading -> saving stages with completion actions

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/save_original_progress/save_original_progress_cubit.dart';
import 'package:openvine/blocs/save_original_progress/save_original_progress_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/watermark_download_provider.dart';
import 'package:openvine/services/watermark_download_service.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:openvine/widgets/retry_after_settings_on_resume.dart';

/// Shows a bottom sheet that tracks original video save progress.
Future<void> showSaveOriginalSheet({
  required BuildContext context,
  required WidgetRef ref,
  required VideoEvent video,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.vineColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(VineTheme.bottomSheetBorderRadius),
      ),
    ),
    builder: (sheetContext) =>
        _SaveOriginalProgressSheet(video: video, ref: ref),
  );
}

class _SaveOriginalProgressSheet extends StatelessWidget {
  const _SaveOriginalProgressSheet({required this.video, required this.ref});

  final VideoEvent video;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SaveOriginalProgressCubit(
        service: ref.read(watermarkDownloadServiceProvider),
        video: video,
      )..start(),
      child: _SaveOriginalProgressView(ref: ref),
    );
  }
}

class _SaveOriginalProgressView extends StatefulWidget {
  const _SaveOriginalProgressView({required this.ref});

  final WidgetRef ref;

  @override
  State<_SaveOriginalProgressView> createState() =>
      _SaveOriginalProgressViewState();
}

class _SaveOriginalProgressViewState extends State<_SaveOriginalProgressView>
    with RetryAfterSettingsOnResume {
  Future<void> _openSettings() async {
    final permissionsService = widget.ref.read(permissionsServiceProvider);
    final cubit = context.read<SaveOriginalProgressCubit>();
    await openSettingsAndRetryOnResume(
      openSettings: permissionsService.openAppSettings,
      retry: () async {
        if (!mounted) return;
        cubit.reset();
        await cubit.start();
      },
    );
  }

  Future<void> _shareFile(WatermarkDownloadSuccess success) async {
    await showShareSheet(
      context,
      ShareParams(files: [XFile(success.filePath)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child:
            BlocBuilder<SaveOriginalProgressCubit, SaveOriginalProgressState>(
              builder: (context, state) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.vineColors.onSurfaceMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (state.isProcessing) ...[
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: DivineCircularProgressIndicator(
                          strokeWidth: 3,
                          color: context.vineColors.accentPositive,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _stageLabel(state.stage, l10n),
                        style: VineTheme.titleMediumFont(
                          color: context.vineColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _stageDescription(state.stage, l10n),
                        style: VineTheme.bodySmallFont(
                          color: context.vineColors.secondaryText,
                        ),
                      ),
                    ] else
                      ..._resultChildren(context, state.result, l10n),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
      ),
    );
  }

  List<Widget> _resultChildren(
    BuildContext context,
    WatermarkDownloadResult? result,
    AppLocalizations l10n,
  ) {
    return switch (result) {
      WatermarkDownloadSuccess() => [
        DivineIcon(
          icon: DivineIconName.checkCircle,
          color: context.vineColors.accentPositive,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.saveOriginalSavedToCameraRoll,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _shareFile(result),
            icon: const DivineIcon(
              icon: DivineIconName.share,
              color: VineTheme.onPrimary,
            ),
            label: Text(l10n.saveOriginalShare),
            style: FilledButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
              foregroundColor: VineTheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.saveOriginalDone,
            style: VineTheme.labelLargeFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        ),
      ],
      WatermarkDownloadPermissionDenied() => [
        DivineIcon(
          icon: DivineIconName.lockSimple,
          color: context.vineColors.accentPositive,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.saveOriginalPhotosAccessNeeded,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.saveOriginalPhotosAccessMessage,
          style: VineTheme.bodySmallFont(
            color: context.vineColors.secondaryText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _openSettings,
            style: FilledButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
              foregroundColor: VineTheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(l10n.saveOriginalOpenSettings),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.saveOriginalNotNow,
            style: VineTheme.labelLargeFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        ),
      ],
      WatermarkDownloadFailure(:final reason) => [
        const DivineIcon(
          icon: DivineIconName.warningCircle,
          color: VineTheme.error,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.saveOriginalDownloadFailed,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          reason,
          style: VineTheme.bodySmallFont(
            color: context.vineColors.secondaryText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.saveOriginalDismiss,
            style: VineTheme.labelLargeFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        ),
      ],
      null => const [],
    };
  }

  String _stageLabel(OriginalSaveStage stage, AppLocalizations l10n) =>
      switch (stage) {
        OriginalSaveStage.downloading => l10n.saveOriginalDownloadingVideo,
        OriginalSaveStage.saving => l10n.saveOriginalSavingToCameraRoll,
      };

  String _stageDescription(OriginalSaveStage stage, AppLocalizations l10n) =>
      switch (stage) {
        OriginalSaveStage.downloading => l10n.saveOriginalFetchingVideo,
        OriginalSaveStage.saving => l10n.saveOriginalSavingVideo,
      };
}
