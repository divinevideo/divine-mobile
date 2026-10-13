// ABOUTME: Provides ClipGallerySaveCubit to the clip library and saves clips
// ABOUTME: with it, reporting the outcome and any copies left without proof.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/clip_gallery_save/clip_gallery_save_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_provenance_providers.dart';
import 'package:openvine/screens/clip_gallery_save/clip_gallery_save_warning_page.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Provides a [ClipGallerySaveCubit] to the clip library.
///
/// Its services are account-independent, so they are read once rather than
/// watched: the gallery, the C2PA check, and the signer of the app's own
/// clips.
class ClipGallerySaveProvider extends BlocProvider<ClipGallerySaveCubit> {
  /// Creates a [ClipGallerySaveProvider] above [child].
  const ClipGallerySaveProvider({super.key, super.child})
    : super(create: createCubit);

  /// Creates this app's [ClipGallerySaveCubit], seeded with [results].
  static ClipGallerySaveCubit createCubit(
    BuildContext context, {
    List<ClipGallerySaveResult> results = const [],
  }) {
    final container = ProviderScope.containerOf(context, listen: false);
    return container.read(clipGallerySaveCubitFactoryProvider)(
      results: results,
    );
  }
}

/// Saves [clips] to the device gallery with the [ClipGallerySaveCubit] above
/// [context], and reports how it went on the app's messenger, offering to
/// name the clips whose copy left without its proof.
///
/// The save outlives the screen it was started from, so everything needed
/// to report it is captured before it starts, as for the DM clip send.
///
/// Returns null when a save is already running.
Future<ClipGallerySaveOutcome?> saveClipsToGallery(
  BuildContext context,
  List<DivineVideoClip> clips,
) async {
  final cubit = context.read<ClipGallerySaveCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final view = View.of(context);
  final textDirection = Directionality.of(context);
  final l10n = context.l10n;

  final outcome = await cubit.saveClips(clips);
  if (outcome == null) return null;

  final destination = cubit.destinationName;
  final withoutProof = outcome.savedWithoutProof;
  final message = switch (outcome) {
    ClipGallerySaveOutcome(permissionDenied: true) =>
      l10n.libraryGalleryPermissionDenied(destination),
    ClipGallerySaveOutcome(savedCount: 0) => l10n.libraryClipsSaveFailed(
      destination,
    ),
    ClipGallerySaveOutcome(:final savedCount, :final failedCount)
        when failedCount > 0 =>
      l10n.libraryClipsSavePartialResult(savedCount, failedCount),
    _ when withoutProof.isNotEmpty => l10n.libraryClipsSavedWithoutProof(
      withoutProof.length,
    ),
    ClipGallerySaveOutcome(:final savedCount) =>
      l10n.libraryClipsSavedToDestination(savedCount, destination),
  };
  final isError =
      outcome.permissionDenied ||
      outcome.failedCount > 0 ||
      withoutProof.isNotEmpty;
  final showsDetails = !outcome.permissionDenied && withoutProof.isNotEmpty;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      DivineSnackbarContainer.snackBar(
        message,
        error: isError,
        actionLabel: showsDetails
            ? l10n.libraryClipsSavedWithoutProofDetails
            : null,
        onActionPressed: showsDetails
            ? () {
                messenger.hideCurrentSnackBar();
                if (!navigator.mounted) return;
                _detach(
                  ClipGallerySaveWarningPage.open(navigator, withoutProof),
                  'open clips saved without proof',
                );
              }
            : null,
        duration: Duration(seconds: showsDetails ? 8 : 5),
      ),
    );
  _detach(
    SemanticsService.sendAnnouncement(view, message, textDirection),
    'announce gallery save outcome',
  );
  return outcome;
}

void _detach(Future<void> operation, String description) => runDetached(
  operation,
  description,
  logName: 'ClipGallerySave',
  category: LogCategory.ui,
);
