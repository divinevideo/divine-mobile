import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/live_chat/live_chat_bloc.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/live/widgets/live_chat_message_tile.dart';

class LiveChatPanel extends StatefulWidget {
  const LiveChatPanel({
    super.key,
  });

  @override
  State<LiveChatPanel> createState() => _LiveChatPanelState();
}

class _LiveChatPanelState extends State<LiveChatPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: BlocBuilder<LiveRoomBloc, LiveRoomState>(
        builder: (context, roomState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chat',
                style: VineTheme.titleLargeFont(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: BlocBuilder<LiveChatBloc, LiveChatState>(
                  builder: (context, state) {
                    if (state.status == LiveChatStatus.loading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: VineTheme.primary,
                        ),
                      );
                    }

                    final activeSessionAddress = state.sessionAddress;
                    final visibleMessages = state.messages
                        .where((message) {
                          return message.sessionAddress ==
                                  activeSessionAddress &&
                              !roomState.hiddenChatParticipantPubkeys.contains(
                                message.pubkey,
                              ) &&
                              !roomState.hiddenParticipantPubkeys.contains(
                                message.pubkey,
                              );
                        })
                        .toList(growable: false);

                    if (visibleMessages.isEmpty) {
                      return Center(
                        child: Text(
                          state.messages
                                  .where(
                                    (message) =>
                                        message.sessionAddress ==
                                        activeSessionAddress,
                                  )
                                  .isEmpty
                              ? 'No messages yet. Break the silence.'
                              : context.l10n.liveHiddenChatNotice,
                          style: VineTheme.bodyMediumFont(
                            color: VineTheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: visibleMessages.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final message = visibleMessages[index];
                        return LiveChatMessageTile(
                          message: message,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: VineTheme.bodyMediumFont(),
                      decoration: InputDecoration(
                        hintText: 'Say something',
                        hintStyle: VineTheme.bodyMediumFont(
                          color: VineTheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: VineTheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  BlocBuilder<LiveChatBloc, LiveChatState>(
                    builder: (context, state) {
                      return DivineButton(
                        label: 'Send',
                        onPressed: state.isSending
                            ? null
                            : () {
                                context.read<LiveChatBloc>().add(
                                  LiveChatMessageSendRequested(
                                    _controller.text,
                                  ),
                                );
                                _controller.clear();
                              },
                        isLoading: state.isSending,
                        size: DivineButtonSize.small,
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
