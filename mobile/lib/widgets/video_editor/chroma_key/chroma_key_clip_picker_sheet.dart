// ABOUTME: Bottom sheet that picks a saved library clip to play behind a
// ABOUTME: green-screened subject.

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Opens the library picker, resolving with the chosen clip's file path or
/// `null` when dismissed.
///
/// Backgrounds come from the clip library rather than the phone's gallery: a
/// library clip is already a local, editor-normalised file, so it can be fed
/// straight into the composition render.
Future<String?> showChromaKeyClipPicker(BuildContext context) {
  return VineBottomSheet.show<String>(
    context: context,
    contentTitle: context.l10n.videoEditorChromaKeyPickClipTitle,
    isScrollControlled: true,
    body: const _ClipPickerBody(),
  );
}

class _ClipPickerBody extends ConsumerWidget {
  const _ClipPickerBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clipLibraryService = ref.watch(clipLibraryServiceProvider);
    final gallerySaveService = ref.watch(gallerySaveServiceProvider);

    return BlocProvider<ClipsLibraryBloc>(
      // The library service is rebuilt on account switches; re-key so the bloc
      // never keeps serving the previous identity's clips.
      key: ValueKey((clipLibraryService, gallerySaveService)),
      create: (_) => ClipsLibraryBloc(
        clipLibraryService: clipLibraryService,
        gallerySaveService: gallerySaveService,
        sharedPreferences: ref.read(sharedPreferencesProvider),
        clipTypeFilter: LibraryClipTypeFilter.video,
      )..add(const ClipsLibraryLoadRequested()),
      child: const _ClipPickerGrid(),
    );
  }
}

class _ClipPickerGrid extends StatelessWidget {
  const _ClipPickerGrid();

  @override
  Widget build(BuildContext context) {
    final (status, clips) = context.select(
      (ClipsLibraryBloc b) => (b.state.status, b.state.sortedClips),
    );

    if (status == ClipsLibraryStatus.loading && clips.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: BrandedLoadingIndicator()),
      );
    }

    if (clips.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          context.l10n.videoEditorChromaKeyNoLibraryClips,
          textAlign: TextAlign.center,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3 / 4,
      ),
      itemCount: clips.length,
      itemBuilder: (context, index) => _ClipTile(clip: clips[index]),
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({required this.clip});

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = clip.thumbnailPath;
    final videoPath = clip.video?.file?.path;
    final canUseBackdrop =
        videoPath != null &&
        videoPath.isNotEmpty &&
        File(videoPath).existsSync();

    return Semantics(
      button: true,
      label:
          clip.libraryTitle ?? context.l10n.videoEditorChromaKeyPickClipTitle,
      child: InkWell(
        // A clip whose file went missing can't be a backdrop; leave it
        // untappable rather than failing after the sheet closes.
        onTap: !canUseBackdrop
            ? null
            : () => Navigator.of(context).pop(videoPath),
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: context.vineColors.surfaceContainer,
            child: thumbnailPath == null
                ? const SizedBox.expand()
                : Image.file(
                    File(thumbnailPath),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, _, _) => const SizedBox.expand(),
                  ),
          ),
        ),
      ),
    );
  }
}
