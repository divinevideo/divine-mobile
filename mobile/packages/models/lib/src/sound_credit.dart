// ABOUTME: The credit lines a video carries in its content for the sounds
// ABOUTME: whose licences ask for attribution; shared by publisher and readers.

import 'package:meta/meta.dart';
import 'package:models/src/audio_event.dart';
import 'package:models/src/video_attribution.dart';

/// Opens a credit line, so a reader sees at a glance what it credits.
const soundCreditPrefix = '♪ ';

/// Closes a credit line. A video uses an excerpt of its sound, mixed into its
/// own audio, which an Attribution licence asks to say (CC BY 4.0
/// §3(a)(1)(B)). English like every published credit: the event must not
/// depend on the poster's language.
const soundCreditEditedMark = '(edited)';

final _creditLine =
    '${RegExp.escape(soundCreditPrefix)}[^\\n]*'
    '${RegExp.escape(soundCreditEditedMark)}';

/// Matches the credit lines at the end of a video's content: one line per
/// credited sound, separated from the caption by a blank line or standing
/// alone.
///
/// Anchored and bounded by the prefix and the mark, so a caption that merely
/// mentions a song is not mistaken for a credit.
final soundCreditPattern = RegExp(
  '(?:^|\\n\\n)((?:$_creditLine\\n)*$_creditLine)\\s*\$',
);

/// A sound credit read back from a video's content.
@immutable
class SoundCredit {
  const SoundCredit({required this.line, required this.work, this.license});

  /// The line exactly as published.
  final String line;

  /// The credited work: its title and creator, such as
  /// `Monkeys Spinning Monkeys – Kevin MacLeod (incompetech.com)`.
  final String work;

  /// The licence's name, such as `CC BY 4.0`.
  final String? license;

  @override
  bool operator ==(Object other) =>
      other is SoundCredit &&
      other.line == line &&
      other.work == work &&
      other.license == license;

  @override
  int get hashCode => Object.hash(line, work, license);
}

/// The line crediting [sound] in a video's content, or `null` when its
/// licence asks for no credit.
///
/// `♪ <title> – <creator>, <licence> <licence link> (edited)`, leaving out
/// what the sound does not say.
String? soundCreditLine(AudioEvent sound) {
  if (!sound.requiresAttribution) return null;
  final external = sound.externalSource;
  final work = [
    sound.title,
    sound.creatorName ??
        external?.creatorName ??
        (sound.isBundled ? sound.source : null),
  ].map(_oneLine).whereType<String>().join(' – ');
  final terms = [
    sound.licenseName ?? external?.license.name,
    sound.licenseUrl ?? external?.license.url,
  ].map(_oneLine).whereType<String>().join(' ');
  final credit = [work, terms].where((part) => part.isNotEmpty).join(', ');
  return '$soundCreditPrefix$credit $soundCreditEditedMark';
}

/// The lines crediting [sounds], in order, once each: a sound used twice in
/// one video is credited once.
List<String> soundCreditLines(Iterable<AudioEvent> sounds) => {
  for (final sound in sounds) ?soundCreditLine(sound),
}.toList();

/// [content] with the credit [lines] after it, one per line, separated from
/// it by a blank line.
///
/// Goes before the Inspired By reference, which readers expect last.
String withSoundCreditLines(String content, Iterable<String> lines) {
  final block = {...lines.where((line) => line.isNotEmpty)}.join('\n');
  if (block.isEmpty) return content;
  return content.isEmpty ? block : '$content\n\n$block';
}

/// The sound credits at the end of [content], before any Inspired By line,
/// in the order they were published. Empty when there are none.
List<SoundCredit> soundCreditsFromContent(String content) {
  final block = soundCreditPattern
      .firstMatch(stripInspiredByAttribution(content))
      ?.group(1);
  if (block == null) return const [];
  return [for (final line in block.split('\n')) _parseCredit(line)];
}

/// [content] without the sound credits at its end. Run it after
/// `stripInspiredByAttribution`, which removes the line that follows them.
String stripSoundCredit(String content) {
  final match = soundCreditPattern.firstMatch(content);
  if (match == null) return content;
  return content.substring(0, match.start).trimRight();
}

SoundCredit _parseCredit(String line) {
  final credit = line
      .substring(
        soundCreditPrefix.length,
        line.length - soundCreditEditedMark.length,
      )
      .trim();
  // The work may hold commas; the terms, a licence name and its link, are
  // whatever follows the last one.
  final split = credit.lastIndexOf(', ');
  if (split == -1) return SoundCredit(line: line, work: credit);
  final license = credit
      .substring(split + 2)
      .split(' ')
      .where((word) => !word.startsWith('http'))
      .join(' ')
      .trim();
  return SoundCredit(
    line: line,
    work: credit.substring(0, split),
    license: license.isEmpty ? null : license,
  );
}

String? _oneLine(String? value) {
  final text = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text == null || text.isEmpty ? null : text;
}
