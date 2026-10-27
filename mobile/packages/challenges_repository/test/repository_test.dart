import 'dart:convert';

import 'package:challenges_repository/challenges_repository.dart';
import 'package:test/test.dart';

import 'synthetic.dart';

void main() {
  group('known challenge reads', () {
    for (final badRecord in ['{', '[]', 'null', 'true', '42', '"text"']) {
      test(
        'recovers from non-event input $badRecord without retaining it',
        () async {
          final h = ReadHarness();
          final store = h.repository.store;
          expect((await h.repository.refresh(h.coordinate)).view.state, 'open');
          h.source.records = [badRecord];
          expect(
            (await h.repository.refresh(h.coordinate)).view.state,
            'unavailable',
          );
          expect(await store.load(h.coordinate), isNot(contains(badRecord)));
          h.source.records = [jsonEncode(h.definition)];
          expect((await h.repository.refresh(h.coordinate)).view.state, 'open');
          final restarted = ChallengesRepository(
            source: h.source.read,
            store: store,
            clock: () => 150,
            isVisible: (_) => true,
          );
          expect((await restarted.refresh(h.coordinate)).view.state, 'open');
        },
      );
    }
    test(
      'legacy malformed JSON and nonobjects cannot poison retained replay',
      () async {
        final h = ReadHarness();
        await h.repository.store.retain(h.coordinate, [
          '{',
          '[]',
          'null',
          '42',
          '"text"',
        ]);
        final recovered = await h.repository.refresh(h.coordinate);
        expect(recovered.view.state, 'open');
        expect(recovered.observation.completeness, ReadCompleteness.complete);
        final restarted = ChallengesRepository(
          source: h.source.read,
          store: h.repository.store,
          clock: () => 150,
          isVisible: (_) => true,
        );
        expect((await restarted.refresh(h.coordinate)).view.state, 'open');
      },
    );
    test(
      'bad JSON does not discard an authenticated unmarked newest revision',
      () async {
        final h = ReadHarness();
        expect((await h.repository.refresh(h.coordinate)).view.state, 'open');
        final newer = jsonEncode(
          h.signer.sign(
            createdAt: 101,
            tags: [
              ['d', 'synthetic:challenge'],
            ],
          ),
        );
        h.source.records = ['{', newer];
        expect(
          (await h.repository.refresh(h.coordinate)).view.state,
          'unavailable',
        );
        expect(await h.repository.store.load(h.coordinate), contains(newer));
        h.source.records = [jsonEncode(h.definition)];
        final restarted = ChallengesRepository(
          source: h.source.read,
          store: h.repository.store,
          clock: () => 150,
          isVisible: (_) => true,
        );
        expect(
          (await restarted.refresh(h.coordinate)).view.state,
          'unavailable',
        );
      },
    );

    test('partial revisions never report cached old rules as open', () async {
      final h = ReadHarness();
      expect((await h.repository.refresh(h.coordinate)).view.state, 'open');
      h.source.records = [];
      h.source.completeness = ReadCompleteness.partial;
      final result = await h.repository.refresh(h.coordinate);
      expect(result.view.state, 'unavailable');
      expect(result.observation.completeness, ReadCompleteness.partial);
      expect(result.completeEntryCount, isNull);
    });
    test(
      'raw observations copy mutable input and ignore forged projections',
      () async {
        final h = ReadHarness();
        final body = jsonEncode(h.definition);
        final input = [body];
        final observation = RawChallengeRead(
          records: input,
          source: ReadSource.indexedApi,
          completeness: ReadCompleteness.complete,
          indexedAt: 145,
        );
        input[0] = '{}';
        h.source.observation = observation;
        final valid = await h.repository.refresh(h.coordinate);
        expect(valid.view.state, 'open');
        expect(valid.completeEntryCount, 0);
        expect(valid.observation.indexedAt, 145);
        final forged = {
          ...h.definition,
          'content': 'Forged rules',
          'created_at': 199,
        };
        h.source.observation = null;
        h.source.records = [jsonEncode(forged)];
        expect(
          (await h.repository.refresh(h.coordinate)).view.definition!.event.id,
          h.definition['id'],
        );
      },
    );
    test(
      'failed and malformed JSON reads do not return an empty success',
      () async {
        final h = ReadHarness();
        h.source.fail = true;
        var result = await h.repository.refresh(h.coordinate);
        expect(result.observation.completeness, ReadCompleteness.unavailable);
        expect(result.completeEntryCount, isNull);
        h.source.fail = false;
        h.source.records = ['{'];
        result = await h.repository.refresh(h.coordinate);
        expect(result.view.state, 'unavailable');
        expect(result.observation.completeness, ReadCompleteness.unavailable);
      },
    );
    test(
      'oversized signed newest definition remains in retained replay',
      () async {
        final h = ReadHarness();
        await h.repository.refresh(h.coordinate);
        h.source.records = [
          jsonEncode(h.signer.definition(createdAt: 101, content: 'a' * 70000)),
        ];
        expect(
          (await h.repository.refresh(h.coordinate)).view.state,
          'unavailable',
        );
        h.source.records = [];
        expect(
          (await h.repository.refresh(h.coordinate)).view.state,
          'unavailable',
        );
      },
    );
    for (final limits in [
      const ReadLimits(maxRecords: 0),
      const ReadLimits(maxRecordBytes: 20),
      const ReadLimits(maxBytes: 20),
    ]) {
      test('bounds raw records before parsing with $limits', () async {
        final h = ReadHarness(limits: limits);
        final read = await h.repository.refresh(h.coordinate);
        expect(read.observation.completeness, ReadCompleteness.unavailable);
        expect(read.view.state, 'unavailable');
      });
    }
    test(
      'complete known relay read never claims a complete indexed count',
      () async {
        final h = ReadHarness();
        h.source.observation = RawChallengeRead(
          records: h.source.records,
          source: ReadSource.relay,
          completeness: ReadCompleteness.complete,
        );
        final result = await h.repository.refresh(h.coordinate);
        expect(result.view.state, 'open');
        expect(result.completeEntryCount, isNull);
      },
    );
    test(
      'authenticated unmarked newest revision cannot reopen old rules',
      () async {
        final signer = SyntheticSigner();
        final definition = signer.definition();
        final newer = signer.sign(
          createdAt: 101,
          tags: [
            ['d', 'synthetic:challenge'],
          ],
        );
        final source = FakeSource([jsonEncode(definition)]);
        final repository = ChallengesRepository(
          source: source.read,
          store: MemoryStore(),
          clock: () => 150,
          isVisible: (_) => true,
        );
        final coordinate = definitionOf(definition).coordinate;
        expect((await repository.refresh(coordinate)).view.state, 'open');
        source.records = [jsonEncode(newer)];
        expect(
          (await repository.refresh(coordinate)).view.state,
          'unavailable',
        );
        source.records = [];
        expect(
          (await repository.refresh(coordinate)).view.state,
          'unavailable',
        );
      },
    );
  });
}

