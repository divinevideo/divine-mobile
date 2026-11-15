// ABOUTME: Remixes section of the video info sheet: the videos that use a clip
// ABOUTME: of this one, each opening its own video after the sheet closes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/video_feed_item/actions/sheet_dismissal.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/video_remixes_cubit.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// The videos that use a clip of [video], read by the [VideoRemixesCubit]
/// the sheet provides.
///
/// Renders nothing for a video with no address, which no remix can credit,
/// without the cubit, while the read runs, and when it finds no remixes.
class MetadataRemixesSection extends StatelessWidget {
  const MetadataRemixesSection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final addressableId = video.addressableId;
    final cubit = context.read<VideoRemixesCubit?>();
    if (addressableId == null || addressableId.isEmpty || cubit == null) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<VideoRemixesCubit, VideoRemixesState>(
      bloc: cubit,
      builder: (context, state) {
        if (state.remixes.isEmpty) return const SizedBox.shrink();
        return MetadataSection(
          label: context.l10n.metadataRemixesLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              for (final remix in state.remixes) _RemixRow(remix: remix),
            ],
          ),
        );
      },
    );
  }
}

/// One remix: its thumbnail, who posted it and its caption. A tap closes the
/// sheet and opens the remix.
class _RemixRow extends ConsumerWidget {
  const _RemixRow({required this.remix});

  final VideoEvent remix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.vineColors;
    // Funnelcake sends the author along; a remix read from the relays
    // carries none, so its profile is read.
    final name =
        remix.authorName ??
        ref
            .watch(fetchUserProfileProvider(remix.pubkey))
            .value
            ?.bestDisplayName ??
        UserProfile.generatedNameFor(remix.pubkey);
    final caption = remix.displayTitle ?? remix.displayContent.trim();

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _open(context),
          child: Row(
            spacing: 12,
            children: [
              _RemixThumbnail(remix: remix),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.titleSmallFont(
                        color: colors.primaryText,
                      ),
                    ),
                    if (caption.isNotEmpty)
                      Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: VineTheme.bodySmallFont(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              DivineIcon(
                icon: DivineIconName.caretRight,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    runDetached(
      presentAfterSheetDismiss<void>(
        context,
        (hostContext) => hostContext.pushWithVideoPause<void>(
          VideoDetailRouteData(id: remix.id).location,
          extra: VideoDetailRouteExtra(initialVideo: remix),
        ),
      ),
      'open a remix',
      logName: 'MetadataRemixesSection',
      category: LogCategory.ui,
    );
  }
}

/// A remix's thumbnail, blurred when the viewer's settings warn about it.
class _RemixThumbnail extends StatelessWidget {
  const _RemixThumbnail({required this.remix});

  static const double _size = 56;

  final VideoEvent remix;

  @override
  Widget build(BuildContext context) {
    final url = remix.thumbnailUrl;
    final placeholder = ColoredBox(color: context.vineColors.surfaceContainer);
    Widget picture = url == null
        ? placeholder
        : VineCachedImage(
            imageUrl: url,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );
    if (remix.shouldShowWarning) {
      picture = ImageFiltered(
        imageFilter: .blur(sigmaX: 12, sigmaY: 12),
        child: picture,
      );
    }
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(dimension: _size, child: picture),
      ),
    );
  }
}
