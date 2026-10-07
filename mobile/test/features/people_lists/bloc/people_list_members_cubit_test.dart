import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_list_members_cubit.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

// Full-length 64-char pubkeys — never truncate.
final String _quiet = 'a' * 64;
final String _busy = 'b' * 64;
final String _unknown = 'c' * 64;
final String _busiest = 'd' * 64;

/// A member's profile as Funnelcake answers it. A null [videos] is a stats
/// object the API sent without its vertical count.
UserProfileFound _found(
  String pubkey, {
  required int? videos,
  double loops = 0,
}) {
  return UserProfileFound(
    profile: UserProfileData(pubkey: pubkey),
    // videoCount deliberately exceeds the vertical count: the extra are
    // horizontal videos the grid cannot render, so nothing should count them.
    stats: ProfileStatsData(
      videoCount: (videos ?? 0) + 10,
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
    late ContentBlocklistRepository blocklist;

    setUp(() {
      profileRepository = _MockProfileRepository();
      blocklist = ContentBlocklistRepository();
      addTearDown(blocklist.dispose);
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
          contentBlocklistRepository: blocklist,
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
        'keeps members without stats after the ranked ones, in list order, '
        'and shows no totals',
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
            contentBlocklistRepository: blocklist,
            pubkeys: [_unknown, _quiet, _busy],
          );
          addTearDown(cubit.close);

          await cubit.load();

          expect(
            cubit.state.members.map((member) => member.pubkey),
            equals([_busy, _unknown, _quiet]),
          );
          expect(cubit.state.members.last.hasStats, isFalse);
          // Two members the API does not know never answered, so seven is
          // the one member's count, not the list's total.
          expect(cubit.state.totalVideos, isNull);
          expect(cubit.state.totalLoops, isNull);
        },
      );

      test(
        'leaves a member whose stats omit the vertical count unranked '
        'and uncounted',
        () async {
          // The API answered for the member, but not the one count the
          // roster ranks on: unknown, not zero, so the member is neither
          // ranked last nor counted as posting nothing, and a total that
          // leaves them out is not the list's.
          when(
            () => profileRepository.getBulkProfilesFromApi(any()),
          ).thenAnswer(
            (_) async => BulkProfilesResponse(
              profiles: {
                _unknown: _found(_unknown, videos: null),
                _busy: _found(_busy, videos: 7),
              },
            ),
          );
          final cubit = PeopleListMembersCubit(
            profileRepository: profileRepository,
            contentBlocklistRepository: blocklist,
            pubkeys: [_unknown, _busy],
          );
          addTearDown(cubit.close);

          await cubit.load();

          expect(
            cubit.state.members.map((member) => member.pubkey),
            equals([_busy, _unknown]),
          );
          expect(cubit.state.members.last.hasStats, isFalse);
          expect(cubit.state.totalVideos, isNull);
          expect(cubit.state.totalLoops, isNull);
        },
      );

      test(
        'reports the list order without stats when there is no repository',
        () async {
          final cubit = PeopleListMembersCubit(
            profileRepository: null,
            contentBlocklistRepository: blocklist,
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
          contentBlocklistRepository: blocklist,
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
        // Members past the cap are still in the roster, unranked, and tied
        // members keep the list's own order even above the 32 elements where
        // Dart's sort stops being stable.
        expect(
          cubit.state.members.map((member) => member.pubkey).toList(),
          equals(pubkeys),
        );
      });

      test('stops paging when Funnelcake is not configured', () async {
        when(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).thenAnswer((_) async => null);
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          contentBlocklistRepository: blocklist,
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

      test('counts a member who answers with zero videos', () async {
        when(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).thenAnswer(
          (_) async => BulkProfilesResponse(
            profiles: {
              _quiet: _found(_quiet, videos: 0),
              _busy: _found(_busy, videos: 5),
            },
          ),
        );
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          contentBlocklistRepository: blocklist,
          pubkeys: [_quiet, _unknown, _busy],
        );
        addTearDown(cubit.close);

        await cubit.load();

        // A zero is an answer: it outranks a member Funnelcake never answered
        // for, and a list where everyone answered still has a total.
        expect(
          cubit.state.members.map((member) => member.pubkey),
          equals([_busy, _quiet, _unknown]),
        );
        expect(cubit.state.totalVideos, isNull);

        final answered = PeopleListMembersCubit(
          profileRepository: profileRepository,
          contentBlocklistRepository: blocklist,
          pubkeys: [_quiet, _busy],
        );
        addTearDown(answered.close);
        await answered.load();
        expect(answered.state.totalVideos, equals(5));
      });

      test('totals a list whose only member has no videos as zero', () async {
        when(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).thenAnswer(
          (_) async => BulkProfilesResponse(
            profiles: {_quiet: _found(_quiet, videos: 0)},
          ),
        );
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          contentBlocklistRepository: blocklist,
          pubkeys: [_quiet],
        );
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.totalVideos, equals(0));
        expect(cubit.state.totalLoops, equals(0));
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
          contentBlocklistRepository: blocklist,
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
          contentBlocklistRepository: blocklist,
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
          contentBlocklistRepository: blocklist,
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
          contentBlocklistRepository: blocklist,
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
          contentBlocklistRepository: blocklist,
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

    group('hidden members', () {
      void stubStats() {
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
      }

      PeopleListMembersCubit buildCubit({
        ContentBlocklistRepository? contentBlocklistRepository,
      }) {
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          contentBlocklistRepository: contentBlocklistRepository ?? blocklist,
          pubkeys: [_quiet, _busy, _busiest],
        );
        addTearDown(cubit.close);
        return cubit;
      }

      List<String> pubkeysOf(PeopleListMembersState state) => [
        for (final member in state.members) member.pubkey,
      ];

      test(
        'leaves out a blocked member even when they post the most',
        () async {
          stubStats();
          await blocklist.blockUser(_busiest);
          final cubit = buildCubit();

          await cubit.load();

          expect(pubkeysOf(cubit.state), equals([_busy, _quiet]));
        },
      );

      test('leaves out a blocked member before any stats arrive', () async {
        await blocklist.blockUser(_busy);

        final cubit = buildCubit();

        expect(pubkeysOf(cubit.state), equals([_quiet, _busiest]));
      });

      test(
        'keeps a hidden member in the list-wide totals, as #9740 decided',
        () async {
          stubStats();
          await blocklist.blockUser(_busiest);
          final cubit = buildCubit();

          await cubit.load();

          expect(cubit.state.totalVideos, equals(132));
          expect(cubit.state.totalLoops, equals(6010));
        },
      );

      test(
        'drops a member blocked after loading, without refetching',
        () async {
          stubStats();
          final cubit = buildCubit();
          await cubit.load();
          expect(pubkeysOf(cubit.state), contains(_busy));

          await blocklist.blockUser(_busy);
          await pumpEventQueue();

          expect(pubkeysOf(cubit.state), equals([_busiest, _quiet]));
          verify(
            () => profileRepository.getBulkProfilesFromApi(any()),
          ).called(1);
        },
      );

      test('keeps out a member blocked while the stats are loading', () async {
        final answer = Completer<BulkProfilesResponse?>();
        when(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).thenAnswer((_) => answer.future);
        final cubit = buildCubit();
        final loading = cubit.load();

        await blocklist.blockUser(_busiest);
        answer.complete(
          BulkProfilesResponse(
            profiles: {
              _quiet: _found(_quiet, videos: 2),
              _busy: _found(_busy, videos: 40),
              _busiest: _found(_busiest, videos: 90),
            },
          ),
        );
        await loading;

        expect(pubkeysOf(cubit.state), equals([_busy, _quiet]));
      });

      test('restores an unblocked member with their stats', () async {
        stubStats();
        await blocklist.blockUser(_busiest);
        final cubit = buildCubit();
        await cubit.load();
        expect(pubkeysOf(cubit.state), isNot(contains(_busiest)));

        await blocklist.unblockUser(_busiest);
        await pumpEventQueue();

        expect(pubkeysOf(cubit.state), equals([_busiest, _busy, _quiet]));
        expect(cubit.state.members.first.videoCount, equals(90));
        verify(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).called(1);
      });

      test(
        'hides an account that muted the viewer, not only ones the viewer '
        'blocked',
        () async {
          stubStats();
          final mutedUs = _MockContentBlocklistRepository();
          when(
            () => mutedUs.stateStream,
          ).thenAnswer((_) => const Stream.empty());
          // The viewer did not block this account; it muted the viewer. Only
          // the feed predicate hides it, which pins that predicate over
          // isBlocked.
          when(() => mutedUs.isBlocked(any())).thenReturn(false);
          when(() => mutedUs.shouldFilterFromFeeds(any())).thenAnswer(
            (invocation) => invocation.positionalArguments.first == _busy,
          );
          final cubit = buildCubit(contentBlocklistRepository: mutedUs);
          expect(pubkeysOf(cubit.state), equals([_quiet, _busiest]));

          await cubit.load();

          expect(pubkeysOf(cubit.state), equals([_busiest, _quiet]));
        },
      );

      test('stops listening for blocklist changes once closed', () async {
        final changes = StreamController<ContentPolicyState>.broadcast();
        addTearDown(changes.close);
        final repository = _MockContentBlocklistRepository();
        when(() => repository.stateStream).thenAnswer((_) => changes.stream);
        when(() => repository.shouldFilterFromFeeds(any())).thenReturn(false);
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          contentBlocklistRepository: repository,
          pubkeys: [_quiet],
        );
        expect(changes.hasListener, isTrue);

        await cubit.close();

        expect(changes.hasListener, isFalse);
      });
    });
  });
}
