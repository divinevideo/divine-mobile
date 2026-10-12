// ABOUTME: Provides GalleryClipImportCubit to the library and explains, once,
// ABOUTME: that only C2PA-verified Divine clips come back from the gallery.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/gallery_clip_import/gallery_clip_import_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_provenance_providers.dart';
import 'package:openvine/providers/video_clip_import_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides a [GalleryClipImportCubit] to the clip library.
///
/// It sits on the library rather than the import page, so an import keeps
/// reporting into the library's grid after the page is closed. The verifier
/// is account-independent; the clip library is per account, so it is resolved
/// when an import starts, not when the screen opens.
class GalleryClipImportProvider extends BlocProvider<GalleryClipImportCubit> {
  /// Creates a [GalleryClipImportProvider] above [child].
  const GalleryClipImportProvider({super.key, super.child})
    : super(create: _create);

  static GalleryClipImportCubit _create(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    return GalleryClipImportCubit(
      verifier: container.read(clipProvenanceVerifierProvider),
      resolveImporter: () =>
          container.read(videoClipImportServiceProvider).importGalleryClip,
      loadThumbnail: container.read(galleryClipThumbnailLoaderProvider),
    );
  }
}

/// Preference keys of the gallery import.
abstract final class GalleryClipImportPrefs {
  /// Whether the one-time explanation of the gallery import was shown.
  static const String explainerShownKey = 'gallery_clip_import_explained';

  /// Device-scoped, not account data: a hint seen once on this device need
  /// not be shown again after an account switch. Declared beside the key so
  /// the preference-key guard can classify it.
  static const List<String> deviceScopedPrefsKeys = [explainerShownKey];
}

/// Explains, the first time only, that just clips shot with Divine come back
/// from the gallery and that each is verified with C2PA first.
///
/// Returns whether to go on to the picker: always once the explanation has
/// been seen, otherwise only when it is confirmed rather than dismissed.
Future<bool> confirmGalleryClipImport(
  BuildContext context,
  SharedPreferences preferences,
) async {
  if (preferences.getBool(GalleryClipImportPrefs.explainerShownKey) ?? false) {
    return true;
  }

  final navigator = Navigator.of(context);
  final confirmed = await VineBottomSheetPrompt.show<bool>(
    context: context,
    sticker: .grandfather,
    title: context.l10n.libraryGalleryImportExplainerTitle,
    subtitle: context.l10n.libraryGalleryImportExplainerSubtitle,
    primaryButtonText: context.l10n.libraryGalleryImportExplainerButton,
    onPrimaryPressed: () => navigator.pop(true),
  );
  if (confirmed != true) return false;

  await preferences.setBool(GalleryClipImportPrefs.explainerShownKey, true);
  return true;
}
