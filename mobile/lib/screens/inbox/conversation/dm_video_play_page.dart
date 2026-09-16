// ABOUTME: Full-screen playback page for a received encrypted (kind 15) video
// ABOUTME: DM. Decrypts to a message-unique temp clip, plays it, saves it to the
// ABOUTME: gallery on demand, and deletes the plaintext on dispose or failure.

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Directory `VideoClip.memory` writes decrypted clips into under the platform
/// temporary directory. Mirrors the package's own path so this page can clean
/// up a partial write even when no [VideoClip] was returned.
const _memoryDirName = 'divine_player_memory';

/// Path `VideoClip.memory` writes [fileName] to.
///
/// Resolved before decrypting so a partial plaintext write can be deleted even
/// when `VideoClip.memory` throws before returning a clip. Matches the
/// package's own concatenation exactly on every platform.
Future<String> _resolveTempPath(String fileName) async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/$_memoryDirName/$fileName';
}

/// Best-effort synchronous delete of a decrypted plaintext temp file.
void _deleteTempFile(String path) {
  try {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  } catch (error, stackTrace) {
    Log.warning(
      'Could not delete decrypted video temp file',
      name: 'DmVideoPlayPage',
      category: LogCategory.video,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Decrypt-to-play progress of [DmVideoPlayPage].
enum _LoadStatus { loading, ready, error }

/// Plays a received encrypted video DM.
///
/// The ciphertext is downloaded and AES-GCM decrypted into a temp file named
/// [clipFileNameFor] the message, played, and deleted when the page is
/// disposed or the decrypt fails. The key and nonce stay in memory only —
/// they are never logged or persisted here.
class DmVideoPlayPage extends ConsumerStatefulWidget {
  /// Creates a play page for [message], a kind 15 video DM.
  const DmVideoPlayPage({
    required this.message,
    this.decryptor,
    super.key,
  });

  /// The received kind 15 message whose [DmMessage.fileMetadata] is a video.
  final DmMessage message;

  /// Download/decrypt service. Defaults to [DmVideoDecryptor]; tests inject a
  /// fake.
  final DmVideoDecryptor? decryptor;

  /// Opens the page for [message] on the enclosing navigator.
  static Future<void> open(BuildContext context, DmMessage message) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DmVideoPlayPage(message: message),
      ),
    );
  }

  /// Temp file name for [message]'s decrypted clip.
  ///
  /// Keyed on the message id so two play pages never share a temp path, and
  /// the extension is taken from the wire MIME type so the native decoder sees
  /// a recognisable container.
  static String clipFileNameFor(DmMessage message) {
    final slash = (message.fileMetadata?.fileType ?? '').indexOf('/');
    final raw = slash == -1
        ? ''
        : message.fileMetadata!.fileType.substring(
            slash + 1,
          );
    final extension = raw.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    return 'dm_video_${message.id}.${extension.isEmpty ? 'mp4' : extension}';
  }

  @override
  ConsumerState<DmVideoPlayPage> createState() => _DmVideoPlayPageState();
}

class _DmVideoPlayPageState extends ConsumerState<DmVideoPlayPage> {
  _LoadStatus _status = _LoadStatus.loading;
  DivineVideoPlayerController? _controller;
  VideoClip? _clip;

  /// The path [VideoClip.memory] will write to. Tracked separately from
  /// [_clip] so a decrypt failure that left a partial file behind is still
  /// cleaned up.
  String? _tempPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final fileMetadata = widget.message.fileMetadata;
    if (fileMetadata == null || !fileMetadata.isVideo) {
      setState(() => _status = _LoadStatus.error);
      return;
    }

    final fileName = DmVideoPlayPage.clipFileNameFor(widget.message);
    _tempPath = await _resolveTempPath(fileName);

