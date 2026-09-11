// ABOUTME: Deterministic discovered-list fixtures for screenshot mode's
// ABOUTME: `06_lists` marketing capture of the Explore Lists gallery.

import 'package:models/models.dart' show CuratedList;

/// Clean, on-brand discovered-list fixtures for the `06_lists` capture.
///
/// Live discovery surfaces real public kind-30005 lists, some with
/// off-brand or misspelled names; screenshot mode seeds these deterministic
/// lists instead so the marketing shot is always clean.
/// `pubkey` is left null so no author by-line can surface an off-brand name.
List<CuratedList> screenshotDiscoverListsFixtures() {
  final now = DateTime.utc(2026);
  CuratedList list(String id, String name, String desc, int count) =>
      CuratedList(
        id: id,
        name: name,
        description: desc,
        videoEventIds: List<String>.generate(count, (i) => '$id-$i'),
        createdAt: now,
        updatedAt: now,
      );
  return [
    list(
      'favorite-classic-vines',
      'Favorite Classic Vines',
      'The loops that started it all',
      152,
    ),
    list('cat-chaos', 'Cat Chaos', 'Certified feline nonsense', 223),
    list('art-lives-here', 'Art Lives Here', 'Animators, painters, makers', 96),
    list('comedy-gold', 'Comedy Gold', 'Loops that never miss', 287),
    list('nature-loops', 'Nature Loops', 'Six seconds of calm', 61),
    list('music-vault', 'Music Vault', 'Beats, covers, originals', 81),
  ];
}
