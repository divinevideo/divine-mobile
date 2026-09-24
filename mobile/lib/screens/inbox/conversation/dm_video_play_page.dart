// ABOUTME: Full-screen playback page for a received encrypted (kind 15) video
// ABOUTME: DM. Decrypts through DmVideoPlaybackCubit, plays, and saves on demand.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/video_playback/dm_video_playback_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/providers/video_providers.dart';

/// Plays a received encrypted video DM.
///
/// The page wires [DmVideoPlaybackCubit]; the cubit owns the decrypted temp
/// file and deletes it when the page closes. The key and nonce never leave
/// the message metadata.
class DmVideoPlayPage extends ConsumerWidget {
  /// Creates a play page for [message], a kind 15 video DM.
  const DmVideoPlayPage({required this.message, super.key});

  /// The received kind 15 message whose [DmMessage.fileMetadata] is a video.
  final DmMessage message;

  /// Opens the page for [message] on the enclosing navigator.
  static Future<void> open(BuildContext context, DmMessage message) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DmVideoPlayPage(message: message),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both services are stateless and account-independent.
    final decryptor = ref.watch(dmVideoDecryptorProvider);
    final gallerySaveService = ref.watch(gallerySaveServiceProvider);
    return BlocProvider(
      key: ValueKey((decryptor, gallerySaveService)),
      create: (_) => DmVideoPlaybackCubit(
        message: message,
        decryptor: decryptor,
        gallerySaveService: gallerySaveService,
      )..load(),
      child: const DmVideoPlayView(),
    );
  }
}

/// UI for [DmVideoPlayPage]. Reads [DmVideoPlaybackCubit] from context.
class DmVideoPlayView extends StatelessWidget {
  /// Creates a [DmVideoPlayView].
  @visibleForTesting
  const DmVideoPlayView({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (DmVideoPlaybackCubit cubit) => cubit.state.status,
    );
    return BlocListener<DmVideoPlaybackCubit, DmVideoPlaybackState>(
      listenWhen: (previous, current) =>
          previous.saveStatus != current.saveStatus,
      listener: _onSaveStatus,
      child: Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: VineTheme.transparent,
          foregroundColor: VineTheme.whiteText,
          actions: [
            if (status == DmVideoPlaybackStatus.ready) const _SaveButton(),
          ],
        ),
        body: Center(
          child: switch (status) {
            DmVideoPlaybackStatus.loading => const _Loading(),
            DmVideoPlaybackStatus.failed => const _Unavailable(),
            DmVideoPlaybackStatus.ready => const _Player(),
          },
        ),
      ),
    );
  }

  void _onSaveStatus(BuildContext context, DmVideoPlaybackState state) {
    final l10n = context.l10n;
    final destination = GallerySaveService.destinationName;
    final (message, isError) = switch (state.saveStatus) {
      DmVideoSaveStatus.idle || DmVideoSaveStatus.saving => (null, false),
      DmVideoSaveStatus.saved => (
        l10n.libraryClipsSavedToDestination(1, destination),
        false,
      ),
      DmVideoSaveStatus.permissionDenied => (
        l10n.libraryGalleryPermissionDenied(destination),
        true,
      ),
      DmVideoSaveStatus.failed => (l10n.videoClipSaveFailed, true),
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(DivineSnackbarContainer.snackBar(message, error: isError));
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton();

  @override
  Widget build(BuildContext context) {
    final saving = context.select(
      (DmVideoPlaybackCubit cubit) =>
          cubit.state.saveStatus == DmVideoSaveStatus.saving,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: DivineIconButton(
        icon: DivineIconName.downloadSimple,
        type: DivineIconButtonType.ghostOverMedia,
        size: DivineIconButtonSize.small,
        onPressed: saving
            ? null
            : () => context.read<DmVideoPlaybackCubit>().saveToGallery(),
        semanticLabel: context.l10n.shareSheetSaveVideo,
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        const DivineCircularProgressIndicator(color: VineTheme.whiteText),
        Text(
          context.l10n.commonLoading,
          style: VineTheme.bodyLargeFont(color: VineTheme.whiteText),
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        const DivineIcon(
          icon: DivineIconName.warningCircle,
          color: VineTheme.whiteText,
          size: 48,
        ),
        Text(
          context.l10n.dmVideoUnavailable,
          style: VineTheme.bodyLargeFont(color: VineTheme.whiteText),
        ),
      ],
    );
  }
}

/// Plays the decrypted clip. Owns the native player controller; a player
/// failure is reported to the cubit, which deletes the clip.
class _Player extends StatefulWidget {
  const _Player();

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  DivineVideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final path = context.read<DmVideoPlaybackCubit>().state.clipPath;
    if (path != null) unawaited(_start(path));
  }

  Future<void> _start(String path) async {
    final controller = DivineVideoPlayerController(
      useTexture: true,
      debugLabel: 'dm_video_play',
    );
    try {
      await controller.initialize();
      await controller.setSource(VideoClip.file(path));
      await controller.play();
    } catch (error, stackTrace) {
      await controller.dispose();
      if (mounted) {
        context.read<DmVideoPlaybackCubit>().playbackFailed(error, stackTrace);
      }
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const DivineCircularProgressIndicator(color: VineTheme.whiteText);
    }
    return DivineVideoPlayer(controller: controller);
  }
}
