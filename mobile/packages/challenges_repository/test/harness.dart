import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:challenges_repository/challenges_repository.dart';
import 'package:test/test.dart';

import 'synthetic.dart';

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

class Harness {
  Harness() {
    definition = NostrEvent.fromJson(organizer.definition());
    video = NostrEvent.fromJson(
      creator.sign(
        kind: 34236,
        tags: [
          ['d', 'synthetic:video'],
        ],
      ),
    );
    owner = creator.pubkey;
    videoId = video.id;
    source = FakeSource([jsonEncode(definition.toJson())]);
    reads = ChallengesRepository(
      source: source.read,
      store: retained,
      clock: () => now,
      isVisible: (event) => !hidden.contains(event.id),
    );
    transport.beforePublish = () {
      expect(
        store.actions,
        isNotEmpty,
        reason: 'Publication must follow durable insertion.',
      );
    };
    repository = createRepository();
  }
  final organizer = SyntheticSigner();
  final creator = SyntheticSigner();
  late NostrEvent definition;
  late NostrEvent video;
  late String? owner;
  late String? videoId;
  int now = 150;
  int signatures = 0;
  final hidden = <String>{};
  bool publicationAllowed = true;
  final relay = 'wss://relay.example.test';
  late FakeSource source;
  final retained = MemoryStore();
  late ChallengesRepository reads;
  final store = Outbox();
  final transport = Transport();
  late ChallengeSubmissionRepository repository;
  Future<String> Function(UnsignedChallengeAction)? signer;
  ChallengeSubmissionRepository createRepository() =>
      ChallengeSubmissionRepository(
        reads: reads,
        store: store,
        transport: transport.publish,
        currentOwner: () => owner,
        canPublish: (_) => publicationAllowed,
        currentVideoId: (_) => videoId,
        writableRelays: () => ['wss://configured.example.test'],
        sign: (fields) async {
          signatures++;
          if (signer != null) return signer!(fields);
          return signFields(fields);
        },
      );
  String signFields(UnsignedChallengeAction fields) => jsonEncode(
    creator.sign(
      kind: fields.kind,
      createdAt: fields.createdAt,
      content: fields.content,
      tags: fields.tags,
    ),
  );
  Future<SubmissionReview> prepare({
    List<List<String>> clientTags = const [],
  }) => repository.prepareEntry(
    definition: definition,
    video: video,
    clientTags: clientTags,
  );
}

class Outbox implements ChallengeSubmissionStore {
  final actions = <String, PendingChallengeAction>{};
  final reviews = <String, SubmissionReview>{};
  bool failInsert = false;
  void Function()? onLoad;
  void Function()? onInsert;
  void Function()? onSave;
  void Function()? onReview;
  @override
  Future<void> saveReview(String owner, SubmissionReview review) async {
    reviews['$owner:${review.id}'] = review;
    onReview?.call();
  }

  @override
  Future<SubmissionReview?> loadReview(String owner, String reviewId) async =>
      reviews['$owner:$reviewId'];
  @override
  Future<List<PendingChallengeAction>> listActions(String owner) async =>
      actions.values.where((action) => action.review.owner == owner).toList();
  @override
  Future<PendingChallengeAction?> loadAction(
    String owner,
    String reviewId,
  ) async {
    onLoad?.call();
    return actions['$owner:$reviewId'];
  }

  @override
  Future<PendingChallengeAction> insertAction(
    String owner,
    PendingChallengeAction action,
  ) async {
    onInsert?.call();
    if (failInsert) throw Exception('Synthetic durable storage failure');
    return actions.putIfAbsent('$owner:${action.review.id}', () => action);
  }

  @override
  Future<void> saveAction(String owner, PendingChallengeAction action) async {
    actions['$owner:${action.review.id}'] = action;
    onSave?.call();
  }
}

class Transport {
  final bodies = <String>[];
  Map<String, RelayOutcome> outcomes = {};
  void Function()? beforePublish;
  void Function()? onPublish;
  Future<Map<String, RelayOutcome>> publish(
    String signedBody,
    List<String> targets,
  ) async {
    beforePublish?.call();
    expect(
      targets,
      containsAll([
        'wss://relay.example.test',
        'wss://configured.example.test',
      ]),
    );
    bodies.add(signedBody);
    onPublish?.call();
    return outcomes;
  }
}
