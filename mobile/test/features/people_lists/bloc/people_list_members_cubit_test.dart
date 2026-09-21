import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_list_members_cubit.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

// Full-length 64-char pubkeys — never truncate.
final String _quiet = 'a' * 64;
final String _busy = 'b' * 64;
final String _unknown = 'c' * 64;
final String _busiest = 'd' * 64;

UserProfileFound _found(
  String pubkey, {
  required int videos,
  double loops = 0,
}) {
  return UserProfileFound(
    profile: UserProfileData(pubkey: pubkey),
    // videoCount deliberately exceeds the vertical count: the extra are
    // horizontal videos the grid cannot render, so nothing should count them.
    stats: ProfileStatsData(
      videoCount: videos + 10,
      reactionCount: 0,
      verticalVideos: videos,
    ),
    engagement: ProfileEngagementData(
      totalReactions: 0,
      totalLoops: loops,
      totalViews: 0,
    ),
  );
}

void main() {
  group(PeopleListMembersCubit, () {
    late _MockProfileRepository profileRepository;

    setUp(() {
      profileRepository = _MockProfileRepository();
    });

    group('load', () {
      test('ranks members by video count, most first', () async {
        when(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).thenAnswer(
          (_) async => BulkProfilesResponse(
            profiles: {
              _quiet: _found(_quiet, videos: 2, loops: 10),
              _busy: _found(_busy, videos: 40, loops: 1000),
              _busiest: _found(_busiest, videos: 90, loops: 5000),
            },
          ),
        );
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          pubkeys: [_quiet, _busy, _busiest],
        );
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, equals(PeopleListMembersStatus.success));
        expect(
          cubit.state.members.map((member) => member.pubkey),
          equals([_busiest, _busy, _quiet]),
        );
        expect(cubit.state.totalVideos, equals(132));
        expect(cubit.state.totalLoops, equals(6010));
      });

      test(
        'keeps members without stats after the ranked ones, in list order',
        () async {
          when(
            () => profileRepository.getBulkProfilesFromApi(any()),
          ).thenAnswer(
            (_) async => BulkProfilesResponse(
              profiles: {_busy: _found(_busy, videos: 7)},
            ),
          );
          final cubit = PeopleListMembersCubit(
            profileRepository: profileRepository,
            pubkeys: [_unknown, _quiet, _busy],
          );
          addTearDown(cubit.close);

          await cubit.load();

          expect(
            cubit.state.members.map((member) => member.pubkey),
            equals([_busy, _unknown, _quiet]),
          );
          expect(cubit.state.members.last.hasStats, isFalse);
          expect(cubit.state.totalVideos, equals(7));
        },
      );

      test(
        'reports the list order without stats when there is no repository',
        () async {
          final cubit = PeopleListMembersCubit(
            profileRepository: null,
            pubkeys: [_busy, _quiet],
          );
          addTearDown(cubit.close);

          await cubit.load();

          expect(cubit.state.status, equals(PeopleListMembersStatus.success));
          expect(
            cubit.state.members.map((member) => member.pubkey),
            equals([_busy, _quiet]),
          );
          expect(cubit.state.totalVideos, isNull);
          expect(cubit.state.totalLoops, isNull);
        },
      );

      test('pages the sampled members a hundred at a time, capped', () async {
        when(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).thenAnswer((_) async => const BulkProfilesResponse(profiles: {}));
        final pubkeys = [
          for (var i = 0; i < kPeopleListStatsMemberCap + 50; i++)
            i.toRadixString(16).padLeft(64, '0'),
        ];
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          pubkeys: pubkeys,
        );
        addTearDown(cubit.close);

        await cubit.load();

        final pages = verify(
          () => profileRepository.getBulkProfilesFromApi(captureAny()),
        ).captured.cast<List<String>>();
        expect(
          pages,
          hasLength(kPeopleListStatsMemberCap ~/ kPeopleListStatsPageSize),
        );
        expect(
          pages.every((page) => page.length == kPeopleListStatsPageSize),
          isTrue,
        );
        expect(pages.first.first, equals(pubkeys.first));
        // Members past the cap are still in the roster, unranked.
        expect(cubit.state.members, hasLength(pubkeys.length));
      });

      test('stops paging when Funnelcake is not configured', () async {
        when(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).thenAnswer((_) async => null);
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          pubkeys: [
            for (var i = 0; i < kPeopleListStatsPageSize * 2; i++)
              i.toRadixString(16).padLeft(64, '0'),
          ],
        );
        addTearDown(cubit.close);

        await cubit.load();

        verify(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).called(1);
        expect(cubit.state.status, equals(PeopleListMembersStatus.success));
        expect(cubit.state.totalVideos, isNull);
      });

      test('counts vertical videos and ignores horizontal ones', () async {
        when(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).thenAnswer(
          (_) async => BulkProfilesResponse(
            profiles: {
              _busy: UserProfileFound(
                profile: UserProfileData(pubkey: _busy),
                stats: const ProfileStatsData(
                  videoCount: 9,
                  reactionCount: 0,
                  verticalVideos: 2,
                ),
              ),
            },
          ),
        );
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          pubkeys: [_busy],
        );
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.totalVideos, equals(2));
        expect(cubit.state.members.single.videoCount, equals(2));
      });

      test('keeps the ranking but shows no totals when a page fails', () async {
        var calls = 0;
        when(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            return BulkProfilesResponse(
              profiles: {_busy: _found(_busy, videos: 3)},
            );
          }
          throw const FunnelcakeException('down');
        });
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          pubkeys: [
            _quiet,
            _busy,
            for (var i = 0; i < kPeopleListStatsPageSize; i++)
              i.toRadixString(16).padLeft(64, '0'),
          ],
        );
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, equals(PeopleListMembersStatus.failure));
        expect(cubit.state.members.first.pubkey, equals(_busy));
        expect(cubit.state.members.first.videoCount, equals(3));
        // The first page's sum is not the list's total.
        expect(cubit.state.totalVideos, isNull);
        expect(cubit.state.totalLoops, isNull);
      });

      test('shows no totals for a list past the member cap', () async {
        when(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).thenAnswer((invocation) async {
          final page = invocation.positionalArguments.single as List<String>;
          return BulkProfilesResponse(
            profiles: {
              for (final pubkey in page)
                pubkey: _found(pubkey, videos: 1, loops: 5),
            },
          );
        });
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          pubkeys: [
            for (var i = 0; i < kPeopleListStatsMemberCap + 1; i++)
              i.toRadixString(16).padLeft(64, '0'),
          ],
        );
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, equals(PeopleListMembersStatus.success));
        // The sampled members are still ranked; only the totals are withheld.
        expect(cubit.state.members.first.videoCount, equals(1));
        expect(cubit.state.members.last.hasStats, isFalse);
        expect(cubit.state.totalVideos, isNull);
        expect(cubit.state.totalLoops, isNull);
      });

      test('totals a list of exactly the member cap', () async {
        when(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).thenAnswer((invocation) async {
          final page = invocation.positionalArguments.single as List<String>;
          return BulkProfilesResponse(
            profiles: {
              for (final pubkey in page)
                pubkey: _found(pubkey, videos: 1, loops: 5),
            },
          );
        });
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          pubkeys: [
            for (var i = 0; i < kPeopleListStatsMemberCap; i++)
              i.toRadixString(16).padLeft(64, '0'),
          ],
        );
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.totalVideos, equals(kPeopleListStatsMemberCap));
        expect(
          cubit.state.totalLoops,
          equals(kPeopleListStatsMemberCap * 5),
        );
      });

      test('leaves loops unknown for a member without engagement', () async {
        when(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).thenAnswer(
          (_) async => BulkProfilesResponse(
            profiles: {
              _quiet: _found(_quiet, videos: 2, loops: 10),
              _busy: UserProfileFound(
                profile: UserProfileData(pubkey: _busy),
                stats: const ProfileStatsData(
                  videoCount: 4,
                  reactionCount: 0,
                  verticalVideos: 4,
                ),
              ),
            },
          ),
        );
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          pubkeys: [_quiet, _busy],
        );
        addTearDown(cubit.close);

        await cubit.load();

        final busy = cubit.state.members.first;
        expect(busy.pubkey, equals(_busy));
        expect(busy.videoCount, equals(4));
        expect(busy.totalLoops, isNull);
        // Videos are all known, so that total stands; ten loops plus an
        // unknown is not a loop total.
        expect(cubit.state.totalVideos, equals(6));
        expect(cubit.state.totalLoops, isNull);
      });
    });
  });
}
