// ABOUTME: Which packs of the CC0 sound collection the importer reads, who made
// ABOUTME: them, and how their files become candidates. Only verified packs.

import 'sound_candidate.dart';
import 'sound_titles.dart';

/// The GitHub repository the CC0 effects are mirrored in.
const cc0Repository = 'lavenderdotpet/CC0-Public-Domain-Sounds';

/// A pack whose licence file names its original author and CC0.
///
/// Folders without such a file (`100-CC0-SFX`, `angerdog` and the like) are
/// left out on purpose: the mirror's own CC0 claim is not enough.
class Cc0Pack {
  const Cc0Pack({
    required this.matches,
    required this.creatorName,
    required this.creatorUrl,
    required this.label,
    required this.kindOf,
    this.tags = const [],
    this.skips = _skipsNothing,
  });

  /// Whether the top-level folder [folder] belongs to this pack.
  final bool Function(String folder) matches;

  final String creatorName;
  final String creatorUrl;

  /// Put in front of a file name that says nothing on its own.
  final String label;

  /// The kind of the file at [path], relative to the pack folder.
  final SoundKind Function(String path) kindOf;

  /// Search tags every sound of the pack gets.
  final List<String> tags;

  /// Whether the file at [path], relative to the pack folder, is left out.
  final bool Function(String path) skips;
}

bool _skipsNothing(String _) => false;

SoundKind _alwaysSfx(String _) => SoundKind.sfx;
SoundKind _alwaysSpeech(String _) => SoundKind.speech;
SoundKind _alwaysMusic(String _) => SoundKind.music;

/// The verified packs, checked against each folder's licence file on
/// 2026-11-04.
final cc0Packs = <Cc0Pack>[
  // "License (Creative Commons Zero, CC0)" in every Kenney License.txt.
  Cc0Pack(
    matches: (folder) => folder.startsWith('kenney_voiceover'),
    creatorName: 'Kenney',
    creatorUrl: 'https://kenney.nl',
    label: 'Voice',
    kindOf: _alwaysSpeech,
    tags: const ['kenney', 'voice', 'announcer'],
  ),
  Cc0Pack(
    matches: (folder) => folder == 'kenney_musicjingles',
    creatorName: 'Kenney',
    creatorUrl: 'https://kenney.nl',
    label: 'Jingle',
    kindOf: _alwaysMusic,
    tags: const ['kenney', 'jingle'],
  ),
  Cc0Pack(
    matches: (folder) =>
        folder.startsWith('kenney_') || folder == 'sci-fi-sounds',
    creatorName: 'Kenney',
    creatorUrl: 'https://kenney.nl',
    label: 'Kenney',
    kindOf: _alwaysSfx,
    tags: const ['kenney'],
  ),
  // Ben Burnes: "These sounds are public domain (Creative Commons 0)" in
  // every _README.txt.
  Cc0Pack(
    matches: (folder) => folder.startsWith('BB_2HTC'),
    creatorName: 'Ben Burnes',
    creatorUrl: 'https://abstractionmusic.com',
    label: 'Sample',
    kindOf: (path) => switch (path.split('/').first) {
      'Loops' || 'Pads' || 'Solos' => SoundKind.music,
      _ => SoundKind.sfx,
    },
    tags: const ['samples'],
  ),
  Cc0Pack(
    matches: (folder) => folder == 'Micro Pack - MadameBerry - Stream Noises',
    creatorName: 'Ben Burnes',
    creatorUrl: 'https://abstractionmusic.com',
    label: 'Stream Noise',
    kindOf: _alwaysSpeech,
  ),
  Cc0Pack(
    matches: (folder) =>
        folder.startsWith('BB_') ||
        folder.startsWith('bb - ') ||
        folder.startsWith('Micro Pack - '),
    creatorName: 'Ben Burnes',
    creatorUrl: 'https://abstractionmusic.com',
    label: 'Foley',
    kindOf: _alwaysSfx,
    tags: const ['foley'],
  ),
  // README: "The sound pack is now under CC0" plus the CC0 waiver.
  Cc0Pack(
    matches: (folder) => folder == 'MMRetroArcadeSoundsPack1_0_5',
    creatorName: 'The Motion Monkey',
    creatorUrl:
        'http://www.themotionmonkey.co.uk/free-resources/retro-arcade-sounds/',
    label: 'Arcade',
    kindOf: (path) =>
        path.startsWith('Speech/') ? SoundKind.speech : SoundKind.sfx,
    tags: const ['retro', 'arcade', '8bit'],
  ),
  // warfork_assets_cc0.txt: "Team Forbidden has waived all copyright".
  Cc0Pack(
    matches: (folder) => folder == 'warfork-cc0',
    creatorName: 'Team Forbidden (Warfork)',
    creatorUrl: 'https://warfork.com',
    label: 'Warfork',
    kindOf: (path) {
      if (path.startsWith('music/') || path.startsWith('sounds/music/')) {
        return SoundKind.music;
      }
      if (path.startsWith('sounds/announcer/') ||
          path.startsWith('sounds/vsay/')) {
        return SoundKind.speech;
      }
      return SoundKind.sfx;
    },
    tags: const ['game'],
    // Voice-overs from the game's trailer, such as "CC0, download for free".
    skips: (path) => path.startsWith('sounds/trailer/'),
  ),
];

