import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/follow_list_sort.dart';
import 'package:openvine/blocs/my_followers/my_followers_bloc.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:user_ranking/user_ranking.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockBlocklist extends Mock implements ContentBlocklistRepository {}

class _MockLoader extends Mock implements UserRankingSignalsLoader {}

const _a = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _b = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _c = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _self =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

void main() {
  group('MyFollowingBloc Smart sort', () {
    late _MockFollowRepository repository;
    late _MockBlocklist blocklist;
    late _MockLoader loader;
    late StreamController<CacheResult<FollowingSnapshot>> snapshots;
    late StreamController<List<String>> updates;

    setUp(() {
      repository = _MockFollowRepository();
      blocklist = _MockBlocklist();
      loader = _MockLoader();
      when(() => loader.loadCachedDisplayNames(any()))
          .thenAnswer((_) async => {});
      snapshots = StreamController<CacheResult<FollowingSnapshot>>();
      updates = StreamController<List<String>>.broadcast();
      when(() => repository.followingPubkeys).thenReturn([]);
      when(() => repository.followingStream).thenAnswer((_) => updates.stream);
      when(() => repository.watchMyFollowingCached())
          .thenAnswer((_) => snapshots.stream);
      when(() => blocklist.isBlocked(any())).thenReturn(false);
      when(() => blocklist.isFollowSevered(any())).thenReturn(false);
      when(() => loader.isEligible(any()))
          .thenAnswer((call) => call.positionalArguments.first != _self);
      when(() => loader.load(any())).thenAnswer(
        (call) async => {
          for (final key in call.positionalArguments.first as Iterable<String>)
            if (key != _self)
              key: UserRankingSignals(
                pubkey: key,
                youFollow: key == _a,
                followsYou: key == _a,
                hasVerifiedNip05: key == _c,
              ),
        },
      );
    });
    tearDown(() async {
      unawaited(snapshots.close());
      await updates.close();
    });
    MyFollowingBloc createBloc() => MyFollowingBloc(
      followRepository: repository,
      contentBlocklistRepository: blocklist,
      rankingSignalsLoader: loader,
    );
    void load(List<String> keys) => snapshots.add(
      CacheResult.live(
        FollowingSnapshot(pubkeys: keys, count: keys.length),
      ),
    );

    test(
      'older repository ranking cannot replace newer live membership',
      () async {
        final pending = Completer<Map<String, UserRankingSignals>>();
        when(() => loader.load([_a])).thenAnswer((_) => pending.future);
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowingListLoadRequested());
        await pumpEventQueue();
        updates.add([_a]);
        await pumpEventQueue();
        updates.add([_b]);
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_b]);
        pending.complete({_a: const UserRankingSignals(pubkey: _a)});
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_b]);
        expect(bloc.state.rawFollowingPubkeys, [_b]);
      },
    );

    test('older cache ranking cannot replace newer live membership', () async {
      final pending = Completer<Map<String, UserRankingSignals>>();
      when(() => loader.load([_a])).thenAnswer((_) => pending.future);
      final bloc = createBloc();
      addTearDown(bloc.close);
      bloc.add(const MyFollowingListLoadRequested());
      load([_a]);
      await pumpEventQueue();
      updates.add([_b]);
      await pumpEventQueue();
      expect(bloc.state.followingPubkeys, [_b]);
      pending.complete({_a: const UserRankingSignals(pubkey: _a)});
      await pumpEventQueue();
      expect(bloc.state.followingPubkeys, [_b]);
      expect(bloc.state.rawFollowingPubkeys, [_b]);
    });

    blocTest<MyFollowingBloc, MyFollowingState>(
      'cached rows still get Smart ranking when the follow stream fails',
      setUp: () {
        when(() => repository.followingPubkeys).thenReturn([_b, _a]);
        when(() => repository.watchMyFollowingCached()).thenAnswer(
          (_) => Stream.error(StateError('follow stream unavailable')),
        );
      },
      build: createBloc,
      act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
      verify: (bloc) {
        expect(bloc.state.isSmartOrderReady, isTrue);
        expect(bloc.state.followingPubkeys, [_a, _b]);
      },
      errors: () => [isA<StateError>()],
    );

    test(
      'ranks scores, switches date sorts, and restores the frozen Smart order',
      () async {
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowingListLoadRequested());
        load([_a, _b, _c]);
        await pumpEventQueue();
        expect(bloc.state.sortOrder, FollowListSort.smart);
        expect(bloc.state.followingPubkeys, [_a, _c, _b]);
        expect(bloc.state.smartOrder, [_a, _c, _b]);
        expect(bloc.state.rankingSignals.keys, containsAll([_a, _b, _c]));
        bloc.add(const MyFollowingSortOrderChanged(FollowListSort.newestFirst));
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_c, _b, _a]);
        bloc.add(const MyFollowingSortOrderChanged(FollowListSort.oldestFirst));
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_a, _b, _c]);
        bloc.add(const MyFollowingSortOrderChanged(FollowListSort.smart));
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_a, _c, _b]);
        verify(() => loader.load(any())).called(1);
      },
    );

    test('equal scores sort by cached display name before pubkey', () async {
      when(() => loader.load(any())).thenAnswer(
        (_) async => {
          _a: const UserRankingSignals(pubkey: _a),
          _b: const UserRankingSignals(pubkey: _b),
        },
      );
      when(() => loader.loadCachedDisplayNames(any()))
          .thenAnswer((_) async => {_a: 'Zulu', _b: 'alice'});
      final bloc = createBloc();
      addTearDown(bloc.close);
      bloc.add(const MyFollowingListLoadRequested());
      load([_a, _b]);
      await pumpEventQueue();
      expect(bloc.state.followingPubkeys, [_b, _a]);
    });

    test(
      'late higher-score arrivals append without moving visible rows',
      () async {
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowingListLoadRequested());
        load([_b, _c]);
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_c, _b]);
        updates.add([_a, _b, _c]);
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_c, _b, _a]);
        load([_c, _a, _b]);
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_c, _b, _a]);
      },
    );

    test(
      'unblock during initial ranking retries the local eligibility snapshot',
      () async {
        var blocked = true;
        var calls = 0;
        final pending = Completer<Map<String, UserRankingSignals>>();
        when(() => loader.isEligible(_a)).thenAnswer((_) => !blocked);
        when(() => loader.load(any())).thenAnswer((call) {
          if (calls++ == 0) return pending.future;
          return Future.value({
            for (final key
                in call.positionalArguments.first as Iterable<String>)
              if (loader.isEligible(key))
                key: UserRankingSignals(pubkey: key, youFollow: key == _a),
          });
        });
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowingListLoadRequested());
        load([_a, _b]);
        await pumpEventQueue();
        expect(bloc.state.isSmartOrderReady, isFalse);
        blocked = false;
        bloc.add(const MyFollowingBlocklistChanged());
        await pumpEventQueue();
        pending.complete({_b: const UserRankingSignals(pubkey: _b)});
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_a, _b]);
        expect(calls, 2);
      },
    );

    test(
      'unblock retries pending newer membership without dropping its new row',
      () async {
        var blocked = true;
        final pending = Completer<Map<String, UserRankingSignals>>();
        when(() => loader.isEligible(_a)).thenAnswer((_) => !blocked);
        when(() => loader.load(any())).thenAnswer(
          (call) async => {
            for (final key
                in call.positionalArguments.first as Iterable<String>)
              if (loader.isEligible(key))
                key: UserRankingSignals(pubkey: key, youFollow: key == _a),
          },
        );
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowingListLoadRequested());
        load([_a, _b]);
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_b]);
        var newerCalls = 0;
        when(() => loader.load([_a, _b, _c])).thenAnswer((_) {
          if (newerCalls++ == 0) return pending.future;
          return Future.value({
            for (final key in [_a, _b, _c])
              key: UserRankingSignals(pubkey: key),
          });
        });
        load([_a, _b, _c]);
        await pumpEventQueue();
        blocked = false;
        bloc.add(const MyFollowingBlocklistChanged());
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_b, _a]);
        pending.complete({
          _b: const UserRankingSignals(pubkey: _b),
          _c: const UserRankingSignals(pubkey: _c),
        });
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_b, _a, _c]);
        expect(bloc.state.rawFollowingPubkeys, [_a, _b, _c]);
        expect(newerCalls, 2);
      },
    );

    test(
      'unblocking appends a previously excluded row without moving others',
      () async {
        var blocked = true;
        when(() => loader.isEligible(_a)).thenAnswer((_) => !blocked);
        when(() => loader.load(any())).thenAnswer(
          (_) async => {
            if (!blocked)
              _a: const UserRankingSignals(pubkey: _a, youFollow: true),
            _b: const UserRankingSignals(pubkey: _b),
          },
        );
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowingListLoadRequested());
        load([_a, _b]);
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_b]);
        blocked = false;
        bloc.add(const MyFollowingBlocklistChanged());
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_b, _a]);
      },
    );

    test('successful signal omissions remain hidden in every sort', () async {
      when(() => loader.load(any())).thenAnswer(
        (_) async => {
          _b: const UserRankingSignals(pubkey: _b),
        },
      );
      final bloc = createBloc();
      addTearDown(bloc.close);
      bloc.add(const MyFollowingListLoadRequested());
      load([_self, _a, _b]);
      await pumpEventQueue();
      expect(bloc.state.followingPubkeys, [_b]);
      for (final order in FollowListSort.values) {
        bloc.add(MyFollowingSortOrderChanged(order));
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_b]);
      }
    });

    blocTest<MyFollowingBloc, MyFollowingState>(
      'ranking failure reports the error and retains only eligible rows',
      setUp: () {
        when(() => loader.load(any()))
            .thenThrow(StateError('local store unavailable'));
        when(() => blocklist.isBlocked(_a)).thenReturn(true);
      },
      build: createBloc,
      act: (bloc) async {
        bloc.add(const MyFollowingListLoadRequested());
        load([_self, _a, _b]);
        await pumpEventQueue();
      },
      verify: (bloc) {
        expect(bloc.state.followingPubkeys, [_b]);
        expect(bloc.state.isSmartOrderReady, isTrue);
      },
      errors: () => [isA<StateError>()],
    );

    test(
      'empty first load still appends the next batch in arrival order',
      () async {
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowingListLoadRequested());
        load([]);
        await pumpEventQueue();
        expect(bloc.state.isSmartOrderReady, isTrue);
        expect(bloc.state.followingPubkeys, isEmpty);
        load([_b, _a]);
        await pumpEventQueue();
        expect(bloc.state.followingPubkeys, [_b, _a]);
      },
    );
  });
  group('MyFollowersBloc Smart sort', () {
    late _MockFollowRepository repository;
    late _MockBlocklist blocklist;
    late _MockLoader loader;
    late StreamController<CacheResult<FollowersSnapshot>> snapshots;
    late StreamController<List<String>> updates;

    setUp(() {
      repository = _MockFollowRepository();
      blocklist = _MockBlocklist();
      loader = _MockLoader();
      when(() => loader.loadCachedDisplayNames(any()))
          .thenAnswer((_) async => {});
      snapshots = StreamController<CacheResult<FollowersSnapshot>>();
      updates = StreamController<List<String>>.broadcast();
      when(() => repository.followingPubkeys).thenReturn([]);
      when(() => repository.followingStream).thenAnswer((_) => updates.stream);
      when(() => repository.watchMyFollowersCached())
          .thenAnswer((_) => snapshots.stream);
      when(() => blocklist.isBlocked(any())).thenReturn(false);
      when(() => blocklist.isFollowSevered(any())).thenReturn(false);
      when(() => loader.isEligible(any()))
          .thenAnswer((call) => call.positionalArguments.first != _self);
      when(() => loader.load(any())).thenAnswer(
        (call) async => {
          for (final key in call.positionalArguments.first as Iterable<String>)
            if (key != _self)
              key: UserRankingSignals(
                pubkey: key,
                youFollow: key == _a,
                followsYou: key == _a,
                hasVerifiedNip05: key == _c,
              ),
        },
      );
    });
    tearDown(() async {
      unawaited(snapshots.close());
      await updates.close();
    });
    MyFollowersBloc createBloc() => MyFollowersBloc(
      followRepository: repository,
      contentBlocklistRepository: blocklist,
      rankingSignalsLoader: loader,
    );
    void load(List<String> keys) => snapshots.add(
      CacheResult.live(
        FollowersSnapshot(
          pubkeys: keys,
          count: keys.length,
          datedCount: keys.length,
        ),
      ),
    );

    test(
      'ranks scores, switches date sorts, and restores the frozen Smart order',
      () async {
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowersListLoadRequested());
        load([_a, _b, _c]);
        await pumpEventQueue();
        expect(bloc.state.sortOrder, FollowListSort.smart);
        expect(bloc.state.followersPubkeys, [_a, _c, _b]);
        expect(bloc.state.smartOrder, [_a, _c, _b]);
        expect(bloc.state.rankingSignals.keys, containsAll([_a, _b, _c]));
        bloc.add(const MyFollowersSortOrderChanged(FollowListSort.newestFirst));
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_a, _b, _c]);
        bloc.add(const MyFollowersSortOrderChanged(FollowListSort.oldestFirst));
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_c, _b, _a]);
        bloc.add(const MyFollowersSortOrderChanged(FollowListSort.smart));
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_a, _c, _b]);
        verify(() => loader.load(any())).called(1);
      },
    );

    test('equal scores sort by cached display name before pubkey', () async {
      when(() => loader.load(any())).thenAnswer(
        (_) async => {
          _a: const UserRankingSignals(pubkey: _a),
          _b: const UserRankingSignals(pubkey: _b),
        },
      );
      when(() => loader.loadCachedDisplayNames(any()))
          .thenAnswer((_) async => {_a: 'Zulu', _b: 'alice'});
      final bloc = createBloc();
      addTearDown(bloc.close);
      bloc.add(const MyFollowersListLoadRequested());
      load([_a, _b]);
      await pumpEventQueue();
      expect(bloc.state.followersPubkeys, [_b, _a]);
    });

    test(
      'late higher-score arrivals append without moving visible rows',
      () async {
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowersListLoadRequested());
        load([_b, _c]);
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_c, _b]);
        load([_a, _b, _c]);
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_c, _b, _a]);
        load([_c, _a, _b]);
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_c, _b, _a]);
      },
    );

    test(
      'unblock during initial ranking retries the local eligibility snapshot',
      () async {
        var blocked = true;
        var calls = 0;
        final pending = Completer<Map<String, UserRankingSignals>>();
        when(() => loader.isEligible(_a)).thenAnswer((_) => !blocked);
        when(() => loader.load(any())).thenAnswer((call) {
          if (calls++ == 0) return pending.future;
          return Future.value({
            for (final key
                in call.positionalArguments.first as Iterable<String>)
              if (loader.isEligible(key))
                key: UserRankingSignals(pubkey: key, youFollow: key == _a),
          });
        });
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowersListLoadRequested());
        load([_a, _b]);
        await pumpEventQueue();
        expect(bloc.state.isSmartOrderReady, isFalse);
        blocked = false;
        bloc.add(const MyFollowersBlocklistChanged());
        await pumpEventQueue();
        pending.complete({_b: const UserRankingSignals(pubkey: _b)});
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_a, _b]);
        expect(calls, 2);
      },
    );

    test(
      'unblock retries pending newer membership without dropping its new row',
      () async {
        var blocked = true;
        final pending = Completer<Map<String, UserRankingSignals>>();
        when(() => loader.isEligible(_a)).thenAnswer((_) => !blocked);
        when(() => loader.load(any())).thenAnswer(
          (call) async => {
            for (final key
                in call.positionalArguments.first as Iterable<String>)
              if (loader.isEligible(key))
                key: UserRankingSignals(pubkey: key, youFollow: key == _a),
          },
        );
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowersListLoadRequested());
        load([_a, _b]);
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_b]);
        var newerCalls = 0;
        when(() => loader.load([_a, _b, _c])).thenAnswer((_) {
          if (newerCalls++ == 0) return pending.future;
          return Future.value({
            for (final key in [_a, _b, _c])
              key: UserRankingSignals(pubkey: key),
          });
        });
        load([_a, _b, _c]);
        await pumpEventQueue();
        blocked = false;
        bloc.add(const MyFollowersBlocklistChanged());
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_b, _a]);
        pending.complete({
          _b: const UserRankingSignals(pubkey: _b),
          _c: const UserRankingSignals(pubkey: _c),
        });
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_b, _a, _c]);
        expect(bloc.state.rawFollowersPubkeys, [_a, _b, _c]);
        expect(newerCalls, 2);
      },
    );

    test(
      'unblocking appends a previously excluded row without moving others',
      () async {
        var blocked = true;
        when(() => loader.isEligible(_a)).thenAnswer((_) => !blocked);
        when(() => loader.load(any())).thenAnswer(
          (_) async => {
            if (!blocked)
              _a: const UserRankingSignals(pubkey: _a, youFollow: true),
            _b: const UserRankingSignals(pubkey: _b),
          },
        );
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowersListLoadRequested());
        load([_a, _b]);
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_b]);
        blocked = false;
        bloc.add(const MyFollowersBlocklistChanged());
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_b, _a]);
      },
    );

    test('successful signal omissions remain hidden in every sort', () async {
      when(() => loader.load(any())).thenAnswer(
        (_) async => {
          _b: const UserRankingSignals(pubkey: _b),
        },
      );
      final bloc = createBloc();
      addTearDown(bloc.close);
      bloc.add(const MyFollowersListLoadRequested());
      load([_self, _a, _b]);
      await pumpEventQueue();
      expect(bloc.state.followersPubkeys, [_b]);
      for (final order in FollowListSort.values) {
        bloc.add(MyFollowersSortOrderChanged(order));
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_b]);
      }
    });

    blocTest<MyFollowersBloc, MyFollowersState>(
      'ranking failure reports the error and retains only eligible rows',
      setUp: () {
        when(() => loader.load(any()))
            .thenThrow(StateError('local store unavailable'));
        when(() => blocklist.isBlocked(_a)).thenReturn(true);
      },
      build: createBloc,
      act: (bloc) async {
        bloc.add(const MyFollowersListLoadRequested());
        load([_self, _a, _b]);
        await pumpEventQueue();
      },
      verify: (bloc) {
        expect(bloc.state.followersPubkeys, [_b]);
        expect(bloc.state.isSmartOrderReady, isTrue);
      },
      errors: () => [isA<StateError>()],
    );

    test(
      'empty first load still appends the next batch in arrival order',
      () async {
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowersListLoadRequested());
        load([]);
        await pumpEventQueue();
        expect(bloc.state.isSmartOrderReady, isTrue);
        expect(bloc.state.followersPubkeys, isEmpty);
        load([_b, _a]);
        await pumpEventQueue();
        expect(bloc.state.followersPubkeys, [_b, _a]);
      },
    );
  });
}
