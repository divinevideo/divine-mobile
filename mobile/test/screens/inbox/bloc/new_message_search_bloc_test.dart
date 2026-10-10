// ABOUTME: Tests for NewMessageSearchBloc — contact loading, filtering,
// ABOUTME: network search, and merge behavior.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/screens/inbox/bloc/new_message_search_bloc.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group(NewMessageSearchBloc, () {
    late _MockProfileRepository mockProfileRepo;
    late _MockFollowRepository mockFollowRepo;

    const debounceDuration = Duration(milliseconds: 400);
    const currentUserPubkey =
        'facade00facade00facade00facade00'
        'facade00facade00facade00facade00';

    setUp(() {
      mockProfileRepo = _MockProfileRepository();
      mockFollowRepo = _MockFollowRepository();
      // The BLoC mirrors the durable vanish tombstones so its sort and filter
      // can resolve names the way the row renders them; every construction
      // needs the stream to exist.
      when(
        mockProfileRepo.watchVanishedPubkeys,
      ).thenAnswer((_) => const Stream<Set<String>>.empty());
    });

    NewMessageSearchBloc createBloc() => NewMessageSearchBloc(
      profileRepository: mockProfileRepo,
      followRepository: mockFollowRepo,
      currentUserPubkey: currentUserPubkey,
      moderationPresentation: moderationPresentationOf,
    );

    UserProfile createTestProfile(
      String pubkey,
      String displayName, {
      String? nip05,
      String? eventId,
    }) {
      return UserProfile(
        pubkey: pubkey,
        displayName: displayName,
        nip05: nip05,
        createdAt: DateTime.now(),
        eventId: eventId ?? 'event-$pubkey',
        rawData: {'display_name': displayName},
      );
    }

    /// A full-length synthetic pubkey, distinct for every [index] below 256.
    String pubkeyAt(int index) => index.toRadixString(16).padLeft(2, '0') * 32;

    /// [count] distinct candidate recipients, none of them the viewer.
    List<UserProfile> recipients(int count) => [
      for (var index = 1; index <= count; index++)
        createTestProfile(pubkeyAt(index), 'Person $index'),
    ];

    test('initial state is loadingContacts', () async {
      when(() => mockFollowRepo.followingPubkeys).thenReturn([]);
      final bloc = createBloc();
      expect(bloc.state.status, NewMessageSearchStatus.loadingContacts);
      expect(bloc.state.contacts, isEmpty);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.results, isEmpty);
      await bloc.close();
    });

    group('excludes the current user (#8351)', () {
      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'omits the viewer from contacts when their contact list self-follows',
        setUp: () {
          when(
            () => mockFollowRepo.followingPubkeys,
          ).thenReturn([currentUserPubkey, 'a' * 64]);
          when(
            () => mockProfileRepo.getCachedProfile(pubkey: currentUserPubkey),
          ).thenAnswer((_) async => createTestProfile(currentUserPubkey, 'Me'));
          when(
            () => mockProfileRepo.getCachedProfile(pubkey: 'a' * 64),
          ).thenAnswer((_) async => createTestProfile('a' * 64, 'Alice'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const NewMessageSearchStarted()),
        expect: () => [
          isA<NewMessageSearchState>().having(
            (s) => s.contacts.map((c) => c.pubkey),
            'contact pubkeys',
            ['a' * 64],
          ),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'omits the viewer from network search results',
        setUp: () {
          when(() => mockFollowRepo.followingPubkeys).thenReturn([]);
          when(
            () => mockProfileRepo.searchUsers(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer(
            (_) async => [
              createTestProfile(currentUserPubkey, 'Me'),
              createTestProfile('a' * 64, 'Alice'),
            ],
          );
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const NewMessageSearchStarted());
          bloc.add(const NewMessageSearchQueryChanged('al'));
        },
        wait: debounceDuration,
        verify: (bloc) {
          expect(bloc.state.results.map((r) => r.pubkey), ['a' * 64]);
        },
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'omits the viewer when their contact list stores upper-case hex',
        setUp: () {
          when(
            () => mockFollowRepo.followingPubkeys,
          ).thenReturn([currentUserPubkey.toUpperCase()]);
          when(
            () => mockProfileRepo.getCachedProfile(
              pubkey: currentUserPubkey.toUpperCase(),
            ),
          ).thenAnswer(
            (_) async =>
                createTestProfile(currentUserPubkey.toUpperCase(), 'Me'),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const NewMessageSearchStarted()),
        expect: () => [
          isA<NewMessageSearchState>().having(
            (s) => s.contacts,
            'contacts',
            isEmpty,
          ),
        ],
      );
    });

    group('NewMessageSearchStarted', () {
      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'loads followed contacts sorted alphabetically',
        setUp: () {
          when(
            () => mockFollowRepo.followingPubkeys,
          ).thenReturn(['b' * 64, 'a' * 64]);
          when(
            () => mockProfileRepo.getCachedProfile(pubkey: 'b' * 64),
          ).thenAnswer((_) async => createTestProfile('b' * 64, 'Bob'));
          when(
            () => mockProfileRepo.getCachedProfile(pubkey: 'a' * 64),
          ).thenAnswer((_) async => createTestProfile('a' * 64, 'Alice'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const NewMessageSearchStarted()),
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.status, 'status', NewMessageSearchStatus.idle)
              .having((s) => s.contacts, 'contacts', hasLength(2))
              .having(
                (s) => s.contacts.first.displayName,
                'first contact',
                'Alice',
              )
              .having(
                (s) => s.contacts.last.displayName,
                'last contact',
                'Bob',
              ),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'emits idle with empty contacts when no follows',
        setUp: () {
          when(() => mockFollowRepo.followingPubkeys).thenReturn([]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const NewMessageSearchStarted()),
        expect: () => [
          const NewMessageSearchState(status: NewMessageSearchStatus.idle),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'skips null profiles from cache',
        setUp: () {
          when(
            () => mockFollowRepo.followingPubkeys,
          ).thenReturn(['a' * 64, 'b' * 64]);
          when(
            () => mockProfileRepo.getCachedProfile(pubkey: 'a' * 64),
          ).thenAnswer((_) async => createTestProfile('a' * 64, 'Alice'));
          when(
            () => mockProfileRepo.getCachedProfile(pubkey: 'b' * 64),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const NewMessageSearchStarted()),
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.status, 'status', NewMessageSearchStatus.idle)
              .having((s) => s.contacts, 'contacts', hasLength(1))
              .having(
                (s) => s.contacts.first.displayName,
                'displayName',
                'Alice',
              ),
        ],
      );
    });

    group('NewMessageSearchQueryChanged', () {
      final alice = createTestProfile('a' * 64, 'Alice', nip05: 'alice@ex.com');
      final bob = createTestProfile('b' * 64, 'Bob');
      final charlie = createTestProfile('c' * 64, 'Charlie');

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'filters contacts locally then merges with network results',
        setUp: () {
          when(
            () => mockProfileRepo.searchUsers(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer(
            (_) async => [createTestProfile('a' * 64, 'Alice Network')],
          );
        },
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          contacts: [alice, bob, charlie],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('alice')),
        wait: debounceDuration,
        expect: () => [
          // Searching with local filter (only Alice matches)
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searching,
              )
              .having((s) => s.query, 'query', 'alice')
              .having((s) => s.results, 'results', hasLength(1))
              .having(
                (s) => s.results.first.displayName,
                'local match',
                'Alice',
              ),
          // Success with merged results (network takes precedence)
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searchSuccess,
              )
              .having((s) => s.results, 'results', hasLength(1))
              .having(
                (s) => s.results.first.displayName,
                'network precedence',
                'Alice Network',
              ),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'filters contacts by NIP-05',
        setUp: () {
          when(
            () => mockProfileRepo.searchUsers(
              query: 'alice@ex',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          contacts: [alice, bob],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('alice@ex')),
        wait: debounceDuration,
        expect: () => [
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searching,
              )
              .having((s) => s.results, 'results', hasLength(1))
              .having((s) => s.results.first.nip05, 'nip05', 'alice@ex.com'),
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searchSuccess,
              )
              .having((s) => s.results, 'results', hasLength(1)),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'merges local contacts with network results deduplicating by pubkey',
        setUp: () {
          when(
            () => mockProfileRepo.searchUsers(
              query: 'bo',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer(
            (_) async => [
              createTestProfile('b' * 64, 'Bob Network'),
              createTestProfile('d' * 64, 'Bobby New'),
            ],
          );
        },
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          contacts: [alice, bob, charlie],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('bo')),
        wait: debounceDuration,
        expect: () => [
          // Searching — local filter matches Bob
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searching,
              )
              .having((s) => s.results, 'results', hasLength(1)),
          // Success — network Bob + Bobby merged, local Bob deduped
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searchSuccess,
              )
              .having((s) => s.results, 'results', hasLength(2))
              .having(
                (s) => s.results.first.displayName,
                'network takes precedence',
                'Bob Network',
              ),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'preserves local contacts on network failure',
        setUp: () {
          when(
            () => mockProfileRepo.searchUsers(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          contacts: [alice, bob],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('alice')),
        wait: debounceDuration,
        expect: () => [
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searching,
              )
              .having((s) => s.results, 'results', hasLength(1)),
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searchFailure,
              )
              .having(
                (s) => s.results,
                'local contacts preserved',
                hasLength(1),
              ),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'resets to idle when query is empty',
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.searchSuccess,
          contacts: [alice],
          query: 'alice',
          results: [alice],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('')),
        wait: debounceDuration,
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.status, 'status', NewMessageSearchStatus.idle)
              .having((s) => s.query, 'query', isEmpty)
              .having((s) => s.results, 'results', isEmpty)
              .having((s) => s.contacts, 'contacts preserved', hasLength(1)),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'resets to idle when query is a single character',
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.searchSuccess,
          contacts: [alice],
          query: 'alice',
          results: [alice],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('a')),
        wait: debounceDuration,
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.status, 'status', NewMessageSearchStatus.idle)
              .having((s) => s.query, 'query', isEmpty)
              .having((s) => s.results, 'results', isEmpty),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'debounces rapid query changes and processes only the final query',
        setUp: () {
          when(
            () => mockProfileRepo.searchUsers(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          contacts: [alice, bob],
        ),
        act: (bloc) {
          bloc
            ..add(const NewMessageSearchQueryChanged('al'))
            ..add(const NewMessageSearchQueryChanged('ali'))
            ..add(const NewMessageSearchQueryChanged('alic'))
            ..add(const NewMessageSearchQueryChanged('alice'));
        },
        wait: debounceDuration,
        expect: () => [
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searching,
              )
              .having((s) => s.query, 'query', 'alice'),
          isA<NewMessageSearchState>().having(
            (s) => s.status,
            'status',
            NewMessageSearchStatus.searchSuccess,
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepo.searchUsers(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).called(1);
          verifyNever(
            () => mockProfileRepo.searchUsers(
              query: 'al',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          );
        },
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'keeps group mode and the selection through a search',
        setUp: () {
          when(
            () => mockProfileRepo.searchUsers(
              query: 'charlie',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) async => [charlie]);
        },
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          contacts: [alice, bob, charlie],
          isGroupMode: true,
          selectedRecipients: [bob, alice],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('charlie')),
        wait: debounceDuration,
        verify: (bloc) {
          expect(bloc.state.status, NewMessageSearchStatus.searchSuccess);
          expect(bloc.state.isGroupMode, isTrue);
          expect(bloc.state.selectedRecipients, equals([bob, alice]));
        },
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'keeps group mode and the selection when the query gets too short',
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.searchSuccess,
          contacts: [alice, bob],
          query: 'alice',
          results: [alice],
          isGroupMode: true,
          selectedRecipients: [bob, alice],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('a')),
        wait: debounceDuration,
        verify: (bloc) {
          expect(bloc.state.status, NewMessageSearchStatus.idle);
          expect(bloc.state.isGroupMode, isTrue);
          expect(bloc.state.selectedRecipients, equals([bob, alice]));
        },
      );
    });

    group('NewMessageSearchCleared', () {
      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'resets to idle and clears query and results',
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.searchSuccess,
          contacts: [createTestProfile('a' * 64, 'Alice')],
          query: 'alice',
          results: [createTestProfile('a' * 64, 'Alice')],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchCleared()),
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.status, 'status', NewMessageSearchStatus.idle)
              .having((s) => s.query, 'query', isEmpty)
              .having((s) => s.results, 'results', isEmpty)
              .having((s) => s.contacts, 'contacts preserved', hasLength(1)),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'keeps group mode and the selection',
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.searchSuccess,
          contacts: recipients(3),
          query: 'person',
          results: recipients(3),
          isGroupMode: true,
          selectedRecipients: recipients(2),
        ),
        act: (bloc) => bloc.add(const NewMessageSearchCleared()),
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.query, 'query', isEmpty)
              .having((s) => s.isGroupMode, 'isGroupMode', isTrue)
              .having(
                (s) => s.selectedRecipients.map((p) => p.pubkey),
                'selected pubkeys',
                [pubkeyAt(1), pubkeyAt(2)],
              ),
        ],
      );
    });

    group('NewMessageSearchGroupModeChanged', () {
      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'enters group mode with nobody selected',
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          contacts: recipients(2),
        ),
        act: (bloc) =>
            bloc.add(const NewMessageSearchGroupModeChanged(enabled: true)),
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.isGroupMode, 'isGroupMode', isTrue)
              .having((s) => s.selectedRecipients, 'selected', isEmpty)
              .having((s) => s.contacts, 'contacts preserved', hasLength(2)),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'leaves group mode and clears the selection',
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          isGroupMode: true,
          selectedRecipients: recipients(2),
        ),
        act: (bloc) =>
            bloc.add(const NewMessageSearchGroupModeChanged(enabled: false)),
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.isGroupMode, 'isGroupMode', isFalse)
              .having((s) => s.selectedRecipients, 'selected', isEmpty),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'keeps the selection when asked to enter the mode it is already in',
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          isGroupMode: true,
          selectedRecipients: recipients(2),
        ),
        act: (bloc) =>
            bloc.add(const NewMessageSearchGroupModeChanged(enabled: true)),
        expect: () => const <NewMessageSearchState>[],
        verify: (bloc) {
          expect(bloc.state.isGroupMode, isTrue);
          expect(bloc.state.selectedRecipients, hasLength(2));
        },
      );
    });

    group('NewMessageSearchRecipientToggled', () {
      NewMessageSearchState groupModeWith(List<UserProfile> selected) =>
          NewMessageSearchState(
            status: NewMessageSearchStatus.idle,
            isGroupMode: true,
            selectedRecipients: selected,
          );

      Iterable<String> selectedPubkeys(NewMessageSearchState state) =>
          state.selectedRecipients.map((profile) => profile.pubkey);

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'adds recipients in the order they were tapped',
        build: createBloc,
        seed: () => groupModeWith(const []),
        act: (bloc) {
          final people = recipients(2);
          bloc
            ..add(NewMessageSearchRecipientToggled(people[1]))
            ..add(NewMessageSearchRecipientToggled(people[0]));
        },
        expect: () => [
          isA<NewMessageSearchState>().having(selectedPubkeys, 'selected', [
            pubkeyAt(2),
          ]),
          isA<NewMessageSearchState>().having(selectedPubkeys, 'selected', [
            pubkeyAt(2),
            pubkeyAt(1),
          ]),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'removes a recipient who is already selected',
        build: createBloc,
        seed: () => groupModeWith(recipients(2)),
        act: (bloc) =>
            bloc.add(NewMessageSearchRecipientToggled(recipients(2).first)),
        expect: () => [
          isA<NewMessageSearchState>().having(selectedPubkeys, 'selected', [
            pubkeyAt(2),
          ]),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'never holds one pubkey twice: a second profile for a selected '
        'pubkey deselects it',
        build: createBloc,
        seed: () => groupModeWith(recipients(1)),
        // The same account reaches the list twice: once from the cached
        // follow list, once from network search with a newer kind 0. A
        // different event id makes the two profiles unequal, so only a
        // comparison by pubkey can match them.
        act: (bloc) => bloc.add(
          NewMessageSearchRecipientToggled(
            createTestProfile(
              pubkeyAt(1),
              'Person 1 from the network',
              eventId: 'a-newer-kind-0',
            ),
          ),
        ),
        expect: () => [
          isA<NewMessageSearchState>().having(
            (s) => s.selectedRecipients,
            'selected',
            isEmpty,
          ),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'never holds one pubkey twice: upper-case hex is the same person',
        build: createBloc,
        seed: () => groupModeWith([createTestProfile('ab' * 32, 'Abby')]),
        act: (bloc) => bloc.add(
          NewMessageSearchRecipientToggled(
            createTestProfile('AB' * 32, 'Abby'),
          ),
        ),
        expect: () => [
          isA<NewMessageSearchState>().having(
            (s) => s.selectedRecipients,
            'selected',
            isEmpty,
          ),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'ignores the signed-in user',
        build: createBloc,
        seed: () => groupModeWith(const []),
        act: (bloc) => bloc
          ..add(
            NewMessageSearchRecipientToggled(
              createTestProfile(currentUserPubkey, 'Me'),
            ),
          )
          ..add(
            NewMessageSearchRecipientToggled(
              createTestProfile(currentUserPubkey.toUpperCase(), 'Me'),
            ),
          )
          // The control: an ordinary recipient sent through the same handler
          // is added, so the empty selection above is the guard at work.
          ..add(NewMessageSearchRecipientToggled(recipients(1).single)),
        expect: () => [
          isA<NewMessageSearchState>().having(selectedPubkeys, 'selected', [
            pubkeyAt(1),
          ]),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'ignores a toggle outside group mode',
        build: createBloc,
        seed: () => const NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
        ),
        act: (bloc) =>
            bloc.add(NewMessageSearchRecipientToggled(recipients(1).single)),
        expect: () => const <NewMessageSearchState>[],
        verify: (bloc) => expect(bloc.state.selectedRecipients, isEmpty),
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'adds the ninth recipient, which fills a ten-person group',
        build: createBloc,
        seed: () => groupModeWith(recipients(8)),
        act: (bloc) =>
            bloc.add(NewMessageSearchRecipientToggled(recipients(9).last)),
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.selectedRecipients, 'selected', hasLength(9))
              .having((s) => s.isGroupFull, 'isGroupFull', isTrue),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'refuses a tenth recipient',
        build: createBloc,
        seed: () => groupModeWith(recipients(9)),
        act: (bloc) =>
            bloc.add(NewMessageSearchRecipientToggled(recipients(10).last)),
        expect: () => const <NewMessageSearchState>[],
        verify: (bloc) {
          expect(bloc.state.selectedRecipients, hasLength(9));
          expect(selectedPubkeys(bloc.state), isNot(contains(pubkeyAt(10))));
        },
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'still removes a recipient from a full group',
        build: createBloc,
        seed: () => groupModeWith(recipients(9)),
        act: (bloc) =>
            bloc.add(NewMessageSearchRecipientToggled(recipients(9).first)),
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.selectedRecipients, 'selected', hasLength(8))
              .having(selectedPubkeys, 'selected', isNot(contains(pubkeyAt(1))))
              .having((s) => s.isGroupFull, 'isGroupFull', isFalse),
        ],
      );
    });

    group('NewMessageSearchState', () {
      test('copyWith creates copy with updated values', () {
        const state = NewMessageSearchState();
        final updated = state.copyWith(
          status: NewMessageSearchStatus.idle,
          query: 'test',
        );

        expect(updated.status, NewMessageSearchStatus.idle);
        expect(updated.query, 'test');
        expect(updated.contacts, isEmpty);
        expect(updated.results, isEmpty);
      });

      test('copyWith preserves existing values when not specified', () {
        final profile = createTestProfile('a' * 64, 'Alice');
        final state = NewMessageSearchState(
          status: NewMessageSearchStatus.searchSuccess,
          contacts: [profile],
          query: 'alice',
          results: [profile],
        );

        final updated = state.copyWith(
          status: NewMessageSearchStatus.searching,
        );

        expect(updated.status, NewMessageSearchStatus.searching);
        expect(updated.contacts, hasLength(1));
        expect(updated.query, 'alice');
        expect(updated.results, hasLength(1));
      });

      test('isSearchActive returns true when query is not empty', () {
        const state = NewMessageSearchState(query: 'test');
        expect(state.isSearchActive, isTrue);
      });

      test('isSearchActive returns false when query is empty', () {
        const state = NewMessageSearchState();
        expect(state.isSearchActive, isFalse);
      });

      test('canStartGroup needs two recipients, because one is a '
          'one-to-one conversation', () {
        expect(
          NewMessageSearchState(selectedRecipients: recipients(1))
              .canStartGroup,
          isFalse,
        );
        expect(
          NewMessageSearchState(selectedRecipients: recipients(2))
              .canStartGroup,
          isTrue,
        );
      });

      test('isGroupFull is reached at nine recipients, the tenth person '
          'being the sender', () {
        expect(
          NewMessageSearchState(selectedRecipients: recipients(8)).isGroupFull,
          isFalse,
        );
        expect(
          NewMessageSearchState(selectedRecipients: recipients(9)).isGroupFull,
          isTrue,
        );
      });

      test('isSelected matches a pubkey whatever its hex case', () {
        final state = NewMessageSearchState(
          selectedRecipients: [createTestProfile('ab' * 32, 'Abby')],
        );

        expect(state.isSelected('ab' * 32), isTrue);
        expect(state.isSelected('AB' * 32), isTrue);
        expect(state.isSelected('cd' * 32), isFalse);
      });
    });

    // #8421: a send-target picker that matches on the raw kind-0 name lets a
    // row be found by a string it does not show, and hides it from the one it
    // does — the same defect #8204 fixed in ConversationListBloc.
    group('peer-name resolution', () {
      const vanishedPubkey =
          'b75b9a3131f4263add94ba20beb352a11032684f2dac07a7e1af827c6f3c1505';
      const alice =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const aliceNpub =
          'npub1424242424242424242424242424242424242424242424242424qamrcaj';
      const labels = DmPeerLabels(
        deletedAccount: 'Deleted account',
        moderation: 'Divine Moderation',
        formerModeration: 'Former moderation account',
        retiredConversationClosed: 'Conversation closed',
      );

      void stubContact(String pubkey, String name) {
        when(
          () => mockProfileRepo.getCachedProfile(pubkey: pubkey),
        ).thenAnswer((_) async => createTestProfile(pubkey, name));
      }

      void stubNoNetworkResults() {
        when(
          () => mockProfileRepo.searchUsers(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          ),
        ).thenAnswer((_) async => []);
      }

      void stubVanished(Set<String> pubkeys) {
        when(
          mockProfileRepo.watchVanishedPubkeys,
        ).thenAnswer((_) => Stream.value(pubkeys));
      }

      Future<void> loadThenSearch(
        NewMessageSearchBloc bloc,
        String query,
      ) async {
        bloc
          ..add(const NewMessageSearchPeerLabelsChanged(labels))
          ..add(const NewMessageSearchStarted());
        await pumpEventQueue();
        final settled = bloc.stream.firstWhere(
          (state) =>
              state.status == NewMessageSearchStatus.searchSuccess ||
              state.status == NewMessageSearchStatus.searchFailure,
        );
        bloc.add(NewMessageSearchQueryChanged(query));
        expect(
          (await settled).status,
          equals(NewMessageSearchStatus.searchSuccess),
        );
      }

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'finds a vanished peer by the substitute their row renders',
        setUp: () {
          stubVanished({vanishedPubkey});
          when(
            () => mockFollowRepo.followingPubkeys,
          ).thenReturn([vanishedPubkey]);
          stubContact(vanishedPubkey, 'Aeontropy');
          stubNoNetworkResults();
        },
        build: createBloc,
        act: (bloc) => loadThenSearch(bloc, 'Deleted'),
        verify: (bloc) {
          expect(
            bloc.state.results.map((p) => p.pubkey),
            contains(vanishedPubkey),
          );
        },
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'does not surface a vanished peer under their own kind-0 name',
        setUp: () {
          stubVanished({vanishedPubkey});
          when(
            () => mockFollowRepo.followingPubkeys,
          ).thenReturn([vanishedPubkey]);
          stubContact(vanishedPubkey, 'Aeontropy');
          stubNoNetworkResults();
        },
        build: createBloc,
        act: (bloc) => loadThenSearch(bloc, 'Aeontropy'),
        verify: (bloc) => expect(bloc.state.results, isEmpty),
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'filters network results by the name their row renders',
        setUp: () {
          stubVanished({vanishedPubkey});
          when(() => mockFollowRepo.followingPubkeys).thenReturn([]);
          when(
            () => mockProfileRepo.searchUsers(
              query: 'Aeontropy',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer(
            (_) async => [createTestProfile(vanishedPubkey, 'Aeontropy')],
          );
        },
        build: createBloc,
        act: (bloc) => loadThenSearch(bloc, 'Aeontropy'),
        verify: (bloc) => expect(bloc.state.results, isEmpty),
      );

      // The two below are the other half of that filter: it may only drop a
      // peer Divine renames. `searchUsers` merges Funnelcake REST with NIP-50
      // relay search and scores bio, npub prefix and fuzzy tokens, so a
      // candidate whose rendered name does not literally spell the query is
      // the normal case, not a mismatch.
      void stubNetworkResult(String query, UserProfile profile) {
        when(
          () => mockProfileRepo.searchUsers(
            query: query,
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          ),
        ).thenAnswer((_) async => [profile]);
      }

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'keeps a network result matched outside the name its row renders',
        setUp: () {
          stubVanished(const {});
          when(() => mockFollowRepo.followingPubkeys).thenReturn([]);
          // Models a bio match: the repository returns Alice for a query
          // her rendered name does not contain.
          stubNetworkResult('photographer', createTestProfile(alice, 'Alice'));
        },
        build: createBloc,
        act: (bloc) => loadThenSearch(bloc, 'photographer'),
        verify: (bloc) =>
            expect(bloc.state.results.map((p) => p.pubkey), [alice]),
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'keeps a network result found by the npub this sheet accepts',
        setUp: () {
          stubVanished(const {});
          when(() => mockFollowRepo.followingPubkeys).thenReturn([]);
          stubNetworkResult(aliceNpub, createTestProfile(alice, 'Alice'));
        },
        build: createBloc,
        // `NewMessageSheet` documents npub as a supported query and decodes
        // nothing itself, so dropping this result removes the paste path.
        act: (bloc) => loadThenSearch(bloc, aliceNpub),
        verify: (bloc) =>
            expect(bloc.state.results.map((p) => p.pubkey), [alice]),
      );

      test(
        're-filters an active search when a tombstone arrives later',
        () async {
          final vanished = StreamController<Set<String>>();
          when(
            mockProfileRepo.watchVanishedPubkeys,
          ).thenAnswer((_) => vanished.stream);
          when(
            () => mockFollowRepo.followingPubkeys,
          ).thenReturn([vanishedPubkey]);
          stubContact(vanishedPubkey, 'Aeontropy');
          stubNoNetworkResults();
          final bloc = createBloc();
          addTearDown(() async {
            await bloc.close();
            await vanished.close();
          });

          await loadThenSearch(bloc, 'Aeontropy');
          expect(
            bloc.state.results.map((p) => p.pubkey),
            contains(vanishedPubkey),
          );

          vanished.add({vanishedPubkey});
          await pumpEventQueue();

          expect(bloc.state.results, isEmpty);
        },
      );

      test(
        're-filters an active search when localized labels change',
        () async {
          stubVanished({vanishedPubkey});
          when(
            () => mockFollowRepo.followingPubkeys,
          ).thenReturn([vanishedPubkey]);
          stubContact(vanishedPubkey, 'Aeontropy');
          stubNoNetworkResults();
          final bloc = createBloc();
          addTearDown(bloc.close);

          await loadThenSearch(bloc, 'Removed');
          expect(bloc.state.results, isEmpty);

          bloc.add(
            const NewMessageSearchPeerLabelsChanged(
              DmPeerLabels(
                deletedAccount: 'Removed account',
                moderation: 'Divine Moderation',
                formerModeration: 'Former moderation account',
                retiredConversationClosed: 'Conversation closed',
              ),
            ),
          );
          await pumpEventQueue();

          expect(
            bloc.state.results.map((p) => p.pubkey),
            contains(vanishedPubkey),
          );
        },
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'finds the moderation account by the name its row shows',
        setUp: () {
          stubVanished(const {});
          when(
            () => mockFollowRepo.followingPubkeys,
          ).thenReturn([kModerationPubkeyHex]);
          stubContact(kModerationPubkeyHex, 'moderation-bot-v2');
          stubNoNetworkResults();
        },
        build: createBloc,
        act: (bloc) => loadThenSearch(bloc, 'Divine Moderation'),
        verify: (bloc) {
          expect(
            bloc.state.results.map((p) => p.pubkey),
            contains(kModerationPubkeyHex),
          );
        },
      );

      // Official branding follows recorded custody (#9963): the picker renders
      // a withdrawn retired key under the neutral label, so that is what the
      // search must match, and Divine's name must not find it.
      for (final custody in RetiredKeyCustody.values) {
        final retired = 'c' * 64;
        final withdrawn = custody.canStillSign;

        NewMessageSearchBloc createBlocFor() => NewMessageSearchBloc(
          profileRepository: mockProfileRepo,
          followRepository: mockFollowRepo,
          currentUserPubkey: currentUserPubkey,
          moderationPresentation: (pubkey) => moderationPresentationOf(
            pubkey,
            retiredKeys: [
              RetiredModerationKey(pubkeyHex: retired, custody: custody),
            ],
          ),
        );

        blocTest<NewMessageSearchBloc, NewMessageSearchState>(
          '${custody.name}: ${withdrawn ? "found by the neutral label, not "
                    "Divine's name" : "found by Divine's name, not the neutral "
                    "label"}',
          setUp: () {
            stubVanished(const {});
            when(() => mockFollowRepo.followingPubkeys).thenReturn([retired]);
            stubContact(retired, 'Looks Official');
            stubNoNetworkResults();
          },
          build: createBlocFor,
          act: (bloc) => loadThenSearch(
            bloc,
            withdrawn ? labels.formerModeration : labels.moderation,
          ),
          verify: (bloc) {
            expect(bloc.state.results.map((p) => p.pubkey), contains(retired));
          },
        );

        blocTest<NewMessageSearchBloc, NewMessageSearchState>(
          '${custody.name}: ${withdrawn ? "not found by Divine's name" : "not found by the neutral label"}',
          setUp: () {
            stubVanished(const {});
            when(() => mockFollowRepo.followingPubkeys).thenReturn([retired]);
            stubContact(retired, 'Looks Official');
            stubNoNetworkResults();
          },
          build: createBlocFor,
          act: (bloc) => loadThenSearch(
            bloc,
            withdrawn ? labels.moderation : labels.formerModeration,
          ),
          verify: (bloc) {
            expect(
              bloc.state.results.map((p) => p.pubkey),
              isNot(contains(retired)),
            );
          },
        );
      }

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'orders contacts by the rendered name, not the raw one',
        setUp: () {
          stubVanished({vanishedPubkey});
          when(
            () => mockFollowRepo.followingPubkeys,
          ).thenReturn([alice, vanishedPubkey]);
          stubContact(alice, 'Aaron');
          // Raw, "Aardvark" sorts first; rendered, "Deleted account" sorts
          // last. The two orders disagree, so only one of them can pass.
          stubContact(vanishedPubkey, 'Aardvark');
        },
        build: createBloc,
        act: (bloc) async {
          bloc
            ..add(const NewMessageSearchPeerLabelsChanged(labels))
            ..add(const NewMessageSearchStarted());
          await pumpEventQueue();
        },
        verify: (bloc) {
          expect(
            bloc.state.contacts.map((p) => p.displayName),
            equals(['Aaron', 'Aardvark']),
          );
        },
      );
    });
  });
}
