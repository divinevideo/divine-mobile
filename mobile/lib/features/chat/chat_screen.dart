// MPL-2.0
import 'dart:async';

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
                              r == null ? m.author : '$r',
                            ),
                            onTap: () => cubit.openThread(m.id),
                          );
                        },
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: context.l10n.profileMessageLabel,
                      ),
                    ),
                  ),
                  DivineIconButton(
                    icon: DivineIconName.paperPlaneTilt,
                    semanticLabel: context.l10n.dmMessageSendLabel,
                    onPressed: () {
                      final text = _controller.text.trim();
                      if (text.isEmpty) return;
                      _controller.clear();
                      unawaited(
                        context.read<ChatCubit>().send(
                          communityId: state.selectedCommunityId,
                          channelId: state.selectedChannelId,
                          author: '',
                          body: text,
                          now: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                        ),
                      );
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
