// ABOUTME: Tests reading a video's poll with its votes, counted by Funnelcake
// ABOUTME: or on the device, and publishing a viewer's vote on it.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:poll_repository/poll_repository.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

String _hex(int n) => n.toRadixString(16).padLeft(64, '0');

final String _author = _hex(1);
final String _viewer = _hex(2);
final String _pollId = _hex(100);
const _relay = 'wss://relay.divine.video';

/// Stands for the default viewer, so a test can still pass `null`.
const _viewerKey = 'viewer';

final _poll = Poll.choice(question: 'Which?', answers: const ['Red', 'Blue']);

Event _pollEvent({String? pubkey, String? id}) => Event.fromJson({
  'id': id ?? _pollId,
  'pubkey': pubkey ?? _author,
  'created_at': 1000,
  'kind': Poll.eventKind,
  'tags': _poll.toTags(),
  'content': _poll.question,
  'sig': '',
});

Event _vote(String voter, String optionId) => Event.fromJson({
  'id': _hex(voter.hashCode + optionId.hashCode),
  'pubkey': voter,
  'created_at': 2000,
  'kind': Poll.voteKind,
  'tags': Poll.voteTags(_pollId, optionId),
  'content': '',
  'sig': '',
});

PublishOutcome _outcome({required bool accepted}) => PublishOutcome(
  eventId: _hex(5),
  acceptedBy: accepted ? const [_relay] : const [],
  rejectedBy: accepted ? const {} : const {_relay: 'blocked: kind'},
  noResponseFrom: const [],
);

