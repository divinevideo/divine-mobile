import 'dart:convert';

import 'package:challenges_repository/challenges_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:openvine/services/challenges/challenge_record_codec.dart';

/// One durable lease per authenticated app session. No signing material is
/// retained. Removal revokes this generation even if an awaited write is late.
class SqliteChallengeStore
    implements BoundedRetainedChallengeStore, ChallengeSubmissionStore {
  SqliteChallengeStore._(
    this.dao,
    this.owner,
    this.generation,
    this.currentOwner,
  );
  final ChallengeRecordsDao dao;
  final String owner;
  final String generation;
  final String? Function() currentOwner;

  static Future<SqliteChallengeStore> open({
    required ChallengeRecordsDao dao,
    required String owner,
    required String? Function() currentOwner,
  }) async {
    if (currentOwner() != owner) throw const ChallengeOwnerRevoked();
    final generation = await dao.openOwner(owner);
    if (currentOwner() != owner) throw const ChallengeOwnerRevoked();
    return SqliteChallengeStore._(dao, owner, generation, currentOwner);
  }

  bool _revoked = false;

  Future<void> retire() async {
    _revoked = true;
  }

  void checkCurrent() {
    if (_revoked || currentOwner() != owner) {
      throw const ChallengeOwnerRevoked();
    }
  }

  Future<void> checkLive() async {
    checkCurrent();
    await dao.checkOwner(owner, generation);
    checkCurrent();
  }

  void _checkOwner(String candidate) {
    if (candidate != owner) throw const ChallengeOwnerRevoked();
  }

  Future<String?> readRecord(String category, String key) async {
    checkCurrent();
    final rows = await dao.read(owner, generation, category);
    checkCurrent();
    return rows.where((row) => row.recordKey == key).firstOrNull?.payload;
  }

  Future<void> writeRecord(String category, String key, String payload) async {
    checkCurrent();
    await dao.put(owner, generation, category, key, payload);
    checkCurrent();
  }

  @override
  Future<List<String>> load(String coordinate) async {
    final body = await readRecord('retained', coordinate);
    if (body == null) return [];
    return ((jsonDecode(body) as Map<String, dynamic>)['records']
            as List<dynamic>)
        .cast<String>();
  }

  @override
  Future<bool> isLimited(String coordinate) async {
    final body = await readRecord('retained', coordinate);
    return body != null &&
        (jsonDecode(body) as Map<String, dynamic>)['limited'] == true;
  }

  @override
  Future<void> retain(String coordinate, List<String> records) async => replace(
    coordinate,
    {...await load(coordinate), ...records}.toList(),
    limited: await isLimited(coordinate),
  );

  @override
  Future<void> replace(
    String coordinate,
    List<String> records, {
    required bool limited,
  }) => writeRecord(
    'retained',
    coordinate,
    jsonEncode({'version': 1, 'limited': limited, 'records': records}),
  );

  @override
  Future<void> saveReview(String owner, SubmissionReview review) async {
    _checkOwner(owner);
    if (review.owner != owner) throw const ChallengeOwnerRevoked();
    await writeRecord(
      'review',
      review.id,
      jsonEncode(ChallengeRecordCodec.review(review)),
    );
  }

  @override
  Future<SubmissionReview?> loadReview(String owner, String reviewId) async {
    _checkOwner(owner);
    final body = await readRecord('review', reviewId);
    if (body == null) return null;
    final review = ChallengeRecordCodec.readReview(
      jsonDecode(body) as Map<String, dynamic>,
    );
    if (review.owner != owner || review.id != reviewId) {
      throw const FormatException('Invalid review ownership');
    }
    return review;
  }

  @override
  Future<List<PendingChallengeAction>> listActions(String owner) async {
    _checkOwner(owner);
    checkCurrent();
    final rows = await dao.read(owner, generation, 'action');
    checkCurrent();
    return rows.map((row) {
      final action = ChallengeRecordCodec.readAction(row.payload);
      if (action.review.owner != owner ||
          action.review.id != row.recordKey ||
          action.signedBody != row.signedBody) {
        throw const FormatException('Invalid outbox ownership');
      }
      return action;
    }).toList();
  }

  @override
  Future<PendingChallengeAction?> loadAction(
    String owner,
    String reviewId,
  ) async =>
      (await listActions(owner))
          .where((a) => a.review.id == reviewId)
          .firstOrNull;

  @override
  Future<PendingChallengeAction> insertAction(
    String owner,
    PendingChallengeAction action,
  ) async {
    _checkOwner(owner);
    checkCurrent();
    if (action.review.owner != owner) throw const ChallengeOwnerRevoked();
    final payload = await dao.put(
      owner,
      generation,
      'action',
      action.review.id,
      ChallengeRecordCodec.action(action),
      signedBody: action.signedBody,
      insertOnly: true,
    );
    return ChallengeRecordCodec.readAction(payload);
  }

  @override
  Future<void> saveAction(String owner, PendingChallengeAction action) async {
    _checkOwner(owner);
    if (action.review.owner != owner) throw const ChallengeOwnerRevoked();
    // ACKs may finish after a normal account switch. They still belong to the
    // original owner; a durable removal generation rejects this write.
    final old = (await dao.read(
      owner,
      generation,
      'action',
    )).where((row) => row.recordKey == action.review.id).firstOrNull;
    if (old == null) throw const ChallengeOwnerRevoked();
    await dao.put(
      owner,
      generation,
      'action',
      action.review.id,
      ChallengeRecordCodec.action(action),
      signedBody: action.signedBody,
    );
  }
}
