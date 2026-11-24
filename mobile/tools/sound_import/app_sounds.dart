// ABOUTME: The sounds the app ships whose licence lets Divine publish them,
// ABOUTME: as candidates read from the app's own sound manifest.

import 'sound_candidate.dart';

/// The divine-mobile revision whose `sounds_manifest.json` and sound files
/// were checked on 2026-11-24. Reading both at one revision keeps the
/// catalog and the files it downloads in step.
const appSoundsCommit = '4ebfd4fe323e87d3a0dece4bb3830c48c5991a74';

const _appRoot =
    'https://raw.githubusercontent.com/divinevideo/divine-mobile/'
    '$appSoundsCommit/mobile';

/// The app's sound manifest at [appSoundsCommit].
const appSoundsManifestUrl = '$_appRoot/assets/sounds/sounds_manifest.json';

/// The licences the manifest names that let Divine republish a sound.
const Map<String, SoundLicense> _licenses = {
  'CC0': SoundLicense.cc0,
  'CC BY 4.0': SoundLicense.ccBy4,
  'CC BY 3.0': SoundLicense.ccBy3,
};

final _freesoundPage = RegExp(
  r'^https://freesound\.org/people/([^/]+)/sounds/\d+/?$',
);

/// Candidates for the sounds in [manifest] that carry one of the licences
/// above and name the Freesound page they came from.
///
/// Leaves out every other entry: most of the app's sounds have no licence
/// or an unknown one, and a licence without its source page cannot be
/// credited. Freesound's API terms forbid copying its database, which is
/// why the importer has no Freesound source; these are single sounds the
/// app already ships, shared under their own licences.
List<SoundCandidate> appSoundCandidates(Map<String, dynamic> manifest) {
  final sounds = manifest['sounds'] as List<dynamic>? ?? const [];
  return [
    for (final sound in sounds.cast<Map<String, dynamic>>()) ?_candidate(sound),
  ];
}

SoundCandidate? _candidate(Map<String, dynamic> sound) {
  final license = _licenses[sound['license']];
  final page = sound['sourceUrl'] as String?;
  final creator = page == null ? null : _freesoundPage.firstMatch(page);
  if (license == null || creator == null) return null;

  final id = sound['id'] as String;
  final user = creator.group(1)!;
  final tags = [
    for (final tag in (sound['tags'] as List<dynamic>? ?? const []))
      if (tag is String && tag != 'freesound') tag,
  ];
  return SoundCandidate(
    id: 'app:$id',
    downloadUrl: '$_appRoot/${Uri.encodeFull(sound['assetPath'] as String)}',
    sourcePage: page!,
    title: sound['title'] as String,
    kind: _kindOf(tags),
    creatorName: user,
    creatorUrl: 'https://freesound.org/people/$user/',
    license: license,
    tags: [
      for (final tag in tags)
        if (tag != 'music' && tag != 'sfx') tag,
    ],
    divineSoundId: id,
  );
}

/// Music when the manifest tags it as music or singing, speech when it is a
/// voice, and an effect otherwise.
SoundKind _kindOf(List<String> tags) {
  if (tags.contains('music') || tags.contains('singing')) {
    return SoundKind.music;
  }
  if (tags.contains('voice')) return SoundKind.speech;
  return SoundKind.sfx;
}
