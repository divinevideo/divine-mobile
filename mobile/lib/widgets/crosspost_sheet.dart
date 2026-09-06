// ABOUTME: Bottom sheet for manually crossposting an own video
// ABOUTME: Select connected platforms, submit jobs, watch progress to permalink

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_cubit.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_state.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/crosspost_models.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows the crosspost flow for the current user's own [video].
///
/// [connections] is the already-fetched connection list from the share
/// sheet, so the platform picker renders immediately.
Future<void> showCrosspostSheet({
  required BuildContext context,
  required WidgetRef ref,
  required VideoEvent video,
  required List<CrossposterConnection> connections,
}) {
  final client = ref.read(crossposterApiClientProvider);
  return VineBottomSheet.show<void>(
    context: context,
    showHeaderDivider: false,
    body: BlocProvider(
      create: (_) => VideoCrosspostCubit(
        client: client,
        eventId: video.id,
        initialConnections: connections,
      ),
      child: const CrosspostSheetView(),
    ),
  );
}

/// Platform ids are brand names; they render as-is in every locale.
String crosspostPlatformDisplayName(String platform) => switch (platform) {
  'instagram' => 'Instagram',
  'tiktok' => 'TikTok',
  'x' => 'X',
  'youtube' => 'YouTube',
  _ => platform,
};

@visibleForTesting
class CrosspostSheetView extends StatelessWidget {
  @visibleForTesting
  const CrosspostSheetView({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: BlocBuilder<VideoCrosspostCubit, VideoCrosspostState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: switch (state.status) {
                VideoCrosspostStatus.initial ||
                VideoCrosspostStatus.loadingConnections ||
                VideoCrosspostStatus.connectionsFailed ||
                VideoCrosspostStatus.ready ||
                VideoCrosspostStatus.submitting => [
                  const _SheetTitle(),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.crosspostSheetSubtitle,
                    textAlign: TextAlign.center,
                    style: VineTheme.bodyLargeFont(
                      color: context.vineColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final connection in state.connectedConnections)
                    _PlatformRow(
                      connection: connection,
                      selected: state.selectedPlatforms.contains(
                        connection.platform,
                      ),
                      enabled: state.status == VideoCrosspostStatus.ready,
                    ),
                  const SizedBox(height: 16),
                  DivineButton(
                    label: context.l10n.crosspostSubmit,
                    isLoading: state.status == VideoCrosspostStatus.submitting,
                    onPressed:
                        state.status == VideoCrosspostStatus.ready &&
                            state.selectedPlatforms.isNotEmpty
                        ? () => context.read<VideoCrosspostCubit>().submit()
                        : null,
                    expanded: true,
                  ),
                ],
                VideoCrosspostStatus.submitFailed => [
                  const _SheetTitle(),
                  const SizedBox(height: 16),
                  Text(
                    _submitErrorText(context, state.submitError),
                    textAlign: TextAlign.center,
                    style: VineTheme.bodyLargeFont(
                      color: context.vineColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DivineButton(
                    label: context.l10n.crosspostSubmit,
                    onPressed: state.selectedPlatforms.isNotEmpty
                        ? () => context.read<VideoCrosspostCubit>().submit()
                        : null,
                    expanded: true,
                  ),
                  const SizedBox(height: 12),
                  _CloseButton(label: context.l10n.crosspostDone),
                ],
                VideoCrosspostStatus.polling ||
                VideoCrosspostStatus.finished => [
                  const _SheetTitle(),
                  const SizedBox(height: 16),
                  for (final job in state.jobs) _JobRow(job: job),
                  if (state.pollTimedOut) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.crosspostStillWorking,
                      textAlign: TextAlign.center,
                      style: VineTheme.bodySmallFont(
                        color: context.vineColors.secondaryText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _CloseButton(label: context.l10n.crosspostDone),
                ],
              },
            );
          },
        ),
      ),
    );
  }

  String _submitErrorText(
    BuildContext context,
    VideoCrosspostSubmitError? error,
  ) => switch (error) {
    VideoCrosspostSubmitError.notOwner => context.l10n.crosspostErrorNotOwner,
    VideoCrosspostSubmitError.notEligible =>
      context.l10n.crosspostErrorNotEligible,
    VideoCrosspostSubmitError.notConnected =>
      context.l10n.crosspostErrorNotConnected,
    VideoCrosspostSubmitError.unauthorized =>
      context.l10n.crosspostErrorUnauthorized,
    VideoCrosspostSubmitError.network ||
    null => context.l10n.crosspostErrorNetwork,
  };
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.crosspostSheetTitle,
      textAlign: TextAlign.center,
      style: VineTheme.headlineSmallFont(color: context.vineColors.primaryText),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: label,
      type: DivineButtonType.secondary,
      onPressed: () => Navigator.of(context).pop(),
      expanded: true,
    );
  }
}