class FakeSource {
  FakeSource(this.records);
  List<String> records;
  bool fail = false;
  RawChallengeRead? observation;
  Future<void> Function()? beforeRead;
  ReadCompleteness completeness = ReadCompleteness.complete;
  Future<RawChallengeRead> read(String coordinate) async {
    await beforeRead?.call();
    if (fail) throw Exception('Synthetic read failure');
    return observation ??
        RawChallengeRead(
          records: records,
          source: ReadSource.indexedApi,
          completeness: completeness,
          indexedAt: 145,
        );
  }
}

class MemoryStore implements RetainedChallengeStore {
  final records = <String, Set<String>>{};
  @override
  Future<List<String>> load(String coordinate) async =>
      records[coordinate]?.toList() ?? [];
  @override
  Future<void> retain(String coordinate, List<String> values) async {
    records.putIfAbsent(coordinate, () => {}).addAll(values);
  }
}

class ReadHarness {
  ReadHarness({ReadLimits limits = const ReadLimits()}) {
    definition = signer.definition();
    coordinate = definitionOf(definition).coordinate;
    source = FakeSource([jsonEncode(definition)]);
    repository = ChallengesRepository(
      source: source.read,
      store: MemoryStore(),
      clock: () => 150,
      isVisible: (_) => true,
      limits: limits,
    );
  }
  final signer = SyntheticSigner();
  late Map<String, Object?> definition;
  late String coordinate;
  late FakeSource source;
  late ChallengesRepository repository;
}
