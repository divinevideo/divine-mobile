import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';

class _Repository extends Mock implements ConcordRepository {}

void main() {
  group('ChatCubit room selection', () {
    test('shows only messages from the selected channel', () async {
      final repository = _Repository();
      final general = ChatMessage(
        id: 'a' * 64,
        channelId: 'general',
        author: 'c' * 64,
        body: 'first room',
        createdAt: 1,
      );
      final introduction = ChatMessage(
        id: 'b' * 64,
        channelId: 'introductions',
        author: 'c' * 64,
        body: 'second room',
        createdAt: 2,
      );
      when(() => repository.timeline(now: 3))
          .thenReturn(FoldedThread([general, introduction], {}));
      when(() => repository.pendingIds).thenReturn([]);
      final cubit = ChatCubit(repository)..refresh(now: 3);
      addTearDown(cubit.close);
      expect(cubit.visibleMessages(), [general]);
      cubit.selectChannel('community-test', 'introductions');
      expect(cubit.visibleMessages(), [introduction]);
    });
  });
}
