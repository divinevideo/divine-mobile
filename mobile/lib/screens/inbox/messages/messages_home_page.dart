// ABOUTME: Wires account-scoped Direct / Rooms navigation into Messages.
// ABOUTME: Keeps the Concord POC behind its existing internal access gate.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/blocs/messages/messages_navigation_cubit.dart';
import 'package:openvine/features/chat/rooms_view.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/screens/inbox/messages/messages_home_view.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

class MessagesHomePage extends ConsumerWidget {
  const MessagesHomePage({required this.direct, super.key});
  final Widget direct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentAuthStateProvider);
    final auth = ref.watch(authServiceProvider);
    final account = auth.isAuthenticated ? auth.currentPublicKeyHex : null;
    final enabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.concordChat),
    );
    final restricted = ref.watch(isDmRestrictedProvider);
    // Do not instantiate chat state or new navigation when the POC is disabled.
    if (!enabled || restricted || account == null || account.isEmpty) {
      return direct;
    }
    final preferences = ref.watch(messagesPreferenceServiceProvider);
    return BlocProvider(
      key: ValueKey((account, preferences)),
      create: (_) => MessagesNavigationCubit(
        account: account,
        preferences: preferences,
      ),
      child: MessagesHomeView(
        direct: direct,
        // The backend currently exposes a fixed POC catalog in ChatState.
        // The public-test disclosure remains until real membership data exists.
        rooms: RoomsView(
          communities: const ChatState().communities,
          onRoomSelected: (community, channel) => runDetached(
            context.pushNamed<void>(
              'chat',
              queryParameters: {
                'community': community,
                'channel': channel,
              },
            ),
            'open community room',
            logName: 'MessagesHomePage',
            category: LogCategory.ui,
          ),
        ),
      ),
    );
  }
}
