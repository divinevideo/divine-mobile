import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:openvine/utils/draft_audio_path_resolver.dart';

/// Stable composition identity across draft relocation and thumbnail rebuilds.
String publishingIdeasRevision(
  Map<String, dynamic> editing,
  List<Map<String, dynamic>> clips, {
  Map<String, dynamic>? selectedSound,
}) {
  final portable = toPortableAudioPaths({
    'editing': editing,
    'clips': clips,
    'sound': ?selectedSound,
  });
  return sha256
      .convert(utf8.encode(jsonEncode(_canonical(portable))))
      .toString();
}

const _presentationOnly = {
  'thumbnailPath',
  'thumbnailTimestampMs',
  'proofManifestJson',
  'ghostFramePath',
  'lensMetadata',
  'libraryTitle',
  'recordedAt',
};

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys =
        value.keys
            .cast<String>()
            .where((key) => !_presentationOnly.contains(key))
            .toList()
          ..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}
