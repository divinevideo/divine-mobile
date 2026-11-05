// ABOUTME: Maps incompetech's track list (Kevin MacLeod, CC BY 4.0) to import
// ABOUTME: candidates, with the credit text the composer asks for.

import 'sound_candidate.dart';

/// Every track, with title, file name, feel, instruments and ISRC.
const incompetechPiecesUrl =
    'https://incompetech.com/music/royalty-free/pieces.json';

/// The credited creator, as incompetech's licence page words it.
const incompetechCreator = 'Kevin MacLeod (incompetech.com)';

const _creatorUrl = 'https://incompetech.com';
const _downloadBase =
    'https://incompetech.com/music/royalty-free/mp3-royaltyfree/';
const _trackPage = 'https://incompetech.com/music/royalty-free/index.html';

/// At most this many feel and instrument tags per track: the sound pill on
/// a video lists every tag after the credit, and the long lists crowd it.
const _maxTags = 5;

/// The candidates for the entries of `pieces.json`.
///
/// Entries without a file name or ISRC are left out: the ISRC is what keeps
/// a track's id stable across runs.
List<SoundCandidate> incompetechCandidates(List<dynamic> pieces) {
  final candidates = <SoundCandidate>[];
  final seen = <String>{};
  for (final piece in pieces.whereType<Map<String, dynamic>>()) {
    final title = (piece['title'] as String?)?.trim() ?? '';
    final fileName = (piece['filename'] as String?)?.trim() ?? '';
    final isrc = (piece['isrc'] as String?)?.trim().toUpperCase() ?? '';
    if (title.isEmpty || fileName.isEmpty || isrc.isEmpty) continue;
    if (!seen.add(isrc)) continue;

    final description = (piece['description'] as String?)?.trim();
    candidates.add(
      SoundCandidate(
        id: 'incompetech:$isrc',
        downloadUrl: '$_downloadBase${Uri.encodeComponent(fileName)}',
        sourcePage: '$_trackPage?isrc=$isrc',
        title: title,
        kind: SoundKind.music,
        creatorName: incompetechCreator,
        creatorUrl: _creatorUrl,
        license: SoundLicense.ccBy4,
        tags: normalizeSearchTags([
          ..._listField(piece['feel']),
          ..._listField(piece['instruments']),
        ]).take(_maxTags).toList(),
        isrc: isrc,
        summary: description == null || description.isEmpty
            ? null
            : description,
        creditLines: incompetechCredit(title),
      ),
    );
  }
  return candidates;
}

/// The attribution incompetech asks for, line by line.
List<String> incompetechCredit(String title) => [
  '"$title" $incompetechCreator',
  'Licensed under Creative Commons: By Attribution 4.0 License',
  SoundLicense.ccBy4.url,
];

Iterable<String> _listField(Object? value) =>
    value is String ? value.split(',') : const [];
