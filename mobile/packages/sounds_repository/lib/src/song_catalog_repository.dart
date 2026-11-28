// ABOUTME: The song catalog behind the sound picker's Songs list: the songs
// ABOUTME: most played now and song search, as sounds the editor can add.

import 'package:models/models.dart'
    show AudioEvent, AudioExternalSource, AudioLicenseMetadata;
import 'package:sounds_repository/src/apple_music_api_client.dart';

/// Lists songs from the Apple Music catalog as sounds.
///
/// Each song is its catalog preview: a provider sound that plays the preview
/// file, credits the artist and links to the song's page. Its terms forbid
/// derivatives, so nothing made with one is offered for reuse.
class SongCatalogRepository {
  /// Creates a [SongCatalogRepository] reading the catalog of the country
  /// [countryCode] names, such as the device region's `US` or `ar`.
  SongCatalogRepository({
    required AppleMusicApiClient client,
    String? countryCode,
  }) : _client = client,
       storefront = storefrontFor(countryCode);

  /// The provider id a song's `AudioExternalSource` carries.
  static const provider = 'apple_music';

  /// The provider's name, as a credit shows it.
  static const providerName = 'Apple Music';

  /// The catalog read when the device names no country.
  static const fallbackStorefront = 'us';

  /// The side of a song's cover, in pixels: enough for a list row at three
  /// device pixels per logical one.
  static const artworkSize = 200;

  /// The terms a song preview comes under: no licence to reuse or adapt it.
  static final previewTerms = AudioLicenseMetadata(
    type: 'apple-music-preview',
    name: 'Apple Music preview',
    url: 'https://www.apple.com/legal/internet-services/itunes/',
    allowsCommercialUse: false,
    allowsDerivatives: false,
    requiresAttribution: false,
  );

  /// The catalog storefront for [countryCode]: the code in lower case, or
  /// [fallbackStorefront] when it is not a two-letter country code, as with
  /// a locale that names no country or a region such as `419`.
  static String storefrontFor(String? countryCode) {
    final code = countryCode?.trim().toLowerCase() ?? '';
    return _countryCode.hasMatch(code) ? code : fallbackStorefront;
  }

  static final _countryCode = RegExp(r'^[a-z]{2}$');
  static final _zeroWidth = RegExp('[​-‍⁠﻿]');

  final AppleMusicApiClient _client;

  /// The storefront whose catalog is read.
  final String storefront;

  /// The songs most played now, most played first.
  ///
  /// Throws [AppleMusicApiException] when the catalog cannot be reached.
  Future<List<AudioEvent>> fetchTrendingSongs() async =>
      _asSounds(await _client.fetchTopSongs(storefront: storefront));

  /// The songs matching [query], a title, an artist or both, best match
  /// first. Empty for a blank query, and for one holding a Nostr private key,
  /// which must never leave the device.
  ///
  /// Throws [AppleMusicApiException] when the catalog cannot be reached.
  Future<List<AudioEvent>> searchSongs(String query) async {
    final term = query.trim();
    if (term.isEmpty || _holdsPrivateKey(term)) return const [];
    return _asSounds(
      await _client.searchSongs(storefront: storefront, term: term),
    );
  }

  bool _holdsPrivateKey(String text) {
    final compact = text.replaceAll(_zeroWidth, '').toLowerCase();
    return compact.contains('nsec1') || compact.contains('ncryptsec1');
  }

  /// [songs] as sounds, once each, without those the catalog gives no
  /// preview for: there is nothing of them to play or to add.
  List<AudioEvent> _asSounds(List<AppleMusicSong> songs) {
    final listed = <String>{};
    return [
      for (final song in songs)
        if (song.previewUrl case final previewUrl? when listed.add(song.id))
          AudioEvent(
            id: '${provider}_${song.id}',
            pubkey: AudioEvent.externalProviderMarker,
            createdAt: 0,
            url: previewUrl,
            mimeType: 'audio/mp4',
            title: song.name,
            source: song.artistName,
            imageUrl: song.artworkUrl(artworkSize),
            publicTags: const ['music'],
            externalSource: AudioExternalSource(
              provider: provider,
              providerSoundId: song.id,
              providerName: providerName,
              creatorName: song.artistName,
              sourceUrl: song.url,
              previewUrl: previewUrl,
              catalogTags: ['music', ...song.genreNames],
              license: previewTerms,
            ),
          ),
    ];
  }
}
