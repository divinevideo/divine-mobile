// MPL-2.0
import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';

/// Native (non-WebView) community chat: community/channel lists,
/// timeline, composer, thread view, reactions, invite acceptance.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  static const path = '/chat';
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _inviteController = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    _inviteController.dispose();
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
              state.threadRootId == null ? 'Community chat' : 'Thread',
            ),
            leading: state.threadRootId == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: cubit.closeThread,
                  ),
          ),
          drawer: Drawer(
            child: ListView(
              children: [
                const DrawerHeader(child: Text('Communities')),
                for (final c in state.communities) ...[
                  ListTile(title: Text(c.name), subtitle: Text(c.id)),
                  for (final ch in c.channels)
                    ListTile(
                      leading: const Icon(Icons.tag),
                      title: Text(ch),
                      selected:
                          state.selectedCommunityId == c.id &&
                          state.selectedChannelId == ch,
                      onTap: () {
                        cubit.selectChannel(c.id, ch);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _inviteController,
                    decoration: const InputDecoration(
                      labelText: 'Invite (community id)',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    onPressed: () {
                      final id = _inviteController.text.trim();
                      if (id.isEmpty) return;
                      unawaited(cubit.acceptInvite(id));
                    },
                    child: Text(
                      state.acceptedInvite
                          ? 'Invite accepted'
                          : 'Accept invite',
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in state.communities)
                      for (final ch in c.channels)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: ChoiceChip(
                            label: Text('#$ch'),
                            selected:
                                state.selectedCommunityId == c.id &&
                                state.selectedChannelId == ch,
                            onSelected: (_) => cubit.selectChannel(c.id, ch),
                          ),
                        ),
                  ],
                ),
              ),
              Expanded(
                child: messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Nothing looping yet. Go find your people.',
                        ),
                      )
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
                            trailing: IconButton(
                              icon: const Icon(Icons.favorite_border),
                              tooltip: 'React',
                              onPressed: () => unawaited(
                                cubit.react(
                                  targetId: m.id,
                                  emoji: '❤️',
                                  now:
                                      DateTime.now().millisecondsSinceEpoch ~/
                                      1000,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                      ),
                    ),
                  ),
                  DivineIconButton(
                    icon: DivineIconName.paperPlaneTilt,
                    semanticLabel: 'Send message',
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
