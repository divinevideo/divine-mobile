// MPL-2.0
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/l10n/l10n.dart';

/// Native conversation for the internal Concord POC selected from Messages.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  static const path = '/chat';
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final cubit = context.read<ChatCubit>();
        final messages = cubit.visibleMessages();
        return Scaffold(
          appBar: AppBar(
            title: Text(
              '#${state.selectedChannelId}',
            ),
            leading: state.threadRootId == null
                ? null
                : DivineIconButton(
                    icon: DivineIconName.arrowLeft,
                    semanticLabel: context.l10n.commonBack,
                    onPressed: cubit.closeThread,
                  ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.messagesPublicTestDisclosure),
              ),
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
                    ? Center(child: Text(context.l10n.inboxEmptyTitle))
                    : ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, i) {
                          final m = messages[i];
                          final r = state.reactions[m.id];
                          return ListTile(
                            title: Text(m.effectiveBody),
                            subtitle: Text(
                              state.pendingIds.contains(m.id)
                                  ? (state.sending
                                        ? context.l10n.authSending
                                        : context.l10n.dmStatusFailed)
                                  : (r == null ? m.author : '$r'),
                            ),
                            trailing: state.pendingIds.contains(m.id)
                                ? DivineButton(
                                    onPressed: state.sending
                                        ? null
                                        : () => cubit.retry(m.id),
                                    label: context.l10n.dmSendFailedRetry,
                                    type: DivineButtonType.link,
                                    size: DivineButtonSize.small,
                                  )
                                : null,
                          );
                        },
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled:
                          !state.sending && !state.loading && !state.loadFailed,
                      decoration: InputDecoration(
                        hintText: context.l10n.profileMessageLabel,
                      ),
                    ),
                  ),
                  DivineIconButton(
                    icon: DivineIconName.paperPlaneTilt,
                    semanticLabel: context.l10n.dmMessageSendLabel,
                    onPressed:
                        state.sending || state.loading || state.loadFailed
                        ? null
                        : () async {
                            final text = _controller.text.trim();
                            if (text.isEmpty) return;
                            final accepted = await context
                                .read<ChatCubit>()
                                .send(
                                  communityId: state.selectedCommunityId,
                                  channelId: state.selectedChannelId,
                                  author: '',
                                  body: text,
                                  nowMilliseconds:
                                      DateTime.now().millisecondsSinceEpoch,
                                );
                            if (mounted && accepted) _controller.clear();
                          },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
