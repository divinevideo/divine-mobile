// ABOUTME: Unit tests for FollowListSearchBloc.
// ABOUTME: Covers query gating, name resolution, filtering and repo swap.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/follow_list_search/follow_list_search_bloc.dart';
import 'package:profile_repository/profile_repository.dart';

class _Errors extends BlocObserver {
  final captured = <Object>[];
  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    captured.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

// Full 64-character hex pubkeys — never truncate in app code, logs, or
// stored state. Full IDs only.
const String _alicePubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _bobPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _carolPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const String _subjectPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';

const List<String> _allPubkeys = [_alicePubkey, _bobPubkey, _carolPubkey];

/// Advance fake time beyond the 300 ms search debounce.
const _pastDebounce = Duration(milliseconds: 400);

UserProfile _profile({
  required String pubkey,
  String? displayName,
  String? nip05,
}) {
  return UserProfile(
    pubkey: pubkey,
    displayName: displayName,
    nip05: nip05,
    rawData: const {},
    createdAt: DateTime.utc(2026),
    eventId: 'event_for_$pubkey',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FollowListKind.followers);
  });

  group(FollowListSearchBloc, () {
    late _MockProfileRepository profileRepository;
    late _MockFollowRepository followRepository;

    setUp(() {
      profileRepository = _MockProfileRepository();
      followRepository = _MockFollowRepository();
      // Default: the API answers nothing, so every assertion below is about
      // on-device matching unless it stubs this differently.
      when(
        () => followRepository.searchFollowList(
          pubkey: any(named: 'pubkey'),
          query: any(named: 'query'),
          kind: any(named: 'kind'),
        ),
      ).thenAnswer((_) async => const <String>{});
      when(
        () => profileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer(
        (_) async => {
          _alicePubkey: _profile(pubkey: _alicePubkey, displayName: 'Alice'),
          _bobPubkey: _profile(
            pubkey: _bobPubkey,
            displayName: 'Bob',
            nip05: '_@bobby.divine.video',
          ),
          _carolPubkey: _profile(pubkey: _carolPubkey, displayName: 'Carol'),
        },
      );
    });

    FollowListSearchBloc createBloc({bool withRepository = true}) {
      return FollowListSearchBloc(
        followRepository: followRepository,
        subjectPubkey: _subjectPubkey,
        listKind: FollowListKind.followers,
        profileRepository: withRepository ? profileRepository : null,
      );
    }

    test('starts with no query and shows every pubkey', () {
      final bloc = createBloc();
      addTearDown(bloc.close);

      expect(bloc.state.isActive, isFalse);
      expect(bloc.state.visibleFrom(_allPubkeys), _allPubkeys);
    });

    test(
      'ignores a query shorter than the minimum and resolves no profiles',
      () {
        fakeAsync((clock) {
          final bloc = createBloc();
          bloc.add(const FollowListSearchQueryChanged('a', _allPubkeys));
          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.query, isEmpty);
          expect(bloc.state.visibleFrom(_allPubkeys), _allPubkeys);
          verifyNever(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          );

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'filters the list down to the display name that matches',
      () {
        fakeAsync((clock) {
          final bloc = createBloc();
          bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'matches on the NIP-05 handle as well as the display name',
      () {
        fakeAsync((clock) {
          final bloc = createBloc();
          bloc.add(const FollowListSearchQueryChanged('bobby', _allPubkeys));
          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.visibleFrom(_allPubkeys), [_bobPubkey]);

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'matches a pasted hex pubkey prefix',
      () {
        fakeAsync((clock) {
          final bloc = createBloc();
          bloc.add(const FollowListSearchQueryChanged('cccccc', _allPubkeys));
          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.visibleFrom(_allPubkeys), [_carolPubkey]);

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'falls back to the generated name when no repository is wired yet',
      () {
        fakeAsync((clock) {
          final bloc = createBloc(withRepository: false);
          bloc.add(
            FollowListSearchQueryChanged(
              UserProfile.defaultDisplayNameFor(_bobPubkey),
              _allPubkeys,
            ),
          );
          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.visibleFrom(_allPubkeys), [_bobPubkey]);

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'resolves names once a late profile repository arrives',
      () {
        fakeAsync((clock) {
          final bloc = createBloc(withRepository: false);

          bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();
          bloc.add(FollowListSearchProfileRepositoryChanged(profileRepository));

          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'keeps matching on generated names when the batch fetch throws',
      () {
        fakeAsync((clock) {
          final previousObserver = Bloc.observer;
          final observer = _Errors();
          Bloc.observer = observer;
          try {
            when(
              () => profileRepository.fetchBatchProfiles(
                pubkeys: any(named: 'pubkeys'),
              ),
            ).thenThrow(Exception('offline'));

            final bloc = createBloc();
            bloc.add(
              FollowListSearchQueryChanged(
                UserProfile.defaultDisplayNameFor(_carolPubkey),
                _allPubkeys,
              ),
            );
            clock.flushMicrotasks();
            clock.elapse(_pastDebounce);
            clock.flushMicrotasks();

            expect(bloc.state.visibleFrom(_allPubkeys), [_carolPubkey]);

            expect(observer.captured, [isA<Exception>()]);
            unawaited(bloc.close());
            clock.flushMicrotasks();
          } finally {
            Bloc.observer = previousObserver;
          }
        });
      },
    );

    test(
      'keeps a row the API matched but this device has no name for',
      () {
        fakeAsync((clock) {
          // The cold-cache case: no profile resolves on device, so on-device
          // matching can only see generated fallback names.
          when(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => const {});
          when(
            () => followRepository.searchFollowList(
              pubkey: _subjectPubkey,
              query: 'ali',
              kind: FollowListKind.followers,
            ),
          ).thenAnswer((_) async => const {_alicePubkey});

          final bloc = createBloc();
          bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'unions API matches with on-device matches',
      () {
        fakeAsync((clock) {
          // The API knows Carol but not Bob; on-device only knows Bob's name.
          when(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => {
              _bobPubkey: _profile(pubkey: _bobPubkey, displayName: 'Zeta Bob'),
            },
          );
          when(
            () => followRepository.searchFollowList(
              pubkey: _subjectPubkey,
              query: 'zeta',
              kind: FollowListKind.followers,
            ),
          ).thenAnswer((_) async => const {_carolPubkey});

          final bloc = createBloc();
          bloc.add(const FollowListSearchQueryChanged('zeta', _allPubkeys));
          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.visibleFrom(_allPubkeys), [
            _bobPubkey,
            _carolPubkey,
          ]);

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'drops API matches from the previous query',
      () {
        fakeAsync((clock) {
          when(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => const {});
          when(
            () => followRepository.searchFollowList(
              pubkey: _subjectPubkey,
              query: 'ali',
              kind: FollowListKind.followers,
            ),
          ).thenAnswer((_) async => const {_alicePubkey});

          final bloc = createBloc();

          bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();
          bloc.add(const FollowListSearchQueryChanged('zzz', _allPubkeys));

          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.remoteMatches, isEmpty);
          expect(bloc.state.visibleFrom(_allPubkeys), isEmpty);

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'skips the API search when there is no subject pubkey',
      () {
        fakeAsync((clock) {
          final bloc = FollowListSearchBloc(
            followRepository: followRepository,
            subjectPubkey: '',
            listKind: FollowListKind.followers,
            profileRepository: profileRepository,
          );
          bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);
          verifyNever(
            () => followRepository.searchFollowList(
              pubkey: any(named: 'pubkey'),
              query: any(named: 'query'),
              kind: any(named: 'kind'),
            ),
          );

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'retries a chunk whose profile fetch threw instead of pinning it',
      () {
        fakeAsync((clock) {
          final previousObserver = Bloc.observer;
          final observer = _Errors();
          Bloc.observer = observer;
          try {
            var attempt = 0;
            when(
              () => profileRepository.fetchBatchProfiles(
                pubkeys: any(named: 'pubkeys'),
              ),
            ).thenAnswer((_) async {
              if (attempt++ == 0) throw Exception('offline');
              return {
                _alicePubkey: _profile(
                  pubkey: _alicePubkey,
                  displayName: 'Alice',
                ),
              };
            });

            final bloc = createBloc();

            bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
            clock.elapse(_pastDebounce);
            clock.flushMicrotasks();
            bloc.add(const FollowListSearchQueryChanged('alic', _allPubkeys));

            clock.flushMicrotasks();
            clock.elapse(_pastDebounce);
            clock.flushMicrotasks();

            expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);

            expect(observer.captured, [isA<Exception>()]);
            unawaited(bloc.close());
            clock.flushMicrotasks();
          } finally {
            Bloc.observer = previousObserver;
          }
        });
      },
    );

    test(
      'retries a partial profile fetch instead of pinning missing rows',
      () {
        fakeAsync((clock) {
          var attempt = 0;
          when(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async {
            if (attempt++ == 0) return const <String, UserProfile>{};
            return {
              _alicePubkey: _profile(
                pubkey: _alicePubkey,
                displayName: 'Alice',
              ),
            };
          });

          final bloc = createBloc();

          bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();
          expect(bloc.state.searchTerms, isNot(contains(_alicePubkey)));

          bloc.add(const FollowListSearchQueryChanged('alic', _allPubkeys));

          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.searchTerms[_alicePubkey], contains('alice'));
          expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);
          verify(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).called(2);

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'drops terms resolved through the previous profile repository',
      () {
        fakeAsync((clock) {
          // This repository cannot reach Alice, so she is only matchable by her
          // generated name until a better one arrives.
          when(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => const {});

          final bloc = createBloc();

          bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          final replacement = _MockProfileRepository();
          when(
            () =>
                replacement.fetchBatchProfiles(pubkeys: any(named: 'pubkeys')),
          ).thenAnswer(
            (_) async => {
              _alicePubkey: _profile(
                pubkey: _alicePubkey,
                displayName: 'Alice',
              ),
            },
          );
          bloc.add(FollowListSearchProfileRepositoryChanged(replacement));

          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'ignores stale resolver emissions after the profile repository changes',
      () {
        fakeAsync((clock) {
          final bloc = createBloc();

          final candidatePubkeys = [
            _alicePubkey,
            for (var i = 0; i < 50; i++) i.toRadixString(16).padLeft(64, '0'),
          ];

          final secondOldFetchStarted = Completer<void>();
          final secondOldFetch = Completer<Map<String, UserProfile>>();
          // The old pass's second chunk holds only the last candidate, so only
          // a reply for it can reach the stale-emission guard.
          final stalePubkey = candidatePubkeys.last;
          var oldCalls = 0;
          when(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) {
            if (oldCalls++ == 0) {
              return Future.value({
                _alicePubkey: _profile(
                  pubkey: _alicePubkey,
                  displayName: 'Alicia',
                ),
              });
            }
            if (!secondOldFetchStarted.isCompleted) {
              secondOldFetchStarted.complete();
            }
            return secondOldFetch.future;
          });

          bloc.add(FollowListSearchQueryChanged('ali', candidatePubkeys));
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();
          expect(secondOldFetchStarted.isCompleted, isTrue);

          final replacement = _MockProfileRepository();
          when(
            () =>
                replacement.fetchBatchProfiles(pubkeys: any(named: 'pubkeys')),
          ).thenAnswer(
            (_) async => {
              _alicePubkey: _profile(
                pubkey: _alicePubkey,
                displayName: 'Alice',
              ),
            },
          );
          bloc.add(FollowListSearchProfileRepositoryChanged(replacement));
          clock.flushMicrotasks();

          secondOldFetch.complete({
            stalePubkey: _profile(pubkey: stalePubkey, displayName: 'Stale'),
          });

          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.searchTerms[_alicePubkey], equals('alice'));
          expect(bloc.state.searchTerms, isNot(contains(stalePubkey)));

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'runs the API search once the subject pubkey arrives',
      () {
        fakeAsync((clock) {
          // Nothing resolves on device, so only the API can produce this match.
          when(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => const {});
          when(
            () => followRepository.searchFollowList(
              pubkey: _subjectPubkey,
              query: 'ali',
              kind: FollowListKind.followers,
            ),
          ).thenAnswer((_) async => const {_alicePubkey});

          final bloc = FollowListSearchBloc(
            followRepository: followRepository,
            subjectPubkey: '',
            listKind: FollowListKind.followers,
            profileRepository: profileRepository,
          );

          bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();
          expect(bloc.state.visibleFrom(_allPubkeys), isEmpty);

          bloc.add(const FollowListSearchSubjectPubkeyChanged(_subjectPubkey));

          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.visibleFrom(_allPubkeys), [_alicePubkey]);

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'clearing the query restores the full list',
      () {
        fakeAsync((clock) {
          final bloc = createBloc();

          bloc.add(const FollowListSearchQueryChanged('ali', _allPubkeys));
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();
          bloc.add(const FollowListSearchQueryChanged('', _allPubkeys));

          clock.flushMicrotasks();
          clock.elapse(_pastDebounce);
          clock.flushMicrotasks();

          expect(bloc.state.isActive, isFalse);
          expect(bloc.state.visibleFrom(_allPubkeys), _allPubkeys);

          unawaited(bloc.close());
          clock.flushMicrotasks();
        });
      },
    );
  });
}
