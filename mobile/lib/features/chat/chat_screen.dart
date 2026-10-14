// ABOUTME: Full-screen mobile room conversation with Divine's shared composer.
// ABOUTME: Keeps channel context, sender identity, and delivery state readable.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_message_tile.dart';
import 'package:openvine/features/chat/public_room_notice.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_input_bar.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Native conversation for the Concord POC selected from Messages.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  static const String path = RoutePaths.chat;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final cubit = context.read<ChatCubit>();
    final state = cubit.state;
    final accepted = await cubit.send(
      communityId: state.selectedCommunityId,
      channelId: state.selectedChannelId,
      author: '',
      body: text,
      nowMilliseconds: DateTime.now().millisecondsSinceEpoch,
    );
    if (mounted && accepted) _controller.clear();
  }

  void _submit(String text) {
    final state = context.read<ChatCubit>().state;
    if (state.sending || state.loading || state.loadFailed) return;
    final body = text.trim();
    if (body.isEmpty) return;
    runDetached(
      _send(body),
      'send room message',
      logName: 'ChatScreen',
      category: LogCategory.ui,
    );
  }

  KeyEventResult _handleComposerKey(FocusNode node, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if ((event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter) ||
        keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        !_controller.value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    // Only a fresh press sends; holding Enter must not republish a draft.
    if (event is KeyDownEvent) _submit(_controller.text);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ChatCubit, ChatState>(
    builder: (context, state) {
      final cubit = context.read<ChatCubit>();
      final messages = cubit.visibleMessages();
      final community = state.communities
          .where((entry) => entry.id == state.selectedCommunityId)
          .firstOrNull;
      return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          toolbarHeight:
              MediaQuery.textScalerOf(context).scale(24) +
              MediaQuery.textScalerOf(context).scale(16) +
              16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#${state.selectedChannelId}',
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              if (community != null)
                Text(
                  community.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
            ],
          ),
          leading: state.threadRootId == null
              ? null
              : DivineIconButton(
                  icon: DivineIconName.arrowLeft,
                  semanticLabel: context.l10n.commonBack,
                  onPressed: cubit.closeThread,
                ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                const PublicRoomNotice(),
                if (state.loading) const DivineLinearProgressIndicator(),
                if (state.loadFailed) ...[
                  Text(context.l10n.dmConversationLoadError),
                  DivineButton(
                    onPressed: state.loading ? null : cubit.start,
                    label: context.l10n.commonRetry,
                    type: DivineButtonType.link,
                  ),
                ],
                if (state.sendFailed) Text(context.l10n.dmSendFailedMessage),
                Expanded(
                  child: messages.isEmpty
                      ? _EmptyRoom(channel: state.selectedChannelId)
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message =
                                messages[messages.length - index - 1];
                            return ChatMessageTile(
                              key: ValueKey(message.id),
                              message: message,
                              reactions:
                                  state.reactions[message.id] ?? const {},
                              pending: state.pendingIds.contains(message.id),
                              sending: state.sending,
                              onRetry: () => runDetached(
                                cubit.retry(message.id),
                                'retry room message',
                                logName: 'ChatScreen',
                                category: LogCategory.ui,
                              ),
                            );
                          },
                        ),
                ),
                Focus(
                  canRequestFocus: false,
                  onKeyEvent: _handleComposerKey,
                  child: MessageInputBar(
                    controller: _controller,
                    clearOnSend: false,
                    textCapitalization: TextCapitalization.sentences,
                    enabled:
                        !state.sending && !state.loading && !state.loadFailed,
                    onSend: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _EmptyRoom extends StatelessWidget {
  const _EmptyRoom({required this.channel});
  final String channel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DivineIcon(
            icon: DivineIconName.chatCircle,
            size: 40,
            color: context.vineColors.onSurfaceMuted,
          ),
          const SizedBox(height: 16),
          Text(
            '#$channel',
            style: VineTheme.titleLargeFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.inboxEmptyTitle,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    ),
  );
}
