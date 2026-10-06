import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/repositories/live_chat_repository.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/live_nostr_codec.dart';
import 'package:openvine/services/livekit_room_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  group('live providers', () {
    late _MockNostrClient mockNostrClient;
    late _MockNip98AuthService mockNip98AuthService;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(const Duration(seconds: 5));
    });

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockNip98AuthService = _MockNip98AuthService();
      when(
        () => mockNostrClient.queryEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          useCache: any(named: 'useCache'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => const <Event>[]);
      when(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(() => mockNostrClient.unsubscribe(any())).thenAnswer((_) async {});
    });

    test(
      'exposes live services and repositories from the dedicated provider file',
      () async {
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(mockNostrClient),
            nip98AuthServiceProvider.overrideWithValue(mockNip98AuthService),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(liveNostrCodecProvider), isA<LiveNostrCodec>());
        expect(container.read(liveApiServiceProvider), isA<LiveApiService>());
        expect(
          container.read(liveKitRoomServiceProvider),
          isA<LiveKitRoomService>(),
        );
        expect(container.read(liveRepositoryProvider), isA<LiveRepository>());
        expect(
          container.read(liveChatRepositoryProvider),
          isA<LiveChatRepository>(),
        );
      },
    );
  });
}