void main() {
  late _MockNostrClient nostrClient;
  late List<({int kind, String content, List<List<String>> tags})> signed;
  late Event? signedEvent;

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_pollEvent());
  });

  setUp(() {
    nostrClient = _MockNostrClient();
    signed = [];
    signedEvent = _vote(_viewer, '1');
  });

  PollRepository repository({
    FunnelcakeApiClient? funnelcakeApiClient,
    String? viewer = _viewerKey,
  }) => PollRepository(
    nostrClient: nostrClient,
    signEvent:
        ({
          required kind,
          required content,
          required tags,
        }) async {
          signed.add((kind: kind, content: content, tags: tags));
          return signedEvent;
        },
    currentPubkey: () => viewer == _viewerKey ? _viewer : viewer,
    funnelcakeApiClient: funnelcakeApiClient,
    relayUrl: _relay,
  );

  group(PollRepository, () {
    group('fetchPoll', () {
      test('reads the poll and its votes in one request', () async {
        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _pollEvent(),
            _vote(_hex(3), '0'),
            _vote(_viewer, '1'),
          ],
        );

        final snapshot = await repository().fetchPoll(
          _pollId,
          authorPubkey: _author,
        );

        expect(snapshot?.poll.id, equals(_pollId));
        expect(snapshot?.results.counts, equals({'0': 1, '1': 1}));
        expect(snapshot?.results.ownVoteId, equals('1'));
        final filters =
            verify(() => nostrClient.queryEvents(captureAny())).captured.single
                as List<Filter>;
        expect(filters.first.ids, equals([_pollId]));
        expect(filters.last.kinds, equals([Poll.voteKind]));
        expect(filters.last.e, equals([_pollId]));
        expect(filters.last.limit, equals(PollRepository.maxVotesRead));
      });

      test('finds no poll published by someone else than the video '
          'creator', () async {
        when(
          () => nostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [_pollEvent(pubkey: _hex(9))]);

        expect(
          await repository().fetchPoll(_pollId, authorPubkey: _author),
          isNull,
        );
      });
    });

    group('fetchPoll with Funnelcake', () {
      late _MockFunnelcakeApiClient funnelcake;

      setUp(() {
        funnelcake = _MockFunnelcakeApiClient();
        when(() => funnelcake.isAvailable).thenReturn(true);
      });

      List<List<Filter>> queried() => verify(
        () => nostrClient.queryEvents(captureAny()),
      ).captured.cast<List<Filter>>();

      test("takes the count from Funnelcake and only the viewer's own vote "
          'from the relays', () async {
        when(() => funnelcake.getPollResults(_pollId)).thenAnswer(
          (_) async => const PollVoteTally(votes: {'0': 4, '1': 0}, voters: 4),
        );
        when(
          () => nostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [_pollEvent(), _vote(_viewer, '0')]);

        final snapshot = await repository(
          funnelcakeApiClient: funnelcake,
        ).fetchPoll(_pollId, authorPubkey: _author);

        expect(snapshot?.results.counts, equals({'0': 4}));
        expect(snapshot?.results.ownVoteId, equals('0'));
        final filters = queried().single;
        expect(filters.first.ids, equals([_pollId]));
        expect(filters.last.authors, equals([_viewer]));
        expect(filters.last.e, equals([_pollId]));
        expect(filters.last.limit, isNull);
      });

      test("still counts a vote of the viewer's that Funnelcake has not "
          'seen yet', () async {
        when(() => funnelcake.getPollResults(_pollId)).thenAnswer(
          (_) async => const PollVoteTally(votes: {'0': 4}, voters: 4),
        );
        when(
          () => nostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [_pollEvent(), _vote(_viewer, '1')]);

        final snapshot = await repository(
          funnelcakeApiClient: funnelcake,
        ).fetchPoll(_pollId, authorPubkey: _author);

        expect(snapshot?.results.counts, equals({'0': 4, '1': 1}));
        expect(snapshot?.results.ownVoteId, equals('1'));
      });

      test('reads only the poll for a viewer who is not signed in', () async {
        when(() => funnelcake.getPollResults(_pollId)).thenAnswer(
          (_) async => const PollVoteTally(votes: {'1': 2}, voters: 2),
        );
        when(
          () => nostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [_pollEvent()]);

        final snapshot = await repository(
          funnelcakeApiClient: funnelcake,
          viewer: null,
        ).fetchPoll(_pollId, authorPubkey: _author);

        expect(snapshot?.results.counts, equals({'1': 2}));
        expect(snapshot?.results.ownVoteId, isNull);
        expect(queried().single, hasLength(1));
      });

      test('counts on the device when Funnelcake does not answer', () async {
        when(
          () => funnelcake.getPollResults(_pollId),
        ).thenThrow(const FunnelcakeTimeoutException());
        when(() => nostrClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments.first as List<Filter>;
          return filters.last.limit == PollRepository.maxVotesRead
              ? [_pollEvent(), _vote(_hex(3), '1'), _vote(_viewer, '0')]
              : [_pollEvent(), _vote(_viewer, '0')];
        });

        final snapshot = await repository(
          funnelcakeApiClient: funnelcake,
        ).fetchPoll(_pollId, authorPubkey: _author);

        expect(snapshot?.results.counts, equals({'0': 1, '1': 1}));
        expect(snapshot?.results.ownVoteId, equals('0'));
        expect(queried(), hasLength(2));
      });

      test('counts on the device when Funnelcake is not configured', () async {
        when(() => funnelcake.isAvailable).thenReturn(false);
        when(
          () => nostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [_pollEvent(), _vote(_hex(3), '1')]);

        final snapshot = await repository(
          funnelcakeApiClient: funnelcake,
        ).fetchPoll(_pollId, authorPubkey: _author);

        expect(snapshot?.results.counts, equals({'1': 1}));
        verifyNever(() => funnelcake.getPollResults(any()));
      });

      test('finds no poll published by someone else than the video '
          'creator', () async {
        when(() => funnelcake.getPollResults(_pollId)).thenAnswer(
          (_) async => const PollVoteTally(votes: {'0': 1}, voters: 1),
        );
        when(
          () => nostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [_pollEvent(pubkey: _hex(9))]);

        expect(
          await repository(
            funnelcakeApiClient: funnelcake,
          ).fetchPoll(_pollId, authorPubkey: _author),
          isNull,
        );
      });
    });

    group('vote', () {
      test('signs and publishes a vote for the answer', () async {
        when(
          () => nostrClient.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _outcome(accepted: true));
        final poll = Poll.fromEvent(_pollEvent())!;

        await repository().vote(poll, '1');

        expect(signed.single.kind, equals(Poll.voteKind));
        expect(signed.single.content, isEmpty);
        expect(
          signed.single.tags,
          equals(Poll.voteTags(_pollId, '1', relayUrl: _relay)),
        );
        verify(() => nostrClient.publishEventAwaitOk(signedEvent!)).called(1);
      });

      test('refuses an answer the poll does not have', () async {
        final poll = Poll.fromEvent(_pollEvent())!;

        await expectLater(
          repository().vote(poll, '7'),
          throwsA(isA<ArgumentError>()),
        );
        expect(signed, isEmpty);
      });

      test('fails when the vote cannot be signed', () async {
        signedEvent = null;
        final poll = Poll.fromEvent(_pollEvent())!;

        await expectLater(
          repository().vote(poll, '0'),
          throwsA(
            isA<PollVoteException>().having(
              (e) => e.outcome,
              'outcome',
              isNull,
            ),
          ),
        );
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('fails when no relay takes the vote', () async {
        when(
          () => nostrClient.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _outcome(accepted: false));
        final poll = Poll.fromEvent(_pollEvent())!;

        await expectLater(
          repository().vote(poll, '0'),
          throwsA(
            isA<PollVoteException>()
                .having((e) => e.outcome?.failed, 'failed', isTrue)
                .having(
                  (e) => e.toString(),
                  'toString',
                  startsWith('PollVoteException: No relay took the vote'),
                ),
          ),
        );
      });
    });
  });
}
