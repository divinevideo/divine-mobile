// ABOUTME: An area of a published video a viewer can tap: a sticker that opens
// ABOUTME: a page, profile, hashtag, sound, place or reply, or takes a vote.

import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:models/src/audio_event.dart';
import 'package:models/src/nostr_hex_utils.dart';
import 'package:text_sanitizer/text_sanitizer.dart';

/// What a tappable sticker on a video opens or takes a vote on.
enum VideoStickerKind {
  /// A web page.
  link,

  /// A profile, by its hex pubkey.
  mention,

  /// The feed of a hashtag.
  hashtag,

  /// The page of the credited sound, or of the video's own sound, the one
  /// its audio reference names, when the target is empty.
  sound,

  /// A place, by its full name such as "Zermatt, Wallis, Schweiz", which the
  /// viewer's map app searches for. The sticker keeps no coordinates.
  place,

  /// A countdown to a moment, by its Unix time in seconds. The Divine player
  /// shows the time left; a tap sets a reminder for when it ends.
  countdown,

  /// The comment or video this video replies to, by its hex event id.
  reply,

  /// A question with two to four answers a viewer votes on, by the hex id of
  /// its NIP-88 `kind:1068` poll event.
  poll,

  /// A poll with one correct answer, which a viewer sees once they answered.
  quiz,

  /// An emoji a viewer drags along a scale from 0 to 100 to rate a question,
  /// published as a poll of eleven steps.
  slider;

  /// Whether a viewer votes on the sticker rather than opening something.
  bool get isPoll => this == poll || this == quiz || this == slider;
}

/// A sticker on a published video that opens what it points to when tapped,
/// or takes a vote.
///
/// The area is the sticker as it stands on the video frame: its centre and
/// size as fractions of the frame's width and height, turned by [rotation]
/// around that centre. It holds still for as long as the sticker shows, from
/// [start] to [end] on the published video, which is why a sticker that moves
/// gets no area.
///
/// Published as a `sticker` tag of kind, target, `"cx cy w h"`, degrees,
/// start and end in milliseconds, style and the text the sticker shows, for
/// example `["sticker", "link", "https://divine.video/", "0.5 0.3 0.4 0.06",
/// "0", "1500", "4200", "light", "divine.video"]`. A missing start or end
/// means the sticker shows from the video's start or until its end; without a
/// style and text a viewer still gets the area, just not the sticker drawn
/// over it. A poll, quiz or slider needs both: without them it shows only as
/// it is in the frames.
class VideoStickerRegion extends Equatable {
  /// Creates the area of a tappable sticker.
  const VideoStickerRegion({
    required this.kind,
    required this.target,
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.start,
    this.end,
    this.style,
    this.label,
  });

  /// The name of the event tag a region is published in.
  static const String tagName = 'sticker';

  /// What a tap opens or votes on.
  final VideoStickerKind kind;

  /// The web address, hex pubkey or hashtag (without `#`) a tap opens; for a
  /// [VideoStickerKind.sound], the id of the credited sound's page (see
  /// [AudioEvent.soundPageId]), or empty for the video's own sound; for a
  /// [VideoStickerKind.place], the place's full name; for a
  /// [VideoStickerKind.countdown], the Unix time in seconds it counts down
  /// to; for a [VideoStickerKind.reply], the hex id of the comment or video
  /// it replies to; for a poll, quiz or slider, the hex id of its poll event,
  /// or empty before it is published.
  final String target;

  /// The sticker's centre, as a fraction of the frame's width.
  final double centerX;

  /// The sticker's centre, as a fraction of the frame's height.
  final double centerY;

  /// The sticker's width before it is turned, as a fraction of the frame's
  /// width.
  final double width;

  /// The sticker's height before it is turned, as a fraction of the frame's
  /// height.
  final double height;

  /// How far the sticker is turned clockwise around its centre, in radians.
  final double rotation;

  /// When the sticker appears on the published video; `null` from its start.
  final Duration? start;

  /// When the sticker disappears; `null` once the video ends.
  final Duration? end;

  /// The name of the look the sticker was drawn in, such as `light`.
  final String? style;

  /// The text the sticker shows: a link's title or domain, a name, or a
  /// hashtag as it was typed, without its `@` or `#`; for a sound, its title,
  /// artist and line of lyrics, one per line; a place's name; a countdown's
  /// title; for a reply, the name of whom it replies to and their comment,
  /// one per line; for a poll or a quiz, its question and then its answers,
  /// one per line; for a slider, its question and then its emoji.
  final String? label;

