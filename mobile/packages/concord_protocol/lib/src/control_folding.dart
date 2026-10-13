// MPL-2.0
import 'package:concord_protocol/src/models.dart';

class FoldedThread {
  FoldedThread(this.messages, this.reactions);
  final List<ChatMessage> messages;
  final Map<String, Map<String, int>> reactions;
}

/// Folds control events over base messages in createdAt order: edits
/// replace the body, deletes drop the message, reactions tally by emoji.
/// Expired messages are dropped relative to [now].
FoldedThread foldControls(
  List<ChatMessage> base,
  List<ControlEvent> controls, {
  required int now,
}) {
  final byId = <String, ChatMessage>{for (final m in base) m.id: m};
  final reactions = <String, Map<String, int>>{};
  final sorted = [...controls]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  for (final c in sorted) {
    switch (c.type) {
      case ControlType.edit:
        final m = byId[c.targetId];
        if (m != null && c.actor == m.author && c.body != null) {
          byId[c.targetId] = ChatMessage(
            id: m.id,
            channelId: m.channelId,
            author: m.author,
            body: m.body,
            createdAt: m.createdAt,
            threadRootId: m.threadRootId,
            expiresAt: m.expiresAt,
            editedBody: c.body,
          );
        }
      case ControlType.delete:
        if (byId[c.targetId]?.author == c.actor) {
          byId.remove(c.targetId);
        }
      case ControlType.reaction:
        if (c.emoji != null) {
          final tally = reactions.putIfAbsent(c.targetId, () => {});
          tally[c.emoji!] = (tally[c.emoji!] ?? 0) + 1;
        }
    }
  }
  final messages = byId.values.where((m) => !m.isExpiredAt(now)).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return FoldedThread(messages, reactions);
}
