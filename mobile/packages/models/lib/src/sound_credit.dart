// ABOUTME: The credit line a video carries in its content when its sound's
// ABOUTME: licence asks for attribution; shared by the publisher and readers.

import 'package:meta/meta.dart';
import 'package:models/src/audio_event.dart';
import 'package:models/src/video_attribution.dart';

/// Opens the line, so a reader sees at a glance what it credits.
const soundCreditPrefix = '♪ ';

/// Closes the line. A video uses an excerpt of its sound, mixed into its own
/// audio, which an Attribution licence asks to say (CC BY 4.0
/// §3(a)(1)(B)). English like every published credit: the event must not
/// depend on the poster's language.
const soundCreditEditedMark = '(edited)';

/// Matches the credit line at the end of a video's content, separated from
/// the caption by a blank line or standing alone.
///
/// Anchored and bounded by the prefix and the mark, so a caption that merely
/// mentions a song is not mistaken for the credit.
final soundCreditPattern = RegExp(
  '(?:^|\\n\\n)(${RegExp.escape(soundCreditPrefix)}[^\\n]*'
  '${RegExp.escape(soundCreditEditedMark)})\\s*\$',
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

/// [content] with the credit [line] after it, separated by a blank line.
///
/// Goes before the Inspired By reference, which readers expect last.
String withSoundCreditLine(String content, String? line) {
  if (line == null || line.isEmpty) return content;
  return content.isEmpty ? line : '$content\n\n$line';
}

/// The sound credit at the end of [content], before any Inspired By line,
/// or `null` when there is none.
SoundCredit? soundCreditFromContent(String content) {
  final line = soundCreditPattern
      .firstMatch(stripInspiredByAttribution(content))
      ?.group(1);
  if (line == null) return null;

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

/// [content] without the sound credit at its end. Run it after
/// `stripInspiredByAttribution`, which removes the line that follows it.
String stripSoundCredit(String content) {
  final match = soundCreditPattern.firstMatch(content);
  if (match == null) return content;
  return content.substring(0, match.start).trimRight();
}

String? _oneLine(String? value) {
  final text = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text == null || text.isEmpty ? null : text;
}