  /// The longest [label] a tag may carry.
  static const int maxLabelLength = 300;

  /// The longest full name of a place a tag may carry.
  static const int maxPlaceLength = 200;

  /// The moment a [VideoStickerKind.countdown] counts down to, or `null` for
  /// any other kind.
  DateTime? get countdownEnd {
    final seconds = kind == VideoStickerKind.countdown
        ? int.tryParse(target)
        : null;
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      seconds * Duration.millisecondsPerSecond,
      isUtc: true,
    );
  }

  /// The lines of [label], which a poll, quiz or slider shows: its question
  /// first, then its answers or its emoji.
  List<String> get labelLines => label?.split('\n') ?? const [];

  /// This region pointing at [target] instead, such as a poll's event id once
  /// the poll is published.
  VideoStickerRegion withTarget(String target) => VideoStickerRegion(
    kind: kind,
    target: target,
    centerX: centerX,
    centerY: centerY,
    width: width,
    height: height,
    rotation: rotation,
    start: start,
    end: end,
    style: style,
    label: label,
  );

  /// Whether the sticker shows at [position] of the published video.
  bool isShownAt(Duration position) {
    final start = this.start;
    final end = this.end;
    return (start == null || position >= start) &&
        (end == null || position < end);
  }

  /// Whether any of the sticker can lie on the frame, measured generously by
  /// the circle around it, however it is turned.
  bool get isOnFrame {
    final reach = width + height;
    return centerX + reach > 0 &&
        centerX - reach < 1 &&
        centerY + reach > 0 &&
        centerY - reach < 1;
  }

  /// The event tag this region is published in.
  List<String> toTag() {
    final tag = [
      tagName,
      kind.name,
      target,
      [centerX, centerY, width, height].map(_fraction).join(' '),
      _degrees(rotation),
      '${start?.inMilliseconds ?? ''}',
      '${end?.inMilliseconds ?? ''}',
      style ?? '',
      label ?? '',
    ];
    while (tag.last.isEmpty) {
      tag.removeLast();
    }
    return tag;
  }

  /// The region [tag] publishes, or `null` when it is no sticker tag or
  /// names something a viewer could not safely open, or is a poll, quiz or
  /// slider whose label lays out no vote.
  static VideoStickerRegion? fromTag(List<String> tag) {
    if (tag.length < 5 || tag[0] != tagName) return null;
    final kind = VideoStickerKind.values.asNameMap()[tag[1]];
    if (kind == null) return null;
    final target = _target(kind, tag[2]);
    if (target == null) return null;

    final area = tag[3].trim().split(RegExp(r'\s+')).map(double.tryParse);
    if (area.length != 4 || area.any((v) => v == null || !v.isFinite)) {
      return null;
    }
    final [centerX!, centerY!, width!, height!] = area.toList();
    if (width <= 0 || height <= 0 || width > 4 || height > 4) return null;

    final degrees = double.tryParse(tag[4].trim());
    if (degrees == null || !degrees.isFinite) return null;

    final start = _milliseconds(tag.elementAtOrNull(5));
    final end = _milliseconds(tag.elementAtOrNull(6));
    if (start == false || end == false) return null;
    if (start is Duration && end is Duration && end <= start) return null;

    final style = tag.elementAtOrNull(7)?.trim() ?? '';
    // Drawn as text, which an unpaired surrogate would break.
    final label = sanitizeUtf16(tag.elementAtOrNull(8)?.trim() ?? '');
    // A vote needs the question and what there is to pick, to lay out.
    if (kind.isPoll && !_isPollLabel(kind, label)) return null;
    final region = VideoStickerRegion(
      kind: kind,
      target: target,
      centerX: centerX,
      centerY: centerY,
      width: width,
      height: height,
      // Whole turns dropped first: a huge angle would overflow to infinity.
      rotation: degrees.remainder(360) * math.pi / 180,
      start: start is Duration ? start : null,
      end: end is Duration ? end : null,
      style: style.isEmpty ? null : style,
      label: label.isEmpty || label.length > maxLabelLength ? null : label,
    );
    // Off the frame, a huge centre would overflow once laid out.
    return region.isOnFrame ? region : null;
  }

  /// The regions among [tags], in order.
  static List<VideoStickerRegion> fromTags(Iterable<List<String>> tags) => [
    for (final tag in tags) ?fromTag(tag),
  ];

  /// The most answers a poll or a quiz can have.
  static const int maxPollOptions = 4;

  /// Whether [label] lays out a [kind] vote: a question and two to
  /// [maxPollOptions] answers, or for a slider a question and its emoji, each
  /// on a line of its own, within [maxLabelLength].
  static bool _isPollLabel(VideoStickerKind kind, String label) {
    final lines = label.split('\n');
    if (label.length > maxLabelLength ||
        lines.any((line) => line.trim().isEmpty)) {
      return false;
    }
    return kind == VideoStickerKind.slider
        ? lines.length == 2
        : lines.length >= 3 && lines.length <= maxPollOptions + 1;
  }

  /// [raw] as the target of a [kind] sticker, or `null` when it is not one:
  /// a link only to an http(s) page of a named host, a mention only to a
  /// pubkey, a hashtag only as one word, a sound only by a library or event
  /// id, and otherwise by nothing, meaning the video's own sound, a place
  /// only by a name on one line, a countdown only to a moment between 1970
  /// and the year 10000, a reply only to an event id, and a poll, quiz or
  /// slider by its event id, and otherwise by nothing, meaning no vote.
  static String? _target(VideoStickerKind kind, String raw) {
    final value = raw.trim();
    switch (kind) {
      case VideoStickerKind.link:
        final uri = Uri.tryParse(value);
        if (uri == null ||
            !(uri.isScheme('https') || uri.isScheme('http')) ||
            uri.host.isEmpty) {
          return null;
        }
        return uri.toString();
      case VideoStickerKind.mention:
        final pubkey = value.toLowerCase();
        return NostrHexUtils.isValidPubkey(pubkey) ? pubkey : null;
      case VideoStickerKind.hashtag:
        final hashtag = value.startsWith('#') ? value.substring(1) : value;
        if (hashtag.isEmpty ||
            hashtag.length > 100 ||
            hashtag.contains(RegExp(r'[\s#/?]'))) {
          return null;
        }
        return sanitizeUtf16(hashtag.toLowerCase());
      case VideoStickerKind.sound:
        // The credited sound's own page, or none for the video's own sound.
        if (RegExp(
          '^${AudioEvent.bundledMarker}_[a-z0-9_]+\$',
        ).hasMatch(value)) {
          return value;
        }
        final eventId = value.toLowerCase();
        return NostrHexUtils.isValidEventId(eventId) ? eventId : '';
      case VideoStickerKind.place:
        // Handed to a map app's search, and drawn nowhere else.
        if (value.isEmpty ||
            value.length > maxPlaceLength ||
            value.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
          return null;
        }
        return sanitizeUtf16(value);
      case VideoStickerKind.countdown:
        final seconds = int.tryParse(value);
        if (seconds == null || seconds <= 0 || seconds >= _maxCountdownEnd) {
          return null;
        }
        return '$seconds';
      case VideoStickerKind.reply:
        final eventId = value.toLowerCase();
        return NostrHexUtils.isValidEventId(eventId) ? eventId : null;
      case VideoStickerKind.poll ||
          VideoStickerKind.quiz ||
          VideoStickerKind.slider:
        final eventId = value.toLowerCase();
        return NostrHexUtils.isValidEventId(eventId) ? eventId : '';
    }
  }

  /// The start of the year 10000 in Unix seconds, past which a date no longer
  /// fits a four-digit year.
  static const int _maxCountdownEnd = 253402300800;

  /// [raw] as a time on the video: `null` when absent or empty, `false` when
  /// it is no whole number of milliseconds of zero or more.
  static Object? _milliseconds(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final milliseconds = int.tryParse(value);
    if (milliseconds == null || milliseconds < 0) return false;
    return Duration(milliseconds: milliseconds);
  }

  /// [value] to a ten-thousandth, about a tenth of a pixel across a 1080p
  /// frame, without trailing zeros.
  static String _fraction(double value) => _trimmed(value.toStringAsFixed(4));

  static String _degrees(double radians) =>
      _trimmed((radians * 180 / math.pi).toStringAsFixed(1));

  static String _trimmed(String fixed) {
    if (!fixed.contains('.')) return fixed;
    final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
    return trimmed == '-0' ? '0' : trimmed;
  }

  @override
  List<Object?> get props => [
    kind,
    target,
    centerX,
    centerY,
    width,
    height,
    rotation,
    start,
    end,
    style,
    label,
  ];
}
