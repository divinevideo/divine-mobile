import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/repositories/live_chat_repository.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/live_nostr_codec.dart';
import 'package:openvine/services/livekit_room_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'live_providers.g.dart';

@Riverpod(keepAlive: true)
LiveNostrCodec liveNostrCodec(Ref ref) {
  return const LiveNostrCodec();
}

@Riverpod(keepAlive: true)
LiveApiService liveApiService(Ref ref) {
  final nip98AuthService = ref.watch(nip98AuthServiceProvider);
  return LiveApiService(nip98AuthService: nip98AuthService);
}

@Riverpod(keepAlive: true)
LiveKitRoomService liveKitRoomService(Ref ref) {
  final service = LiveKitRoomService();
  ref.onDispose(service.dispose);
  return service;
}

@Riverpod(keepAlive: true)
LiveRepository liveRepository(Ref ref) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final codec = ref.watch(liveNostrCodecProvider);
  final liveApiService = ref.watch(liveApiServiceProvider);
  return LiveRepository(
    nostrClient: nostrClient,
    codec: codec,
    liveApiService: liveApiService,
  );
}

@Riverpod(keepAlive: true)
LiveChatRepository liveChatRepository(Ref ref) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final codec = ref.watch(liveNostrCodecProvider);
  return LiveChatRepository(
    nostrClient: nostrClient,
    codec: codec,
  );
}
