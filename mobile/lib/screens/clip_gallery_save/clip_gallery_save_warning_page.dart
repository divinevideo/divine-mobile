// ABOUTME: Page naming the clips that were saved to the gallery without their
// ABOUTME: C2PA proof, why, and offering to save them again once it can be added.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/clip_gallery_save/clip_gallery_save_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/library/clip_gallery_save.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';

/// Lists the clips whose gallery copy carries no proof that they were shot
/// with Divine, so the gallery import cannot bring them back, and says why
/// for each.
///
/// Clips whose proof could not be added for now, such as recordings made
/// offline, can be saved again from here: only those that then carry proof
/// are saved, so trying again never adds another copy without it.
class ClipGallerySaveWarningPage extends StatelessWidget {
  /// Creates a [ClipGallerySaveWarningPage] for [results].
  const ClipGallerySaveWarningPage({required this.results, super.key});

  /// The clips saved without proof, as the save reported them.
  final List<ClipGallerySaveResult> results;

  /// Opens the page for [results] on [navigator].
  ///
  /// Not a route of its own: the results only exist in memory, so there is
  /// nothing a URL could restore. It takes a navigator rather than a context
  /// because a save outlives the library it was started from.
  static Future<void> open(
    NavigatorState navigator,
    List<ClipGallerySaveResult> results,
  ) {
    return navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ClipGallerySaveWarningPage(results: results),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ClipGallerySaveCubit>(
      create: (context) =>
          ClipGallerySaveProvider.createCubit(context, results: results),
      child: const ClipGallerySaveWarningView(),
    );
  }
}

/// The warning page's content, for a [ClipGallerySaveCubit] above it.
class ClipGallerySaveWarningView extends StatelessWidget {
  /// Creates a [ClipGallerySaveWarningView].
  @visibleForTesting
  const ClipGallerySaveWarningView({super.key});

  Future<void> _retry(BuildContext context) async {
    final cubit = context.read<ClipGallerySaveCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final outcome = await cubit.retry();
    if (outcome == null || !outcome.permissionDenied) return;
    messenger.showSnackBar(
      DivineSnackbarContainer.snackBar(
        l10n.libraryGalleryPermissionDenied(cubit.destinationName),
        error: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = context.select(
      (ClipGallerySaveCubit cubit) => cubit.state.results,
    );
    final isSaving = context.select(
      (ClipGallerySaveCubit cubit) => cubit.state.isSaving,
    );
    final canRetry = context.select(
      (ClipGallerySaveCubit cubit) => cubit.state.hasRetryableClips,
    );

    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        title: context.l10n.libraryGallerySaveWarningTitle,
        surfaceTintColor: VineTheme.transparent,
        showBackButton: true,
        onBackPressed: context.safePop,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: results.length + 1,
                itemBuilder: (context, index) => index == 0
                    ? const _Intro()
                    : _ClipRow(result: results[index - 1]),
              ),
            ),
            if (canRetry || isSaving)
              Padding(
                padding: const EdgeInsets.all(16),
                child: DivineButton(
                  expanded: true,
                  label: context.l10n.commonRetry,
                  isLoading: isSaving,
                  onPressed: isSaving ? null : () => _retry(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Text(
        context.l10n.libraryGallerySaveWarningIntro,
        style: VineTheme.bodyMediumFont(
          color: context.vineColors.secondaryText,
        ),
      ),
    );
  }
}

class _ClipRow extends StatelessWidget {
  const _ClipRow({required this.result});

  final ClipGallerySaveResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final warning = result.warning;
    final status = switch (warning) {
      ClipGallerySaveWarning.signingUnavailable =>
        l10n.libraryGallerySaveWarningSigningUnavailable,
      ClipGallerySaveWarning.stopMotion =>
        l10n.libraryGallerySaveWarningStopMotion,
      ClipGallerySaveWarning.signingUnsupported =>
        l10n.libraryGallerySaveWarningSigningUnsupported,
      ClipGallerySaveWarning.noProof => l10n.libraryGallerySaveWarningNoProof,
      ClipGallerySaveWarning.notVerified =>
        l10n.libraryGalleryImportItemNotVerified,
      null when result.saved => l10n.libraryGallerySaveWarningSavedWithProof,
      null => l10n.videoClipSaveFailed,
    };

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          spacing: 12,
          children: [
            _Thumbnail(clip: result.clip),
            Expanded(
              // A row a retry can settle is announced as it changes, since
              // that happens while the user may be anywhere on the page.
              child: Semantics(
                liveRegion: warning?.isRetryable ?? true,
                child: Text(
                  status,
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
            ),
            _StatusIcon(result: result),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.clip});

  static const double _width = 48;
  static const double _height = 64;

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    final path = clip.thumbnailPath ?? clip.stopMotionFrames?.firstOrNull?.path;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: SizedBox(
          width: _width,
          height: _height,
          child: path == null
              ? const _ThumbnailPlaceholder()
              : ClipThumbnailImage(
                  path: path,
                  fit: BoxFit.cover,
                  // Decode at the size it is shown, not the full frame.
                  cacheHeight:
                      (_height * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  placeholder: const _ThumbnailPlaceholder(),
                ),
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.surfaceContainerHigh,
      child: Center(
        child: DivineIcon(
          icon: .filmSlate,
          size: 20,
          color: context.vineColors.secondaryText,
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.result});

  static const double _size = 24;

  final ClipGallerySaveResult result;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _size,
      child: ExcludeSemantics(
        child: switch (result.warning) {
          ClipGallerySaveWarning.signingUnavailable => DivineIcon(
            icon: .warningCircle,
            color: context.vineColors.accentWarning,
          ),
          ClipGallerySaveWarning() => DivineIcon(
            icon: .prohibit,
            color: context.vineColors.onErrorContainer,
          ),
          null when result.saved => DivineIcon(
            icon: .checkCircle,
            color: context.vineColors.accentPositive,
          ),
          null => DivineIcon(
            icon: .prohibit,
            color: context.vineColors.onErrorContainer,
          ),
        },
      ),
    );
  }
}
