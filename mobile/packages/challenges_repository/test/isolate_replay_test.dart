import 'dart:convert';
import 'dart:isolate';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:challenges_repository/challenges_repository.dart';
import 'package:test/test.dart';

import 'harness.dart' show Harness;

class _BoundedStore implements BoundedRetainedChallengeStore {
  List<String> records = [];
  bool limited = false;
  @override
  Future<List<String>> load(String coordinate) async => records;
  @override
  Future<bool> isLimited(String coordinate) async => limited;
  @override
  Future<void> retain(String coordinate, List<String> value) async =>
      records = value;
  @override
  Future<void> replace(
    String coordinate,
    List<String> value, {
    required bool limited,
  }) async {
    records = value;
    this.limited = limited;
  }
}

void main() {
  group('real worker replay', () {
    test(
      'a capped source cannot permanently poison retained clean history',
      () async {
        final h = Harness();
        final store = _BoundedStore();
        var capped = true;
        final reads = ChallengesRepository(
          source: (_) async => RawChallengeRead(
            records: [jsonEncode(h.definition.toJson())],
            source: ReadSource.relay,
            completeness: ReadCompleteness.partial,
            revisionsComplete: true,
            retentionLimited: capped,
          ),
          store: store,
          clock: () => 150,
          isVisible: (_) => true,
        );
        final coordinate = '31923:${h.organizer.pubkey}:synthetic:challenge';
        expect(
          (await reads.refresh(coordinate)).observation.retentionLimited,
          isTrue,
        );
        expect(store.limited, isFalse);
        capped = false;
        expect(
          (await reads.refresh(coordinate)).observation.retentionLimited,
          isFalse,
        );
      },
    );
    test('production work boundary executes in named child isolate', () async {
      final caller = Isolate.current.debugName;
      final worker = await isolatedChallengeWork(
        () => Isolate.current.debugName,
      );
      expect(worker, 'challenge-replay');
      expect(worker, isNot(caller));
    });
    test(
      'visibility changed during worker await is rechecked before playback',
      () async {
        final h = Harness();
        final entry = h.creator.template(
          buildEntry(definitionOf(h.definition), h.video, 150),
        );
        final records = [jsonEncode(h.definition.toJson()), jsonEncode(entry)];
        var hidden = false;
        var calls = 0;
        Future<T> work<T>(T Function() job) async {
          final result = await isolatedChallengeWork(job);
          calls++;
          if (calls == 3) hidden = true;
          return result;
        }

        final reads = ChallengesRepository(
          source: (_) async => RawChallengeRead(
            records: records,
            source: ReadSource.relay,
            completeness: ReadCompleteness.partial,
            revisionsComplete: true,
          ),
          store: _BoundedStore(),
          clock: () => 150,
          isVisible: (event) => !(hidden && event.id == h.video.id),
          work: work,
        );
        final read = await reads.refresh(
          '31923:${h.organizer.pubkey}:synthetic:challenge',
        );
        expect(calls, greaterThan(3));
        expect(read.view.state, 'open');
        expect(read.view.entries, isEmpty);
        expect(read.completeEntryCount, isNull);
      },
    );
    test(
      'capacity keeps fresh rules but persists unavailable entry history',
      () async {
        final h = Harness();
        final entry = h.creator.template(
          buildEntry(definitionOf(h.definition), h.video, 150),
        );
        final store = _BoundedStore();
        var records = [jsonEncode(h.definition.toJson())];
        ChallengesRepository create() => ChallengesRepository(
          source: (_) async => RawChallengeRead(
            records: records,
            source: ReadSource.relay,
            completeness: ReadCompleteness.partial,
            revisionsComplete: true,
          ),
          store: store,
          clock: () => 150,
          isVisible: (_) => true,
          work: isolatedChallengeWork,
          limits: const ReadLimits(maxRecords: 1),
        );
        final coordinate = '31923:${h.organizer.pubkey}:synthetic:challenge';
        await create().refresh(coordinate);
        records = [jsonEncode(entry)];
        final limited = await create().refresh(coordinate);
        expect(limited.view.state, 'open');
        expect(limited.observation.retentionLimited, isTrue);
        expect(limited.view.entries, isEmpty);
        expect(store.records, hasLength(1));
        records = [
          jsonEncode(
            h.organizer.sign(
              createdAt: 151,
              tags: [
                ['d', 'synthetic:challenge'],
              ],
            ),
          ),
        ];
        final invalid = await create().refresh(coordinate);
        expect(invalid.view.state, 'unavailable');
        expect(invalid.observation.retentionLimited, isTrue);
        records = [jsonEncode(h.definition.toJson())];
        expect((await create().refresh(coordinate)).view.state, 'unavailable');
      },
    );
  });
}

ChallengeDefinition definitionOf(NostrEvent event) =>
    parseChallengeEvent(event).value! as ChallengeDefinition;
