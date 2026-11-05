// ABOUTME: One freely licensed sound the importer may publish, with the credit
// ABOUTME: its licence asks for. Serialised into the work directory's catalog.

/// What a sound is, for the picker's Music and Effects filter.
enum SoundKind {
  /// Shows under Music.
  music,

  /// Shows under Effects.
  sfx,

  /// Pure speech: only under All, so it gets no kind tag.
  speech;

  /// The `t` tag the app reads as this kind, or null for [speech].
  String? get kindTag => switch (this) {
    music => 'music',
    sfx => 'sfx',
    speech => null,
  };
}

/// A licence the importer accepts, as the event's `license` and
/// `license_url` tags name it.
class SoundLicense {
  const SoundLicense({
    required this.name,
    required this.url,
    required this.requiresAttribution,
  });

  /// Creative Commons Zero: no credit needed, given anyway.
  static const cc0 = SoundLicense(
    name: 'CC0 1.0',
    url: 'https://creativecommons.org/publicdomain/zero/1.0/',
    requiresAttribution: false,
  );

  /// Creative Commons Attribution 4.0.
  static const ccBy4 = SoundLicense(
    name: 'CC BY 4.0',
    url: 'https://creativecommons.org/licenses/by/4.0/',
    requiresAttribution: true,
  );

  static const List<SoundLicense> _known = [cc0, ccBy4];

  final String name;
  final String url;

  /// Whether sharing the sound, or a work made with it, must credit its
  /// creator and say what was changed.
  final bool requiresAttribution;

  /// The known licence with [url].
  ///
  /// Throws a [FormatException] for any other licence, so a catalog edited
  /// by hand cannot slip an unreviewed one in.
  static SoundLicense fromUrl(String url) => _known.firstWhere(
    (license) => license.url == url,
    orElse: () => throw FormatException('Unknown licence', url),
  );
}

/// A sound found in a source listing, before anything is downloaded.
class SoundCandidate {
  const SoundCandidate({
    required this.id,
    required this.downloadUrl,
    required this.sourcePage,
    required this.title,
    required this.kind,
    required this.creatorName,
    required this.creatorUrl,
    required this.license,
    this.tags = const [],
    this.isrc,
    this.summary,
    this.creditLines = const [],
    this.expectedBytes,
  });

  factory SoundCandidate.fromJson(Map<String, dynamic> json) {
    return SoundCandidate(
      id: json['id'] as String,
      downloadUrl: json['downloadUrl'] as String,
      sourcePage: json['sourcePage'] as String,
      title: json['title'] as String,
      kind: SoundKind.values.byName(json['kind'] as String),
      creatorName: json['creatorName'] as String,
      creatorUrl: json['creatorUrl'] as String,
      license: SoundLicense.fromUrl(json['licenseUrl'] as String),
      tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
      isrc: json['isrc'] as String?,
      summary: json['summary'] as String?,
      creditLines: (json['creditLines'] as List<dynamic>? ?? const [])
          .cast<String>(),
      expectedBytes: json['expectedBytes'] as int?,
    );
  }

  /// Stable across runs, so the work directory can resume: the source and
  /// its own identifier, such as `incompetech:USUAN2600004`.
  final String id;

  /// Where the original file is downloaded from.
  final String downloadUrl;

  /// The page that shows where the sound came from and under which
  /// licence; published as the `source` tag.
  final String sourcePage;

  final String title;
  final SoundKind kind;
  final String creatorName;
  final String creatorUrl;
  final SoundLicense license;

  /// Search tags besides the kind tag, lowercase and without spaces.
  final List<String> tags;

  /// The recording's ISRC, for music that has one.
  final String? isrc;

  /// A short description, published as NIP-94's `summary`.
  final String? summary;

  /// The credit exactly as the creator asks for it. Replaces the generic
  /// title, creator and licence lines of the event's `content` when set.
  final List<String> creditLines;

  /// The original file's size, when the listing says, for dry runs.
  final int? expectedBytes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'downloadUrl': downloadUrl,
    'sourcePage': sourcePage,
    'title': title,
    'kind': kind.name,
    'creatorName': creatorName,
    'creatorUrl': creatorUrl,
    'licenseUrl': license.url,
    if (tags.isNotEmpty) 'tags': tags,
    'isrc': ?isrc,
    'summary': ?summary,
    if (creditLines.isNotEmpty) 'creditLines': creditLines,
    'expectedBytes': ?expectedBytes,
  };
}

/// [raw] as a search tag: lowercase, without spaces or punctuation, so
/// `Drum Kit` and `drum kit` become the same `drumkit`.
String normalizeSearchTag(String raw) =>
    raw.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// [tags] normalised, without empty ones and duplicates, in order.
List<String> normalizeSearchTags(Iterable<String> tags) {
  final seen = <String>{};
  return [
    for (final tag in tags.map(normalizeSearchTag))
      if (tag.isNotEmpty && seen.add(tag)) tag,
  ];
}
