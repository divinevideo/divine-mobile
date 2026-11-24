// ABOUTME: Packs a portable, editable video draft for an encrypted DM.
// ABOUTME: Restores its media into new local files and saves an account-scoped copy.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blurhash_service/blurhash_service.dart';
import 'package:crypto/crypto.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/utils/draft_audio_path_resolver.dart';
import 'package:openvine/utils/editor_state_history_compaction.dart';
import 'package:openvine/utils/json_tree_rewrite.dart';
import 'package:path/path.dart' as p;
import 'package:unified_logger/unified_logger.dart';
import 'package:uuid/uuid.dart';

/// The project format is a bounded JSON manifest followed by the listed
/// media bytes. Media entries use numeric references and generated filenames.
class DraftTransferService {
  DraftTransferService({required this.documentsPath});

  final String documentsPath;
  final Map<String, Future<DivineVideoDraft>> _imports = {};

  static const _magic = 0x44564431; // DVD1
  static const _headerBytes = 8;
  static const int _maxManifestBytes = 8 * 1024 * 1024;
  static const _maxFiles = 256;
  static const _extensions = {
    '.mp4',
    '.mov',
    '.m4v',
    '.webm',
    '.mkv',
    '.avi',
    '.3gp',
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
    '.heic',
    '.heif',
    '.avif',
    '.aac',
    '.m4a',
    '.mp3',
    '.wav',
    '.ogg',
    '.flac',
    '.opus',
    '.caf',
    '.aiff',
  };

  /// Creates an owned temporary project file. The caller deletes or transfers it.
  Future<File> exportDraft(
    DivineVideoDraft draft, {
    required Directory temporaryDirectory,
  }) async {
    if (draft.clips.isEmpty) throw const FormatException('Empty draft');
    final canonicalDocumentsPath = Directory(
      documentsPath,
    ).resolveSymbolicLinksSync();
    final media =
        <String, ({File file, int size, String extension, int index})>{};
    var mediaBytes = 0;
    final project = _rewriteMedia(_projectFields(draft.toJson()), (
      value, {
      required audio,
      required optional,
    }) {
      final resolved = audio
          ? resolveAudioPath(value, documentsPath)
          : p.join(documentsPath, p.basename(value));
      final file = File(resolved);
      if (!file.existsSync() && optional) return null;
      if (!file.existsSync() ||
          !p.isWithin(
            canonicalDocumentsPath,
            file.resolveSymbolicLinksSync(),
          )) {
        throw const FormatException('Draft media is missing or external');
      }
      final extension = p.extension(resolved).toLowerCase();
      if (!_extensions.contains(extension)) {
        throw const FormatException('Unsupported draft media');
      }
      final key = file.path;
      final existing = media[key];
      if (existing != null) return '@${existing.index}';
      final size = file.lengthSync();
      mediaBytes += size;
      if (size == 0 || media.length == _maxFiles) {
        throw const FormatException('Invalid draft media');
      }
      if (mediaBytes > dmVideoMaxPlaintextBytes) {
        throw DmVideoTooLargeException(mediaBytes);
      }
      final index = media.length;
      media[key] = (file: file, size: size, extension: extension, index: index);
      return '@$index';
    });
    final manifest = utf8.encode(
      jsonEncode({
        'project': project,
        'files': [
          for (final entry in media.values)
            {'extension': entry.extension, 'size': entry.size},
        ],
      }),
    );
    final total = _headerBytes + manifest.length + mediaBytes;
    if (manifest.length > _maxManifestBytes ||
        total > dmVideoMaxPlaintextBytes) {
      throw DmVideoTooLargeException(total);
    }

    _validateHistory(project, manifest.length);

    final output = File(
      p.join(temporaryDirectory.path, '${const Uuid().v4()}.divinedraft'),
    );
    try {
      final header = ByteData(_headerBytes)
        ..setUint32(0, _magic)
        ..setUint32(4, manifest.length);
      final sink = output.openWrite();
      try {
        sink
          ..add(header.buffer.asUint8List())
          ..add(manifest);
        for (final entry in media.values) {
          await sink.addStream(entry.file.openRead(0, entry.size));
        }
      } finally {
        await sink.close();
      }
      if (output.lengthSync() != total) {
        throw const FormatException('Media changed during export');
      }
      return output;
    } on Object {
      await _deleteFiles([output]);
      rethrow;
    }
  }

