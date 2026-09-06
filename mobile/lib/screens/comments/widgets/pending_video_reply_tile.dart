// ABOUTME: Pending row for a video reply whose background publish is in flight.
// ABOUTME: Shows upload progress so the poster is not left staring at nothing.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

/// Placeholder tile shown while a recorded video reply uploads and publishes.
///
/// A video reply publishes in the background and navigates away, so the
/// destination comments sheet would otherwise show nothing at all until the
/// whole round-trip (render → upload → sign → broadcast → relay echo) finishes
/// — seconds to tens of seconds of silence that reads as a failed post
/// (#5862). Progress is read from [BackgroundPublishBloc] so this tile owns
/// its own updates and the placeholder bridge only has to insert and remove.
class PendingVideoReplyTile extends StatefulWidget {
  const PendingVideoReplyTile({required this.draftId, super.key});

  /// Draft id of the in-flight publish, decoded from the placeholder comment id.
  final String draftId;

  static const _tileWidth = 248.0;

  @override
  State<PendingVideoReplyTile> createState() => _PendingVideoReplyTileState();
}

class _PendingVideoReplyTileState extends State<PendingVideoReplyTile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.commentsVideoReplyPendingSemanticLabel,
        Directionality.of(context),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 0 progress renders as an indeterminate spinner: the upload has not
    // reported yet, and a 0% bar reads as stalled.
    final progress = context.select((BackgroundPublishBloc bloc) {
      for (final upload in bloc.state.uploads) {
        if (upload.draft.id == widget.draftId) return upload.progress;
      }
      return null;
    });

    return Semantics(
      label: l10n.commentsVideoReplyPendingSemanticLabel,
      liveRegion: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: PendingVideoReplyTile._tileWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.containerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 12,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: DivineCircularProgressIndicator(
                      strokeWidth: 2,
                      value: (progress ?? 0) > 0 ? progress : null,
                      color: context.vineColors.onSurface,
                    ),
                  ),
                  Text(
                    l10n.commentsVideoReplyPending,
                    style: VineTheme.labelMediumFont(
                      color: context.vineColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
