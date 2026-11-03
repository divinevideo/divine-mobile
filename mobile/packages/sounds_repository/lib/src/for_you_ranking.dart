import 'dart:math';

import 'package:models/models.dart';

/// Orders the sound picker's "For you" list.
///
/// A sound someone the viewer follows published scores by how new it is:
/// 2 today, 1.5 after three days, 1.25 after six. Each further sound by the
/// same person counts a tenth less than their one before, so one busy account
/// does not fill the list. Divine's own sounds score by a quality boost that
/// eases off down their list, 1.8 for the first and 3 % less for each one
/// after it, so the two interleave: the newest uploads lead, and Divine's
/// sounds come in among them from the first rows on. [now] dates the uploads
/// and also seeds the order of Divine's sounds, so their mix changes from day
/// to day but not from one rebuild to the next.
List<AudioEvent> rankForYouSounds({
  required List<AudioEvent> followed,
  required List<AudioEvent> divine,
  required DateTime now,
}) {
  final nowSeconds = now.millisecondsSinceEpoch / 1000;
  double recency(AudioEvent sound) {
    final ageDays = max(0, nowSeconds - sound.createdAt) / 86400;
    return 1 + pow(2, -ageDays / 3).toDouble();
  }

  // A person's newest sound counts in full and each older one a tenth less,
  // ties going to the one listed first.
  final newestFirst = followed.indexed.toList()
    ..sort((a, b) {
      final byAge = b.$2.createdAt.compareTo(a.$2.createdAt);
      return byAge != 0 ? byAge : a.$1.compareTo(b.$1);
    });
  final newerByPerson = <String, int>{};
  final followedScores = List<double>.filled(followed.length, 0);
  for (final (index, sound) in newestFirst) {
    final newer = newerByPerson[sound.pubkey] ?? 0;
    newerByPerson[sound.pubkey] = newer + 1;
    followedScores[index] = recency(sound) * pow(0.9, newer);
  }

  final day = DateTime.utc(now.year, now.month, now.day);
  final dailyDivine = List.of(divine)
    ..shuffle(Random(day.millisecondsSinceEpoch ~/ 86400000));
  final scored = [
    for (final (index, sound) in followed.indexed)
      (sound: sound, score: followedScores[index]),
    for (final (index, sound) in dailyDivine.indexed)
      (sound: sound, score: 1.8 * pow(0.97, index)),
  ];
  // List.sort is not stable, so ties keep their input order by index.
  final indexed = scored.indexed.toList()
    ..sort((a, b) {
      final byScore = b.$2.score.compareTo(a.$2.score);
      return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
    });
  return [for (final (_, entry) in indexed) entry.sound];
}
