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

  /// Whether this line credits [sound].
  ///
  /// Matched by the sound's title rather than the whole line: the event a
  /// video references can name the creator, licence or source differently
  /// from the sound that was credited when the video was published.
  bool credits(AudioEvent sound) {
    final title = _oneLine(sound.title);
    if (title == null) return line == soundCreditLine(sound);
    return work == title || work.startsWith('$title – ');
  }

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
/// `♪ <title> – <creator> <source link>, <licence> <licence link> (edited)`,
/// leaving out what the sound does not say.
///
/// The source link (CC BY 4.0 §3(a)(1)(A)(v)) is taken only from the app's
/// own manifest or the sound proxy, never from a Nostr event: the poster
/// signs it without seeing it, and a published sound is reached through the
/// video's `e … audio` reference anyway.
String? soundCreditLine(AudioEvent sound) {
  if (!sound.requiresAttribution) return null;
  final external = sound.externalSource;
  final work = [
    [
      sound.title,
      sound.creatorName ??
          external?.creatorName ??
          (sound.isBundled ? sound.source : null),
    ].map(_oneLine).whereType<String>().join(' – '),
    _httpsLink(sound.sourceUrl ?? external?.sourceUrl),
  ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
  final terms = [
    sound.licenseName ?? external?.license.name,
    _creativeCommonsLink(sound.licenseUrl ?? external?.license.url),
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
  if (split == -1) return SoundCredit(line: line, work: _withoutLink(credit));
  final license = credit
      .substring(split + 2)
      .split(' ')
      .where((word) => !word.startsWith('http'))
      .join(' ')
      .trim();
  return SoundCredit(
    line: line,
    work: _withoutLink(credit.substring(0, split)),
    license: license.isEmpty ? null : license,
  );
}

/// [work] without the source link that ends it.
String _withoutLink(String work) {
  final space = work.lastIndexOf(' ');
  return space != -1 && work.startsWith('https://', space + 1)
      ? work.substring(0, space)
      : work;
}

/// [url] as an HTTPS link when it points at a Creative Commons licence, else
/// null. Older licence links use http, so those are upgraded.
///
/// The link comes from the sound's event, written by whoever published the
/// sound, and is signed into the poster's video without them seeing it, so
/// any other link is left out.
String? _creativeCommonsLink(String? url) {
  final uri = Uri.tryParse(url?.trim() ?? '');
  if (uri == null || !const {'https', 'http'}.contains(uri.scheme)) {
    return null;
  }
  return const {
        'creativecommons.org',
        'www.creativecommons.org',
      }.contains(uri.host)
      ? uri.replace(scheme: 'https', port: 443).toString()
      : null;
}

/// [url] when it is an HTTPS link, else null.
String? _httpsLink(String? url) {
  final uri = Uri.tryParse(url?.trim() ?? '');
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
      ? uri.toString()
      : null;
}

String? _oneLine(String? value) {
  final text = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text == null || text.isEmpty ? null : text;
}
