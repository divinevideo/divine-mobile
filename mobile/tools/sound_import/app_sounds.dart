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

/// What the Freesound pages of the app's CC BY sounds say, checked on
/// 2026-11-24: the recording's own title, which the credit names (CC BY 3.0
/// requires it), and whether the app ships only an excerpt of it, which the
/// credit has to say as a change. The app's titles are shortened, and two
/// of its files are 6-second cuts of 39 s and 1:23 recordings.
const Map<String, ({String title, bool excerpt})> _ccByOriginals = {
  'freesound_yay': (title: 'YAY.mp3', excerpt: false),
  'freesound_hello_acapella': (title: 'Hello Acapella', excerpt: false),
  'freesound_radio_announcement': (
    title: 'Your no.1 talk, music and news radio.m4a',
    excerpt: false,
  ),
  'freesound_elevator_music': (title: 'Elevator Music', excerpt: true),
  'freesound_bossa_nova_guitar': (
    title: 'II-V-I Bossa Nova Guitar',
    excerpt: false,
  ),
  'freesound_vibrant_energy': (
    title: 'Vibrant and Uplifting Energy',
    excerpt: true,
  ),
};

final _freesoundPage = RegExp(
  r'^https://freesound\.org/people/([^/]+)/sounds/\d+/?$',
);

/// Candidates for the sounds in [manifest] that carry one of the licences
/// above and name the Freesound page they came from.
///
/// Leaves out every other entry: most of the app's sounds have no licence
/// or an unknown one, and a licence without its source page cannot be
/// credited. A CC BY sound is also left out until its Freesound title is in
/// [_ccByOriginals], so its credit names the recording as the licence asks.
/// Freesound's API terms forbid copying its database, which is why the
/// importer has no Freesound source; these are single sounds the app already
/// ships, shared under their own licences.
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
  final original = license.requiresAttribution ? _ccByOriginals[id] : null;
  if (license.requiresAttribution && original == null) return null;

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
    // As the app files its shipped sounds (`VineSoundKind`): music when
    // tagged so, an effect otherwise. A sound with no kind tag that its
    // audio analysis finds to be speech would drop out of Funnelcake's lists.
    kind: tags.contains('music') ? SoundKind.music : SoundKind.sfx,
    creatorName: user,
    creatorUrl: 'https://freesound.org/people/$user/',
    license: license,
    tags: [
      for (final tag in tags)
        if (tag != 'music' && tag != 'sfx') tag,
    ],
    creditLines: [
      if (original != null) ...[
        original.title,
        'Created by $user',
        'License: ${license.name} (${license.url})',
        if (original.excerpt) 'Excerpt of the original recording',
      ],
    ],
    divineSoundId: id,
  );
}
