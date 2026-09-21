import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/video_render_failure_reason.dart';
import 'package:openvine/providers/video_editor_provider.dart';

/// Tells the user that the render failed, and why, below the clip preview.
///
/// The preview's failure overlay only has room for a retry button — the
/// default capture card is 112px wide — so the words live here. Most failures
/// get "Generation failed"; a device out of storage gets the sentence that
/// says what to do, because a blind retry walks the user into the same wall
/// (#7125). Renders nothing while no render has failed.
class VideoMetadataRenderFailureBanner extends ConsumerWidget {
  /// Creates the banner, laid out with [padding] only while it is visible.
  const VideoMetadataRenderFailureBanner({
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    super.key,
  });

  /// Space around the banner. Not applied while nothing is shown, so the
  /// hidden banner costs the surrounding layout nothing.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (renderFailed, reason) = ref.watch(
      videoEditorProvider.select(
        (s) => (s.renderFailed, s.renderFailureReason),
      ),
    );
    if (!renderFailed) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: _RenderFailureNotice(message: _message(context.l10n, reason)),
    );
  }
}

/// The copy for [reason].
///
/// A full disk and a sound that could not be fetched each change what the
/// user is told, because the remedy differs: free up space, or get back on
/// the network and retry. Everything else gets the generic failure.
String _message(AppLocalizations l10n, VideoRenderFailureReason? reason) =>
    switch (reason) {
      VideoRenderFailureReason.insufficientStorage =>
        l10n.publishErrorLowStorage,
      VideoRenderFailureReason.audioUnavailable =>
        l10n.publishErrorServerUnreachable,
      _ => l10n.videoMetadataGenerationFailed,
    };

class _RenderFailureNotice extends StatefulWidget {
  const _RenderFailureNotice({required this.message});

  final String message;

  @override
  State<_RenderFailureNotice> createState() => _RenderFailureNoticeState();
}

class _RenderFailureNoticeState extends State<_RenderFailureNotice> {
  @override
  void initState() {
    super.initState();
    // The banner swaps in on a state change, not a route push, so screen
    // readers get no automatic signal — announce it explicitly (#7125).
    // Fire-and-forget: the platform reports nothing worth reacting to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          widget.message,
          Directionality.of(context),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => DivineInfoCard(
    tone: .error,
    icon: .warning,
    message: widget.message,
  );
}
