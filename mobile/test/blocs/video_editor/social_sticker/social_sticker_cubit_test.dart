// ABOUTME: Tests the social sticker cubit: who a mention may name, the typed
// ABOUTME: hashtag and its limit, the link, and the credited sound and design.

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/blocs/video_editor/social_sticker/social_sticker_cubit.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

const _pubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

UserProfile _profile({String pubkey = _pubkey}) => UserProfile(
  pubkey: pubkey,
  name: 'alice',
  rawData: const {},
  createdAt: DateTime(2026),
  eventId: 'event',
);

void main() {
  group(SocialStickerCubit, () {
    late _MockContentBlocklistRepository blocklistRepository;

    setUp(() {
      blocklistRepository = _MockContentBlocklistRepository();
      when(() => blocklistRepository.isBlocked(any())).thenReturn(false);
      when(() => blocklistRepository.hasBlockedUs(any())).thenReturn(false);
      when(() => blocklistRepository.hasMutedUs(any())).thenReturn(false);
    });

    SocialStickerCubit build(
      SocialStickerData initial, {
      Set<String> otherHashtags = const {},
      List<SocialStickerData> soundChoices = const [],
    }) => SocialStickerCubit(
      initial: initial,
      blocklistRepository: blocklistRepository,
      otherHashtags: otherHashtags,
      soundChoices: soundChoices,
    );

    group('initial state', () {
      test('starts a mention of a blocked person without them', () {
        when(() => blocklistRepository.hasMutedUs(_pubkey)).thenReturn(true);

        final cubit = build(
          const SocialStickerData(
            kind: SocialStickerKind.mention,
            style: InfoStickerStyle.neon,
            pubkey: _pubkey,
            name: 'alice',
          ),
        );
        addTearDown(cubit.close);

        expect(cubit.state.personBlocked, isTrue);
        expect(cubit.state.data.pubkey, isNull);
        expect(cubit.state.data.style, equals(InfoStickerStyle.neon));
        expect(cubit.state.canConfirm, isFalse);
      });
    });

    group('personPicked', () {
      blocTest<SocialStickerCubit, SocialStickerState>(
        'mentions the person by their handle',
        build: () =>
            build(const SocialStickerData(kind: SocialStickerKind.mention)),
        act: (cubit) => cubit.personPicked(_profile()),
        expect: () => [
          isA<SocialStickerState>()
              .having((s) => s.data.pubkey, 'pubkey', _pubkey)
              .having((s) => s.data.name, 'name', 'alice')
              .having((s) => s.canConfirm, 'canConfirm', isTrue),
        ],
      );

      blocTest<SocialStickerCubit, SocialStickerState>(
        'keeps the sticker and flags a person the creator blocked',
        setUp: () =>
            when(() => blocklistRepository.isBlocked(_pubkey)).thenReturn(true),
        build: () =>
            build(const SocialStickerData(kind: SocialStickerKind.mention)),
        act: (cubit) => cubit.personPicked(_profile()),
        expect: () => [
          const SocialStickerState(
            data: SocialStickerData(kind: SocialStickerKind.mention),
            personBlocked: true,
          ),
        ],
      );
    });

    group('hashtagChanged', () {
      blocTest<SocialStickerCubit, SocialStickerState>(
        'keeps the hashtag the way it would be published',
        build: () =>
            build(const SocialStickerData(kind: SocialStickerKind.hashtag)),
        act: (cubit) => cubit.hashtagChanged('SummerVibes'),
        expect: () => [
          isA<SocialStickerState>().having(
            (s) => s.data.hashtag,
            'hashtag',
            'summervibes',
          ),
        ],
      );

      final fullPost = {for (var i = 0; i < 10; i++) 'tag$i'};

      blocTest<SocialStickerCubit, SocialStickerState>(
        'cannot add an eleventh hashtag to the post',
        build: () => build(
          const SocialStickerData(kind: SocialStickerKind.hashtag),
          otherHashtags: fullPost,
        ),
        act: (cubit) => cubit.hashtagChanged('summer'),
        verify: (cubit) {
          expect(cubit.state.isOverHashtagLimit, isTrue);
          expect(cubit.state.canConfirm, isFalse);
        },
      );

      blocTest<SocialStickerCubit, SocialStickerState>(
        'can show a hashtag the full post carries already',
        build: () => build(
          const SocialStickerData(kind: SocialStickerKind.hashtag),
          otherHashtags: fullPost,
        ),
        act: (cubit) => cubit.hashtagChanged('tag3'),
        verify: (cubit) => expect(cubit.state.canConfirm, isTrue),
      );
    });

    group('linkChanged', () {
      blocTest<SocialStickerCubit, SocialStickerState>(
        'points the link to the typed address',
        build: () =>
            build(const SocialStickerData(kind: SocialStickerKind.link)),
        act: (cubit) => cubit.linkChanged(url: 'divine.video', title: ''),
        verify: (cubit) {
          expect(cubit.state.data.url, equals('https://divine.video'));
          expect(cubit.state.canConfirm, isTrue);
        },
      );

      blocTest<SocialStickerCubit, SocialStickerState>(
        'cannot place text that is no web address',
        build: () =>
            build(const SocialStickerData(kind: SocialStickerKind.link)),
        act: (cubit) => cubit.linkChanged(url: 'not an address', title: 'x'),
        verify: (cubit) => expect(cubit.state.canConfirm, isFalse),
      );
    });

    group('soundPicked', () {
      const song = SocialStickerData(
        kind: SocialStickerKind.soundCredit,
        soundTitle: 'Song',
        soundArtist: 'Artist',
      );
      const other = SocialStickerData(
        kind: SocialStickerKind.soundCredit,
        soundTitle: 'Other',
        soundArtist: 'Band',
      );

      blocTest<SocialStickerCubit, SocialStickerState>(
        'drops the artist and page id of the sound it credited before',
        build: () => build(
          song.copyWith(),
          soundChoices: const [
            SocialStickerData(
              kind: SocialStickerKind.soundCredit,
              soundTitle: 'Song',
              soundArtist: 'Artist',
              soundId: 'bundled_song',
            ),
            SocialStickerData(
              kind: SocialStickerKind.soundCredit,
              soundTitle: 'Untitled',
            ),
          ],
        ),
        act: (cubit) => cubit.soundPicked(
          const SocialStickerData(
            kind: SocialStickerKind.soundCredit,
            soundTitle: 'Untitled',
          ),
        ),
        expect: () => [
          isA<SocialStickerState>()
              .having((s) => s.data.soundTitle, 'soundTitle', 'Untitled')
              .having((s) => s.data.soundArtist, 'soundArtist', isNull)
              .having((s) => s.data.soundId, 'soundId', isNull),
        ],
      );

      test('keeps the credited sound a choice when it left the video', () {
        final cubit = build(song, soundChoices: const [other]);
        addTearDown(cubit.close);

        expect(cubit.state.soundChoices, equals(const [song, other]));
      });

      blocTest<SocialStickerCubit, SocialStickerState>(
        'credits another sound in the same design with the same lyrics',
        build: () => build(
          song.copyWith(
            soundDesign: SocialStickerSoundDesign.vinyl,
            lyric: 'A line',
          ),
          soundChoices: const [song, other],
        ),
        act: (cubit) => cubit.soundPicked(other),
        expect: () => [
          isA<SocialStickerState>().having(
            (s) => s.data,
            'data',
            other.copyWith(
              soundDesign: SocialStickerSoundDesign.vinyl,
              lyric: 'A line',
            ),
          ),
        ],
      );
    });

    group('lyricChanged', () {
      blocTest<SocialStickerCubit, SocialStickerState>(
        'adds a line of lyrics and drops it again when cleared',
        build: () => build(
          const SocialStickerData(
            kind: SocialStickerKind.soundCredit,
            soundTitle: 'Song',
            soundArtist: 'Artist',
          ),
        ),
        act: (cubit) => cubit
          ..lyricChanged('A line ')
          ..lyricChanged(''),
        expect: () => [
          isA<SocialStickerState>().having(
            (s) => s.data.lyric,
            'lyric',
            'A line',
          ),
          isA<SocialStickerState>().having((s) => s.data.lyric, 'lyric', null),
        ],
      );
    });
  });
}
