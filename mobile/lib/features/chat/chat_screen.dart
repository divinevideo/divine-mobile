// MPL-2.0
import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';

/// Native (non-WebView) community chat POC: timeline + composer.
/// Community/channel lists and thread/reaction rendering consume the
/// same [ChatState]; invite acceptance goes through [ChatCubit].
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
    return Scaffold(
      appBar: AppBar(title: const Text('Community chat')),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatCubit, ChatState>(
              builder: (context, state) => ListView.builder(
                itemCount: state.messages.length,
                itemBuilder: (context, i) {
                  final m = state.messages[i];
                  final r = state.reactions[m.id];
                  return ListTile(
                    title: Text(m.effectiveBody),
                    subtitle: Text(r == null ? m.author : '$r'),
                  );
                },
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(hintText: 'Message'),
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
                      communityId: 'community-test',
                      channelId: 'general',
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
  }
}
