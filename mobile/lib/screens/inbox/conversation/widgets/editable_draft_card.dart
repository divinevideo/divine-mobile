// ABOUTME: Imports an explicitly opened project and takes its recipient to the editor.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/draft_transfer_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/router/creation_session_guard.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';

class EditableDraftCard extends ConsumerWidget {
  const EditableDraftCard({
    required this.message,
    required this.canOpen,
    super.key,
  });

  final DmMessage message;
  final bool canOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider(
      key: ValueKey(message.id),
      create: (_) => _DraftImportCubit(),
      child: BlocBuilder<_DraftImportCubit, _DraftImportState>(
        builder: (context, state) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              context.l10n.dmSharedDraft,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            if (canOpen)
              DivineButton(
                label: context.l10n.dmOpenDraft,
                maxLines: 2,
                isLoading: state == _DraftImportState.importing,
                onPressed: () => unawaited(_open(context, ref)),
              ),
            if (state == _DraftImportState.failed)
              Semantics(
                liveRegion: true,
                child: Text(
                  context.l10n.dmDraftImportFailed,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(draftStorageServiceProvider);
    final auth = ref.read(authServiceProvider);
    final owner = storage.ownerPubkey;
    bool owns(NostrSessionReadiness session) =>
        owner != null &&
        session.pubkey == owner &&
        session.phase != NostrSessionPhase.tearingDown;
    if (!owns(ref.read(nostrSessionProvider))) return;
    var retired = false;
    final session = ref.listenManual(nostrSessionProvider, (_, next) {
      if (!owns(next)) retired = true;
    });
    bool stillWanted() =>
        context.mounted &&
        !retired &&
        auth.currentPublicKeyHex == owner &&
        !ref
            .read(contentBlocklistRepositoryProvider)
            .isBlocked(
              message.senderPubkey,
            );

    try {
      final importer = ref.read(draftTransferServiceProvider);
      final decryptor = ref.read(dmVideoDecryptorProvider);
      final id = await context.read<_DraftImportCubit>().open(() async {
        final draft = await importer.importDraft(
          messageId: message.id,
          senderPubkey: message.senderPubkey,
          storage: storage,
          stillWanted: stillWanted,
          download: () => decryptor.decrypt(
            message,
            editableDraft: true,
            timeLimit: const Duration(minutes: 5),
            stillWanted: stillWanted,
          ),
        );
        return draft.id;
      });
      if (!context.mounted || id == null || !stillWanted()) return;
      final router = GoRouter.of(context);
      if (hasCreationSessionInRouteStack(
        router.routerDelegate.currentConfiguration,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.uploadFailureSheetSavedToDraftsSnackbar,
          ),
        );
        return;
      }
      final publisher = ref.read(videoPublishProvider.notifier);
      await publisher.clearAll(keepAutosavedDraft: true);
      if (!context.mounted || !stillWanted()) return;
      await VideoEditorDraftRouteData(
        draftId: id,
        from: VideoEditorScreen.libraryOrigin,
      ).push<void>(context);
    } finally {
      session.close();
    }
  }
}

enum _DraftImportState { idle, importing, failed }

class _DraftImportCubit extends Cubit<_DraftImportState> {
  _DraftImportCubit() : super(_DraftImportState.idle);

  Future<String?> open(Future<String> Function() importDraft) async {
    if (isClosed || state == _DraftImportState.importing) return null;
    emit(_DraftImportState.importing);
    try {
      final id = await importDraft();
      if (isClosed) return null;
      emit(_DraftImportState.idle);
      return id;
    } on Object {
      if (!isClosed) emit(_DraftImportState.failed);
      return null;
    }
  }
}