const _audioExtensions = {'wav', 'ogg', 'mp3', 'm4a', 'flac'};

/// The order in which one recording's copies are preferred when a pack ships
/// it in several formats: the lossless one first.
const _formatPreference = ['wav', 'flac', 'm4a', 'ogg', 'mp3'];

/// One file of the repository's tree listing.
class RepositoryFile {
  const RepositoryFile({
    required this.path,
    required this.blobSha,
    required this.size,
  });

  final String path;

  /// Git's blob hash: equal for byte-identical files.
  final String blobSha;
  final int size;
}

/// The candidates among [files] of the repository at [commit].
///
/// Leaves out unverified packs, previews, macOS metadata and byte-identical
/// copies, and keeps one format of a recording a pack ships several times.
List<SoundCandidate> cc0Candidates(
  List<RepositoryFile> files, {
  required String commit,
}) {
  final seenBlobs = <String>{};
  final byRecording = <String, RepositoryFile>{};
  final packOf = <String, Cc0Pack>{};

  for (final file in files) {
    final parts = file.path.split('/');
    if (parts.length < 2) continue;
    final name = parts.last;
    final extension = name.contains('.')
        ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
        : '';
    if (!_audioExtensions.contains(extension)) continue;
    if (parts.contains('__MACOSX') || name.startsWith('._')) continue;
    if (name.toLowerCase().startsWith('preview')) continue;

    final pack = _packFor(parts.first);
    if (pack == null || pack.skips(parts.skip(1).join('/'))) continue;
    if (!seenBlobs.add(file.blobSha)) continue;

    final key = _recordingKey(file.path);
    final kept = byRecording[key];
    if (kept == null || _rank(file.path) < _rank(kept.path)) {
      byRecording[key] = file;
      packOf[key] = pack;
    }
  }

  final candidates = <SoundCandidate>[];
  for (final MapEntry(:key, value: file) in byRecording.entries) {
    final pack = packOf[key]!;
    final parts = file.path.split('/');
    final inPack = parts.skip(1).join('/');
    final kind = pack.kindOf(inPack);
    final folderTags = parts
        .sublist(1, parts.length - 1)
        .where((folder) => !_formatFolders.contains(folder.toLowerCase()))
        .where((folder) => folder != 'Audio' && folder != 'sounds');
    candidates.add(
      SoundCandidate(
        id: 'cc0:${file.path}',
        downloadUrl:
            'https://raw.githubusercontent.com/$cc0Repository/$commit/'
            '${_encodePath(file.path)}',
        sourcePage:
            'https://github.com/$cc0Repository/blob/$commit/'
            '${_encodePath(file.path)}',
        title: titleFromFileName(parts.last, context: pack.label),
        kind: kind,
        creatorName: pack.creatorName,
        creatorUrl: pack.creatorUrl,
        license: SoundLicense.cc0,
        tags: normalizeSearchTags([...pack.tags, ...folderTags]),
        expectedBytes: file.size,
      ),
    );
  }
  candidates.sort((a, b) => a.id.compareTo(b.id));
  return candidates;
}

const _formatFolders = {'wav', 'ogg', 'm4a', 'mp3', 'flac'};

Cc0Pack? _packFor(String folder) {
  for (final pack in cc0Packs) {
    if (pack.matches(folder)) return pack;
  }
  return null;
}

/// The same recording in another format folder or with another extension
/// maps to the same key.
String _recordingKey(String path) {
  final parts = path.split('/');
  final name = parts.removeLast();
  final stem = name.contains('.')
      ? name.substring(0, name.lastIndexOf('.'))
      : name;
  return [
    for (final folder in parts)
      if (!_formatFolders.contains(folder.toLowerCase())) folder,
    stem,
  ].join('/');
}

int _rank(String path) {
  final extension = path.substring(path.lastIndexOf('.') + 1).toLowerCase();
  final index = _formatPreference.indexOf(extension);
  return index == -1 ? _formatPreference.length : index;
}

String _encodePath(String path) =>
    path.split('/').map(Uri.encodeComponent).join('/');
