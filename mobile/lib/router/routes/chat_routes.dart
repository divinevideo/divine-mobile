// MPL-2.0
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_screen.dart';
import 'package:openvine/features/chat/concord_session.dart';
import 'package:openvine/providers/auth_providers.dart';

/// Chat routes bound to the active Divine session (no new login flow):
/// relay + signer come from the already signed-in identity.
List<RouteBase> chatRoutes(Ref ref) => [
  GoRoute(
    path: ChatScreen.path,
    name: 'chat',
    builder: (ctx, st) {
      final auth = ref.read(authServiceProvider);
      return BlocProvider(
        create: (_) => ChatCubit(
          buildConcordRepository(
            pubkey: auth.currentPublicKeyHex,
            signer: auth.currentIdentity,
            streamPubkey: auth.currentPublicKeyHex ?? '',
          ),
        ),
        child: const ChatScreen(),
      );
    },
  ),
];
