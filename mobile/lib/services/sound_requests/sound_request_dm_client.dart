// ABOUTME: Adapts sound request intents to the existing durable DM outbox.
// ABOUTME: Stable keys and timestamps survive crashes between enqueue and save.
import 'package:dm_repository/dm_repository.dart';
import 'package:models/models.dart';

class SoundRequestDmClient implements SoundRequestTransport {
  SoundRequestDmClient({
    required DmRepository repository,
    required this.ownerPubkey,
  }) : _repository = repository;
  final DmRepository _repository;
  final String ownerPubkey;
  void _checkAccount() {
    if (_repository.userPubkey != ownerPubkey) {
      throw StateError('DM account changed');
    }
  }

  @override
  Stream<List<DmMessage>> watchMessages() {
    _checkAccount();
    return _repository.watchSoundRequestMessages();
  }

  @override
  Future<String> enqueue(SoundRequestSendIntent intent) async {
    _checkAccount();
    final history = await _repository.watchSoundRequestMessages().first;
    _checkAccount();
    final delivered = history
        .where(
          (m) =>
              m.senderPubkey == ownerPubkey &&
              m.tags.any(
                (t) => t.length == 2 && t[0] == 'batch' && t[1] == intent.key,
              ),
        )
        .firstOrNull;
    if (delivered != null) return delivered.id;
    final result = await _repository.enqueueSend(
      recipientPubkey: intent.recipient,
      content: intent.content,
      idempotencyKey: intent.key,
      createdAt: intent.createdAt,
      additionalTags: intent.tags,
    );
    _checkAccount();
    if (!result.accepted) throw StateError('Sound request delivery refused');
    return result.queuedRumorId!;
  }

  @override
  Future<void> retry(String rumorId) async {
    _checkAccount();
    final history = await _repository.watchSoundRequestMessages().first;
    _checkAccount();
    if (history.any((m) => m.id == rumorId && m.senderPubkey == ownerPubkey)) {
      return;
    }
    final result = await _repository.recoverFullSend(rumorId: rumorId);
    _checkAccount();
    if (!result.success) throw StateError('Sound request delivery pending');
  }
}
