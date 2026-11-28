// ABOUTME: Tests for the song catalog repository: which storefront it reads,
// ABOUTME: how a song becomes a sound, and what it never sends to the catalog.

import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:sounds_repository/sounds_repository.dart';
import 'package:test/test.dart';

class _MockAppleMusicApiClient extends Mock implements AppleMusicApiClient {}

const _nightDrive = AppleMusicSong(
  id: '1',
  name: 'Night Drive',
  artistName: 'The Paper Kites Club',
  url: 'https://music.apple.com/us/song/1',
  previewUrl: 'https://audio-ssl.itunes.apple.com/preview-1.m4a',
  artworkUrlTemplate: 'https://is1-ssl.mzstatic.com/image/1/{w}x{h}bb.jpg',
  genreNames: ['Pop', 'Music'],
);

const _withoutPreview = AppleMusicSong(
  id: '2',
  name: 'Unreleased',
  artistName: 'Somebody',
  url: 'https://music.apple.com/us/song/2',
);

void main() {
  group(SongCatalogRepository, () {
    late _MockAppleMusicApiClient client;

    setUp(() {
      client = _MockAppleMusicApiClient();
    });

    void stubTopSongs(List<AppleMusicSong> songs) {
      when(
        () => client.fetchTopSongs(storefront: any(named: 'storefront')),
      ).thenAnswer((_) async => songs);
    }

    void stubSearch(List<AppleMusicSong> songs) {
      when(
        () => client.searchSongs(
          storefront: any(named: 'storefront'),
          term: any(named: 'term'),
        ),
      ).thenAnswer((_) async => songs);
    }

    group('storefrontFor', () {
      test('is the country code in lower case', () {
        expect(SongCatalogRepository.storefrontFor('AR'), equals('ar'));
        expect(SongCatalogRepository.storefrontFor(' gb '), equals('gb'));
      });

      test('falls back when the code names no country', () {
        for (final code in [null, '', '419', 'usa', 'u1']) {
          expect(
            SongCatalogRepository.storefrontFor(code),
            equals(SongCatalogRepository.fallbackStorefront),
            reason: 'for $code',
          );
        }
      });
    });

    group('fetchTrendingSongs', () {
      test("reads the top songs of the country's storefront", () async {
        stubTopSongs(const []);

        await SongCatalogRepository(
          client: client,
          countryCode: 'AR',
        ).fetchTrendingSongs();

        verify(() => client.fetchTopSongs(storefront: 'ar')).called(1);
      });

      test('reads the fallback storefront without a country', () async {
        stubTopSongs(const []);

        await SongCatalogRepository(client: client).fetchTrendingSongs();

        verify(() => client.fetchTopSongs(storefront: 'us')).called(1);
      });

      test('lists a song as a provider sound that plays its preview', () async {
        stubTopSongs(const [_nightDrive]);

        final sounds = await SongCatalogRepository(
          client: client,
        ).fetchTrendingSongs();

        expect(sounds, hasLength(1));
        final sound = sounds.single;
        expect(sound.id, equals('apple_music_1'));
        expect(sound.isExternalProviderSound, isTrue);
        expect(sound.attributionEventId, isNull);
        expect(sound.title, equals('Night Drive'));
        expect(sound.source, equals('The Paper Kites Club'));
        expect(sound.url, equals(_nightDrive.previewUrl));
        expect(sound.mimeType, equals('audio/mp4'));
        expect(sound.soundKind, equals(SoundKind.music));
        expect(
          sound.imageUrl,
          equals('https://is1-ssl.mzstatic.com/image/1/200x200bb.jpg'),
        );
        final external = sound.externalSource!;
        expect(external.provider, equals('apple_music'));
        expect(external.providerSoundId, equals('1'));
        expect(external.providerName, equals('Apple Music'));
        expect(external.creatorName, equals('The Paper Kites Club'));
        expect(external.sourceUrl, equals(_nightDrive.url));
        expect(external.previewUrl, equals(_nightDrive.previewUrl));
        expect(external.catalogTags, equals(['music', 'Pop', 'Music']));
      });

      test('gives a song terms that forbid reusing it', () async {
        stubTopSongs(const [_nightDrive]);

        final sounds = await SongCatalogRepository(
          client: client,
        ).fetchTrendingSongs();

        final license = sounds.single.externalSource!.license;
        expect(license.allowsDerivatives, isFalse);
        expect(license.allowsCommercialUse, isFalse);
        expect(license.name, equals('Apple Music preview'));
      });

      test('leaves out a song the catalog gives no preview for', () async {
        stubTopSongs(const [_withoutPreview, _nightDrive]);

        final sounds = await SongCatalogRepository(
          client: client,
        ).fetchTrendingSongs();

        expect(sounds.map((sound) => sound.id), equals(['apple_music_1']));
      });

      test('lists a song the chart repeats once', () async {
        stubTopSongs(const [_nightDrive, _nightDrive]);

        final sounds = await SongCatalogRepository(
          client: client,
        ).fetchTrendingSongs();

        expect(sounds, hasLength(1));
      });

      test('passes on a failed request', () async {
        when(
          () => client.fetchTopSongs(storefront: any(named: 'storefront')),
        ).thenThrow(
          const AppleMusicApiException('Apple Music request failed'),
        );

        await expectLater(
          SongCatalogRepository(client: client).fetchTrendingSongs(),
          throwsA(isA<AppleMusicApiException>()),
        );
      });
    });

    group('searchSongs', () {
      test('searches the storefront for the trimmed query', () async {
        stubSearch(const [_nightDrive]);

        final sounds = await SongCatalogRepository(
          client: client,
          countryCode: 'mx',
        ).searchSongs('  paper  ');

        expect(sounds.single.title, equals('Night Drive'));
        verify(
          () => client.searchSongs(storefront: 'mx', term: 'paper'),
        ).called(1);
      });

      test('answers a blank query without asking the catalog', () async {
        final sounds = await SongCatalogRepository(
          client: client,
        ).searchSongs('   ');

        expect(sounds, isEmpty);
        verifyNever(
          () => client.searchSongs(
            storefront: any(named: 'storefront'),
            term: any(named: 'term'),
          ),
        );
      });

      test('never sends a query holding a private key', () async {
        final repository = SongCatalogRepository(client: client);

        for (final query in [
          'nsec1qqqsyqcyq5rqwzqfpg9scrgwpugpzysnzs23v9ccrydpk8qarc0sexample',
          'my key NSEC1ABCDEF',
          'ncryptsec1qgg9947rlpvqu76pj5ecreduf9jxhselq2nae2kghhv',
          'nse​c1qqqsyqcyq5rqwzqfpg9',
        ]) {
          expect(
            await repository.searchSongs(query),
            isEmpty,
            reason: 'for $query',
          );
        }
        verifyNever(
          () => client.searchSongs(
            storefront: any(named: 'storefront'),
            term: any(named: 'term'),
          ),
        );
      });
    });
  });
}
