// ABOUTME: Tests the local picker data lifecycle without mounting a widget.
// ABOUTME: Covers ranking, retained snapshots, identity, and obsolete async work.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/local_user_picker/local_user_picker_cubit.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:user_ranking/user_ranking.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockRankingLoader extends Mock implements UserRankingSignalsLoader {}

void main() {
  group('LocalUserPickerCubit', () {
    final a = 'a' * 64;
    final b = 'b' * 64;
    final c = 'c' * 64;
    UserProfile profile(String key, String name) => UserProfile(
      pubkey: key,
      displayName: name,
      rawData: const {},
      createdAt: DateTime.utc(2026),
      eventId: 'e' * 64,
    );
    late _MockFollowRepository follow;
    late _MockProfileRepository profiles;
    late _MockRankingLoader loader;
    late StreamController<List<String>> followers;
    LocalUserPickerCubit create({LocalUserPickerState? initialState}) {
      final cubit = LocalUserPickerCubit(
        followRepository: follow,
        profileRepository: profiles,
        rankingSignalsLoader: loader,
        isBlocked: (_) => false,
        initialState: initialState,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    setUp(() {
      follow = _MockFollowRepository();
      profiles = _MockProfileRepository();
      loader = _MockRankingLoader();
      followers = StreamController<List<String>>.broadcast(sync: true);
      addTearDown(() {
        unawaited(followers.close());
      });
      when(() => follow.followingPubkeys).thenReturn([a, b, c]);
      when(follow.streamMyFollowers).thenAnswer((_) => followers.stream);
      when(() => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')))
          .thenAnswer(
            (_) async => [
              profile(a, 'Zoe'),
              profile(b, 'Maria'),
              profile(c, 'Aaron'),
            ],
          );
      when(() => loader.isEligible(any())).thenReturn(true);
      when(() => loader.load(any())).thenAnswer(
        (_) async => {
          a: UserRankingSignals(pubkey: a),
          b: UserRankingSignals(pubkey: b),
          c: UserRankingSignals(pubkey: c),
        },
      );
    });

    test(
      'refreshes after initial ranked emission without moving visible rows',
      () async {
        final cubit = create();
        when(() => loader.refreshInBackground(any())).thenAnswer((_) {
          expect(cubit.state.loaded, isTrue);
          expect(cubit.state.profiles.map((p) => p.pubkey), [b, a]);
        });
        await cubit.started();
        followers.add([a, b]);
        verify(() => loader.refreshInBackground([b, a])).called(1);
        expect(cubit.state.profiles.map((p) => p.pubkey), [b, a]);
      },
    );

    test(
      'ranks initial mutuals then appends late mutuals under the active query',
      () async {
        final cubit = create();
        await cubit.started();
        followers.add([a, b]);
        expect(cubit.state.profiles.map((p) => p.pubkey), [b, a]);
        cubit.queryChanged('a');
        expect(cubit.state.visibleProfiles.map((p) => p.pubkey), [b]);
        followers.add([a, b, c]);
        expect(cubit.state.profiles.map((p) => p.pubkey), [b, a, c]);
        expect(cubit.state.visibleProfiles.map((p) => p.pubkey), [b, c]);
      },
    );

    test('same-owner replacement retains query metadata and first-visible positions while loading', () async {
      final original = create();
      await original.started();
      followers.add([a, b]);
      original.queryChanged('a');
      expect(original.state.profiles.map((p) => p.pubkey), [b, a]);
      final snapshot = original.state;
      await original.close();
      final cached = Completer<List<UserProfile>>();
      when(() => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')))
          .thenAnswer((_) => cached.future);
      final replacement = create(initialState: snapshot);
      final loading = replacement.started();
      expect(replacement.state.visibleProfiles.map((p) => p.pubkey), [b]);
      cached.complete([profile(c, 'Aaron')]);
      await loading;
      followers.add([a, b, c]);
      expect(replacement.state.profiles.map((p) => p.pubkey), [b, a, c]);
      expect(replacement.state.visibleProfiles.map((p) => p.pubkey), [b, c]);
    });

    test(
      'vanished identity updates matching without moving existing rows',
      () async {
        final cubit = create();
        await cubit.started();
        followers.add([a, b]);
        expect(cubit.state.profiles.map((p) => p.pubkey), [b, a]);
        cubit.queryChanged('Zoe');
        expect(cubit.state.visibleProfiles.map((p) => p.pubkey), [a]);
        cubit.identityChanged(
          vanishedPubkeys: {a},
          deletedAccountLabel: 'withdrawn',
        );
        expect(cubit.state.visibleProfiles, isEmpty);
        cubit.queryChanged('withdrawn');
        expect(cubit.state.visibleProfiles.map((p) => p.pubkey), [a]);
        expect(cubit.state.profiles.map((p) => p.pubkey), [b, a]);
      },
    );

    test(
      'retained state cannot be changed through caller-owned collections',
      () async {
        final rows = [profile(a, 'Zoe'), profile(b, 'Maria')];
        final order = [a, b];
        final signals = {
          a: UserRankingSignals(pubkey: a),
          b: UserRankingSignals(pubkey: b),
        };
        final vanished = <String>{};
        final snapshot = LocalUserPickerState(
          profiles: rows,
          order: order,
          rankingSignals: signals,
          vanishedPubkeys: vanished,
          loaded: true,
          orderReady: true,
          query: 'Zoe',
        );
        rows.clear();
        order.clear();
        signals.clear();
        vanished.add(a);
        final cubit = create(initialState: snapshot);
        expect(cubit.state.visibleProfiles.map((p) => p.pubkey), [a]);
        expect(cubit.state.order, [a, b]);
        expect(cubit.state.rankingSignals.keys, [a, b]);
        expect(() => cubit.state.profiles.clear(), throwsUnsupportedError);
        expect(() => cubit.state.order.clear(), throwsUnsupportedError);
        expect(
          () => cubit.state.rankingSignals.clear(),
          throwsUnsupportedError,
        );
        expect(
          () => cubit.state.vanishedPubkeys.add(a),
          throwsUnsupportedError,
        );
      },
    );

    test('successful signal omissions remove retained rows even when profile reads fail', () async {
      final original = create();
      await original.started();
      followers.add([a, b, c]);
      expect(original.state.profiles.map((p) => p.pubkey), [c, b, a]);
      final snapshot = original.state;
      await original.close();
      when(() => loader.load(any()))
          .thenAnswer((_) async => {b: UserRankingSignals(pubkey: b)});
      when(() => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')))
          .thenThrow(StateError('cache unavailable'));
      final replacement = create(initialState: snapshot);
      await replacement.started();
      expect(replacement.state.profiles.map((p) => p.pubkey), [b]);
      expect(replacement.state.loaded, isTrue);
    });

    test('failed reads retain only still-followed eligible metadata', () async {
      final original = create();
      await original.started();
      followers.add([a, b, c]);
      expect(original.state.profiles.length, 3);
      final snapshot = original.state;
      await original.close();
      final replacement = create(initialState: snapshot);
      when(() => follow.followingPubkeys).thenReturn([a, b]);
      when(() => loader.isEligible(a)).thenReturn(false);
      when(() => loader.load(any()))
          .thenThrow(StateError('signals unavailable'));
      when(() => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')))
          .thenThrow(StateError('cache unavailable'));
      await replacement.started();
      expect(replacement.state.profiles.map((p) => p.pubkey), [b]);
      expect(replacement.state.loaded, isTrue);
    });

    test(
      'older overlapping load cannot replace the newer eligibility snapshot',
      () async {
        final pending = Completer<Map<String, UserRankingSignals>>();
        final entered = Completer<void>();
        when(() => loader.load(any())).thenAnswer((_) {
          entered.complete();
          return pending.future;
        });
        final cubit = create();
        final oldLoad = cubit.started();
        await entered.future;
        when(() => loader.load(any()))
            .thenAnswer((_) async => {b: UserRankingSignals(pubkey: b)});
        await cubit.started();
        followers.add([a, b, c]);
        expect(cubit.state.profiles.map((p) => p.pubkey), [b]);
        final current = cubit.state;
        pending.complete({a: UserRankingSignals(pubkey: a)});
        await oldLoad;
        expect(cubit.state, current);
      },
    );

    test('closing during profile read discards late data', () async {
      final pending = Completer<List<UserProfile>>();
      final entered = Completer<void>();
      when(() => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')))
          .thenAnswer((_) {
            entered.complete();
            return pending.future;
          });
      final cubit = create();
      final loading = cubit.started();
      await entered.future;
      await cubit.close();
      final closed = cubit.state;
      pending.complete([profile(a, 'Zoe')]);
      await loading;
      expect(cubit.state, closed);
      expect(cubit.state.profiles, isEmpty);
    });

    test('all follower sources failing falls back to currently eligible candidates', () async {
      final cubit = create();
      await cubit.started();
      when(() => loader.isEligible(a)).thenReturn(false);
      when(() => follow.followingPubkeys).thenReturn([a, b]);
      followers.addError(
        StateError('followers unavailable'),
        StackTrace.current,
      );
      expect(cubit.state.profiles.map((p) => p.pubkey), [b]);
      expect(cubit.state.loaded, isTrue);
    });

    test(
      'hydrated metadata for the same event refreshes visible rows',
      () async {
        final original = create();
        await original.started();
        followers.add([a, b]);
        expect(original.state.profiles.map((p) => p.displayName), [
          'Maria',
          'Zoe',
        ]);
        final snapshot = original.state;
        await original.close();
        when(() => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')))
            .thenAnswer((_) async => [profile(a, 'Aaron')]);
        final replacement = create(initialState: snapshot);
        await replacement.started();
        followers.add([a, b]);
        expect(replacement.state.profiles.map((p) => p.displayName), [
          'Maria',
          'Aaron',
        ]);
      },
    );
  });
}
