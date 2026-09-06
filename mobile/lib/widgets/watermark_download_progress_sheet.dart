// ABOUTME: Progress bottom sheet for watermark video download
// ABOUTME: Shows downloading -> watermarking -> saving stages with completion actions

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/watermark_download_progress/watermark_download_progress_cubit.dart';
import 'package:openvine/blocs/watermark_download_progress/watermark_download_progress_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/watermark_download_provider.dart';
import 'package:openvine/services/watermark_download_service.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:openvine/widgets/retry_after_settings_on_resume.dart';

Future<void> showWatermarkDownloadSheet({
  required BuildContext context,
  required WidgetRef ref,
  required VideoEvent video,
  required String watermarkText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.vineColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(VineTheme.bottomSheetBorderRadius),
      ),
    ),
    builder: (sheetContext) => _WatermarkDownloadProgressSheet(
      video: video,
      watermarkText: watermarkText,
      ref: ref,
    ),
  );
}

class _WatermarkDownloadProgressSheet extends StatelessWidget {
  const _WatermarkDownloadProgressSheet({
    required this.video,
    required this.watermarkText,
    required this.ref,
  });

  final VideoEvent video;
  final String watermarkText;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WatermarkDownloadProgressCubit(
        service: ref.read(watermarkDownloadServiceProvider),
        video: video,
        watermarkText: watermarkText,
      )..start(),
      child: _WatermarkDownloadProgressView(ref: ref),
    );
  }
}

class _WatermarkDownloadProgressView extends StatefulWidget {
  const _WatermarkDownloadProgressView({required this.ref});

  final WidgetRef ref;

  @override
  State<_WatermarkDownloadProgressView> createState() =>
      _WatermarkDownloadProgressViewState();
}

class _WatermarkDownloadProgressViewState
    extends State<_WatermarkDownloadProgressView>
    with RetryAfterSettingsOnResume {
  Future<void> _openSettings() async {
    final permissionsService = widget.ref.read(permissionsServiceProvider);
    final cubit = context.read<WatermarkDownloadProgressCubit>();
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child:
            BlocBuilder<
              WatermarkDownloadProgressCubit,
              WatermarkDownloadProgressState
            >(
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
                        _stageLabel(state.stage, context),
                        style: VineTheme.titleMediumFont(
                          color: context.vineColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _stageDescription(state.stage, context),
                        style: VineTheme.bodySmallFont(
                          color: context.vineColors.secondaryText,
                        ),
                      ),
                    ] else
                      ..._resultChildren(context, state.result),
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
  ) {
    final l10n = context.l10n;
    return switch (result) {
      WatermarkDownloadSuccess() => [
        DivineIcon(
          icon: DivineIconName.checkCircle,
          color: context.vineColors.accentPositive,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.watermarkDownloadSavedToCameraRoll,
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
            label: Text(l10n.watermarkDownloadShare),
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
            l10n.watermarkDownloadDone,
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
          l10n.watermarkDownloadPhotosAccessNeeded,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.watermarkDownloadPhotosAccessDescription,
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
            child: Text(l10n.watermarkDownloadOpenSettings),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.watermarkDownloadNotNow,
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
          l10n.watermarkDownloadFailed,
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
            l10n.watermarkDownloadDismiss,
            style: VineTheme.labelLargeFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        ),
      ],
      null => const [],
    };
  }

  String _stageLabel(WatermarkDownloadStage stage, BuildContext context) =>
      switch (stage) {
        WatermarkDownloadStage.downloading =>
          context.l10n.watermarkDownloadStageDownloading,
        WatermarkDownloadStage.watermarking =>
          context.l10n.watermarkDownloadStageWatermarking,
        WatermarkDownloadStage.saving =>
          context.l10n.watermarkDownloadStageSaving,
      };

  String _stageDescription(
    WatermarkDownloadStage stage,
    BuildContext context,
  ) => switch (stage) {
    WatermarkDownloadStage.downloading =>
      context.l10n.watermarkDownloadStageDownloadingDesc,
    WatermarkDownloadStage.watermarking =>
      context.l10n.watermarkDownloadStageWatermarkingDesc,
    WatermarkDownloadStage.saving =>
      context.l10n.watermarkDownloadStageSavingDesc,
  };
}
