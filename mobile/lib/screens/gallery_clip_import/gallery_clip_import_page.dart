// ABOUTME: Page listing the videos picked from the gallery while each one's
// ABOUTME: C2PA credential is checked, with a spinner until its result is in.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/gallery_clip_import/gallery_clip_import_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';

/// Shows how the import of videos picked from the gallery is going.
///
/// It renders a [GalleryClipImportCubit] owned by the library, so closing the
/// page does not stop the import: the videos still being checked are added
/// and show up in the library's grid as they pass.
class GalleryClipImportPage extends StatelessWidget {
  /// Creates a [GalleryClipImportPage] for [cubit].
  const GalleryClipImportPage({required this.cubit, super.key});

  /// The library's import, which this page only displays.
  final GalleryClipImportCubit cubit;

  /// Opens the page for [cubit] on the enclosing navigator.
  ///
  /// Not a route of its own: the picked videos are temporary files that only
  /// the running import knows, so there is nothing a URL could restore.
  static Future<void> open(
    BuildContext context,
    GalleryClipImportCubit cubit,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GalleryClipImportPage(cubit: cubit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: const GalleryClipImportView(),
    );
  }
}

/// The import page's content, for a [GalleryClipImportCubit] above it.
class GalleryClipImportView extends StatelessWidget {
  /// Creates a [GalleryClipImportView].
  @visibleForTesting
  const GalleryClipImportView({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.select(
      (GalleryClipImportCubit cubit) => cubit.state.items,
    );
    final isImporting = context.select(
      (GalleryClipImportCubit cubit) => cubit.state.isImporting,
    );

    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        title: context.l10n.libraryGalleryImportTitle,
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
                itemCount: items.length + 1,
                itemBuilder: (context, index) => index == 0
                    ? const _Intro()
                    : _ClipRow(item: items[index - 1]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: DivineButton(
                expanded: true,
                label: context.l10n.libraryGalleryImportDone,
                onPressed: isImporting ? null : () => context.safePop(),
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
        context.l10n.libraryGalleryImportExplainerSubtitle,
        style: VineTheme.bodyMediumFont(
          color: context.vineColors.secondaryText,
        ),
      ),
    );
  }
}

class _ClipRow extends StatelessWidget {
  const _ClipRow({required this.item});

  final GalleryClipImportItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = switch (item.status) {
      GalleryClipImportItemStatus.waiting =>
        l10n.libraryGalleryImportItemWaiting,
      GalleryClipImportItemStatus.checking =>
        l10n.libraryGalleryImportItemChecking,
      GalleryClipImportItemStatus.added => l10n.libraryGalleryImportItemAdded,
      GalleryClipImportItemStatus.alreadyInLibrary =>
        l10n.libraryGalleryImportItemAlreadyInLibrary,
      GalleryClipImportItemStatus.notVerified =>
        l10n.libraryGalleryImportItemNotVerified,
      GalleryClipImportItemStatus.checkUnavailable =>
        l10n.libraryGalleryImportItemCheckUnavailable,
      GalleryClipImportItemStatus.failed => l10n.shareSheetAddToClipsFailed,
    };

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          spacing: 12,
          children: [
            _Thumbnail(item: item),
            Expanded(
              // Announced as it changes, since the result arrives while the
              // user may be anywhere on the page.
              child: Semantics(
                liveRegion: item.status.isFinished,
                child: Text(
                  status,
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
            ),
            _StatusIndicator(status: item.status),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item});

  static const double _width = 48;
  static const double _height = 64;

  final GalleryClipImportItem item;

  @override
  Widget build(BuildContext context) {
    final thumbnail = item.thumbnail;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: SizedBox(
          width: _width,
          height: _height,
          child: thumbnail == null
              ? ColoredBox(
                  color: context.vineColors.surfaceContainerHigh,
                  child: Center(
                    child: DivineIcon(
                      icon: .filmSlate,
                      size: 20,
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                )
              : Image.memory(
                  thumbnail,
                  fit: BoxFit.cover,
                  // Decode at the size it is shown, not the full video frame.
                  cacheWidth: (_width * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  gaplessPlayback: true,
                ),
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  static const double _size = 24;

  final GalleryClipImportItemStatus status;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _size,
      child: ExcludeSemantics(
        child: switch (status) {
          GalleryClipImportItemStatus.waiting ||
          GalleryClipImportItemStatus.checking => const Padding(
            padding: EdgeInsets.all(2),
            child: DivineCircularProgressIndicator(strokeWidth: 2.5),
          ),
          GalleryClipImportItemStatus.added => DivineIcon(
            icon: .checkCircle,
            color: context.vineColors.accentPositive,
          ),
          GalleryClipImportItemStatus.alreadyInLibrary => DivineIcon(
            icon: .checkCircle,
            color: context.vineColors.secondaryText,
          ),
          GalleryClipImportItemStatus.notVerified ||
          GalleryClipImportItemStatus.failed => DivineIcon(
            icon: .prohibit,
            color: context.vineColors.onErrorContainer,
          ),
          GalleryClipImportItemStatus.checkUnavailable => DivineIcon(
            icon: .warningCircle,
            color: context.vineColors.accentWarning,
          ),
        },
      ),
    );
  }
}
