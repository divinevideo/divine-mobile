// ABOUTME: Builds aggregate-only diagnostics for locally stored drafts and clips.
// ABOUTME: Reads database rows and media existence without changing either one.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/utils/path_resolver.dart';

/// Collects a safe inventory that explains why a local library appears empty.
class LocalContentDiagnosticsService {
  const LocalContentDiagnosticsService({
    required ClipsDao clipsDao,
    required DraftsDao draftsDao,
    required String? ownerPubkey,
    required String documentsPath,
    Future<bool> Function(String path)? fileExists,
  }) : _clipsDao = clipsDao,
       _draftsDao = draftsDao,
       _ownerPubkey = ownerPubkey,
       _documentsPath = documentsPath,
       _fileExists = fileExists ?? _defaultFileExists;

  final ClipsDao _clipsDao;
  final DraftsDao _draftsDao;
  final String? _ownerPubkey;
  final String _documentsPath;
  final Future<bool> Function(String path) _fileExists;

  static Future<bool> _defaultFileExists(String path) =>
      Future.value(File(path).existsSync());

  Future<Map<String, dynamic>> collect() async {
    final clips = await _clipsDao.getClipInventory();
    final drafts = await _draftsDao.getDraftInventory();

    final visibleClips = clips.where(
      (row) =>
          row.deletedAt == null &&
          _isVisible(row.ownerPubkey) &&
          (row.draftId == null ||
              row.draftId == VideoEditorConstants.autoSaveId),
    );
    final visibleDrafts = drafts.where((row) => _isVisible(row.ownerPubkey));
    final anonymousClips = clips.where(
      (row) => row.ownerPubkey == DraftStorageService.anonymousOwnerPubkey,
    );
    final anonymousDrafts = drafts.where(
      (row) => row.ownerPubkey == DraftStorageService.anonymousOwnerPubkey,
    );
    final foreignClips = clips.where((row) => _isForeign(row.ownerPubkey));
    final foreignDrafts = drafts.where((row) => _isForeign(row.ownerPubkey));

    final draftIdsWithClips = {
      for (final clip in clips)
        if (clip.draftId != null &&
            clip.deletedAt == null &&
            _isVisible(clip.ownerPubkey))
          clip.draftId!,
    };
    final sourceFiles = <String>{};
    for (final clip in clips) {
      if (clip.deletedAt != null || !_isVisible(clip.ownerPubkey)) continue;
      final rawPath = clip.filePath;
      if (rawPath == null || rawPath.isEmpty) continue;
      final path = resolvePath(rawPath, _documentsPath);
      if (path != null) sourceFiles.add(path);
    }
    final existence = await Future.wait(sourceFiles.map(_fileExists));
    final missingSourceFileCount = existence.where((exists) => !exists).length;

    return {
      'visibleDraftRows': visibleDrafts.length,
      'visibleClipRows': visibleClips.length,
      'anonymousDraftRows': anonymousDrafts.length,
      'anonymousClipRows': anonymousClips.length,
      'foreignDraftRows': foreignDrafts.length,
      'foreignClipRows': foreignClips.length,
      'zeroClipDraftRows': visibleDrafts
          .where((draft) => !draftIdsWithClips.contains(draft.id))
          .length,
      'missingSourceMediaFiles': missingSourceFileCount,
    };
  }

  bool _isVisible(String? rowOwner) =>
      _ownerPubkey == null || rowOwner == null || rowOwner == _ownerPubkey;

  bool _isForeign(String? rowOwner) =>
      _ownerPubkey != null &&
      rowOwner != null &&
      rowOwner != _ownerPubkey &&
      rowOwner != DraftStorageService.anonymousOwnerPubkey;
}
