// ABOUTME: Provides DmClipSaveCubit to a DM screen and runs "Add to clips"
// ABOUTME: so its result is still reported after the user leaves that screen.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/clip_save/dm_clip_save_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_provenance_providers.dart';
import 'package:openvine/providers/video_clip_import_provider.dart';
import 'package:openvine/utils/detached_future.dart';

/// Provides a [DmClipSaveCubit] to a DM screen.
///
/// The decryptor and verifier are account-independent. The clip library is
/// per account, so it is resolved when a save starts, not when the screen
/// opens.
class DmClipSaveProvider extends BlocProvider<DmClipSaveCubit> {
  /// Creates a [DmClipSaveProvider] above [child].
  const DmClipSaveProvider({super.key, super.child}) : super(create: _create);

  static DmClipSaveCubit _create(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    return DmClipSaveCubit(
      decryptor: container.read(dmVideoDecryptorProvider),
      verifier: container.read(clipProvenanceVerifierProvider),
      resolveImporter: () =>
          container.read(videoClipImportServiceProvider).importReceivedClip,
    );
  }
}

/// Adds [message]'s received video to the clip library behind the C2PA check.
///
/// The check outlives the screen that started it, so the messenger and
/// strings are captured up front and the outcome is reported on the app's
/// [ScaffoldMessenger] even after the user has navigated away.
Future<void> addReceivedClipToLibrary(
  BuildContext context,
  DmMessage message,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final view = View.of(context);
  final textDirection = Directionality.of(context);
  final l10n = context.l10n;
  final cubit = context.read<DmClipSaveCubit>();

  void report(String text, {required bool error}) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(DivineSnackbarContainer.snackBar(text, error: error));
    runDetached(
      SemanticsService.sendAnnouncement(view, text, textDirection),
      'announce clip save status',
      logName: 'DmClipSave',
      category: LogCategory.ui,
    );
  }

  report(l10n.dmClipChecking, error: false);
  final status = await cubit.save(message);
  final (text, isError) = switch (status) {
    DmClipSaveStatus.idle || DmClipSaveStatus.checking => (
      null,
      false,
    ),
    DmClipSaveStatus.saved => (l10n.videoEditorClipSavedSuccess, false),
    DmClipSaveStatus.notVerified => (l10n.dmClipNotVerified, true),
    DmClipSaveStatus.checkUnavailable => (l10n.dmClipCheckUnavailable, true),
    DmClipSaveStatus.failed => (l10n.shareSheetAddToClipsFailed, true),
  };
  if (text == null) return;
  report(text, error: isError);
}