class _PlatformRow extends StatelessWidget {
  const _PlatformRow({
    required this.connection,
    required this.selected,
    required this.enabled,
  });

  final CrossposterConnection connection;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final name = crosspostPlatformDisplayName(connection.platform);
    final account = connection.externalAccountName;
    return Semantics(
      button: true,
      label: name,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () => context.read<VideoCrosspostCubit>().togglePlatform(
                connection.platform,
              )
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            spacing: 12,
            children: [
              DivineSpriteCheckbox(
                state: !enabled
                    ? DivineCheckboxState.disabled
                    : selected
                    ? DivineCheckboxState.selected
                    : DivineCheckboxState.unselected,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                    if (account != null && account.isNotEmpty)
                      Text(
                        account,
                        style: VineTheme.bodySmallFont(
                          color: context.vineColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job});

  final CrosspostJob job;

  @override
  Widget build(BuildContext context) {
    final name = crosspostPlatformDisplayName(job.platform);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            spacing: 12,
            children: [
              if (job.status.isPending)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: DivineCircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.vineColors.accentPositive,
                  ),
                )
              else
                DivineIcon(
                  icon: switch (job.status) {
                    CrosspostJobStatus.posted ||
                    CrosspostJobStatus.skipped => DivineIconName.checkCircle,
                    _ => DivineIconName.warningCircle,
                  },
                  size: 20,
                  color:
                      job.status == CrosspostJobStatus.posted ||
                          job.status == CrosspostJobStatus.skipped
                      ? context.vineColors.accentPositive
                      : VineTheme.error,
                ),
              Expanded(
                child: Text(
                  name,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              Text(
                _statusLabel(context, job.status),
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
            ],
          ),
          if (job.status == CrosspostJobStatus.posted &&
              job.externalPostUrl != null)
            _ViewPostLink(url: job.externalPostUrl!),
          if (job.status == CrosspostJobStatus.failed)
            Text(
              _failureText(context, job.errorCode),
              style: VineTheme.bodySmallFont(color: VineTheme.error),
            ),
          if (job.status == CrosspostJobStatus.needsReauth)
            _ReconnectPrompt(platformName: name),
        ],
      ),
    );
  }

  String _statusLabel(
    BuildContext context,
    CrosspostJobStatus status,
  ) => switch (status) {
    CrosspostJobStatus.queued => context.l10n.crosspostStatusQueued,
    CrosspostJobStatus.uploading => context.l10n.crosspostStatusUploading,
    CrosspostJobStatus.dispatching => context.l10n.crosspostStatusProcessing,
    CrosspostJobStatus.processing ||
    CrosspostJobStatus.unknown => context.l10n.crosspostStatusProcessing,
    CrosspostJobStatus.posted => context.l10n.crosspostStatusPosted,
    CrosspostJobStatus.failed => context.l10n.crosspostStatusFailed,
    CrosspostJobStatus.needsReauth => context.l10n.crosspostStatusNeedsReauth,
    CrosspostJobStatus.skipped => context.l10n.crosspostStatusSkipped,
  };

  String _failureText(BuildContext context, String? errorCode) =>
      switch (errorCode) {
        'not_owner' => context.l10n.crosspostErrorNotOwner,
        'not_eligible' => context.l10n.crosspostErrorNotEligible,
        'not_connected' => context.l10n.crosspostErrorNotConnected,
        'unauthorized' => context.l10n.crosspostErrorUnauthorized,
        'network' => context.l10n.crosspostErrorNetwork,
        _ => context.l10n.crosspostFailedGeneric,
      };
}

class _ViewPostLink extends StatelessWidget {
  const _ViewPostLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.crosspostViewPost;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            spacing: 6,
            children: [
              Text(
                label,
                style: VineTheme.labelLargeFont(
                  color: context.vineColors.accentPositive,
                ),
              ),
              DivineIcon(
                icon: DivineIconName.arrowUpRight,
                size: 16,
                color: context.vineColors.accentPositive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReconnectPrompt extends StatelessWidget {
  const _ReconnectPrompt({required this.platformName});

  final String platformName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          context.l10n.crosspostReconnectPrompt(platformName),
          style: VineTheme.bodySmallFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        DivineButton(
          label: context.l10n.crosspostReconnect,
          type: DivineButtonType.secondary,
          size: DivineButtonSize.small,
          onPressed: () => launchUrl(
            Uri.parse(AppConfig.crossposterBaseUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }
}
