import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_page.dart';

class _Relay extends Mock implements RelayGateway {}

class _Cipher extends Mock implements StreamCipher {}

void main() {
  group('selectChatRoom', () {
    late ChatCubit cubit;
    setUp(() {
      cubit = ChatCubit(
        ConcordRepository(
          relay: _Relay(),
          store: InMemoryConcordStore('a' * 64),
          cipher: _Cipher(),
        ),
      );
    });
    tearDown(() => cubit.close());

    test('opens the requested channel instead of the default', () {
      expect(
        selectChatRoom(
          cubit,
          communityId: 'community-test',
          channelId: 'introductions',
        ),
        isTrue,
      );
      expect(cubit.state.selectedChannelId, 'introductions');
    });
    test('rejects incomplete and unknown room coordinates', () {
      expect(selectChatRoom(cubit, channelId: 'general'), isFalse);
      expect(
        selectChatRoom(cubit, communityId: 'unknown', channelId: 'general'),
        isFalse,
      );
      expect(
        selectChatRoom(
          cubit,
          communityId: 'community-test',
          channelId: 'unknown',
        ),
        isFalse,
      );
      expect(cubit.state.selectedChannelId, 'general');
    });
    test('the base route opens the catalog default', () {
      expect(selectChatRoom(cubit), isTrue);
      expect(cubit.state.selectedChannelId, 'general');
    });
  });
}