  /// A blurhash of [draft]'s cover, sent with a share so the chat card shows
  /// a preview before anyone downloads the project. Only the blurhash leaves
  /// the device: an encrypted thumbnail would reuse the project's GCM nonce.
  ///
  /// Null when the draft has no readable cover or encoding takes longer than
  /// [timeout]. Never throws.
  Future<String?> readCoverBlurhash(
    DivineVideoDraft draft, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final path = draft.coverThumbnailPath;
    if (path == null || path.isEmpty) return null;
    try {
      var file = File(path);
      if (!file.existsSync()) {
        file = File(p.join(documentsPath, p.basename(path)));
      }
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      return await BlurhashService.generateBlurhash(
        bytes,
      ).timeout(timeout, onTimeout: () => null);
    } on Object catch (error) {
      // The preview is optional; a draft whose cover cannot be read still
      // sends. The path is left out of the log.
      Log.warning(
        'Left the cover out of a shared draft: ${error.runtimeType}',
        name: 'DraftTransferService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Downloads only on request. Reopening the same message returns the
  /// recipient's existing copy, including any edits made since importing.
  Future<DivineVideoDraft> importDraft({
    required String messageId,
    required String senderPubkey,
    required DraftStorageService storage,
    required Future<Uint8List> Function() download,
    required bool Function() stillWanted,
  }) async {
    final owner = storage.ownerPubkey;
    if (owner == null || !stillWanted()) {
      throw StateError('No active draft owner');
    }
    final digest = sha256.convert(utf8.encode('$owner:$messageId'));
    final id = 'draft_shared_$digest';
    final active = _imports[id];
    if (active != null) return active;
    final job = _importDraft(
      id: id,
      senderPubkey: senderPubkey,
      storage: storage,
      download: download,
      stillWanted: stillWanted,
    );
    _imports[id] = job;
    try {
      return await job;
    } finally {
      _imports.removeWhere((key, _) => key == id);
    }
  }

  Future<DivineVideoDraft> _importDraft({
    required String id,
    required String senderPubkey,
    required DraftStorageService storage,
    required Future<Uint8List> Function() download,
    required bool Function() stillWanted,
  }) async {
    final existing = await storage.getDraftById(id);
    if (existing != null) return existing;
    if (!stillWanted()) throw StateError('Draft import cancelled');
    final bundle = await download();
    if (!stillWanted()) throw StateError('Draft import cancelled');
    if (bundle.length < _headerBytes ||
        bundle.length > dmVideoMaxPlaintextBytes) {
      throw const FormatException('Invalid draft size');
    }
    final header = ByteData.sublistView(bundle, 0, _headerBytes);
    final manifestSize = header.getUint32(4);
    if (header.getUint32(0) != _magic ||
        manifestSize > _maxManifestBytes ||
        manifestSize > bundle.length - _headerBytes) {
      throw const FormatException('Unknown project format');
    }
    var offset = _headerBytes + manifestSize;
    final manifest = jsonDecode(
      utf8.decode(Uint8List.sublistView(bundle, _headerBytes, offset)),
    ) as Map<String, dynamic>;
    final project = manifest['project'] as Map<String, dynamic>;
    _validateDepth(project);
    _validateHistory(project, manifestSize);
    final files = manifest['files'] as List<dynamic>;
    if (files.length > _maxFiles) {
      throw const FormatException('Too many media files');
    }
    final entries = <({String extension, int start, int end})>[];
    for (final item in files.cast<Map<String, dynamic>>()) {
      final extension = item['extension'] as String;
      final size = item['size'] as int;
      if (!_extensions.contains(extension) ||
          size <= 0 ||
          size > bundle.length - offset) {
        throw const FormatException('Invalid media entry');
      }
      entries.add((extension: extension, start: offset, end: offset + size));
      offset += size;
    }
    if (offset != bundle.length) throw const FormatException('Trailing data');

    final nonce = const Uuid().v4();
    final destinations = <int, String>{};
    final restored = _rewriteMedia(_projectFields(project), (
      value, {
      required audio,
      required optional,
    }) {
      final index = value.startsWith('@')
          ? int.tryParse(value.substring(1))
          : null;
      if (index == null || index < 0 || index >= entries.length) {
        throw const FormatException('Invalid media reference');
      }
      final name = 'shared_${nonce}_$index${entries[index].extension}';
      final relative = audio ? p.join(extractedClipAudioDirName, name) : name;
      if (destinations.putIfAbsent(index, () => relative) != relative) {
        throw const FormatException('Conflicting media reference');
      }
      return relative;
    }, senderPubkey: senderPubkey);
    if (destinations.length != entries.length) {
      throw const FormatException('Unreferenced media');
    }

    final written = <File>[];
    try {
      for (final destination in destinations.entries) {
        if (!stillWanted()) throw StateError('Draft import cancelled');
        final entry = entries[destination.key];
        final file = File(p.join(documentsPath, destination.value));
        written.add(file);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          Uint8List.sublistView(bundle, entry.start, entry.end),
        );
      }
      final now = DateTime.now().toIso8601String();
      final draft = DivineVideoDraft.fromJson({
        ...restored,
        'id': id,
        'createdAt': now,
        'lastModified': now,
        'publishStatus': PublishStatus.draft.name,
        'clipSourceCredits': _creditSender(
          ClipSourceCredit.listFromJson(restored['clipSourceCredits']),
          senderPubkey,
        ),
      }, documentsPath);
      if (draft.clips.isEmpty ||
          draft.clips.any((clip) => !clip.hasResolvableVideoFile) ||
          draft.clips.map((clip) => clip.id).toSet().length !=
              draft.clips.length) {
        throw const FormatException('Unusable draft timeline');
      }
      if (!stillWanted()) throw StateError('Draft import cancelled');
      await storage.saveDraft(draft);
      return draft;
    } on Object {
      await _deleteFiles(written);
      rethrow;
    }
  }

  static const _projectKeys = {
    'clips',
    'title',
    'description',
    'allowVideoReuse',
    'captionMentions',
    'inspiredByVideo',
    'inspiredByNpubs',
    'hashtags',
    'selectedApproach',
    'editorStateHistory',
    'editorEditingParameters',
    'selectedSound',
    'audioShareAttribution',
    'contentWarning',
    'thumbnailTimestamp',
    'customThumbnailPath',
    'clipSourceCredits',
  };

  static Map<String, dynamic> _projectFields(Map<String, dynamic> json) => {
    for (final key in _projectKeys)
      if (json.containsKey(key)) key: json[key],
  };

  static const _optionalMedia = {
    'thumbnailPath',
    'ghostFramePath',
    'compositeThumbnailPath',
    'thumbnail',
    'customThumbnailPath',
  };

  static const Set<String> _clipMedia = {
    'file',
    'filePath',
    'forwardVideoPath',
    'reversedVideoPath',
    'chromaKeySourcePath',
    'rawSourcePath',
    'sourcePath',
    'boomerangSourcePath',
    'backgroundImage',
    'backgroundVideo',
    ..._optionalMedia,
  };

  static Map<String, dynamic> _rewriteMedia(
    Map<String, dynamic> project,
    String? Function(
      String value, {
      required bool audio,
      required bool optional,
    })
    replace, {
    String? senderPubkey,
  }) =>
      rewriteJsonMaps(project, (map) {
            // Divine exports widget layers by ID or captures their pixels.
            // A direct file URL has no draft-owned lifetime on another device.
            if (map['fileUrl'] != null) {
              throw const FormatException('Unsupported file-backed layer');
            }
            final result = Map<String, dynamic>.from(map)
              ..remove('proofManifestJson')
              ..remove(proofManifestRefKey)
              ..remove(proofManifestsKey)
              ..remove('recordingSha256')
              ..remove('galleryBackup')
              ..remove('assetRecoveryAttempts');
            if (map.containsKey('filePath') && map.containsKey('recordedAt')) {
              result['importedSource'] = true;
              if (senderPubkey != null) {
                result['sourceCredits'] = _creditSender(
                  _clipCredits(map),
                  senderPubkey,
                );
                // Folded into sourceCredits above, so a dropped credit cannot
                // come back through the clip's single-credit fields.
                _legacyClipCreditKeys.forEach(result.remove);
              }
            }
            final audioEvent =
                map['id'] is String &&
                map.containsKey('pubkey') &&
                map.containsKey('createdAt');
            for (final entry in map.entries) {
              final key = entry.key;
              final value = entry.value;
              if (key == 'retainedSourcePaths' && value is List) {
                result['retainedSourcePaths'] = [
                  for (final item in value.cast<String>())
                    replace(item, audio: false, optional: false),
                ];
                continue;
              }
              if (key is! String || value is! String || value.isEmpty) continue;
              final audio =
                  audioEvent && (key == 'url' || key == 'originalUrl');
              if (audio) {
                final uri = Uri.tryParse(value);
                if (uri?.scheme == 'https' ||
                    uri?.scheme == 'http' ||
                    uri?.scheme == 'asset') {
                  continue;
                }
              }
              final localMedia =
                  _clipMedia.contains(key) ||
                  key == 'path' ||
                  (key == 'image' && map['type'] == 'image') ||
                  ((key == 'video' || key == 'source') &&
                      map['video'] is String &&
                      map['source'] is String);
              if (audio || localMedia) {
                result[key] = replace(
                  value,
                  audio: audio,
                  optional: _optionalMedia.contains(key),
                );
              }
            }
            return result;
          })!
          as Map<String, dynamic>;

  static const _legacyClipCreditKeys = [
    'sourceAuthorPubkey',
    'sourceEventId',
    'sourceAddressableId',
    'sourceRelayHint',
  ];

  /// Every credit a clip map carries: its list, and the single credit of a
  /// clip saved before the list existed.
  static List<ClipSourceCredit> _clipCredits(Map<dynamic, dynamic> clip) {
    String? field(String key) {
      final value = clip[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final author = field('sourceAuthorPubkey');
    final addressable = field('sourceAddressableId');
    return [
      ...ClipSourceCredit.listFromJson(clip['sourceCredits']),
      if (author != null)
        ClipSourceCredit(
          authorPubkey: author,
          eventId: field('sourceEventId'),
          addressableId: addressable,
          relayUrl: field('sourceRelayHint'),
        )
      else if (addressable != null)
        ClipSourceCredit.fromAddressableId(
          addressableId: addressable,
          eventId: field('sourceEventId'),
          relayUrl: field('sourceRelayHint'),
        ),
    ];
  }

  /// Keeps the credits whose video coordinate names the credited account, and
  /// adds the sender.
  ///
  /// Credits become locked rows in the recipient's post form and `p`/`a` tags
  /// that notify the credited account, published under the recipient's name.
  /// Only a coordinate ties the account to the video without a lookup; a
  /// credit naming just an account or an event id is the sender's word alone,
  /// so it is dropped. The sender is credited for what they shared.
  static List<Map<String, dynamic>> _creditSender(
    Iterable<ClipSourceCredit> credits,
    String senderPubkey,
  ) {
    final kept = credits.where(_namesPublishedVideo).toList();
    // The first entry backs the original author's pubkey and source event.
    return [
      for (final credit in kept) credit.toJson(),
      if (!kept.any(
        (credit) => pubkeysEqual(credit.authorPubkey, senderPubkey),
      ))
        ClipSourceCredit(authorPubkey: senderPubkey).toJson(),
    ];
  }

  /// Whether [credit] names the published video a clip was reused from by a
  /// coordinate, which names that video's author, and credits that author.
  static bool _namesPublishedVideo(ClipSourceCredit credit) {
    final author = credit.inspiredByInfo?.creatorPubkey;
    return author != null &&
        author.isNotEmpty &&
        pubkeysEqual(author, credit.authorPubkey);
  }

  /// A saved history shares identical metadata across undo steps. Restoring
  /// it makes a distinct copy per step, so the transfer limit must also cover
  /// those copies. The writer only references earlier entries with full meta.
  static void _validateHistory(
    Map<String, dynamic> project,
    int manifestBytes,
  ) {
    final history = project['editorStateHistory'];
    if (history == null) return;
    if (history is! Map || history['m'] == true) {
      throw const FormatException('Unsupported editor history');
    }
    final entries = history['history'];
    if (entries is! List) return;
    var expandedBytes = manifestBytes;
    final metaSizes = <int, int>{};
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry is! Map || !entry.containsKey(historyMetaRefKey)) continue;
      final index = entry[historyMetaRefKey];
      if (index is! int || index < 0 || index >= i) {
        throw const FormatException('Invalid editor history reference');
      }
      final source = entries[index];
      if (source is! Map ||
          source['meta'] is! Map ||
          source.containsKey(historyMetaRefKey)) {
        throw const FormatException('Invalid editor history reference');
      }
      expandedBytes += metaSizes.putIfAbsent(
        index,
        () => utf8.encode(jsonEncode(source['meta'])).length,
      );
      if (expandedBytes > _maxManifestBytes) {
        throw DmVideoTooLargeException(expandedBytes);
      }
    }
  }

  static void _validateDepth(Object? root) {
    void visit(Object? value, int depth) {
      if (depth > 64) {
        throw const FormatException('Project nesting is too deep');
      }
      final children = switch (value) {
        Map() => value.values,
        List() => value,
        _ => const <Object?>[],
      };
      for (final child in children) {
        visit(child, depth + 1);
      }
    }

    visit(root, 0);
  }

  static Future<void> _deleteFiles(Iterable<File> files) async {
    for (final file in files) {
      try {
        if (file.existsSync()) await file.delete();
      } on FileSystemException {
        // Cleanup is best effort; preserve the original import/export error.
      }
    }
  }
}
