// ABOUTME: Shared UI for showing that a NIP-71 video is a reply.
// ABOUTME: Fetches parent video context and links back to the parent route.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_reply_parent_provider.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:unified_logger/unified_logger.dart';

enum VideoReplyParentLinkVariant { overlay, metadata }

class VideoReplyParentLink extends ConsumerWidget {
  const VideoReplyParentLink({
    required this.video,
    required this.variant,
    this.onInteracted,
    super.key,
  });

  final VideoEvent video;
  final VideoReplyParentLinkVariant variant;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeId = video.replyRootRouteId;
    if (routeId == null) return const SizedBox.shrink();
    final l10n = context.l10n;

    final parent = ref.watch(videoReplyParentProvider(routeId));
    final label = _labelFor(
      context,
      parent.when(
        data: (video) => video,
        error: (error, stackTrace) {
          Log.warning(
            'Failed to load parent video for reply routeId=$routeId',
            category: LogCategory.video,
          );
          return null;
        },
        loading: () => null,
      ),
    );

    return Semantics(
      button: true,
      label: l10n.commentsOpenReplyParentLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          onInteracted?.call();
          context.pushWithVideoPause(VideoDetailScreen.pathForId(routeId));
        },
        child: variant == VideoReplyParentLinkVariant.overlay
            ? _OverlayReplyLink(label: label)
            : _MetadataReplyLink(label: label),
      ),
    );
  }

  String _labelFor(BuildContext context, VideoEvent? parent) {
    final l10n = context.l10n;
    final title = parent?.displayTitle?.trim();
    if (title != null && title.isNotEmpty) {
      return l10n.commentsReplyParentLabel(title);
    }

    final authorName = parent?.authorName?.trim();
    if (authorName != null && authorName.isNotEmpty) {
      return l10n.commentsReplyParentLabel(authorName);
    }

    final content = parent?.displayContent.trim();
    if (content != null && content.isNotEmpty) {
      return l10n.commentsReplyParentLabel(content);
    }

    return l10n.commentsReplyParentFallbackLabel;
  }
}

class _OverlayReplyLink extends StatelessWidget {
  const _OverlayReplyLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.backgroundColor.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: VineTheme.vineGreen.withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DivineIcon(
                icon: DivineIconName.arrowBendUpLeft,
                color: VineTheme.vineGreen,
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: VineTheme.labelSmallFont(color: VineTheme.whiteText)
                      .copyWith(
                        shadows: VineTheme.buttonShadows,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetadataReplyLink extends StatelessWidget {
  const _MetadataReplyLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.vineColors.outlineDisabled),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            DivineIcon(
              icon: DivineIconName.arrowBendUpLeft,
              color: context.vineColors.accentPositive,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.commentsReplyParentSectionTitle,
                    style: VineTheme.labelMediumFont(
                      color: context.vineColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: VineTheme.titleSmallFont(
                      color: context.vineColors.primaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            DivineIcon(
              icon: DivineIconName.caretRight,
              color: context.vineColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
