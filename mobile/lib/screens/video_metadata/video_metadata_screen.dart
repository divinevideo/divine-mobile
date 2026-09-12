// ABOUTME: Video metadata editing screen for post details, title, description,
// ABOUTME: tags and expiration with updated visual hierarchy

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_stack.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_stack.dart';

/// The user's choice on the "C2PA signing failed" prompt.
enum _C2paMissingChoice { regenerate, skip }

/// Screen for editing video metadata including title, description, tags, and
/// expiration settings.
class VideoMetadataScreen extends ConsumerStatefulWidget {
  /// Creates a video metadata editing screen.
  const VideoMetadataScreen({this.draftMode, super.key});

  /// Route name for this screen.
  static const routeName = 'video-metadata';

  /// Path for this route.
  static const String path = RoutePaths.videoMetadata;

  /// Query parameter carrying the composition mode from the draft editor.
  static const draftModeQueryParameter = 'mode';

  /// Builds the metadata location for a draft editor composition.
  ///
  /// Drafts always use the capture metadata flow. Stop-motion drafts retain
  /// their distinct mode so future mode-specific behavior can branch without
  /// consulting the unrelated last-used recorder preference.
  static String pathForDraft({required bool isStopMotion}) {
    final mode = isStopMotion
        ? VideoRecorderMode.stopMotion
        : VideoRecorderMode.capture;
    return Uri(
      path: path,
      queryParameters: {draftModeQueryParameter: mode.name},
    ).toString();
  }

  /// Parses the only recorder modes valid for an editor draft.
  static VideoRecorderMode? draftModeFromName(String? name) => switch (name) {
    'capture' => VideoRecorderMode.capture,
    'stopMotion' => VideoRecorderMode.stopMotion,
    _ => null,
  };

  /// Mode derived from the draft composition by the video editor.
  ///
  /// When absent, direct recorder flows retain the persisted recorder mode.
  final VideoRecorderMode? draftMode;

  @override
  ConsumerState<VideoMetadataScreen> createState() =>
      _VideoMetadataScreenState();
}

class _VideoMetadataScreenState extends ConsumerState<VideoMetadataScreen> {
  /// Guards against stacking a second prompt: the mount-time check and the
  /// `ref.listen` in `build` can both fire for the same failure.
  bool _isC2paPromptOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Clear any stale error/completed state from a previous publish attempt
      // so the overlay doesn't block the new publish flow.
      ref.read(videoPublishProvider.notifier).clearError();
      final recorderMode =
          widget.draftMode ??
          ref.read(creationAnalyticsTrackerProvider).activeMode ??
          VideoRecorderMode.fromName(
            ref
                .read(sharedPreferencesProvider)
                .getString(VideoRecorderMode.persistenceKey),
          );
      unawaited(
        ref.read(creationAnalyticsTrackerProvider).editorOpened(recorderMode),
      );
      // `ref.listen` only fires on a *change*, so a render that already failed
      // signing before this screen mounted (resumed draft, or capture/lip-sync
      // where the render is kicked off before navigation) would never surface
      // the prompt. Catch that already-true case here (#6058).
      if (ref.read(videoEditorProvider).c2paSigningFailed) {
        unawaited(_promptC2paMissing());
      }
    });
  }

  Future<void> _promptC2paMissing() async {
    if (_isC2paPromptOpen) return;
    _isC2paPromptOpen = true;
    try {
      await _showC2paMissingPrompt();
    } finally {
      _isC2paPromptOpen = false;
    }
  }

  Future<void> _showC2paMissingPrompt() async {
    final l10n = context.l10n;
    // Blaming connectivity for a service-side failure sends users to debug wifi
    // that is working. Only claim the connection when the device is actually
    // offline; otherwise say the service didn't respond.
    final isOnline = ref.read(connectionStatusServiceProvider).isOnline;
    final note = isOnline
        ? l10n.videoMetadataC2paMissingNoteServiceUnavailable
        : l10n.videoMetadataC2paMissingNote;
    // Non-dismissible: forfeiting the content credential is a provenance
    // decision, so require an explicit button rather than letting an accidental
    // barrier tap / swipe silently post without it (#6058).
    final choice = await VineBottomSheetPrompt.show<_C2paMissingChoice>(
      context: context,
      sticker: .alert,
      title: l10n.videoMetadataC2paMissingTitle,
      subtitle: l10n.videoMetadataC2paMissingBody,
      additionalText: note,
      primaryButtonText: l10n.videoMetadataC2paMissingRegenerate,
      onPrimaryPressed: () =>
          Navigator.of(context).pop(_C2paMissingChoice.regenerate),
      secondaryButtonText: l10n.videoMetadataC2paMissingSkip,
      onSecondaryPressed: () =>
          Navigator.of(context).pop(_C2paMissingChoice.skip),
      isDismissible: false,
      enableDrag: false,
    );
    if (!mounted) return;

    final notifier = ref.read(videoEditorProvider.notifier);
    switch (choice) {
      case _C2paMissingChoice.regenerate:
      case null:
        // Regenerate, or a system-back with no choice: re-sign the existing
        // render (no re-encode) rather than silently forfeiting provenance.
        // Only an explicit "Skip" publishes without the credential
        // (#6058).
        unawaited(notifier.retryC2paSigning());
      case _C2paMissingChoice.skip:
        // Explicit consent to publish without a content credential.
        notifier.acknowledgeC2paSigningFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    // When the render finishes without a C2PA content credential (signing
    // configured but failed), let the user regenerate or knowingly post
    // without provenance (#6058).
    ref.listen(videoEditorProvider.select((s) => s.c2paSigningFailed), (
      previous,
      next,
    ) {
      if (next && previous != true) {
        unawaited(_promptC2paMissing());
      }
    });

    // The recorder bloc is screen-scoped and this screen is a separate route,
    // so read the mode the recorder persisted rather than the (absent) bloc.
    final recorderMode =
        widget.draftMode ??
        VideoRecorderMode.fromName(
          ref
              .watch(sharedPreferencesProvider)
              .getString(VideoRecorderMode.persistenceKey),
        );

    // Cancel video render when user navigates back
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        unawaited(ref.read(videoEditorProvider.notifier).cancelRenderVideo());
      },
      // Dismiss keyboard when tapping outside input fields
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: switch (recorderMode) {
          // Lip-sync shares capture's editor + metadata flow. Stop-motion
          // produces a normal video clip, so it shares the same capture-mode
          // metadata UI. Upload has no video editor, so recorder navigation
          // pushes this route without a mode query. A restored draft uses the
          // capture stack even when upload is the persisted recorder mode.
          .capture ||
          .stopMotion ||
          .lipSync ||
          .upload => const VideoMetadataCaptureStack(),
          .classic => const VideoMetadataClassicStack(),
        },
      ),
    );
  }
}
