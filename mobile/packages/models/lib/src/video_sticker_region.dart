// ABOUTME: An area of a published video a viewer can tap: a sticker that
// ABOUTME: opens a web page, a profile, a hashtag or a sound, and its tag.

import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:models/src/audio_event.dart';
import 'package:models/src/nostr_hex_utils.dart';
import 'package:text_sanitizer/text_sanitizer.dart';

/// What a tappable sticker on a video opens.
enum VideoStickerKind {
  /// A web page, opened in the browser.
  link,

  /// A profile, by its hex pubkey.
  mention,

  /// The feed of a hashtag.
  hashtag,

  /// The page of the video's own sound, the one its audio reference names.
  sound,
}

/// A sticker on a published video that opens what it points to when tapped.
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
/// over it.
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

  /// What a tap opens.
  final VideoStickerKind kind;

  /// The web address, hex pubkey or hashtag (without `#`) a tap opens; for a
  /// [VideoStickerKind.sound], the id of the credited sound's page (see
  /// [AudioEvent.soundPageId]), or empty for the video's own sound.
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
  /// artist and line of lyrics, one per line.
  final String? label;

  /// The longest [label] a tag may carry.
  static const int maxLabelLength = 300;

  /// Whether the sticker shows at [position] of the published video.
  bool isShownAt(Duration position) {
    final start = this.start;
    final end = this.end;
    return (start == null || position >= start) &&
        (end == null || position < end);
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
  /// names something a viewer could not safely open.
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
    return VideoStickerRegion(
      kind: kind,
      target: target,
      centerX: centerX,
      centerY: centerY,
      width: width,
      height: height,
      rotation: degrees * math.pi / 180,
      start: start is Duration ? start : null,
      end: end is Duration ? end : null,
      style: style.isEmpty ? null : style,
      label: label.isEmpty || label.length > maxLabelLength ? null : label,
    );
  }

  /// The regions among [tags], in order.
  static List<VideoStickerRegion> fromTags(Iterable<List<String>> tags) => [
    for (final tag in tags) ?fromTag(tag),
  ];

  /// [raw] as the target of a [kind] sticker, or `null` when it is not one:
  /// a link only to an http(s) page of a named host, a mention only to a
  /// pubkey, a hashtag only as one word, a sound only by a library or event
  /// id, and otherwise by nothing, meaning the video's own sound.
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
    }
  }

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