    DivineVideoPlayerController? controller;
    try {
      final decryptor = widget.decryptor ?? DmVideoDecryptor();
      final clip = await decryptor.materialize(
        url: widget.message.content,
        key: fileMetadata.decryptionKey,
        nonce: fileMetadata.decryptionNonce,
        fileName: fileName,
      );
      if (!mounted) {
        _deleteTempFile(clip.uri);
        return;
      }

      controller = DivineVideoPlayerController(
        useTexture: true,
        debugLabel: 'dm_video_play',
      );
      try {
        await controller.initialize();
        await controller.setSource(clip);
        await controller.play();
      } catch (_) {
        await controller.dispose();
        rethrow;
      }

      if (!mounted) {
        await controller.dispose();
        _deleteTempFile(clip.uri);
        return;
      }

      setState(() {
        _controller = controller;
        _clip = clip;
        _status = _LoadStatus.ready;
      });
    } catch (error, stackTrace) {
      Log.error(
        'Encrypted video DM failed to decrypt or load',
        name: 'DmVideoPlayPage',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      await controller?.dispose();
      _cleanupTempFiles();
      if (mounted) setState(() => _status = _LoadStatus.error);
    }
  }

  Future<void> _saveToGallery() async {
    final clip = _clip;
    if (clip == null || _saving) return;
    setState(() => _saving = true);

    final result = await ref
        .read(gallerySaveServiceProvider)
        .saveVideoToGallery(EditorVideo.file(clip.uri));

    if (!mounted) return;
    setState(() => _saving = false);

    final l10n = context.l10n;
    final destination = GallerySaveService.destinationName;
    final (message, isError) = switch (result) {
      GallerySaveSuccess() => (
        l10n.libraryClipsSavedToDestination(1, destination),
        false,
      ),
      GallerySavePermissionDenied() => (
        l10n.libraryGalleryPermissionDenied(destination),
        true,
      ),
      GallerySaveFailure() => (l10n.videoClipSaveFailed, true),
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(DivineSnackbarContainer.snackBar(message, error: isError));
  }

  /// Deletes every temp path this page could have written.
  void _cleanupTempFiles() {
    final clipUri = _clip?.uri;
    if (clipUri != null) _deleteTempFile(clipUri);
    final tempPath = _tempPath;
    if (tempPath != null) _deleteTempFile(tempPath);
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    _cleanupTempFiles();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          if (_status == _LoadStatus.ready)
            IconButton(
              onPressed: _saving ? null : _saveToGallery,
              tooltip: context.l10n.shareSheetSaveVideo,
              icon: const DivineIcon(
                icon: DivineIconName.downloadSimple,
                color: Colors.white,
              ),
            ),
        ],
      ),
      body: Center(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (_status) {
      _LoadStatus.loading => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            context.l10n.commonLoading,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      _LoadStatus.error => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.dmVideoUnavailable,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      _LoadStatus.ready => DivineVideoPlayer(controller: _controller),
    };
  }
}

/// Decrypts [message]'s encrypted video DM and saves it to the device gallery.
///
/// Reuses [GallerySaveService] on the decrypted clip and always removes the
/// temp file before returning. The key and nonce stay in memory only. Throws
/// if the download or decrypt fails; otherwise the result never throws.
Future<GallerySaveResult> saveEncryptedVideoDm({
  required DmMessage message,
  required GallerySaveService gallerySaveService,
  DmVideoDecryptor? decryptor,
}) async {
  final fileMetadata = message.fileMetadata;
  if (fileMetadata == null || !fileMetadata.isVideo) {
    return const GallerySaveFailure('Message is not a video');
  }

  VideoClip? clip;
  String? tempPath;
  try {
    final fileName = DmVideoPlayPage.clipFileNameFor(message);
    // Resolve the target before decrypting so a partial plaintext write is
    // deleted even if `VideoClip.memory` throws before returning a clip.
    tempPath = await _resolveTempPath(fileName);
    clip = await (decryptor ?? DmVideoDecryptor()).materialize(
      url: message.content,
      key: fileMetadata.decryptionKey,
      nonce: fileMetadata.decryptionNonce,
      fileName: fileName,
    );
    return await gallerySaveService.saveVideoToGallery(
      EditorVideo.file(clip.uri),
    );
  } finally {
    final path = clip?.uri ?? tempPath;
    if (path != null) _deleteTempFile(path);
  }
}
